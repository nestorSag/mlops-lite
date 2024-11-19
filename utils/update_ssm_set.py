"""
This script is used to update a set stored in SSM. The set is stored as a comma-separated string, where elements are sorted.
"""
import argparse
import logging
import re

import boto3

from utils.init_ssm_param import init_or_get_ssm_param
ssm = boto3.client('ssm')

def fetch_ssm_set(param: str) -> set:
    
    response = init_or_get_ssm_param(param)
    raw_value = response['Parameter']['Value']
    values = re.search(r'^\[(.*)\]$', raw_value).group(1).split(',')
    values = set([v for v in values if v != ""]) # drop empty strings
    return values

def upload_ssm_set(param: str, value: set) -> None:
    str_value = "[" + ",".join(sorted(list(value))) + "]"
    logging.info(f"Updated {param} to {str_value}")
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
    values = fetch_ssm_set(param)
    if add:
        logging.info(f'Adding {elem} to {param}')
        values.add(elem)
    else:
        values.discard(elem)
        logging.info(f'Removing {elem} from {param}')
    upload_ssm_set(param, values)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Update an SSM parameter that stores a Python set')
    parser.add_argument('--param', type=str, help='SSM set')
    parser.add_argument('--elem', type=str, help='Element to add or remove')
    parser.add_argument('--action', type=str, help='Action')
    args = parser.parse_args()
    
    if args.action not in ['add', 'remove']:
        raise ValueError('Action must be "add" or "remove"')
    
    update_ssm_set(
        args.param, 
        args.elem, 
        args.action == 'add'
    )