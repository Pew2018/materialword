#!/usr/bin/env bash
# Synthetic data only. Verify the same persisted event in two real TZ processes.
set -euo pipefail
probe_directory=$(mktemp -d "${TMPDIR:-/tmp}/materialword-timezone.XXXXXX")
trap 'rm -rf "$probe_directory"' EXIT
TZ=Asia/Hong_Kong MW_TZ_PHASE=author MW_TZ_FILE="$probe_directory/event.json" \
  flutter test --no-pub test/helpers/timezone_replay_probe.dart --reporter expanded
TZ=America/New_York MW_TZ_PHASE=reader MW_TZ_FILE="$probe_directory/event.json" \
  flutter test --no-pub test/helpers/timezone_replay_probe.dart --reporter expanded
