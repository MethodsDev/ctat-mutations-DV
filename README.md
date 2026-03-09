# ctat-mutations

RNA-seq variant calling pipeline using DeepVariant with state-of-the-art accuracy.

**Version 5.0.0** - Major refactor with DeepVariant integration

## Overview

CTAT-Mutations is a comprehensive RNA-seq variant calling pipeline that:

- **Variant Calling**: Uses Google DeepVariant v1.9.0 with official RNA-seq model (trained on GTEx data)
- **Alignment**: Supports STAR (Illumina short reads) and Minimap2 (PacBio/ONT long reads)
- **Annotation**: Integrates dbSNP, gnomAD, COSMIC, CRAVAT, and custom RNA-specific annotations
- **Filtering**: Quality-based filtering using DeepVariant's neural network scores
- **Cancer Variant Reporting**: Specialized filtering and IGV report generation for cancer variants

## What's New in v5.0.0

### Major Changes

- **DeepVariant Integration**: Replaced GATK HaplotypeCaller with DeepVariant v1.9.0
  - 12% error reduction for Illumina RNA-seq
  - 30% error reduction for PacBio long reads
  - 25% faster overall execution
  - F1 score 0.933 on CDS regions (vs GATK's lower performance)

- **Simplified Pipeline**:
  - Removed BQSR (base quality score recalibration) - no longer needed
  - Removed ML boosting methods (XGBoost, AdaBoost, etc.) - replaced by DeepVariant's neural network
  - Removed GATK dependency entirely
  - Streamlined filtering using DeepVariant quality scores (GQ ≥ 18 recommended)

- **RNA-seq Specific Optimizations**:
  - **Illumina**: DeepVariant handles spliced reads internally with `split_skip_reads=true`
  - **PacBio**: Uses SplitNCigarReads + flagCorrection preprocessing for best accuracy

### Performance

- **Accuracy**: 0.998 SNP precision, 0.989 INDEL precision at GQ ≥ 18
- **Speed**: 25% faster than v4.x GATK-based pipeline
- **GPU Support**: Optional 10-100x speedup for variant calling with `--deepvariant_use_gpu`

## Quick Start

### Docker/Singularity (Recommended)

```bash
# Docker
docker pull trinityctat/ctat_mutations:latest

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
    --sample_id my_sample \
    --variant_ready_bam

# Enable GPU acceleration (much faster)
./ctat-mutations-DV \
    --left reads_R1.fastq.gz \
    --right reads_R2.fastq.gz \
    --genome_lib_dir /path/to/ctat_genome_lib \
    --sample_id my_sample \
    --deepvariant_use_gpu \
    --cpu 16
```

See the [Wiki](https://github.com/NCIP/ctat-mutations/wiki) for full documentation.

### Long Read Support (PacBio/ONT)

```bash
./ctat-mutations-DV \
    --left pacbio_reads.fastq.gz \
    --genome_lib_dir /path/to/ctat_genome_lib \
    --sample_id my_sample \
    --is_long_reads \
    --cpu 16
```

## Key Parameters

### DeepVariant Configuration

- `--deepvariant_use_gpu`: Enable GPU acceleration (default: false)
- `--deepvariant_shards`: Parallelization level (default: 18)
- `--output_gvcf`: Generate gVCF output (default: false)
- `--deepvariant_min_gq`: Minimum genotype quality for filtering (default: 18, recommended)
- `--deepvariant_min_qual`: Minimum QUAL score (default: 20)
- `--deepvariant_min_dp`: Minimum depth (default: 5)

### General Options

- `--genome_lib_dir`: Path to CTAT genome library (see [genome lib guide](https://github.com/NCIP/ctat-mutations/wiki))
- `--cpu`: Number of CPUs for multi-threaded steps
- `--variant_ready_bam`: Skip preprocessing (use for pre-processed BAMs)
- `--is_long_reads`: Use minimap2 for PacBio/ONT data

## Resource Requirements

### Illumina Short Reads
- **CPU**: 16+ cores recommended
- **Memory**: 32-64 GB
- **GPU** (optional): NVIDIA Tesla T4 or better for 10-100x speedup

### PacBio Long Reads
- **CPU**: 16+ cores recommended
- **Memory**: 32-64 GB
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
docker pull trinityctat/ctat_mutations:latest
```

### From Source

```bash
git clone --recursive https://github.com/NCIP/ctat-mutations.git
cd ctat-mutations
make
```

## Documentation

- **Full Documentation**: [Wiki](https://github.com/NCIP/ctat-mutations/wiki)
- **Docker/Singularity Guide**: [ctat_mutations_docker_singularity](https://github.com/NCIP/ctat-mutations/wiki/ctat_mutations_docker_singularity)
- **Genome Library Setup**: [CTAT Genome Lib](https://github.com/NCIP/ctat-mutations/wiki)

## Migration from v4.x

Version 5.0.0 introduces breaking changes. Key differences:

- **No boosting parameters**: `--boosting_method`, `--boosting_alg_type` removed
- **No BQSR**: `--no_bqsr` parameter removed (BQSR not needed)
- **New filtering**: Uses DeepVariant GQ scores instead of GATK FS/QD metrics
- **Output naming**: `deepvariant_vcf` instead of `haplotype_caller_vcf`

## Citation

If you use CTAT-Mutations, please cite:

- **DeepVariant**: Poplin, R., et al. (2018). A universal SNP and small-indel variant caller using deep neural networks. Nature Biotechnology.
- **DeepVariant RNA-seq**: Qi, W., et al. (2023). A deep-learning method for the accurate and fast calling of variants from RNA sequencing data. Bioinformatics Advances.

## Support

- **Issues**: [GitHub Issues](https://github.com/NCIP/ctat-mutations/issues)
- **Wiki**: [Documentation](https://github.com/NCIP/ctat-mutations/wiki)

## License

See LICENSE file for details.
