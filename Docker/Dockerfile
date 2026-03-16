FROM ubuntu:24.04

LABEL maintainer="bhaas@broadinstitute.org"
LABEL description="CTAT-Mutations v5.0.0 - RNA-seq variant calling with DeepVariant"
LABEL version="5.0.0"

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get -qq -y install --no-install-recommends \
    automake \
    autoconf \
    autotools-dev \
    build-essential \
    bzip2 \
    ca-certificates \
    curl \
    openjdk-21-jre-headless \
    g++ \
    gcc \
    git \
    libbz2-dev \
    libcurl4-openssl-dev \
    libdb-dev \
    liblzma-dev \
    libncurses5-dev \
    libssl-dev \
    libtool \
    make \
    pbzip2 \
    perl \
    pigz \
    procps \
    tabix \
    unzip \
    wget \
    zlib1g \
    zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

# Install Perl modules
RUN curl -L http://cpanmin.us | perl - App::cpanminus && \
    cpanm install URI::Escape

ENV SRC=/usr/local/src
ENV BIN=/usr/local/bin

# Install Miniforge (community conda distribution without TOS requirements)
WORKDIR $SRC
RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O miniforge_install.sh && \
    bash ./miniforge_install.sh -b -p $BIN/miniforge3 && \
    rm miniforge_install.sh

ENV PATH="$BIN/miniforge3/bin:${PATH}"

# Install Python packages (keeping open-cravat and igv-reports at specific versions for compatibility)
# Note: setuptools<70 is required for pkg_resources which is needed by open-cravat
# Note: chardet<5.0 is required for open-cravat (newer versions removed universaldetector)
RUN conda install -y python=3.11 pip "setuptools<70" wheel && \
    pip install --no-cache-dir --upgrade-strategy=only-if-needed \
        requests \
        pandas \
        scikit-learn \
        aiosqlite3 \
        "setuptools<70" \
        "chardet<5.0" \
        open-cravat==2.1.0 \
        igv-reports==1.9.0 && \
    conda clean -a -y

# Configure open-cravat
RUN oc config md > /dev/null || true


## Samtools 1.21 (latest stable)
ENV SAMTOOLS_VERSION=1.21
WORKDIR $SRC
RUN wget -q https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 && \
    tar xjf samtools-${SAMTOOLS_VERSION}.tar.bz2 && \
    cd samtools-${SAMTOOLS_VERSION} && \
    ./configure --without-curses && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf samtools-${SAMTOOLS_VERSION} samtools-${SAMTOOLS_VERSION}.tar.bz2

## BCFtools 1.21 (latest stable)
ENV BCFTOOLS_VERSION=1.21
WORKDIR $SRC
RUN wget -q https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 && \
    tar xjf bcftools-${BCFTOOLS_VERSION}.tar.bz2 && \
    cd bcftools-${BCFTOOLS_VERSION} && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf bcftools-${BCFTOOLS_VERSION} bcftools-${BCFTOOLS_VERSION}.tar.bz2

