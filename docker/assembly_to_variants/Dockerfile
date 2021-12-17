# TAG gcr.io/dnastack-pub-container-store/assembly_to_variants:latest
FROM ubuntu:xenial

MAINTAINER Heather Ward <heather@dnastack.com>

RUN apt-get -qq update && \
    apt-get -qq install \
        curl \
        wget \
        unzip \
        openjdk-8-jre-headless \
        libcurl4-openssl-dev \
        libssl-dev \
        libglew-dev \
        libpng-dev \
        libfreetype6-dev \
        libxml2-dev \
        libglm-dev \
        jq \
        snp-sites \
        bcftools \
        build-essential \
        libz-dev \
        tabix \
        vcftools \
        libbz2-dev \
        liblzma-dev \
        python3-dev \
        python3-pip

# blast 2.6.0
RUN wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.6.0/ncbi-blast-2.6.0+-src.tar.gz && \
	tar -zxvf ncbi-blast-2.6.0+-src.tar.gz --directory /opt/ && \
	rm ncbi-blast-2.6.0+-src.tar.gz
RUN cd /opt/ncbi-blast-2.6.0+-src/c++ && \
	./configure && \
	make
ENV PATH $PATH:/opt/ncbi-blast-2.6.0+-src/c++/ReleaseMT/bin

# mview
RUN wget https://github.com/desmid/mview/archive/v1.67.tar.gz && \
    tar -zxvf v1.67.tar.gz --directory /opt/ && \
    rm v1.67.tar.gz
ENV PERL5LIB=$PERL5LIB:/opt/mview-1.67/lib/
RUN ln -s /opt/mview-1.67/bin/mview /usr/local/bin/

COPY scripts/* /usr/local/bin/
