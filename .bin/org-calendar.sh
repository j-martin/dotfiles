#!/usr/bin/env bash

set -o errexit
set -o pipefail

awk -f ical2org.awk <(curl --silent "$(keyring get system cal-jmartin)") >> ~/.org/calendar.org
