#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import asyncio
import sys
# from kasa import SmartPlug
from homeassistant_api import Client
import keyring
from typing import List
import time
import io

COMMAND_ON = 'on'
COMMAND_OFF = 'off'
COMMAND_TOGGLE = 'toggle'

def switch(entity_id: str, command: str) -> None:
    client = Client('https://assistant.home.jmartin.ca/api', keyring.get_password('system', 'homeassistant'))
    switch = client.get_domain('switch')
    # switch.turn_on(entity_id="switch.office_desk")
    if command == COMMAND_ON:
        switch.turn_on(entity_id=entity_id)
        print(f"Turned on: {entity_id}")
    elif command == COMMAND_OFF:
        switch.turn_off(entity_id=entity_id)
        print(f"Turned off: {entity_id}")
    elif command == COMMAND_TOGGLE:
        switch.toggle(entity_id=entity_id)
        print(f"Toggled: {entity_id}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--entity-id", default="switch.desk_lights")
    parser.add_argument("command", choices=[COMMAND_ON, COMMAND_OFF, COMMAND_TOGGLE])
    args = parser.parse_args()

    with open('out', 'w+') as fp:
        fp.seek(0, io.SEEK_END)
        fp.writelines([f"{time.time()} - {args.command}\n"])

    switch(args.entity_id, args.command)

if __name__ == '__main__':
    main()
