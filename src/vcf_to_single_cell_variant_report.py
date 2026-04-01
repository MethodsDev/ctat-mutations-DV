#!/usr/bin/env python3

import sys
import re
import logging
import argparse
import gzip
import multiprocessing
import os
import tempfile
import time
import psutil
import pysam


logging.basicConfig(format="\n %(levelname)s : %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)


BAM_READER = None
CELL_BARCODE_BAM_TAG = "CB"
UMI_BAM_TAG = "XM"


def progress_bar(progress_percent):
    sys.stdout.write("\r")
    sys.stdout.flush()
    if progress_percent == 100:
        sys.stdout.write("[{}{}]{}\n".format("*" * progress_percent, " " * (100 - progress_percent), str(progress_percent) + "%"))
    else:
        sys.stdout.write("[{}{}]{}".format("*" * progress_percent, " " * (100 - progress_percent), str(progress_percent) + "%"))


def chunk_lines(lines, num_chunks):
    if not lines:
        return []

    num_chunks = max(1, min(num_chunks, len(lines)))
    chunk_size = (len(lines) + num_chunks - 1) // num_chunks

    return [lines[i:i + chunk_size] for i in range(0, len(lines), chunk_size)]


def parse_sc_read_name(read):
    cb = read.get_tag(CELL_BARCODE_BAM_TAG) if read.has_tag(CELL_BARCODE_BAM_TAG) else None
    umi = read.get_tag(UMI_BAM_TAG) if read.has_tag(UMI_BAM_TAG) else None
    if cb or umi:
        return "{}^{}^{}".format(cb or "NA", umi or "NA", read.query_name)

    return read.query_name


def init_worker_bam_reader(bam_file, cell_barcode_bam_tag, umi_bam_tag):
    global BAM_READER, CELL_BARCODE_BAM_TAG, UMI_BAM_TAG
    BAM_READER = pysam.AlignmentFile(bam_file, "rb")
    CELL_BARCODE_BAM_TAG = cell_barcode_bam_tag
    UMI_BAM_TAG = umi_bam_tag


def close_worker_bam_reader():
    global BAM_READER
    if BAM_READER is not None:
        BAM_READER.close()
        BAM_READER = None


def locate_variant_in_read(readstart, cigar, target_position):
    currentpos = int(readstart)
    readpos = 1
    base_readpos = None
    adjacent_base_type = "M"

    for match in re.finditer(r"(\d+)([MIDNSHP=X])", cigar):
        cigarnumval = int(match.group(1))
        cigarletter = match.group(2)

        if currentpos > target_position:
            break

        if cigarletter in ("I", "S"):
            readpos += cigarnumval
        elif cigarletter in ("D", "N"):
            currentpos += cigarnumval
        elif cigarletter in ("M", "=", "X"):
            segment_end_pos = readpos + cigarnumval - 1
            for _ in range(cigarnumval):
                if currentpos == target_position:
                    base_readpos = readpos
                    if base_readpos == segment_end_pos:
                        next_match = re.match(r"(\d+)([MIDNSHP=X])", cigar[match.end():])
                        if next_match is not None:
                            adjacent_base_type = next_match.group(2)
                    break
                currentpos += 1
                readpos += 1

            if base_readpos is not None:
                break

    return base_readpos, adjacent_base_type


def summarize_variant(vcf_line):
    vcf_line = vcf_line.decode("utf-8") if isinstance(vcf_line, bytes) else vcf_line
    fields = vcf_line.rstrip().split("\t")

    chrom = fields[0]
    position = int(fields[1])
    ref_bases = fields[3]
    alt_bases = fields[4]

    if alt_bases == "*":
        return [f"{chrom}:{position}:{ref_bases}:{alt_bases}", [], []]

    variant_type = "M"
    if len(ref_bases) > len(alt_bases):
        variant_type = "D"
    elif len(ref_bases) < len(alt_bases):
        variant_type = "I"

    reads_with_variant = []
    reads_without_variant = []

    for read in BAM_READER.fetch(chrom, position - 1, position):
        if read.query_sequence is None or read.cigarstring is None:
            continue

        readname = parse_sc_read_name(read)
        base_readpos, adjacent_base_type = locate_variant_in_read(read.reference_start + 1, read.cigarstring, position)
        if base_readpos is None:
            continue

        read_suffix = read.query_sequence[(base_readpos - 1):]
        if read_suffix.startswith(alt_bases) and variant_type == adjacent_base_type:
            reads_with_variant.append(readname)
        elif read_suffix.startswith(ref_bases):
            reads_without_variant.append(readname)

    return [f"{chrom}:{position}:{ref_bases}:{alt_bases}", reads_with_variant, reads_without_variant]


def process_chunk(chunk_index, vcf_lines):
    return (chunk_index, [summarize_variant(line) for line in vcf_lines])


class VariantReportBuilder:
    def __init__(self, input_vcf, bam_file, threads, chunks, output_file, cell_barcode_bam_tag, umi_bam_tag):
        self.input_vcf = input_vcf
        self.bam_file = bam_file
        self.threads = threads
        self.chunks = chunks
        self.output_file = output_file
        self.cell_barcode_bam_tag = cell_barcode_bam_tag
        self.umi_bam_tag = umi_bam_tag

        message_str = f"""
            {'Single Cell Variant Report':^30s}\n\t{'VCF':11s} : {input_vcf}\n\t{'BAM':11s} : {bam_file}\n\t{'CPU count':11s} : {threads}\n\t{'Chunking':11s} : {chunks}\n\t{'Cell tag':11s} : {cell_barcode_bam_tag}\n\t{'UMI tag':11s} : {umi_bam_tag}"""
        logger.info(message_str)

    def load_vcf(self):
        self.variant_lines = []
        with gzip.open(self.input_vcf, "rt") as vcf:
            for line in vcf:
                if not line.startswith("#"):
                    self.variant_lines.append(line)
        return self

    def build(self):
        logger.info("\tBuilding single-cell variant report")
        idx_list = chunk_lines(self.variant_lines, self.chunks)
        total_chunks = len(idx_list)
        self._total_variants = sum(len(c) for c in idx_list)
        self.variant_lines = None  # free raw VCF lines — no longer needed

        self._tmp_path = tempfile.mktemp(suffix=".tsv")
        tmp_fh = open(self._tmp_path, "w")
        chunks_done = [0]  # list for mutability inside closure

        def logging_return(result):
            chunk_index, chunk_result = result
            for within_idx, (pos_token, reads_w_var, reads_wo_var) in enumerate(chunk_result):
                tmp_fh.write(
                    "{}\t{}\t{}\t{}\t{}\t{}\t{}\n".format(
                        chunk_index,
                        within_idx,
                        pos_token,
                        len(reads_w_var),
                        ",".join(reads_w_var),
                        len(reads_wo_var),
                        ",".join(reads_wo_var),
                    )
                )
            tmp_fh.flush()
            chunks_done[0] += 1

        if self.threads > 1:
            pool = multiprocessing.Pool(
                self.threads,
                initializer=init_worker_bam_reader,
                initargs=(self.bam_file, self.cell_barcode_bam_tag, self.umi_bam_tag),
            )

            def error_handler(error):
                logger.error("ERROR_HANDLER - CAUGHT: " + str(error))
                tmp_fh.close()
                pool.terminate()
                pool.join()
                sys.exit(2)
        else:
            init_worker_bam_reader(self.bam_file, self.cell_barcode_bam_tag, self.umi_bam_tag)

        message_str = f"\t\tStart Time: {time.asctime(time.localtime(time.time()))}"
        logger.info(message_str)

        for chunk_index, chunk_variant_lines in enumerate(idx_list):
            if self.threads > 1:
                pool.apply_async(
                    process_chunk,
                    args=(chunk_index, chunk_variant_lines),
                    callback=logging_return,
                    error_callback=error_handler,
                )
            else:
                logging_return(process_chunk(chunk_index, chunk_variant_lines))

        if self.threads > 1:
            pool.close()
            while chunks_done[0] < total_chunks:
                progress_percent = int(chunks_done[0] / total_chunks * 100)
                mem = psutil.virtual_memory()
                used_gb = mem.used / 1024**3
                total_gb = mem.total / 1024**3
                bar = "[{}{}]{} | RAM: {:.1f}/{:.1f} GB ({:.0f}%)".format(
                    "*" * progress_percent,
                    " " * (100 - progress_percent),
                    str(progress_percent) + "%",
                    used_gb,
                    total_gb,
                    mem.percent,
                )
                sys.stdout.write("\r" + bar)
                sys.stdout.flush()
                time.sleep(2)
            mem = psutil.virtual_memory()
            used_gb = mem.used / 1024**3
            total_gb = mem.total / 1024**3
            sys.stdout.write("\r[{}]100% | RAM: {:.1f}/{:.1f} GB ({:.0f}%)\n".format(
                "*" * 100, used_gb, total_gb, mem.percent
            ))
            sys.stdout.flush()
            pool.join()
        else:
            close_worker_bam_reader()

        tmp_fh.close()
        return self

    def write_output(self):
        logger.info("\tSorting and writing output report: {}".format(self.output_file))

        with open(self._tmp_path) as f:
            lines = f.readlines()
        os.unlink(self._tmp_path)

        if len(lines) != self._total_variants:
            raise RuntimeError(
                "The output report has a different number of variants than the input VCF: actual={} generated={}".format(
                    self._total_variants, len(lines)
                )
            )

        lines.sort(key=lambda l: (int(l.split("\t", 2)[0]), int(l.split("\t", 2)[1])))

        with open(self.output_file, "w") as ofh:
            print(
                "\t".join(
                    [
                        "chr_pos_variant",
                        "num_reads_with_variant",
                        "reads_with_variant",
                        "num_ref_matching_reads",
                        "ref_matching_reads",
                    ]
                ),
                file=ofh,
            )
            for line in lines:
                # strip the two leading sort index columns (chunk_index, within_idx)
                ofh.write(line.split("\t", 2)[2])


def main():
    parser = argparse.ArgumentParser(
        description="Generate a single-cell variant support report from a VCF and BAM.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--vcf", type=str, required=True, help="Input VCF.gz file.")
    parser.add_argument("--bam", type=str, required=True, help="Input BAM file.")
    parser.add_argument("--output", type=str, required=True, help="Output report filename.")
    parser.add_argument("--threads", type=int, default=8, help="Number of CPUs to use.")
    parser.add_argument("--chunks", type=int, default=1000, help="Number of chunks to divide the VCF into.")
    parser.add_argument("--cell_barcode_bam_tag", type=str, default="CB", help="BAM tag containing the cell barcode.")
    parser.add_argument("--umi_bam_tag", type=str, default="XM", help="BAM tag containing the UMI.")
    parser.add_argument("--debug", "-d", action="store_true", default=False, help="Debug mode, verbose.")

    args = parser.parse_args()

    if args.debug:
        logger.setLevel(logging.DEBUG)

    print(
        "\n####################################################################################\n\tSingle-Cell Variant Report\n####################################################################################"
    )

    VariantReportBuilder(
        input_vcf=args.vcf,
        bam_file=args.bam,
        threads=args.threads,
        chunks=args.chunks,
        output_file=args.output,
        cell_barcode_bam_tag=args.cell_barcode_bam_tag,
        umi_bam_tag=args.umi_bam_tag,
    ).load_vcf().build().write_output()


if __name__ == "__main__":
    main()
