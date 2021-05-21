FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    curl \
    bash \
    git \
    python3 \
    jq

ENV LC_ALL C.UTF-8
ENV LANG=C.UTF-8

RUN mkdir ~/.covid-cloud; cd ~/.covid-cloud && \
    curl -L https://github.com/DNAstack/public-covid-cloud-cli/releases/latest/download/covid-cloud-linux > ~/.covid-cloud/covid-cloud && \
    chmod u+x covid-cloud && \
    ~/.covid-cloud/covid-cloud config search-url https://search.international.covidcloud.ca/ && \
    echo "export PATH=$PATH:/home/root/.covid-cloud/" >> ~/.bashrc

CMD [ "~/.covid-cloud/covid-cloud" ]