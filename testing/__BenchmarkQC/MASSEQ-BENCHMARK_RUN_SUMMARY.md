# MASSEQ Benchmark Run Summary

This document records the execution performed on March 19, 2026 in:

`/home/unix/bhaas/projects/DeepVariantEval/test_masseq`

The goal was to follow the DeepVariant MASSEQ case-study structure while substituting the actual DeepVariant invocation with the local `ctat-mutations-DV` workflow in long-read mode.

## Goal

Benchmark the local `ctat-mutations-DV` workflow on the public DeepVariant MASSEQ chr20 PacBio case-study data for HG004 on GRCh38.

## CTAT Workflow Used

`/home/unix/bhaas/GITHUB/MDL/ctat-mutations-DV/ctat-mutations-DV`

## Genome Library Used

```bash
CTAT_GENOME_LIB=/home/unix/bhaas/CTAT_GENOME_LIBS/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play/ctat_genome_lib_build_dir
```

## Important Caveat

The official MASSEQ case study uses `--regions=chr20` directly with `run_deepvariant`.

The current CTAT WDL passes `--intervals` through as:

```bash
--regions=<path>
```

When this was attempted with a one-line file containing `chr20`, DeepVariant MASSEQ failed because it tried to parse the file path itself as a region literal.

Because the public case-study BAM is already chr20-only, the successful CTAT rerun omitted `--intervals` entirely and relied on the BAM content to keep the run restricted to chr20.

This means:

- the CTAT variant-calling run is still chr20-only
- the benchmarking command below was run against the provided exon/10x BED as downloaded
- the resulting metrics are not directly comparable to an official genome-wide MASSEQ benchmark unless the benchmark regions are also restricted consistently to chr20

## High-Level Execution Flow

1. Create the workspace directories.
2. Download the GRCh38 reference used by the case study.
3. Download the HG004 GIAB benchmark truth resources.
4. Download the public HG004 MASSEQ chr20 BAM and BAI.
5. Download the MASSEQ exon/10x evaluation BED.
6. Validate the input BAM.
7. Attempt a CTAT run with `--intervals`; observe failure due to `--regions` file-path handling.
8. Rerun CTAT in long-read mode without `--intervals`.
9. Benchmark the resulting VCF with `hap.py`.
10. Record outputs and caveats.

## Exact Commands Used

### 1. Create directories

```bash
mkdir -p input benchmark reference output happy logs
```

### 2. Download the reference

```bash
FTPDIR=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids

curl -L --fail --retry 3 -C - \
  "$FTPDIR/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz" | \
  gunzip > reference/GRCh38_no_alt_analysis_set.fasta

curl -L --fail --retry 3 -C - \
  -o reference/GRCh38_no_alt_analysis_set.fasta.fai \
  "$FTPDIR/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.fai"
```

### 3. Download the HG004 GIAB truth set

```bash
GIAB=https://ftp-trace.ncbi.nlm.nih.gov/giab/ftp/release/AshkenazimTrio/HG004_NA24143_mother/NISTv4.2.1/GRCh38

curl -L --fail --retry 3 -C - \
  -o benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed \
  "$GIAB/HG004_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed"

curl -L --fail --retry 3 -C - \
  -o benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark.vcf.gz \
  "$GIAB/HG004_GRCh38_1_22_v4.2.1_benchmark.vcf.gz"

curl -L --fail --retry 3 -C - \
  -o benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi \
  "$GIAB/HG004_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi"
```

### 4. Download the MASSEQ public inputs

```bash
HTTPDIR=https://storage.googleapis.com/deepvariant/masseq-case-study

curl -L --fail --retry 3 -C - \
  -o input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam \
  "$HTTPDIR/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam"

curl -L --fail --retry 3 -C - \
  -o input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam.bai \
  "$HTTPDIR/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam.bai"

curl -L --fail --retry 3 -C - \
  -o input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.depth.10x.exons.bed \
  "$HTTPDIR/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.depth.10x.exons.bed"
```

### 5. Validate the input BAM

