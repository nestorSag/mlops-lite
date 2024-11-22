"""
This script is used to update a valid JSON string stored in SSM.
"""
import argparse
import logging
import re
import json

import boto3

from init_ssm_param import init_or_get_ssm_param
ssm = boto3.client('ssm')

def fetch_ssm_json(param: str) -> set:
    
    response = init_or_get_ssm_param(param, is_json=True)
    raw_value = response['Parameter']['Value']
    return json.loads(raw_value)

def upload_ssm_json(param: str, json_: dict) -> None:
    str_value = json.dumps(json_)
    logging.info(f"Updated {param} to {str_value}")
    ssm.put_parameter(
        Name=param,
        Value=str_value,
        Type='String',
        Overwrite=True
    )

def update_ssm_json(
    param: str,
    key: str,
    value: str = None,
    add: bool = True
):
    json_ = fetch_ssm_json(param)
    if add:
        if value is None:
            raise ValueError('Value must be provided when adding')
        else:
            logging.info(f"Adding '{key}' -> '{value}' to {param}")
            json_[key] = value
    else:
        try:
            del json_[key]
        except KeyError:
            logging.warning(f"Key '{key}' not found in {param}")
            return
        logging.info(f"Removing '{key}' -> '{value}' from {param}")
    upload_ssm_json(param, json_)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Update an SSM parameter that stores a JSON')
    parser.add_argument('--param', type=str, help='SSM set')
    parser.add_argument('--key', type=str, help='Key to add or remove')
    parser.add_argument('--value', type=str, help='Value to add or remove')
    parser.add_argument('--action', type=str, help='Action')
    args = parser.parse_args()
    
    if args.action not in ['add', 'remove']:
        raise ValueError('Action must be "add" or "remove"')
    
    update_ssm_json(
        args.param, 
        args.key,
        args.value,
        args.action == 'add',
    )