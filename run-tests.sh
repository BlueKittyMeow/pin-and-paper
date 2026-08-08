#!/usr/bin/env bash
# Serialized, load-capped, disk-safe `flutter test` for pin_and_paper.
#
# WHY THIS EXISTS (2026-08-06 full-suite "hang" postmortem):
# Full-suite runs were observed freezing forever at
# "canvas_screen_test.dart: (tearDownAll)". The tests were never the
# problem — every started suite (canvas included) completed. The freeze is
# flutter_tools' shared incremental compiler (frontend_server) dying or
# starving mid-run; the runner then waits forever on "loading <file>"
# compiles that never finish while the compact reporter redraws the last
# visible test label, which made it LOOK like a test-teardown hang.
#
# ROOT CAUSE, in order of impact on MysteryOfGlass:
#   1. DISK: /tmp lives on the root partition, which chronically runs
#      ~100% full. flutter test writes a ~55 MB kernel dill to
#      $TMPDIR/flutter_tools.*/ PER TEST FILE (plus a 54 MB cache copy),
#      several files at a time. When the partition fills, the compiler
#      wedges or crashes ("The Dart compiler exited unexpectedly", or a
#      silent hang when it dies while idle — flutter_tools' death check
#      races). Standalone single-file runs fit in the leftover space,
#      which is why they always passed. Killed runs leak their
#      /tmp/flutter_tools.* dirs, making the next run more likely to die.
#   2. Concurrent `flutter test` runs in the SAME checkout (e.g. two
#      Claude sessions) race over build/test_cache/*.dill state.
#   3. Memory pressure: default concurrency spawns (cores-2)=10
#      flutter_tester processes (~0.5 GB each) on a 15 GB machine that is
#      usually already swapping.
#
# This wrapper: redirects TMPDIR to /home (bigger partition), refuses to
# start without 2 GB free there, serializes runs per-checkout with flock,
# and caps tester concurrency.
#
# Usage:  ./run-tests.sh [flutter test args...]
#         CONCURRENCY=6 ./run-tests.sh test/screens/
set -euo pipefail

cd "$(dirname "$0")/pin_and_paper"

# 1. Temp space: flutter's compiler scratch goes on the roomier /home
#    partition instead of the chronically-full root partition.
export TMPDIR="${TMPDIR_OVERRIDE:-$HOME/.cache/flutter-test-tmp}"
mkdir -p "$TMPDIR"

# Preflight: fail loudly (instead of wedging silently) if temp space is low.
free_mb=$(df --output=avail -m "$TMPDIR" | tail -1 | tr -d ' ')
if [ "$free_mb" -lt 2048 ]; then
  echo "run-tests.sh: only ${free_mb} MB free on $(df --output=target -m "$TMPDIR" | tail -1)." >&2
  echo "flutter test needs ~2 GB of temp space for compiler dills; free some first." >&2
  exit 1
fi

# Stale compiler scratch from killed runs accumulates here; sweep dirs
# older than a day (they are only meaningful to a live run).
find "$TMPDIR" -maxdepth 1 -name 'flutter_tools.*' -mmin +1440 -exec rm -rf {} + 2>/dev/null || true

# 2 + 3. One run per checkout at a time; small tester fleet.
CONCURRENCY="${CONCURRENCY:-4}"
LOCK_FILE=".dart_tool/flutter_test.lock"
mkdir -p .dart_tool

exec flock -w 1800 "$LOCK_FILE" \
  flutter test --concurrency="$CONCURRENCY" "$@"
