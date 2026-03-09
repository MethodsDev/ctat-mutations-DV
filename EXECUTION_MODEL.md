# CTAT-Mutations v5.0.0 Execution Model

## Overview: How Docker is Used in Both Execution Modes

CTAT-Mutations uses **WDL (Workflow Description Language)** executed by **Cromwell**. This means Docker is used **at the task level**, not at the pipeline level.

---

## Execution Mode 1: Running via Docker Container

```
User runs:
  docker run trinityctat/ctat_mutations:5.0.0 ./ctat-mutations-DV ...

┌─────────────────────────────────────────────────────────────┐
│ Docker Container: trinityctat/ctat_mutations:5.0.0          │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ ./ctat-mutations-DV (Python CLI script)                │    │
│  │   - Validates parameters                             │    │
│  │   - Generates WDL input JSON                         │    │
│  │   - Launches: java -jar cromwell.jar ...            │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                    │
│                          ▼                                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Cromwell (Java workflow engine)                      │    │
│  │   - Parses WDL workflow                              │    │
│  │   - Executes tasks sequentially/in parallel          │    │
│  └─────────────────────────────────────────────────────┘    │
│         │         │         │         │                      │
│         ▼         ▼         ▼         ▼                      │
│    ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐            │
│    │ STAR   │ │Picard  │ │bcftools│ │  ???   │            │
│    │ (exec) │ │ (exec) │ │ (exec) │ │DeepVar?│            │
│    └────────┘ └────────┘ └────────┘ └────────┘            │
│                                                               │
│  All tools already installed in container                    │
└─────────────────────────────────────────────────────────────┘
```

**Key Point**: Everything runs inside ONE Docker container. All tools are pre-installed.

---

## Execution Mode 2: Running Directly (Native)

```
User runs:
  ./ctat-mutations-DV --left reads.fq --right reads.fq ...

┌─────────────────────────────────────────────────────────────┐
│ Host Machine (your laptop/server)                            │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ ./ctat-mutations-DV (Python CLI script)                │    │
│  │   - Validates parameters                             │    │
│  │   - Generates WDL input JSON                         │    │
│  │   - Launches: java -jar cromwell.jar ...            │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                    │
│                          ▼                                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Cromwell (Java workflow engine)                      │    │
│  │   - Parses WDL workflow                              │    │
│  │   - Reads task runtime.docker specifications         │    │
│  │   - Launches Docker containers PER TASK if specified │    │
│  └─────────────────────────────────────────────────────┘    │
│         │         │         │         │                      │
│         ▼         ▼         ▼         ▼                      │
│    ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────────────┐  │
│    │ STAR   │ │Picard  │ │bcftools│ │ Docker Container │  │
│    │ (exec) │ │ (exec) │ │ (exec) │ │ (DeepVariant)    │  │
│    │ native │ │ native │ │ native │ │                  │  │
│    └────────┘ └────────┘ └────────┘ │ ┌──────────────┐ │  │
│                                      │ │ DeepVariant  │ │  │
│    Tools installed on host           │ │   binaries   │ │  │
│                                      │ └──────────────┘ │  │
│                                      │ google/          │  │
│                                      │ deepvariant:1.9.0│  │
│                                      └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**Key Point**: Most tasks run natively on your host. **But tasks with `runtime.docker` specified will spawn Docker containers.**

---

## How Cromwell Handles Docker

### Task WITHOUT Docker Specification

```wdl
task RunSTAR {
    command <<<
        STAR --genomeDir ${genome} ...
    >>>

    runtime {
        cpu: 8
        memory: "32 GB"
        # NO docker specified
    }
}
```

**Cromwell behavior**:
- **In Docker mode**: Runs `STAR` binary inside the container
- **In native mode**: Runs `STAR` binary on your host (must be in PATH)

### Task WITH Docker Specification

```wdl
task DeepVariant_call_variants {
    command <<<
        /opt/deepvariant/bin/call_variants ...
    >>>

    runtime {
        docker: "google/deepvariant:1.9.0"
        cpu: 8
        memory: "16 GB"
    }
}
```

**Cromwell behavior**:
- **In Docker mode**: Runs inside existing container (expects DeepVariant pre-installed)
- **In native mode**: **Spawns NEW Docker container** with google/deepvariant:1.9.0 image!

---

## Current State of CTAT-Mutations v5.0.0

### ⚠️ **ISSUE**: Docker Image Missing DeepVariant Binaries

Our Dockerfile currently does NOT install DeepVariant binaries:

```dockerfile
## DeepVariant v1.9.0 configuration
# Note: DeepVariant binaries are used via official Docker image (google/deepvariant:1.9.0)
# The WDL workflow will use the official DeepVariant Docker containers
# Models are included in the DeepVariant Docker images
ENV DEEPVARIANT_VERSION=1.9.0

# Download RNA-seq model (v1.4.0 - most recent RNA model)
# This is used for Illumina RNA-seq variant calling
RUN mkdir -p /opt/models/rnaseq && \
    cd /opt/models/rnaseq && \
    wget -q https://storage.googleapis.com/deepvariant/models/...
