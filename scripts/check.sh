#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh scripts/run.sh --headless --script res://tests/test_simulation.gd
sh scripts/run.sh --headless --script res://tests/test_shift_clock.gd
sh scripts/run.sh --headless --script res://tests/test_desk.gd
sh scripts/run.sh --headless --script res://tests/test_interface.gd
sh scripts/run.sh --headless --script res://tests/test_application.gd
sh scripts/run.sh --headless --script res://tests/test_desktop_window.gd
sh scripts/run.sh --headless --script res://tests/test_chat.gd
sh scripts/run.sh --headless --script res://tests/test_main_menu.gd
sh scripts/run.sh --headless --script res://tests/test_tutorial.gd
sh scripts/run.sh --headless --script res://tests/test_manager.gd
sh scripts/run.sh --headless --script res://tests/test_notifications.gd
sh scripts/run.sh --headless --script res://tests/test_cold_open.gd
sh scripts/run.sh --headless --script res://tests/test_daily_press.gd
sh scripts/run.sh --headless --script res://tests/test_daily_reader.gd
sh scripts/run.sh --headless --script res://tests/test_save_slots.gd
sh scripts/run.sh --headless --script res://tests/test_policy_campaign.gd
sh scripts/run.sh --headless --script res://tests/test_policy_integration.gd
sh scripts/run.sh --headless --script res://tests/test_tutorial_pointer.gd
sh scripts/run.sh --headless --script res://tests/test_banter.gd
sh scripts/run.sh --headless --script res://tests/test_portraits.gd
sh scripts/run.sh --headless --script res://tests/test_pr_bank.gd
sh scripts/run.sh --headless --script res://tests/test_encounters.gd
