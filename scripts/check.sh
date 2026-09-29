#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh scripts/run.sh --headless --script res://tests/test_simulation.gd
sh scripts/run.sh --headless --script res://tests/test_shift_clock.gd
sh scripts/run.sh --headless --script res://tests/test_interface.gd
sh scripts/run.sh --headless --script res://tests/test_application.gd
sh scripts/run.sh --headless --script res://tests/test_desktop_window.gd
sh scripts/run.sh --headless --script res://tests/test_chat.gd
sh scripts/run.sh --headless --script res://tests/test_main_menu.gd
sh scripts/run.sh --headless --script res://tests/test_tutorial.gd
sh scripts/run.sh --headless --script res://tests/test_manager.gd
sh scripts/run.sh --headless --script res://tests/test_notifications.gd
