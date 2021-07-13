FROM python:3-slim
RUN apt-get update && apt-get install -y jq procps curl unzip wget
ENV LC_ALL C.UTF-8
ENV LANG=C.UTF-8

RUN mkdir ~/.dnastack; cd ~/.dnastack && \
    curl -L https://github.com/DNAstack/public-dnastack-cli/releases/latest/download/dnastack-linux > ~/.dnastack/dnastack &&  \
    chmod u+x dnastack

ENV PATH "$PATH:/root/.dnastack"
