"""
This script is used to initialised a set or valid JSON stored in SSM. The set is stored as a comma-separated string, where elements are sorted.
"""
import argparse
import logging

import boto3

ssm = boto3.client('ssm')

def init_or_get_ssm_param(
    param: str,
    is_json: bool = False
) -> dict:
    try:
        response_dict = ssm.get_parameter(Name=param)
    except ssm.exceptions.ParameterNotFound:
        logging.warning(f'Parameter {param} not found. Initialising.')
        ssm.put_parameter(
            Name=param,
            Value=r"{}" if is_json else "[]",
            Type='String',
            Overwrite=True
        )
        logging.info(f'Created {param}')
        response_dict = ssm.get_parameter(Name=param)
    return response_dict

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Initialises an SSM parameter as "[]" if not found')
    parser.add_argument('--param', type=str, help='SSM set parameter')
    parser.add_argument('--is_json', action='store_true', help='Whether the parameter is a JSON object')
    args = parser.parse_args()
    
    _ = init_or_get_ssm_param(
        args.param,
        args.is_json
    )