"""
This module is used to test the endpoint by sending requests periodically
"""
import json
import argparse
import time
import logging

import boto3
import pandas as pd

# send logging to stdout
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(message)s")

def test_endpoint(
    endpoint_name: str,
    region: str,
    sample_data: str,
    batch_size: int = 5,
    frequency: int = 1
):

    sagemaker_runtime = boto3.client(
        "sagemaker-runtime", region_name=region)

    data = pd.read_csv(sample_data)

    while True:
        sample = data.sample(batch_size)
        sample_json = json.dumps({"dataframe_split": sample.to_dict(orient="split")})
        response = sagemaker_runtime.invoke_endpoint(
            EndpointName=endpoint_name, 
            Body=bytes(sample_json, encoding='utf-8'),
            ContentType='application/json',
        )
        parsed_response = response['Body'].read().decode("utf-8")
        logging.info(f"Latest respnse: {parsed_response}")
        time.sleep(frequency)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample-data", type=str, required=True, help="Path to a csv file with data for testing")
    parser.add_argument("--endpoint-name", type=str, required=True)
    parser.add_argument("--region", type=str, required=True, help="AWS region")
    parser.add_argument("--batch-size", type=int, default=5, help="Batch size for each request")
    parser.add_argument("--frequency", type=int, default=2, help="Request frequency in seconds")
    args = parser.parse_args()

    test_endpoint(
        endpoint_name=args.endpoint_name,
        region=args.region,
        sample_data=args.sample_data,
        batch_size=args.batch_size,
        frequency=args.frequency
    )