"""
This script is used to update a set stored in SSM. The set is stored as a comma-separated string, where elements are sorted.
"""
import argparse
import logging

import boto3

ssm = boto3.client('ssm')

def init_or_get_ssm_set(
    param: str
) -> dict:
    try:
        response_dict = ssm.get_parameter(Name=param)
    except ssm.exceptions.ParameterNotFound:
        logging.warning(f'Parameter {param} not found. Initialising.')
        ssm.put_parameter(
            Name=param,
            Value="[]",
            Type='String',
            Overwrite=True
        )
        logging.info(f'Created {param}')
        response_dict = ssm.get_parameter(Name=param)
    return response_dict

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Initialises an SSM parameter as "[]" if not found')
    parser.add_argument('--param', type=str, help='SSM set parameter')
    args = parser.parse_args()
    
    _ = init_or_get_ssm_set(
        args.param
    )