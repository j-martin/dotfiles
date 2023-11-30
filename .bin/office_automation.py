#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import asyncio
import sys
from homeassistant_api import Client
import keyring
from typing import List
import time
import io

COMMAND_ON = 'on'
COMMAND_OFF = 'off'


def trigger_scene(scene_id: str, command: str) -> None:
    client = Client('https://assistant.home.jmartin.ca/api', keyring.get_password('system', 'homeassistant'))
    scene = client.get_domain('scene')
    scene_prefix = f"scene.{scene_id}"
    entity_id=f"{scene_prefix}_{command}"
    print(f"Turned {command}: {entity_id}")
    scene.turn_on(entity_id=entity_id)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scene", default="office_call")
    parser.add_argument("command", choices=[COMMAND_ON, COMMAND_OFF])
    args = parser.parse_args()

    with open('out', 'w+') as fp:
        fp.seek(0, io.SEEK_END)
        fp.writelines([f"{time.time()} - {args.command}\n"])

    trigger_scene(args.scene, args.command)

if __name__ == '__main__':
    main()
