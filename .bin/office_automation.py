#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import asyncio
import sys
from kasa import SmartPlug
from typing import List
import time
import io

COMMAND_ON = 'on'
COMMAND_OFF = 'off'
COMMAND_TOGGLE = 'toggle'

async def switch(host: str, command: str) -> None:
    dev = SmartPlug(host)
    if command == COMMAND_ON:
        await dev.turn_on()
        print(f"Turned on: {host}")
    elif command == COMMAND_OFF:
        await dev.turn_off()
        print(f"Turned off: {host}")
    elif command == COMMAND_TOGGLE:
        await dev.update()
        if dev.is_on:
            await dev.turn_off()
            print(f"Turned off: {host}")
        else:
            await dev.turn_on()
            print(f"Turned on: {host}")


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="lights.office.jmartin.ca")
    parser.add_argument("command", choices=[COMMAND_ON, COMMAND_OFF, COMMAND_TOGGLE])
    args = parser.parse_args()

    with open('out', 'w+') as fp:
        fp.seek(0, io.SEEK_END)
        fp.writelines([f"{time.time()} - {args.command}\n"])

    await switch(args.host, args.command)

if __name__ == '__main__':
    asyncio.run(main())
