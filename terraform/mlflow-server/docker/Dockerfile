FROM python:3.8.0

# RUN adduser --disabled-password --gecos '' mlflow
# USER mlflow

RUN pip install \
    mlflow \
    pymysql \
    boto3

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD curl -f http://localhost:5000/ || exit 1
## Environment variables made available through the Fargate task.
## Do not enter values
CMD mlflow server \
    --host 0.0.0.0 \
    --port 5000 \
    --default-artifact-root ${BUCKET} \
    --backend-store-uri mysql+pymysql://${USERNAME}:${PASSWORD}@${HOST}:${PORT}/${DATABASE}

