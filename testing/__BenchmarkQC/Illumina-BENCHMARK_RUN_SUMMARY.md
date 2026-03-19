# DeepVariant RNA-seq Benchmark Run Summary

This document records the exact execution flow used on March 19, 2026 to benchmark the local `ctat-mutations-DV` workflow on the DeepVariant Illumina RNA-seq case-study data.

## Goal

Follow the DeepVariant RNA-seq case-study preprocessing and benchmarking steps as closely as practical, but replace the case-study DeepVariant execution command with the local `ctat-mutations-DV` wrapper.

## Workspace

`/home/unix/bhaas/projects/DeepVariantEval/test_illumina`

## CTAT Workflow Used

`/home/unix/bhaas/GITHUB/MDL/ctat-mutations-DV/ctat-mutations-DV`

## Genome Library Used

Environment variable:

```bash
CTAT_GENOME_LIB=/home/unix/bhaas/CTAT_GENOME_LIBS/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play/ctat_genome_lib_build_dir
```

## High-Level Execution Plan

1. Create the standard case-study directory layout.
2. Download the GRCh38 reference used by the case study.
3. Download GIAB HG005 benchmark truth resources.
4. Download the Gencode annotation and derive `chr20_CDS.bed`.
5. Download the HG005 Illumina RNA-seq BAM and BAI.
6. Run `mosdepth` to produce per-base coverage.
7. Build the 3x coverage regions and intersect them with chr20 CDS and GIAB benchmark regions.
8. Run `ctat-mutations-DV` on the BAM restricted to `data/chr20_CDS_3x.bed`.
9. Benchmark the resulting VCF with `hap.py`.

## Exact Commands Used

### 1. Create directories

```bash
mkdir -p data benchmark reference model output happy logs
```

### 2. Download the case-study reference

```bash
FTPDIR=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids

curl -L --fail --retry 3 -C - \
  "$FTPDIR/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz" | \
  gunzip > reference/GRCh38_no_alt_analysis_set.fasta

curl -L --fail --retry 3 -C - \
  -o reference/GRCh38_no_alt_analysis_set.fasta.fai \
  "$FTPDIR/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.fai"
```

### 3. Download GIAB HG005 truth resources

```bash
GIAB=https://ftp-trace.ncbi.nlm.nih.gov/giab/ftp/release/ChineseTrio/HG005_NA24631_son/NISTv4.2.1/GRCh38

curl -L --fail --retry 3 -C - \
  -o benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.bed \
  "$GIAB/HG005_GRCh38_1_22_v4.2.1_benchmark.bed"

curl -L --fail --retry 3 -C - \
  -o benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz \
  "$GIAB/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz"

curl -L --fail --retry 3 -C - \
  -o benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi \
  "$GIAB/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi"
```

### 4. Download Gencode and derive chr20 CDS regions

```bash
curl -L --fail --retry 3 -C - \
  -o data/gencode.v41.basic.annotation.gff3.gz \
  https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_41/gencode.v41.basic.annotation.gff3.gz

gzip -dc data/gencode.v41.basic.annotation.gff3.gz | \
awk -v OFS='\t' '$1 == "chr20" && $3 == "CDS" && $4 < $5 { print $1, $4, $5, "CDS" }' | \
awk '!dup[$0]++' > data/chr20_CDS.bed
```

### 5. Download HG005 Illumina RNA-seq BAM

```bash
HTTPDIR=https://storage.googleapis.com/brain-genomics-public/research/sequencing/grch38/bam/rna/illumina/mrna

curl -L --fail --retry 3 -C - \
  -o data/hg005_gm26107.mrna.grch38.bam \
  "$HTTPDIR/hg005_gm26107.mrna.grch38.bam"

curl -L --fail --retry 3 -C - \
  -o data/hg005_gm26107.mrna.grch38.bam.bai \
  "$HTTPDIR/hg005_gm26107.mrna.grch38.bam.bai"
```

### 6. Validate BAM readability

