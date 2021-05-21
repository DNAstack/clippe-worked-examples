FROM ubuntu:latest

ENV HTSLIB_VERSION 1.12

RUN apt-get update && DEBIAN_FRONTEND="noninteractive" apt-get install -y \
    autoconf automake make gcc perl zlib1g-dev libbz2-dev liblzma-dev libcurl4-openssl-dev libssl-dev libncurses5-dev \
    libfontconfig1-dev libgraphite2-dev libharfbuzz-dev libicu-dev texlive texlive-latex-extra \
    wget curl 
    

# Install HTSLIB
RUN wget https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 && \
    tar -xjvf htslib-${HTSLIB_VERSION}.tar.bz2 && \
    (cd htslib-${HTSLIB_VERSION} && ./configure && make && make install ) && \
    rm -rf htslib-${HTSLIB_VERSION}.tar.bz2

RUN wget https://github.com/samtools/samtools/releases/download/${HTSLIB_VERSION}/samtools-${HTSLIB_VERSION}.tar.bz2 && \
    tar -xjvf samtools-${HTSLIB_VERSION}.tar.bz2 && \
    (cd samtools-${HTSLIB_VERSION} && ./configure --with-htslib=system && make && make install ) && \
    rm -rf samtools-${HTSLIB_VERSION}.tar.bz2 

RUN wget https://github.com/samtools/bcftools/releases/download/${HTSLIB_VERSION}/bcftools-${HTSLIB_VERSION}.tar.bz2 && \
    tar -xjvf bcftools-${HTSLIB_VERSION}.tar.bz2 && \
    (cd bcftools-${HTSLIB_VERSION} && ./configure --with-htslib=system && make && make install ) && \
    rm -rf bcftools-${HTSLIB_VERSION}.tar.bz2 


RUN apt-get install -y python3 python3-pip && \
    pip install -U matplotlib cython pysam pandas numpy

ENV PATH="/root/.cargo/bin:${PATH}"
# Install Rust
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
RUN cargo install tectonic

