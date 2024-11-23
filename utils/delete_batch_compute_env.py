"""
This module prevents a Terraform bug when destroying AWS Batch compute environments, where Terraform deletes IAM roles attached to it before the compute environment itself,
setting the latter in an INVALID state and making it undeletable. This script deletes the compute environment in the right order.
"""
import logging
import argparse

import boto3

def delete_compute_environment(compute_env_name: str, queue_name: str):
    """
    Delete the specified AWS Batch compute environment.
    """
    try:
        client = boto3.client('batch')
        # first, disable the queue
        client.update_job_queue(jobQueue=queue_name, state='DISABLED')
        # delete queue
        client.delete_job_queue(jobQueue=queue_name)
        # disable compute environment
        client.update_compute_environment(computeEnvironment=compute_env_name, state='DISABLED')
        # delete compute environment
        client.delete_compute_environment(computeEnvironment=compute_env_name)
        logging.info(f"Deleted compute environment {compute_env_name} and queue {queue_name}")
    except Exception as e:
        logging.exception(f"Error deleting compute environment {compute_env_name} and queue {queue_name}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Delete an AWS Batch compute environment and its associated queue")
    parser.add_argument("--env_name", help="The name of the compute environment to delete")
    parser.add_argument("--queue_name", help="The name of the queue to delete")
    args = parser.parse_args()
    delete_compute_environment(args.env_name, args.queue_name)