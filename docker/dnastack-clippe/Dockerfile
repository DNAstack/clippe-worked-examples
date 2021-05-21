FROM python:3-slim
RUN apt-get update && apt-get install -y jq
ENV LC_ALL C.UTF-8
ENV LANG=C.UTF-8
RUN pip install -U clippe pyaml
RUN mkdir ~/.clippe

CMD clippe