```bash
samtools quickcheck -v \
  input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam

samtools idxstats \
  input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam | \
  sed -n '1,10p'
```

### 6. Failed attempt using a one-line chr20 region file

A file was created containing:

```text
chr20
```

Attempted command:

```bash
/home/unix/bhaas/GITHUB/MDL/ctat-mutations-DV/ctat-mutations-DV \
  --bam input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam \
  --genome_lib_dir "$CTAT_GENOME_LIB" \
  --sample_id HG004 \
  --variant_ready_bam \
  --is_long_reads \
  --intervals input/chr20.regions.list \
  --deepvariant_shards "$(nproc)" \
  --cpu "$(nproc)" \
  --no_annotate_variants \
  --no_cravat \
  --no_filter_cancer_variants \
  -O output/ctat_hg004
```

Observed failure:

```text
ValueError: Could not parse ".../chr20.regions.list" as a region literal.
```

### 7. Successful CTAT long-read rerun

Because the BAM is already chr20-only, the successful rerun omitted `--intervals`:

```bash
export CTAT_GENOME_LIB=/home/unix/bhaas/CTAT_GENOME_LIBS/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play/ctat_genome_lib_build_dir

/home/unix/bhaas/GITHUB/MDL/ctat-mutations-DV/ctat-mutations-DV \
  --bam input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam \
  --genome_lib_dir "$CTAT_GENOME_LIB" \
  --sample_id HG004 \
  --variant_ready_bam \
  --is_long_reads \
  --deepvariant_shards "$(nproc)" \
  --cpu "$(nproc)" \
  --no_annotate_variants \
  --no_cravat \
  --no_filter_cancer_variants \
  -O output/ctat_hg004_chr20bam
```

Internally, CTAT ran DeepVariant MASSEQ as:

```bash
/opt/deepvariant/bin/run_deepvariant \
  --model_type=MASSEQ \
  --ref=.../ref_genome.fa \
  --reads=.../HG004...chr20.bam \
  --output_vcf=HG004.deepvariant.init.vcf.gz \
  --sample_name=HG004 \
  --disable_small_model \
  --num_shards=16 \
  --intermediate_results_dir=intermediate_results
```

### 8. Initial broad benchmark with `hap.py`

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$(pwd):$(pwd)" \
  -w "$(pwd)" \
  jmcdani20/hap.py:v0.3.12 \
  /opt/hap.py/bin/hap.py \
    benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark.vcf.gz \
    output/ctat_hg004_chr20bam/HG004.deepvariant.init.vcf.gz \
    -f input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.depth.10x.exons.bed \
    -r reference/GRCh38_no_alt_analysis_set.fasta \
    -o happy/happy.output \
    --engine=vcfeval \
    --pass-only \
    --threads="$(nproc)"
```

### 9. Corrected chr20-restricted benchmark with `hap.py`

This is the case-study-comparable benchmark command.

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$(pwd):$(pwd)" \
  -w "$(pwd)" \
  jmcdani20/hap.py:v0.3.12 \
  /opt/hap.py/bin/hap.py \
    benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark.vcf.gz \
    output/ctat_hg004_chr20bam/HG004.deepvariant.init.vcf.gz \
    -f benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed \
    -r reference/GRCh38_no_alt_analysis_set.fasta \
    -o happy/happy.output.chr20 \
    --engine=vcfeval \
    --pass-only \
    -l chr20 \
    --target-regions=input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.depth.10x.exons.bed \
    --threads="$(nproc)"
```

## Key Output Files

### CTAT outputs

- `output/ctat_hg004_chr20bam/HG004.deepvariant.init.vcf.gz`
- `output/ctat_hg004_chr20bam/HG004.deepvariant.init.vcf.gz.tbi`
- `output/ctat_hg004_chr20bam/HG004.variant-ready.bam`
- `output/ctat_hg004_chr20bam/HG004.variant-ready.bam.bai`

### Benchmark outputs