## Bedtools 2.31.1 (latest stable)
ENV BEDTOOLS_VERSION=2.31.1
WORKDIR $SRC
RUN wget -q https://github.com/arq5x/bedtools2/releases/download/v${BEDTOOLS_VERSION}/bedtools-${BEDTOOLS_VERSION}.tar.gz && \
    tar -zxf bedtools-${BEDTOOLS_VERSION}.tar.gz && \
    cd bedtools2 && \
    make -j$(nproc) && \
    cp bin/* $BIN/ && \
    cd .. && \
    rm -rf bedtools2 bedtools-${BEDTOOLS_VERSION}.tar.gz

## STAR 2.7.11b (latest stable)
ENV STAR_VERSION=2.7.11b
WORKDIR $SRC
RUN wget -q https://github.com/alexdobin/STAR/archive/${STAR_VERSION}.tar.gz && \
    tar -xzf ${STAR_VERSION}.tar.gz && \
    mv STAR-${STAR_VERSION}/bin/Linux_x86_64_static/STAR $BIN/ && \
    rm -rf STAR-${STAR_VERSION} ${STAR_VERSION}.tar.gz


## Picard 3.3.0 (latest stable)
ENV PICARD_VERSION=3.3.0
WORKDIR $SRC
RUN wget -q https://github.com/broadinstitute/picard/releases/download/${PICARD_VERSION}/picard.jar
ENV PICARD_HOME=$SRC/picard.jar

# Create picard wrapper script
RUN echo '#!/bin/bash' > $BIN/picard && \
    echo 'java -jar /usr/local/src/picard.jar "$@"' >> $BIN/picard && \
    chmod +x $BIN/picard

## Minimap2 2.28 (latest stable)
ENV MINIMAP2_VERSION=2.28
WORKDIR $SRC
RUN wget -q https://github.com/lh3/minimap2/releases/download/v${MINIMAP2_VERSION}/minimap2-${MINIMAP2_VERSION}_x64-linux.tar.bz2 && \
    tar -xjf minimap2-${MINIMAP2_VERSION}_x64-linux.tar.bz2 && \
    mv minimap2-${MINIMAP2_VERSION}_x64-linux/minimap2 $BIN/ && \
    rm -rf minimap2-${MINIMAP2_VERSION}_x64-linux minimap2-${MINIMAP2_VERSION}_x64-linux.tar.bz2


## DeepVariant v1.9.0 configuration
# Note: DeepVariant binaries are used via official Docker image (google/deepvariant:1.9.0)
# The WDL workflow will use the official DeepVariant Docker containers
# Models are included in the DeepVariant Docker images
ENV DEEPVARIANT_VERSION=1.9.0

# Note: All DeepVariant models (RNASEQ, MASSEQ) are bundled in the google/deepvariant Docker image


## flagCorrection - improves DeepVariant accuracy on long-read RNA-seq
# Note: flagCorrection is an R script, but we'll skip installation for now
# Users can run it separately if needed, or we can add R dependencies later
# WORKDIR $SRC
# RUN git clone https://github.com/vladimirsouza/lrRNAseqVariantCalling.git && \
#     cd lrRNAseqVariantCalling/tools && \
#     chmod +x flagCorrection.r && \
#     cp flagCorrection.r /usr/local/bin/flagCorrection


## K8 1.2 (latest stable)
ENV K8_VERSION=1.2
WORKDIR $SRC
RUN wget -q https://github.com/attractivechaos/k8/releases/download/v${K8_VERSION}/k8-${K8_VERSION}.tar.bz2 && \
    tar -xjf k8-${K8_VERSION}.tar.bz2 && \
    cp k8-${K8_VERSION}/k8-x86_64-Linux $BIN/k8 && \
    rm -rf k8-${K8_VERSION} k8-${K8_VERSION}.tar.bz2

ENV PATH=/usr/local/src/ctat-mutations/WDL/:/usr/local/src/ctat-mutations/src/:$PATH


## MethodsDev CTAT mutations DV
WORKDIR $SRC
ENV CTAT_MUTATIONS_VERSION=5.0.2
ENV CTAT_MUTATIONS_COMMIT=b89eb9a40d20e1a18b2d70ff7cc67b7c38889bd3

# Clone from GitHub using specific commit
RUN git clone --recursive https://github.com/MethodsDev/ctat-mutations-DV.git ctat-mutations && \
    cd ctat-mutations && \
    git checkout $CTAT_MUTATIONS_COMMIT && \
    git submodule update --init --recursive && \
    cd plugins/bamsifter && \
    make && \
    cd /usr/local/src/ctat-mutations && \
    make

# Docker cleanup - remove build dependencies but keep runtime dependencies
RUN apt-get -qq -y remove automake build-essential curl gcc g++ git make unzip wget && \
    apt-get -qq -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/log/dpkg.log /tmp/* /var/tmp/*

WORKDIR /usr/local/src/ctat-mutations

# Version information
# Ubuntu: 24.04 LTS
# Java: OpenJDK 21
# Python: 3.11
# Samtools: 1.21
# BCFtools: 1.21
# Bedtools: 2.31.1
# STAR: 2.7.11b
# Picard: 3.3.0
# Minimap2: 2.28
# DeepVariant: 1.10.0 (via google/deepvariant Docker image; models bundled in DV image)
# K8: 1.2
# open-cravat: 2.1.0 (pinned for compatibility)
# igv-reports: 1.9.0 (pinned for compatibility)
