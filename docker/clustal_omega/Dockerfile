# TAG gcr.io/dnastack-pub-container-store/clustal_omega:1.2.4
FROM ubuntu:xenial

MAINTAINER Heather Ward <heather@dnastack.com>

RUN apt-get -qq update && \
    apt-get -qq install \
    wget \
    build-essential \
    libargtable2-dev

ENV CLUSTAL_OMEGA_VERSION 1.2.4

RUN wget https://github.com/GSLBiotech/clustal-omega/archive/refs/tags/${CLUSTAL_OMEGA_VERSION}-cmake.tar.gz && \
    tar -zxvf ${CLUSTAL_OMEGA_VERSION}-cmake.tar.gz --directory /opt && \
    rm ${CLUSTAL_OMEGA_VERSION}-cmake.tar.gz

RUN cd /opt/clustal-omega-${CLUSTAL_OMEGA_VERSION}-cmake && \
    ./configure && \
    make && \
    make install
