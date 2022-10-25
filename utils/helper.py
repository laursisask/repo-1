#   -*- coding: utf-8 -*-
#
#   This file is part of allocator-cli
#
#   Copyright (C) 2020 SKALE Labs
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.

import datetime
import functools
import json
import logging
import os
import urllib
from decimal import Decimal

import click
from web3 import Web3

from utils.constants import (
    SKALE_ALLOCATOR_CONFIG_FILE,
    SKALE_ALLOCATOR_ABI_FILE,
    PERMILLE_MULTIPLIER,
    ZERO_ADDRESS,
    DEBUG_LOG_FILEPATH
)
from utils.texts import Texts
from utils.transaction import TxFee


G_TEXTS = Texts()
logger = logging.getLogger(__name__)


def safe_mk_dirs(path):
    if os.path.exists(path):
        return
    logger.info(f'Creating {path} directory')
    os.makedirs(path, exist_ok=True)


def read_json(path):
    with open(path, encoding='utf-8') as data_file:
        return json.loads(data_file.read())


def write_json(path, content):
    with open(path, 'w') as outfile:
        json.dump(content, outfile, indent=4)


def download_file(url, filepath):
    try:
        return urllib.request.urlretrieve(url, filepath)
    except urllib.error.HTTPError:
        print(f'Couldn\'t donwload file: {url}')


def config_exists():
    return os.path.exists(SKALE_ALLOCATOR_CONFIG_FILE)


def read_config():
    config = read_json(SKALE_ALLOCATOR_CONFIG_FILE)
    config['abi'] = read_json(SKALE_ALLOCATOR_ABI_FILE)
    return config


def get_config():
    if config_exists():
        return read_config()


def abort_if_false(ctx, param, value):
    if not value:
        ctx.abort()


def to_skl(wei, unit='ether'):  # todo: replace with from_wei()
    if wei is None:
        return None
    return Web3.fromWei(Decimal(wei), unit)


def from_wei(val, unit='ether'):
    if val is None:
        return None
    return Web3.fromWei(Decimal(val), unit)


def to_wei(val, unit='ether'):
    if val is None:
        return None
    return Web3.toWei(Decimal(val), unit)


def permille_to_percent(val):
    return int(val) / PERMILLE_MULTIPLIER


def percent_to_permille(val):
    return int(val * PERMILLE_MULTIPLIER)


def escrow_exists(skale, address):
    return skale.allocator.get_escrow_address(address) != ZERO_ADDRESS


def print_no_escrow_msg(address):
    print(f'\n{G_TEXTS["no_escrow"]}: {address}')


def convert_timestamp(timestamp):
    dt = datetime.datetime.utcfromtimestamp(int(timestamp))
    return dt.strftime('%d.%m.%Y')


def print_err_with_log_path(e=''):
    print(e, f'\nPlease check logs: {DEBUG_LOG_FILEPATH}')


def print_gas_price(gas_price):
    print(f'Transaction gas price: {from_wei(gas_price, unit="gwei")} Gwei ({gas_price} wei)\n')


def transaction_cmd(func):
    @click.option(
        '--pk-file',
        help=G_TEXTS['pk_file']['help']
    )
    @click.option(
        '--gas-price',
        type=float,
        help=G_TEXTS['gas_price']['help']
    )
    @click.option(
        '--max-fee',
        type=float,
        help=G_TEXTS['max_fee']['help']
    )
    @click.option(
        '--max-priority-fee',
        help=G_TEXTS['max_priority_fee']['help']
    )
    @functools.wraps(func)
    def wrapper(
            *args,
            gas_price=None,
            max_priority_fee=None,
            max_fee=None,
            **kwargs
    ):
        fee = TxFee(
            gas_price=to_wei(gas_price, 'gwei'),
            max_priority_fee_per_gas=to_wei(max_priority_fee, 'gwei'),
            max_fee_per_gas=to_wei(max_fee, 'gwei')
        )
        return func(*args, fee=fee, **kwargs)
    return wrapper
