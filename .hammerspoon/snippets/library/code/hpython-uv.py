#!/usr/bin/env -S uv run --script
# {"desc":"Python Header - uv with httpx"}
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "httpx>=0.28.1",
# ]
# ///

import httpx
import json
import argparse
import asyncio
import textwrap
import os
