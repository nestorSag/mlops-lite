FROM continuumio/miniconda3:latest

ARG PROJECT=./test-project
ENV PROJECT=${PROJECT}

WORKDIR /app

COPY ./${PROJECT} ./ml-projects/${PROJECT}
COPY Makefile .

RUN apt-get update && apt-get -y install make
RUN pip install mlflow

CMD make local-training project=${PROJECT}