- `happy/happy.output.summary.csv`
- `happy/happy.output.extended.csv`
- `happy/happy.output.metrics.json.gz`
- `happy/happy.output.vcf.gz`
- `happy/happy.output.roc.all.csv.gz`
- `happy/happy.output.chr20.summary.csv`
- `happy/happy.output.chr20.extended.csv`
- `happy/happy.output.chr20.metrics.json.gz`
- `happy/happy.output.chr20.vcf.gz`
- `happy/happy.output.chr20.roc.all.csv.gz`

## Initial Broad Benchmark Summary

From `happy/happy.output.summary.csv`:

### SNP

- Recall: `0.022291`
- Precision: `0.967314`
- F1: `0.043577`
- Truth TP/FN: `947 / 41537`
- Query FP/UNK: `32 / 8891`

### INDEL

- Recall: `0.018411`
- Precision: `0.709877`
- F1: `0.035891`
- Truth TP/FN: `111 / 5918`
- Query FP/UNK: `47 / 1221`

## Why These Metrics Are Misleading

These metrics are not directly comparable to the intended MASSEQ case-study benchmark because:

- the query VCF is chr20-only
- the evaluation BED spans many chromosomes
- `hap.py` reported many warnings of the form `No calls for location chrN in query!`

This drives recall very low because the benchmark is effectively asking a chr20-only callset to cover non-chr20 truth regions.

## Corrected chr20 Benchmark Summary

From `happy/happy.output.chr20.summary.csv`:

### SNP

- Recall: `0.934132`
- Precision: `0.987342`
- F1: `0.960000`
- Truth TP/FN: `936 / 66`
- Query FP/UNK: `12 / 31`

### INDEL

- Recall: `0.770370`
- Precision: `0.884298`
- F1: `0.823412`
- Truth TP/FN: `104 / 31`
- Query FP/UNK: `14 / 41`

## Comparison To The Official Case Study

The corrected chr20-restricted benchmark matches the case-study reported metrics exactly.

Case-study values:

- `INDEL`: recall `0.770370`, precision `0.884298`, F1 `0.823412`
- `SNP`: recall `0.934132`, precision `0.987342`, F1 `0.960000`

Corrected local chr20 benchmark values:

- `INDEL`: recall `0.770370`, precision `0.884298`, F1 `0.823412`
- `SNP`: recall `0.934132`, precision `0.987342`, F1 `0.960000`

## Recommended Next Fix

For a like-for-like MASSEQ benchmark, the comparison regions should be restricted to chr20 consistently, for example by intersecting or filtering the exon/10x BED to chr20 before running `hap.py`.

That refinement has now been applied via the corrected `happy.output.chr20.*` benchmark outputs.

## Notes for Re-running With a New CTAT Version

To rerun this benchmark with a new `ctat-mutations-DV` version:

1. Reuse the downloaded reference, truth resources, BAM, and BED files.
2. Point to the new CTAT executable.
3. Write to a fresh output directory such as `output/ctat_hg004_chr20bam_vNEXT`.
4. Run the same `hap.py` command, or preferably a chr20-restricted benchmark variant once that refinement is added.

Minimal rerun command:

```bash
export CTAT_GENOME_LIB=/home/unix/bhaas/CTAT_GENOME_LIBS/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play/ctat_genome_lib_build_dir

/path/to/new/ctat-mutations-DV \
  --bam input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam \
  --genome_lib_dir "$CTAT_GENOME_LIB" \
  --sample_id HG004 \
  --variant_ready_bam \
  --is_long_reads \
  --deepvariant_shards "$(nproc)" \
  --cpu "$(nproc)" \
  --no_annotate_variants \
  --no_cravat \
  --no_filter_cancer_variants \
  -O output/ctat_hg004_chr20bam_vNEXT
```

## Operational Notes

- The patched CTAT Cromwell backend now launches task containers with the current host UID/GID instead of hardcoded `1000:1000`.
- The successful MASSEQ CTAT run produced a VCF with `33676` variants according to the DeepVariant postprocess log.
- The first failure around `--intervals` is likely worth reporting upstream to DeepVariant because MASSEQ handled `--regions` differently from the earlier RNASEQ/BED case.
