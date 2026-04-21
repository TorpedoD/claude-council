#!/usr/bin/env bash
# Append a council run record to the JSONL journal atomically.
# Usage: journal_append.sh '<json_string>'
# The JSON string is passed as the first argument.
set -euo pipefail

JOURNAL_DIR="$(cd "$(dirname "$0")/../journal" 2>/dev/null && pwd || echo "$(dirname "$0")/../journal")"
JOURNAL_FILE="$JOURNAL_DIR/council-log.jsonl"
LOCK_DIR="$JOURNAL_DIR/.append.lock.d"

mkdir -p "$JOURNAL_DIR"
[ -f "$JOURNAL_FILE" ] || : > "$JOURNAL_FILE"

if [ "${1:-}" = "" ]; then
  echo "Error: no JSON payload provided" >&2
  exit 1
fi
JSON_PAYLOAD="$1"

# jq is required — silent skip lets malformed payloads corrupt the journal.
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required. Install with: brew install jq" >&2
  exit 2
fi

# Validate JSON (structural) before taking the lock.
if ! printf '%s' "$JSON_PAYLOAD" | jq -e . >/dev/null 2>&1; then
  echo "Error: invalid JSON payload" >&2
  exit 3
fi

# Normalise to single line; strip embedded newlines that would break JSONL.
JSON_LINE="$(printf '%s' "$JSON_PAYLOAD" | jq -c .)"

# Portable append lock: prefer flock (Linux / Homebrew util-linux); fall back
# to mkdir-based locking, which is atomic across POSIX filesystems incl. macOS.
acquire_lock() {
  if command -v flock >/dev/null 2>&1; then
    exec 200>"$JOURNAL_FILE.lock"
    flock -x 200
    LOCK_MODE="flock"
    return 0
  fi
  # mkdir is atomic; spin with bounded retries (~5s total).
  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 50 ]; then
      echo "Error: could not acquire journal lock after ~5s ($LOCK_DIR)" >&2
      exit 4
    fi
    sleep 0.1
  done
  LOCK_MODE="mkdir"
}

release_lock() {
  if [ "${LOCK_MODE:-}" = "mkdir" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
  # flock mode: fd 200 released automatically on exit.
}

LOCK_MODE=""
trap 'release_lock' EXIT INT TERM
acquire_lock

printf '%s\n' "$JSON_LINE" >> "$JOURNAL_FILE"

release_lock
trap - EXIT INT TERM

echo "Journal updated: $JOURNAL_FILE"
