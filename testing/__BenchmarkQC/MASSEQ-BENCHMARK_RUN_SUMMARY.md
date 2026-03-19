# MASSEQ Benchmark Context For Future Codex Runs

This file is a reusable handoff for future Codex benchmarking work, not just a one-time run log.

It captures the known-good MASSEQ benchmark setup established on March 19, 2026 for benchmarking the local `ctat-mutations-DV` workflow against the public DeepVariant MASSEQ chr20 case study.

## Benchmark Intent

Use this benchmark to compare a new `ctat-mutations-DV` version against a fixed long-read MASSEQ baseline on:

- sample: `HG004`
- assay: PacBio HiFi MASSEQ
- model type: DeepVariant `MASSEQ`
- reference space: `GRCh38`
- effective evaluation scope: `chr20`

The benchmark goal is stability testing. For future reruns, change the CTAT checkout or executable under test while keeping inputs, region logic, and scoring method fixed.

## Workspace And Fixed Paths

Original benchmark workspace:

`/home/unix/bhaas/projects/DeepVariantEval/test_masseq`

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

Source:

```bash
https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/
```

### Truth Set

```bash
benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed
benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark.vcf.gz
benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi
```

Source:

```bash
https://ftp-trace.ncbi.nlm.nih.gov/giab/ftp/release/AshkenazimTrio/HG004_NA24143_mother/NISTv4.2.1/GRCh38/
```

### Public MASSEQ Inputs

```bash
input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam
input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.chr20.bam.bai
input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.depth.10x.exons.bed
```

Source:

```bash
https://storage.googleapis.com/deepvariant/masseq-case-study/
```

## Benchmark Invariants Codex Should Preserve

- The MASSEQ BAM is already restricted to `chr20`.
- The CTAT run should use long-read mode via `--is_long_reads`.
- The benchmark should remain focused on the raw DeepVariant VCF, not downstream annotation or filtering.
- Benchmark comparison must stay `chr20`-restricted or the recall will be artificially deflated.
- Future comparisons should write to a fresh output directory instead of overwriting the baseline run.

## Known Pitfall

Do not assume `--intervals` works for this MASSEQ benchmark the same way it does for the RNA-seq benchmark.

The baseline attempt passed a one-line region file containing `chr20` via:

```bash
--intervals input/chr20.regions.list
```

That failed because DeepVariant MASSEQ attempted to parse the file path itself as a region literal and raised:

```text
ValueError: Could not parse ".../chr20.regions.list" as a region literal.
```

For this benchmark, the known-good workaround is:

- omit `--intervals` from the CTAT call
- rely on the chr20-only BAM to keep variant calling restricted
- enforce correct `chr20` scoping during `hap.py` evaluation

## Baseline CTAT Run

This is the known-good CTAT command pattern for MASSEQ reruns:

```bash
export CTAT_GENOME_LIB=/home/unix/bhaas/CTAT_GENOME_LIBS/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play/ctat_genome_lib_build_dir

/path/to/ctat-mutations-DV \
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

Expected internal DeepVariant mode:

```bash
--model_type=MASSEQ
```

## Baseline Benchmark Command

Use the chr20-corrected `hap.py` invocation below. This is the benchmark definition that matched the official case-study metrics.

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$(pwd):$(pwd)" \
  -w "$(pwd)" \
  jmcdani20/hap.py:v0.3.12 \
  /opt/hap.py/bin/hap.py \
    benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark.vcf.gz \
    output/ctat_hg004_chr20bam_vNEXT/HG004.deepvariant.init.vcf.gz \
    -f benchmark/HG004_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed \
    -r reference/GRCh38_no_alt_analysis_set.fasta \
    -o happy/happy.output.chr20.vNEXT \
    --engine=vcfeval \
    --pass-only \
    -l chr20 \
    --target-regions=input/HG004.giab_na24143.hifi_reads.lima.0--0.lima.IsoSeqX_bc01_5p--IsoSeqX_3p.refined.grch38.mm2.splitN.fc.depth.10x.exons.bed \
    --threads="$(nproc)"
```

## Expected Output Files

### CTAT

- `output/ctat_hg004_chr20bam_vNEXT/HG004.deepvariant.init.vcf.gz`
- `output/ctat_hg004_chr20bam_vNEXT/HG004.deepvariant.init.vcf.gz.tbi`
- `output/ctat_hg004_chr20bam_vNEXT/HG004.variant-ready.bam`
- `output/ctat_hg004_chr20bam_vNEXT/HG004.variant-ready.bam.bai`

### `hap.py`

- `happy/happy.output.chr20.vNEXT.summary.csv`
- `happy/happy.output.chr20.vNEXT.extended.csv`
- `happy/happy.output.chr20.vNEXT.metrics.json.gz`
- `happy/happy.output.chr20.vNEXT.vcf.gz`
- `happy/happy.output.chr20.vNEXT.roc.all.csv.gz`

## Baseline Metrics To Match

These are the reference metrics from the March 19, 2026 corrected chr20 run. Future Codex benchmark work should compare against these values first.

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

## Success Criteria For Future Reruns

- The CTAT run completes without the MASSEQ `--regions` parsing failure.
- The output VCF is generated at the top level of the chosen output directory.
- `hap.py` completes on the chr20-restricted comparison.
- Metrics remain at or very near the baseline values above unless the tested CTAT change is expected to alter calls.
- Any metric drift should be reported explicitly as either expected or a regression.

## Failure Modes Codex Should Check First

- `--intervals` was accidentally reintroduced into the MASSEQ CTAT command.
- `hap.py` was run against genome-wide truth regions without matching chr20 restriction.
- The wrong truth BED or wrong target BED was used.
- The wrong output VCF path was benchmarked.
- A different reference build or genome library was substituted.

## Minimal Codex Handoff Prompt

If future Codex sessions need a compact benchmark brief, this is the minimum context to provide:

```text
Rerun the HG004 MASSEQ benchmark for ctat-mutations-DV using the existing benchmark fixtures in /home/unix/bhaas/projects/DeepVariantEval/test_masseq. Keep the benchmark definition fixed. Do not use --intervals for MASSEQ, because the known baseline failed when DeepVariant parsed the region-file path as a literal region. Use the chr20-only BAM as input, run CTAT in --is_long_reads mode, then benchmark the resulting VCF with hap.py using -l chr20 and the MASSEQ exon/10x BED as --target-regions. Compare against the March 19, 2026 baseline: SNP F1 0.960000, INDEL F1 0.823412.
```
