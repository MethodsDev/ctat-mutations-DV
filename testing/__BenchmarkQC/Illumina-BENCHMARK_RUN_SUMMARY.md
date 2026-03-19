# Illumina RNA-seq Benchmark Context For Future Codex Runs

This file is a reusable handoff for future Codex benchmarking work, not just a one-time run log.

It captures the known-good Illumina RNA-seq benchmark setup established on March 19, 2026 for benchmarking the local `ctat-mutations-DV` workflow against the public DeepVariant RNA-seq case study.

## Benchmark Intent

Use this benchmark to compare a new `ctat-mutations-DV` version against a fixed short-read RNA-seq baseline on:

- sample: `HG005`
- assay: Illumina mRNA RNA-seq
- model type: DeepVariant `RNASEQ`
- reference space: `GRCh38`
- effective evaluation scope: `chr20 CDS` positions with at least `3x` coverage

The benchmark goal is stability testing. For future reruns, change the CTAT checkout or executable under test while keeping inputs, derived BED logic, and scoring method fixed.

## Workspace And Fixed Paths

Original benchmark workspace:

`/home/unix/bhaas/projects/DeepVariantEval/test_illumina`

CTAT executable used for the baseline:

`/home/unix/bhaas/GITHUB/MDL/ctat-mutations-DV/ctat-mutations-DV`

Genome library used for the baseline:

```bash
CTAT_GENOME_LIB=/home/unix/bhaas/CTAT_GENOME_LIBS/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play/ctat_genome_lib_build_dir
```

## Fixed Inputs

These inputs should be treated as frozen benchmark fixtures unless the benchmark itself is being intentionally redesigned.

### Reference

```bash
reference/GRCh38_no_alt_analysis_set.fasta
reference/GRCh38_no_alt_analysis_set.fasta.fai
```

### Truth Set

```bash
benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.bed
benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz
benchmark/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi
```

Source:

```bash
https://ftp-trace.ncbi.nlm.nih.gov/giab/ftp/release/ChineseTrio/HG005_NA24631_son/NISTv4.2.1/GRCh38/
```

### Annotation-Derived Regions

```bash
data/gencode.v41.basic.annotation.gff3.gz
data/chr20_CDS.bed
data/hg005_3x.bed
data/chr20_CDS_3x.bed
benchmark/chr20_CDS_3x.benchmark_regions.bed
```

The evaluation regions are derived from:

- Gencode v41 basic annotation CDS records on `chr20`
- `mosdepth` per-base coverage filtered at `>= 3x`
- intersection with the GIAB benchmark BED

### RNA-seq BAM

```bash
data/hg005_gm26107.mrna.grch38.bam
data/hg005_gm26107.mrna.grch38.bam.bai
```

Source:

```bash
https://storage.googleapis.com/brain-genomics-public/research/sequencing/grch38/bam/rna/illumina/mrna/
```

## Benchmark Invariants Codex Should Preserve

- Use the supplied HG005 Illumina RNA-seq BAM directly.
- Keep `--variant_ready_bam` enabled so the benchmark focuses on variant calling rather than CTAT BAM preprocessing.
- Keep the interval restriction fixed at `data/chr20_CDS_3x.bed`.
- Score only within `benchmark/chr20_CDS_3x.benchmark_regions.bed`.
- Keep annotation and cancer-filtering steps disabled so benchmark outputs remain centered on the raw VCF.
- Future comparisons should write to a fresh output directory instead of overwriting the baseline run.

## Region Construction Logic

These derived BEDs are part of the benchmark definition. If they are rebuilt, the exact logic should remain unchanged:

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

## Baseline CTAT Run

This is the known-good CTAT command pattern for Illumina RNA-seq reruns:

```bash
export CTAT_GENOME_LIB=/home/unix/bhaas/CTAT_GENOME_LIBS/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play/ctat_genome_lib_build_dir

/path/to/ctat-mutations-DV \
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
```

Expected internal DeepVariant mode:

```bash
--model_type=RNASEQ
```

## Baseline Benchmark Command

Use this `hap.py` invocation for future reruns:

```bash
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

## Expected Output Files

### CTAT

- `output/ctat_hg005_vNEXT/HG005.deepvariant.init.vcf.gz`
- `output/ctat_hg005_vNEXT/HG005.deepvariant.init.vcf.gz.tbi`
- `output/ctat_hg005_vNEXT/HG005.variant-ready.bam`
- `output/ctat_hg005_vNEXT/HG005.variant-ready.bam.bai`

### `hap.py`

- `happy/happy.output.vNEXT.summary.csv`
- `happy/happy.output.vNEXT.extended.csv`
- `happy/happy.output.vNEXT.metrics.json.gz`
- `happy/happy.output.vNEXT.vcf.gz`
- `happy/happy.output.vNEXT.roc.all.csv.gz`

## Baseline Metrics To Match

These are the reference metrics from the March 19, 2026 run. Future Codex benchmark work should compare against these values first.

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

## Success Criteria For Future Reruns

- The CTAT run completes with `RNASEQ` DeepVariant mode and emits the expected top-level VCF.
- The run keeps region restriction fixed at `data/chr20_CDS_3x.bed`.
- `hap.py` completes against `benchmark/chr20_CDS_3x.benchmark_regions.bed`.
- Metrics remain at or very near the baseline values above unless the tested CTAT change is expected to alter calls.
- Any metric drift should be reported explicitly as either expected or a regression.

## Failure Modes Codex Should Check First

- The interval BED was changed or regenerated with different filtering logic.
- A benchmark was run against the full GIAB BED instead of `benchmark/chr20_CDS_3x.benchmark_regions.bed`.
- The wrong VCF path was passed to `hap.py`.
- Annotation or filtering options were re-enabled and affected the benchmark artifact being compared.
- A different reference build or genome library was substituted.

## Operational Notes

- `mosdepth` was run in a container in the baseline because no host binary was on `PATH`.
- `hap.py` outputs created by Docker may be owned by `root` depending on how the container is launched.
- The case-study reference and CTAT genome-lib reference matched sufficiently on the primary contigs used in this restricted benchmark.

## Minimal Codex Handoff Prompt

If future Codex sessions need a compact benchmark brief, this is the minimum context to provide:

```text
Rerun the HG005 Illumina RNA-seq benchmark for ctat-mutations-DV using the existing fixtures in /home/unix/bhaas/projects/DeepVariantEval/test_illumina. Keep the benchmark definition fixed. Use the HG005 RNA-seq BAM directly with --variant_ready_bam, restrict CTAT calling to data/chr20_CDS_3x.bed, and benchmark the output VCF with hap.py against benchmark/chr20_CDS_3x.benchmark_regions.bed. Compare against the March 19, 2026 baseline: SNP F1 0.968421, INDEL F1 0.823529.
```
