# ctat-mutations

RNA-seq variant calling pipeline using DeepVariant with state-of-the-art accuracy.

**Version 5.0.0** - Major refactor with DeepVariant integration

## Overview

CTAT-Mutations is a comprehensive RNA-seq variant calling pipeline that:

- **Variant Calling**: Uses Google DeepVariant v1.10.0 with native RNA-seq model for short (Illumina) or long (PacBio) RNA-seq reads
- **Alignment**: Supports STAR (Illumina short reads) and Minimap2 (PacBio long reads)
- **Annotation**: Integrates dbSNP, gnomAD, COSMIC, CRAVAT, and custom RNA-specific annotations
- **Filtering**: Quality-based filtering using DeepVariant's neural network scores
- **Cancer Variant Reporting**: Specialized filtering and IGV report generation for cancer variants



# Run with FASTQs
./ctat-mutations-DV \
    --left reads_R1.fastq.gz \
    --right reads_R2.fastq.gz \
    --genome_lib_dir /path/to/ctat_genome_lib \
    --sample_id my_sample \
    --cpu 16

# Run with BAM input
./ctat-mutations-DV \
    --bam aligned.bam \
    --genome_lib_dir /path/to/ctat_genome_lib \
    --sample_id my_sample

   #GPU acceleration is available: --deepvariant_use_gpu)
```


### Long Read Support (PacBio)

```bash
./ctat-mutations-DV \
    --left pacbio_reads.fastq.gz \
    --genome_lib_dir /path/to/ctat_genome_lib \
    --sample_id my_sample \
    --is_long_reads \
    --cpu 16
```

### Single-Cell BAM Tag Configuration

For single-cell mode, the pipeline can read cell barcode and UMI values directly from BAM tags.
Defaults are `CB` for the cell barcode tag and `XM` for the UMI tag.

```bash
./ctat-mutations-DV \
    --bam aligned.bam \
    --genome_lib_dir /path/to/ctat_genome_lib \
    --sample_id my_sample \
    --is_single_cells \
    --cell_barcode_bam_tag CB \
    --umi_bam_tag XM
```


## Key Parameters

### DeepVariant Configuration

- `--deepvariant_shards`: Internal parallelization level (default: 18)
- `--output_gvcf`: Generate gVCF output (default: false)
- `--deepvariant_min_gq`: Minimum genotype quality for filtering (default: 18, recommended)
- `--deepvariant_min_qual`: Minimum QUAL score (default: 20)
- `--deepvariant_min_dp`: Minimum depth (default: 5)
- `--deepvariant_use_gpu`: Request GPU-accelerated DeepVariant execution when supported by the execution environment


### General Options

- `--genome_lib_dir`: Path to CTAT genome library (see [genome lib guide](https://github.com/NCIP/ctat-mutations/wiki))
- `--cpu`: Number of CPUs for multi-threaded steps
- `--variant_ready_bam`: Skip preprocessing (use for pre-processed BAMs)
- `--is_long_reads`: Use minimap2 for PacBio data
- `--cell_barcode_bam_tag`: BAM tag containing the cell barcode in single-cell mode (default: `CB`)
- `--umi_bam_tag`: BAM tag containing the UMI in single-cell mode (default: `XM`)

## Resource Requirements

- **CPU**: 16+ cores recommended
- **Memory**: 32-64 GB
- **GPU** (optional): NVIDIA Tesla T4 or better for 10-100x speedup
- **Disk**: ~2-3x input BAM size

## Output Files

- `{sample_id}.vcf.gz`: DeepVariant variant calls
- `{sample_id}.g.vcf.gz`: gVCF file (if `--output_gvcf` enabled)
- `{sample_id}.filtered.vcf.gz`: Quality-filtered variants (GQ-based)
- `{sample_id}.annotated.vcf.gz`: Fully annotated variants
- `{sample_id}.cancer.vcf`: Cancer-specific filtered variants
- `{sample_id}.cancer.tsv`: Cancer variant table
- `{sample_id}_cancer_igv_report.html`: IGV visualization report

## Installation

### Using Docker (Easiest)

```bash
docker pull trinityctat/ctat_mutations_dv:latest
```

### From Source

```bash
git clone --recursive git@github.com:MethodsDev/ctat-mutations-DV.git
cd ctat-mutations-DV
make
```

### Required CTAT Genome Lib

For now, we reuse the ctat genome lib for the old ctat-mutations software, and so see these earlier [data library installation instructions](https://github.com/TrinityCTAT/ctat-mutations/wiki/CTAT-mutations-installation).


## Citations for CTAT-Mutations-DV workflow components

- **DeepVariant RNA-seq**: Qi, W., et al. (2023). A deep-learning method for the accurate and fast calling of variants from RNA sequencing data. Bioinformatics Advances.

- **STAR aligner for Illumina RNA-seq**: STAR aligner: STAR: ultrafast universal RNA-seq aligner. Dobin A, Davis CA, Schlesinger F, Drenkow J, Zaleski C, Jha S, Batut P, Chaisson M, Gingeras TR. Bioinformatics. 2013 Jan 1;29(1):15-21. doi: 10.1093/bioinformatics/bts635. Epub 2012 Oct 25. PMID: 23104886

- **Minimap2 for PacBio Kinnex/MAS-Iso-Seq**: Li H. Minimap2: pairwise alignment for nucleotide sequences. Bioinformatics. 2018 Sep 15;34(18):3094-3100. doi: 10.1093/bioinformatics/bty191. PMID: 29750242; PMCID: PMC6137996.

- **SnpEff**: Cingolani P. Variant Annotation and Functional Prediction: SnpEff. Methods Mol Biol. 2022;2493:289-314. doi: 10.1007/978-1-0716-2293-3_19. PMID: 35751823.

- **Rediportal**: Picardi E, D'Erchia AM, Lo Giudice C, Pesole G. REDIportal: a comprehensive database of A-to-I RNA editing events in humans. Nucleic Acids Res. 2017 Jan 4;45(D1):D750-D757. doi: 10.1093/nar/gkw767. Epub 2016 Sep 1. PMID: 27587585; PMCID: PMC5210607.



