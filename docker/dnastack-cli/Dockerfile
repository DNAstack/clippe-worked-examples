FROM python:3-slim
RUN apt-get update && apt-get install -y jq procps curl unzip wget

ENV LC_ALL C.UTF-8
ENV LANG=C.UTF-8

ARG CLI_VERSION

RUN mkdir /opt/dnastack; cd /opt/dnastack && \
    curl -L "https://github.com/DNAstack/public-dnastack-cli/releases/download/${CLI_VERSION}/dnastack-linux" > dnastack &&  \
    chmod +x dnastack

ENV PATH "$PATH:/opt/dnastack"
