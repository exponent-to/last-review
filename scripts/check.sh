#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh scripts/run.sh --headless --script res://tests/test_simulation.gd
sh scripts/run.sh --headless --script res://tests/test_interface.gd
sh scripts/run.sh --headless --script res://tests/test_intro.gd