```

But the WDL tasks currently use the CTAT Docker image:

```wdl
# In workflow inputs
String docker = "trinityctat/ctat_mutations:latest"

# In DeepVariant tasks
call DeepVariant_make_examples {
    input:
        docker = docker,  # Uses ctat_mutations image!
        ...
}
```

### 🔴 **This will FAIL when running via Docker!**

The CTAT Docker container doesn't have DeepVariant binaries at `/opt/deepvariant/bin/`.

---

## Solution: Two Approaches

### Approach 1: Use google/deepvariant Docker Images (Recommended)

Update WDL to use official DeepVariant images for DeepVariant tasks:

```wdl
# Add new input
String deepvariant_docker = "google/deepvariant:1.9.0"
String deepvariant_docker_gpu = "google/deepvariant:1.9.0-gpu"

# Update DeepVariant task calls
call DeepVariant_make_examples {
    input:
        docker = deepvariant_docker,  # Use DeepVariant image
        ...
}

call DeepVariant_call_variants {
    input:
        docker = deepvariant_docker,
        docker_gpu = deepvariant_docker_gpu,
        ...
}
```

**Execution flow (Docker mode)**:
```
User: docker run ctat_mutations:5.0.0 ...
  └─> Container: ctat_mutations:5.0.0
       └─> Cromwell
            ├─> STAR task (native in container)
            ├─> Picard task (native in container)
            └─> DeepVariant task
                 └─> ⚠️ NESTED Docker? (docker-in-docker problem!)
```

**Problem**: Running Docker inside Docker requires `--privileged` or Docker socket mounting.

**Execution flow (Native mode)**:
```
User: ./ctat-mutations-DV ...
  └─> Host machine
       └─> Cromwell
            ├─> STAR task (native on host)
            ├─> Picard task (native on host)
            └─> DeepVariant task
                 └─> docker run google/deepvariant:1.9.0 ... ✅ Works!
```

### Approach 2: Install DeepVariant in CTAT Image

Add DeepVariant binaries to the CTAT Docker image:

```dockerfile
# Install DeepVariant binaries
RUN conda install -y -c bioconda python=3.10
RUN conda install -y -c bioconda deepvariant=1.9.0

# Or download pre-built binaries
RUN wget https://github.com/google/deepvariant/.../deepvariant_binaries.tar.gz && \
    tar -xzf deepvariant_binaries.tar.gz -C /opt/deepvariant
```

**Pro**: Works in both Docker and native modes
**Con**: Increases image size (~2-3GB), requires Python 3.10 environment

---

## Current Workaround for Testing

### For Native Execution (Recommended Now)

1. Install all tools natively (already done!)
2. Pull DeepVariant Docker images:
   ```bash
   docker pull google/deepvariant:1.9.0
   docker pull google/deepvariant:1.9.0-gpu
   ```
3. Cromwell will automatically use DeepVariant via Docker for those tasks
4. Everything else runs natively

**This is why I recommended native testing** - it works with the current WDL!

### For Docker Execution (Broken Currently)

The Docker image is missing DeepVariant binaries. Options:

1. **Rebuild Docker with DeepVariant** (Approach 2 above)
2. **Use Docker-in-Docker** (complex, requires `--privileged`)
3. **Wait for WDL update** to use google/deepvariant images properly

---

## Summary Table

| Execution Mode | STAR | Picard | bcftools | DeepVariant | Notes |
|----------------|------|--------|----------|-------------|-------|
| **Docker Container** | ✅ In container | ✅ In container | ✅ In container | ❌ **MISSING** | Needs DeepVariant binaries added to image |
| **Native (Direct)** | ✅ On host | ✅ On host | ✅ On host | ✅ **Via Docker** | Cromwell spawns google/deepvariant containers |

---

## What Needs to be Fixed

### Option A: Native-First Approach (Current State)

1. ✅ All non-DeepVariant tools installed on host
2. ✅ DeepVariant Docker images pulled
3. ⚠️ WDL currently uses wrong Docker image for DeepVariant
4. **TODO**: Update WDL to use google/deepvariant images

### Option B: Docker-First Approach

1. **TODO**: Add DeepVariant binaries to CTAT Docker image
2. **TODO**: Handle Python 3.10 environment for DeepVariant
3. **TODO**: Test Docker-in-Docker if using google/deepvariant images

---

## Recommended Next Steps

1. **For now**: Test with native execution
   - All tools work on your host
   - DeepVariant via Docker containers (spawned by Cromwell)

2. **Update WDL** to properly use google/deepvariant images
   - Add `deepvariant_docker` parameter
   - Update DeepVariant task calls

3. **Update Docker image** to include DeepVariant
   - Or accept Docker-in-Docker complexity
   - Or keep Docker mode disabled for now

The native execution mode is actually **more efficient** because:
- No container overhead for most tasks
- Only DeepVariant needs containerization
- Cromwell handles this seamlessly
