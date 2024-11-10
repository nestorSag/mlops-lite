"""
This script is used to update a set stored in SSM. The set is stored as a comma-separated string, where elements are sorted.
"""
import argparse
import logging

import boto3

ssm = boto3.client('ssm')

def fetch_ssm_set(param: str) -> set:
    
    try:
        response = ssm.get_parameter(Name=param)
    except ssm.exceptions.ParameterNotFound:
        logging.warning(f'Parameter {param} not found')
        return set()
    value = set(response['Parameter']['Value'].split(','))
    return value

def upload_ssm_set(param: str, value: set) -> None:
    str_value = ",".join(sorted(list(value)))
    ssm.put_parameter(
        Name=param,
        Value=str_value,
        Type='String',
        Overwrite=True
    )

def update_ssm_set(
    param: str,
    elem: str,
    add: bool = True
):
    value = fetch_ssm_set(param)
    if add:
        value.add(elem)
    else:
        value.discard(elem)
    upload_ssm_set(param, value)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Update an SSM parameter that stores a Python set')
    parser.add_argument('--param', type=str, help='SSM set')
    parser.add_argument('--elem', type=str, help='SSM')
    parser.add_argument('--action', type=str, help='Action')
    args = parser.parse_args()
    
    if args.action not in ['add', 'remove']:
        raise ValueError('Action must be "add" or "remove"')
    
    update_ssm_set(
        args.param, 
        args.elem, 
        args.action == 'add'
    )