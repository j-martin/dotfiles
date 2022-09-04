#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import asyncio
import sys
from kasa import SmartPlug
from typing import List

COMMAND_ON = 'on'
COMMAND_OFF = 'off'

def switch(host: str, command: str) -> None:
    dev = SmartPlug(host)
    if command == COMMAND_OFF:
        asyncio.run(dev.turn_off())
    else:
        asyncio.run(dev.turn_on())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="lights.office.jmartin.ca")
    parser.add_argument("command", choices=[COMMAND_ON, COMMAND_OFF])
    args = parser.parse_args()

    switch(args.host, args.command)

if __name__ == '__main__':
    main()
