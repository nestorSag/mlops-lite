FROM chainguard/conda:latest

ARG PROJECT=./test-project
ENV PROJECT=${PROJECT}

WORKDIR /app

COPY ./${PROJECT} /app/${PROJECT}
COPY Makefile .

RUN pip install mlflow

CMD make local-training project=${PROJECT}