FROM python:3.9-slim-buster

RUN apt-get update && apt-get install -y gcc make build-essential zlib1g-dev liblzma-dev libbz2-dev

ADD src /reports

WORKDIR /reports
RUN pip install -r requirements.txt
