# CTAT-Mutations v5.0.0 Execution Model

## Overview: How Docker is Used in Both Execution Modes

CTAT-Mutations uses **WDL (Workflow Description Language)** executed by **Cromwell**. Docker is used **at the task level** for DeepVariant, while other tools run natively.

---

## DeepVariant Architecture

CTAT-Mutations uses a single `DeepVariant` WDL task that calls `run_deepvariant`, the official wrapper from Google. This wrapper internally orchestrates three stages:

1. **make_examples** - Converts BAM pileups into TensorFlow examples (parallelized via `--num_shards`)
2. **call_variants** - Runs the neural network model on examples
3. **postprocess_variants** - Converts predictions to VCF format

All intermediate files are managed automatically via `--intermediate_results_dir`.

### Model Selection

| Input Type | `--model_type` | Model Path | Notes |
|------------|---------------|------------|-------|
| Illumina RNA-seq | `RNASEQ` | `/opt/models/rnaseq` | Native RNA-seq model, auto-configures `split_skip_reads` |
| PacBio/ONT long reads | `MASSEQ` | `/opt/models/masseq` | Used after SplitNCigarReads + flagCorrection preprocessing |

All models are bundled in the `google/deepvariant:1.10.0` Docker image.

### GPU Support

For Terra deployments, GPU acceleration is available:
- Set `deepvariant_use_gpu = true` in workflow inputs
- Uses `google/deepvariant:1.10.0-gpu` Docker image
- Runtime attributes set `gpuType: "nvidia-tesla-t4"` and `gpuCount: 1`
- `run_deepvariant` auto-detects GPU when running in the GPU container

---

## Execution Mode 1: Running via Docker Container

```
User runs:
  docker run trinityctat/ctat_mutations:5.0.0 ./ctat-mutations-DV ...

+-------------------------------------------------------------+
| Docker Container: trinityctat/ctat_mutations:5.0.0          |
|                                                             |
|  ./ctat-mutations-DV (Python CLI) --> Cromwell              |
|       |         |         |         |                       |
|       v         v         v         v                       |
|  +--------+ +--------+ +--------+ +------------------+     |
|  | STAR   | |Picard  | |bcftools| | Docker Container |     |
|  | (exec) | | (exec) | | (exec) | | (DeepVariant)    |     |
|  +--------+ +--------+ +--------+ | run_deepvariant  |     |
|                                    | google/deepvariant|    |
|  All tools in container            |     :1.10.0      |     |
|                                    +------------------+     |
+-------------------------------------------------------------+
```

**Note**: Running Docker inside Docker requires `--privileged` or Docker socket mounting.

---

## Execution Mode 2: Running Directly (Native)

```
User runs:
  ./ctat-mutations-DV --left reads.fq --right reads.fq ...

+-------------------------------------------------------------+
| Host Machine                                                |
|                                                             |
|  ./ctat-mutations-DV (Python CLI) --> Cromwell              |
|       |         |         |         |                       |
|       v         v         v         v                       |
|  +--------+ +--------+ +--------+ +------------------+     |
|  | STAR   | |Picard  | |bcftools| | Docker Container |     |
|  | native | | native | | native | | run_deepvariant  |     |
|  +--------+ +--------+ +--------+ | google/deepvariant|    |
|                                    |     :1.10.0      |     |
|  Tools installed on host           +------------------+     |
+-------------------------------------------------------------+
```

**Key Point**: Most tasks run natively. Only DeepVariant runs in a Docker container (spawned by Cromwell).

---

## WDL Task Structure

### DeepVariant Task (single task, handles everything internally)

```wdl
task DeepVariant {
    input {
        File input_bam
        File ref_fasta
        String sample_name
        Boolean is_long_reads
        Boolean use_gpu = false
        Int num_shards = 18
        String docker           # google/deepvariant:1.10.0
        String docker_gpu       # google/deepvariant:1.10.0-gpu
    }

    String model_type = if is_long_reads then "MASSEQ" else "RNASEQ"

    command <<<
        /opt/deepvariant/bin/run_deepvariant \
            --model_type=~{model_type} \
            --ref=~{ref_fasta} \
            --reads=~{input_bam} \
            --output_vcf=~{sample_name}.vcf.gz \
            --disable_small_model \
            --num_shards=~{num_shards} \
            --intermediate_results_dir=intermediate_results
    >>>

    runtime {
        docker: if use_gpu then docker_gpu else docker
        gpuType: if use_gpu then "nvidia-tesla-t4" else ""
        gpuCount: if use_gpu then 1 else 0
    }
}
```

**Cromwell behavior**:
- **In Docker mode**: Spawns a `google/deepvariant:1.10.0` container (docker-in-docker)
- **In native mode**: Spawns a `google/deepvariant:1.10.0` container on the host

---

## Setup for Native Execution

1. Install all non-DeepVariant tools natively (STAR, Picard, samtools, bcftools, etc.)
2. Pull DeepVariant Docker images:
   ```bash
   docker pull google/deepvariant:1.10.0
   docker pull google/deepvariant:1.10.0-gpu  # optional, for GPU
   ```
3. Cromwell automatically spawns DeepVariant containers for variant calling tasks
4. Everything else runs natively on the host

---

## Summary Table

| Execution Mode | STAR | Picard | bcftools | DeepVariant | Notes |
|----------------|------|--------|----------|-------------|-------|
| **Docker Container** | In container | In container | In container | Via nested Docker | Requires docker-in-docker |
| **Native (Direct)** | On host | On host | On host | Via Docker container | Cromwell spawns google/deepvariant |
| **Terra** | Cloud VM | Cloud VM | Cloud VM | Cloud VM (GPU optional) | Separate Docker images per task |