```bash
samtools quickcheck -v data/hg005_gm26107.mrna.grch38.bam
samtools idxstats data/hg005_gm26107.mrna.grch38.bam | sed -n '1,15p'
```

### 7. Generate coverage with `mosdepth`

Containerized `mosdepth` was used because no local `mosdepth` binary was present on `PATH`.

```bash
docker run --rm \
  -v "$(pwd):$(pwd)" \
  -w "$(pwd)" \
  quay.io/biocontainers/mosdepth:0.3.1--h4dc83fb_1 \
  mosdepth \
    --threads "$(nproc)" \
    data/hg005_coverage \
    data/hg005_gm26107.mrna.grch38.bam
```

### 8. Build the 3x evaluation regions

```bash
min_coverage=3

gzip -dc data/hg005_coverage.per-base.bed.gz | \
egrep -v 'HLA|decoy|random|alt|chrUn|chrEBV' | \
awk -v OFS='\t' -v min_coverage="$min_coverage" '$4 >= min_coverage { print }' | \
bedtools merge -d 1 -c 4 -o mean -i - > data/hg005_3x.bed

bedtools intersect \
  -a data/hg005_3x.bed \
  -b data/chr20_CDS.bed > data/chr20_CDS_3x.bed

bedtools intersect \
  -a benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.bed \
  -b data/chr20_CDS_3x.bed > benchmark/chr20_CDS_3x.benchmark_regions.bed
```

### 9. Run `ctat-mutations-DV`

This is the substitution point for the original DeepVariant case study.

Key choices:

- `--bam`: use the case-study BAM directly.
- `--variant_ready_bam`: skip CTAT BAM preprocessing and call on the supplied BAM.
- `--intervals data/chr20_CDS_3x.bed`: match the case-study restricted region set.
- `--no_annotate_variants --no_cravat --no_filter_cancer_variants`: keep the run focused on the core VCF used for benchmarking.

```bash
export CTAT_GENOME_LIB=/home/unix/bhaas/CTAT_GENOME_LIBS/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play/ctat_genome_lib_build_dir

/home/unix/bhaas/GITHUB/MDL/ctat-mutations-DV/ctat-mutations-DV \
  --bam data/hg005_gm26107.mrna.grch38.bam \
  --genome_lib_dir "$CTAT_GENOME_LIB" \
  --sample_id HG005 \
  --variant_ready_bam \
  --intervals data/chr20_CDS_3x.bed \
  --deepvariant_shards "$(nproc)" \
  --cpu "$(nproc)" \
  --no_annotate_variants \
  --no_cravat \
  --no_filter_cancer_variants \
  -O output/ctat_hg005
```

What CTAT executed internally for the variant-calling step:

```bash
/opt/deepvariant/bin/run_deepvariant \
  --model_type=RNASEQ \
  --ref=.../ref_genome.fa \
  --reads=.../hg005_gm26107.mrna.grch38.bam \
  --output_vcf=HG005.deepvariant.init.vcf.gz \
  --sample_name=HG005 \
  --disable_small_model \
  --num_shards=16 \
  --regions=.../chr20_CDS_3x.bed \
  --intermediate_results_dir=intermediate_results
```

### 10. Benchmark with `hap.py`

```bash
docker run --rm \
  -v "$(pwd):$(pwd)" \
  -w "$(pwd)" \
  jmcdani20/hap.py:v0.3.12 \
  /opt/hap.py/bin/hap.py \
    benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz \
    output/ctat_hg005/HG005.deepvariant.init.vcf.gz \
    -f benchmark/chr20_CDS_3x.benchmark_regions.bed \
    -r reference/GRCh38_no_alt_analysis_set.fasta \
    -o happy/happy.output \
    --engine=vcfeval \
    --pass-only \
    --target-regions=data/chr20_CDS_3x.bed \
    --threads="$(nproc)"
```

## Resulting Key Files

### Inputs and derived regions

