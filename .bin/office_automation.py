#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import asyncio
import sys
from kasa import SmartPlug
from typing import List


async def toggle(host: str) -> None:
    dev = SmartPlug(host)
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
    args = parser.parse_args()
    await toggle(args.host)

if __name__ == '__main__':
    asyncio.run(main())
