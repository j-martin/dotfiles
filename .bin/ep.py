#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from sys import stdin
from datetime import datetime


def process(date):
    now = datetime.now()
    utcnow = datetime.utcnow()
    d = date.strip()
    try:
        timestamp = int(d)
    except:
        timestamp = 0

    print("now       local    : {} | {}".format(rounded(now), rounded(now.timestamp())))
    print("now       utc      : {} | {}".format(rounded(utcnow), rounded(utcnow.timestamp())))

    if timestamp < 2147483647:
        print("timestamp local  s : {} | {}".format(rounded(datetime.fromtimestamp(timestamp)), rounded(d)))
        print("timestamp utc    s : {} | {}".format(rounded(datetime.utcfromtimestamp(timestamp)), rounded(d)))
    elif timestamp > 0:
        timestamp = timestamp / 1000
        print("timestamp local ms : {} | {}".format(rounded(datetime.fromtimestamp(timestamp)), rounded(d)))
        print("timestamp utc   ms : {} | {}".format(rounded(datetime.utcfromtimestamp(timestamp)), rounded(d)))


def rounded(date):
    return str(date).split('.')[0]


def main():
    [process(line) for line in stdin.readlines()]

if __name__ == '__main__':
    main()
