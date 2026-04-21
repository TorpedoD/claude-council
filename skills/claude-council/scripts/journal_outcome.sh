#!/usr/bin/env bash
# Record the outcome of a prior council run by sha1-prefix match.
# Usage: journal_outcome.sh <sha1_prefix> <outcome_note...>
#
# Looks up runs in council-log.jsonl whose question_sha1_prefix starts with
# <sha1_prefix>, then sets their .outcome field to <outcome_note>. Uses the
# same mkdir-lock as journal_append.sh so concurrent writes can't interleave.
set -euo pipefail

JOURNAL_DIR="$(cd "$(dirname "$0")/../journal" 2>/dev/null && pwd || echo "$(dirname "$0")/../journal")"
JOURNAL_FILE="$JOURNAL_DIR/council-log.jsonl"
LOCK_DIR="$JOURNAL_DIR/.append.lock.d"

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
  echo "Usage: journal_outcome.sh <sha1_prefix> <outcome note ...>" >&2
  exit 1
fi
PREFIX="$1"; shift
NOTE="$*"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required. Install with: brew install jq" >&2
  exit 2
fi
if [ ! -f "$JOURNAL_FILE" ]; then
  echo "Error: no journal found at $JOURNAL_FILE" >&2
  exit 3
fi

acquire_lock() {
  if command -v flock >/dev/null 2>&1; then
    exec 200>"$JOURNAL_FILE.lock"
    flock -x 200
    LOCK_MODE="flock"
    return 0
  fi
  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    tries=$((tries + 1))
    [ "$tries" -gt 50 ] && { echo "Error: lock timeout" >&2; exit 4; }
    sleep 0.1
  done
  LOCK_MODE="mkdir"
}
release_lock() {
  [ "${LOCK_MODE:-}" = "mkdir" ] && rmdir "$LOCK_DIR" 2>/dev/null || true
}
LOCK_MODE=""
trap 'release_lock' EXIT INT TERM
acquire_lock

TMP="$(mktemp "${JOURNAL_FILE}.XXXXXX")"
MATCHED=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
    # Preserve corrupt lines untouched.
    printf '%s\n' "$line" >> "$TMP"
    continue
  fi
  CUR_PREFIX="$(printf '%s' "$line" | jq -r '.question_sha1_prefix // ""')"
  case "$CUR_PREFIX" in
    "$PREFIX"*)
      printf '%s' "$line" | jq -c --arg n "$NOTE" '.outcome = $n' >> "$TMP"
      MATCHED=$((MATCHED + 1))
      ;;
    *)
      printf '%s\n' "$line" >> "$TMP"
      ;;
  esac
done < "$JOURNAL_FILE"

if [ "$MATCHED" -eq 0 ]; then
  rm -f "$TMP"
  release_lock
  trap - EXIT INT TERM
  echo "No matching run for sha1 prefix: $PREFIX" >&2
  exit 5
fi

mv "$TMP" "$JOURNAL_FILE"
release_lock
trap - EXIT INT TERM
echo "Updated $MATCHED run(s) with outcome: $NOTE"
