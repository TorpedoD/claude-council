#!/usr/bin/env bash
# Search the council journal for runs similar to a given question.
# Usage: journal_search.sh "<raw question text>"
#
# Matches first on sha1-prefix (stable key), then falls back to keyword
# overlap against recommendation_one_liner + dissent_ledger text. Caps at
# 2 results per SKILL.md Step 2.
set -euo pipefail

JOURNAL_DIR="$(cd "$(dirname "$0")/../journal" 2>/dev/null && pwd || echo "$(dirname "$0")/../journal")"
JOURNAL_FILE="$JOURNAL_DIR/council-log.jsonl"
MAX_RESULTS=2

[ ! -f "$JOURNAL_FILE" ] && exit 0
[ ! -s "$JOURNAL_FILE" ] && exit 0

QUERY="${1:-}"
[ -z "$QUERY" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  echo "Warning: jq not found — journal search skipped" >&2
  exit 0
fi

# Compute the query sha (same recipe as SKILL.md Step 9).
QUERY_SHA="$(printf '%s' "$QUERY" | shasum | cut -c1-8)"

# Pass 1: exact sha1-prefix match.
SHA_HITS=$(jq -rc --arg s "$QUERY_SHA" \
  'select(.question_sha1_prefix != null and (.question_sha1_prefix | startswith($s[0:8])))' \
  "$JOURNAL_FILE" 2>/dev/null | head -n "$MAX_RESULTS" || true)

format_line() {
  jq -r '"[\(.ts // "unknown date")] sha1:\(.question_sha1_prefix // "?") mode:\(.mode // "?") — \(.recommendation_one_liner // "(no summary)") — outcome: \(.outcome // "not recorded")"'
}

if [ -n "$SHA_HITS" ]; then
  printf '%s\n' "$SHA_HITS" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf '%s' "$line" | format_line
  done
  exit 0
fi

# Pass 2: keyword overlap. Keywords are lowercased, length >= 4, deduped,
# and grep'd with -F (fixed-string) to avoid regex injection from user input.
KEYWORDS=$(printf '%s' "$QUERY" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z' '\n' \
  | awk 'length >= 4' | sort -u | head -20)
[ -z "$KEYWORDS" ] && exit 0

RESULTS=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then continue; fi

  # Parenthesise // to force correct precedence — // binds looser than +, so
  # without parens the ledger join is never reached when rec is non-null.
  REC_TEXT=$(printf '%s' "$line" | jq -r \
    '(.recommendation_one_liner // "") + " " + ((.dissent_ledger // []) | join(" "))' \
    | tr '[:upper:]' '[:lower:]')

  SCORE=0
  for kw in $KEYWORDS; do
    if printf '%s' "$REC_TEXT" | grep -qF -- "$kw"; then
      SCORE=$((SCORE + 1))
    fi
  done

  if [ "$SCORE" -ge 2 ]; then
    printf '%s' "$line" | format_line
    RESULTS=$((RESULTS + 1))
    [ "$RESULTS" -ge "$MAX_RESULTS" ] && break
  fi
done < "$JOURNAL_FILE"

exit 0