- `reference/GRCh38_no_alt_analysis_set.fasta`
- `reference/GRCh38_no_alt_analysis_set.fasta.fai`
- `benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.bed`
- `benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz`
- `benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi`
- `data/hg005_gm26107.mrna.grch38.bam`
- `data/hg005_gm26107.mrna.grch38.bam.bai`
- `data/chr20_CDS.bed`
- `data/hg005_3x.bed`
- `data/chr20_CDS_3x.bed`
- `benchmark/chr20_CDS_3x.benchmark_regions.bed`

### CTAT outputs

- `output/ctat_hg005/HG005.deepvariant.init.vcf.gz`
- `output/ctat_hg005/HG005.deepvariant.init.vcf.gz.tbi`
- `output/ctat_hg005/HG005.variant-ready.bam`
- `output/ctat_hg005/HG005.variant-ready.bam.bai`
- `output/ctat_hg005/cromwell-workflow-logs/`
- `output/ctat_hg005/cromwell-executions/`

### hap.py outputs

- `happy/happy.output.summary.csv`
- `happy/happy.output.extended.csv`
- `happy/happy.output.metrics.json.gz`
- `happy/happy.output.vcf.gz`
- `happy/happy.output.roc.all.csv.gz`

## Final Benchmark Metrics

From `happy/happy.output.summary.csv`:

### SNP

- Recall: `0.961672`
- Precision: `0.975265`
- F1: `0.968421`
- Truth TP/FN: `276 / 11`
- Query FP/UNK: `7 / 44`

### INDEL

- Recall: `0.777778`
- Precision: `0.875000`
- F1: `0.823529`
- Truth TP/FN: `7 / 2`
- Query FP/UNK: `1 / 5`

## Notes for Re-running With a New `ctat-mutations-DV` Version

To benchmark a new CTAT version next time, keep everything else the same and only change:

- the CTAT checkout or executable path
- the output directory name
- optionally the `sample_id` if you want version-specific filenames

Recommended repeat-run pattern:

1. Reuse the existing downloaded inputs and derived BED files.
2. Point to the new `ctat-mutations-DV` executable.
3. Write to a fresh output directory such as `output/ctat_hg005_vNEXT`.
4. Run the same `hap.py` command against that new VCF.
5. Compare the new `happy.output.summary.csv` against the previous run.

Minimal rerun commands:

```bash
export CTAT_GENOME_LIB=/home/unix/bhaas/CTAT_GENOME_LIBS/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play/ctat_genome_lib_build_dir

/path/to/new/ctat-mutations-DV \
  --bam data/hg005_gm26107.mrna.grch38.bam \
  --genome_lib_dir "$CTAT_GENOME_LIB" \
  --sample_id HG005 \
  --variant_ready_bam \
  --intervals data/chr20_CDS_3x.bed \
  --deepvariant_shards "$(nproc)" \
  --cpu "$(nproc)" \
  --no_annotate_variants \
  --no_cravat \
  --no_filter_cancer_variants \
  -O output/ctat_hg005_vNEXT

docker run --rm \
  -v "$(pwd):$(pwd)" \
  -w "$(pwd)" \
  jmcdani20/hap.py:v0.3.12 \
  /opt/hap.py/bin/hap.py \
    benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz \
    output/ctat_hg005_vNEXT/HG005.deepvariant.init.vcf.gz \
    -f benchmark/chr20_CDS_3x.benchmark_regions.bed \
    -r reference/GRCh38_no_alt_analysis_set.fasta \
    -o happy/happy.output.vNEXT \
    --engine=vcfeval \
    --pass-only \
    --target-regions=data/chr20_CDS_3x.bed \
    --threads="$(nproc)"
```

## Operational Notes

- `mosdepth` and `hap.py` outputs were created by Docker and are owned by `root`, but they are readable.
- The CTAT run used the local Cromwell wrapper successfully and produced symlinked top-level outputs under `output/ctat_hg005/`.
- The case-study reference and the CTAT genome-lib reference matched on the primary contigs used here, which was sufficient for this restricted benchmark.
