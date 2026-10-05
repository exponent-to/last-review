#!/bin/sh
# Run every test suite, CHECK_JOBS at a time (default: CPU count, at most 8).
# Each suite's output goes to its own log; a one-line result is printed as each
# finishes, and the logs of any failing suites are printed in full at the end.
# Exits non-zero if any suite fails. CHECK_JOBS=1 runs them one by one.
set -eu
cd "$(dirname "$0")/.."

# Every tests/test_*.gd, longest first so the slow suites never start last.
slow="test_simulation test_shift_clock test_policy_integration test_interface test_encounters test_pr_bank"
suites=$slow
for path in tests/test_*.gd; do
	suite=$(basename "$path" .gd)
	case " $slow " in *" $suite "*) ;; *) suites="$suites $suite" ;; esac
done

cpus=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
jobs=${CHECK_JOBS:-$cpus}
[ "$jobs" -gt 8 ] && [ -z "${CHECK_JOBS:-}" ] && jobs=8
[ "$jobs" -ge 1 ] || jobs=1

logs=$(mktemp -d "${TMPDIR:-/tmp}/check.XXXXXX")
trap 'rm -rf "$logs"' EXIT INT TERM
started=$(date +%s)
total=$(echo $suites | wc -w | tr -d ' ')
echo "Running $total suites, $jobs at a time."

# The worker never fails xargs itself: a failing suite is recorded in
# $logs/failed, so one failure can't stop the others from running or reporting.
printf '%s\n' $suites | xargs -P "$jobs" -I{} sh -c '
	suite=$1
	logs=$2
	begin=$(date +%s)
	if sh scripts/run.sh --headless --script "res://tests/$suite.gd" >"$logs/$suite.log" 2>&1; then
		result=ok
	else
		result=FAIL
		echo "$suite" >>"$logs/failed"
	fi
	printf "%-4s %-26s %4ss\n" "$result" "$suite" "$(( $(date +%s) - begin ))"
' check-suite {} "$logs"

elapsed=$(( $(date +%s) - started ))
if [ -s "$logs/failed" ]; then
	for suite in $(sort "$logs/failed"); do
		printf '\n===== %s =====\n' "$suite"
		cat "$logs/$suite.log"
	done
	printf '\n%s of %s suites failed in %ss:\n' "$(wc -l <"$logs/failed" | tr -d ' ')" "$total" "$elapsed"
	sort "$logs/failed" | sed 's/^/  /'
	exit 1
fi
echo "All $total suites passed in ${elapsed}s."
