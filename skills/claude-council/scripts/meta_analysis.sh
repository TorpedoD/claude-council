#!/usr/bin/env bash
# Aggregate the council journal to surface patterns for persona refinement.
# Usage: meta_analysis.sh
# Outputs a dated amendment proposal to journal/persona-diffs/YYYY-MM-DD-amendments.md
# Requires jq for JSON parsing.

SCRIPT_DIR="$(dirname "$0")"
JOURNAL_DIR="$SCRIPT_DIR/../journal"
JOURNAL_FILE="$JOURNAL_DIR/council-log.jsonl"
DIFFS_DIR="$JOURNAL_DIR/persona-diffs"
TODAY=$(date +%Y-%m-%d)
OUTPUT_FILE="$DIFFS_DIR/$TODAY-amendments.md"

if [ ! -f "$JOURNAL_FILE" ]; then
  echo "No journal found at $JOURNAL_FILE. Run at least one council first." >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "jq is required for meta-analysis. Install via: brew install jq" >&2
  exit 1
fi

mkdir -p "$DIFFS_DIR"

TOTAL=$(wc -l < "$JOURNAL_FILE" | tr -d ' ')
if [ "$TOTAL" -lt 5 ]; then
  echo "Only $TOTAL runs in journal — need at least 5 for meaningful patterns." >&2
  echo "Run more councils and record outcomes before running meta-analysis." >&2
  exit 1
fi

echo "Analyzing $TOTAL council runs..."

# Count outcomes — use boolean select; `jq -r` on `null` emits nothing,
# so the prior `select(.outcome == null) | .outcome` pattern always produced 0.
OUTCOMES_RECORDED=$(jq -r 'select((.outcome // null) != null) | "x"' "$JOURNAL_FILE" | wc -l | tr -d ' ')
OUTCOMES_NULL=$(jq -r 'select((.outcome // null) == null) | "x"' "$JOURNAL_FILE" | wc -l | tr -d ' ')

# Confidence distribution per persona — aggregate all 5, not just 2.
count_conf() {  # $1=persona key, $2=level
  jq -r ".advisors_confidence.$1 // empty" "$JOURNAL_FILE" | grep -c "^$2$" || true
}
RED_TEAM_HIGH=$(count_conf red_team high);          RED_TEAM_LOW=$(count_conf red_team low)
FIRST_PRIN_HIGH=$(count_conf first_principles high); FIRST_PRIN_LOW=$(count_conf first_principles low)
EXPAND_HIGH=$(count_conf expansionist high);         EXPAND_LOW=$(count_conf expansionist low)
OUTSIDER_HIGH=$(count_conf outsider high);           OUTSIDER_LOW=$(count_conf outsider low)
EXEC_HIGH=$(count_conf executor high);               EXEC_LOW=$(count_conf executor low)

# Bias frequency
TOP_BIASES=$(jq -r '.biases_flagged[]? // empty' "$JOURNAL_FILE" | sort | uniq -c | sort -rn | head -5)

# Mode distribution
MODE_QUICK=$(jq -r 'select(.mode == "Quick") | .mode' "$JOURNAL_FILE" | wc -l | tr -d ' ')
MODE_STANDARD=$(jq -r 'select(.mode == "Standard") | .mode' "$JOURNAL_FILE" | wc -l | tr -d ' ')
MODE_DEEP=$(jq -r 'select(.mode == "Deep") | .mode' "$JOURNAL_FILE" | wc -l | tr -d ' ')

# Chairman confidence distribution
CHAIR_HIGH=$(jq -r 'select(.chairman_confidence == "high") | .chairman_confidence' "$JOURNAL_FILE" | wc -l | tr -d ' ')
CHAIR_LOW=$(jq -r 'select(.chairman_confidence == "low") | .chairman_confidence' "$JOURNAL_FILE" | wc -l | tr -d ' ')

# Write amendment proposal
cat > "$OUTPUT_FILE" << EOF
# Council Meta-Analysis — $TODAY

Generated from $TOTAL council runs.

## Summary Statistics

| Metric | Value |
|---|---|
| Total runs | $TOTAL |
| Outcomes recorded | $OUTCOMES_RECORDED |
| Outcomes missing | $OUTCOMES_NULL |
| Quick mode runs | $MODE_QUICK |
| Standard mode runs | $MODE_STANDARD |
| Deep mode runs | $MODE_DEEP |
| Chairman high-confidence runs | $CHAIR_HIGH |
| Chairman low-confidence runs | $CHAIR_LOW |

## Bias Frequency (top flags)

\`\`\`
$TOP_BIASES
\`\`\`

## Persona Confidence Patterns

| Persona | High | Low |
|---|---|---|
| Red Team | $RED_TEAM_HIGH | $RED_TEAM_LOW |
| First Principles | $FIRST_PRIN_HIGH | $FIRST_PRIN_LOW |
| Expansionist | $EXPAND_HIGH | $EXPAND_LOW |
| Outsider | $OUTSIDER_HIGH | $OUTSIDER_LOW |
| Executor | $EXEC_HIGH | $EXEC_LOW |

## Proposed Amendments

Review these manually. Accept, reject, or modify as appropriate. Never auto-apply.

EOF

# Generate contextual amendment suggestions based on patterns
if [ "$CHAIR_LOW" -gt "$((TOTAL / 3))" ]; then
  echo "### Chairman confidence is low in >33% of runs" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Possible causes: questions are routinely under-constrained before council runs; bias audit flags are not being heeded; advisor confidence blocks are systematically uncertain." >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "**Proposed:** Add a more aggressive pre-triage check — if framed question lacks explicit stakes and at least 2 concrete options, always ask for clarification before fan-out." >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

if [ "$RED_TEAM_LOW" -gt "$RED_TEAM_HIGH" ]; then
  echo "### Red Team confidence skews low more than high" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Red Team is being uncertain when it should be attacking confidently. The pre-mortem structure may need strengthening — agents that hedge on the attack are not fulfilling the adversarial role." >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "**Proposed:** Add to Red Team prompt: 'If you cannot identify a specific failure mode, force yourself to construct the most plausible one. A speculative attack is more useful than a hedged non-attack.'" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

if [ "$EXEC_LOW" -gt "$EXEC_HIGH" ]; then
  echo "### Executor confidence is frequently low" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Executor is correctly triggering DATA COMPLETENESS: DRAFT STATUS when inputs are missing. This may indicate most council questions are under-specified for operational planning. Consider adding a step that prompts the user for key operational facts before running the Executor." >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

if [ "$FIRST_PRIN_LOW" -gt "$FIRST_PRIN_HIGH" ]; then
  echo "### First Principles confidence skews low" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "First Principles is hedging on reframings. The Tree-of-Thoughts approach may need tighter constraints — force commitment to the strongest reframing rather than presenting all three as equal." >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

if [ "$EXPAND_LOW" -gt "$EXPAND_HIGH" ]; then
  echo "### Expansionist confidence skews low" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Expansionist is unsure of its alternative options. This may indicate the questions are too domain-specific for cross-frame ideation. Consider adding: 'If you cannot generate 3 genuinely novel options, generate 2 and explain why the frame constrains further options.'" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

if [ "$OUTSIDER_LOW" -gt "$OUTSIDER_HIGH" ]; then
  echo "### Outsider confidence skews low" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Outsider is frequently uncertain, which may be appropriate (the role is deliberately under-informed). If Outsider confidence is *always* low, the cross-domain insight may not be adding value — consider whether the field-channelling approach needs sharper selection criteria." >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

if [ "$OUTCOMES_NULL" -gt "$((TOTAL * 2 / 3))" ]; then
  echo "### Outcome tracking is sparse ($OUTCOMES_NULL/$TOTAL runs have no outcome recorded)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Without outcomes, meta-analysis cannot improve persona calibration over time. The self-improvement loop depends on knowing which recommendations played out. Remind users more prominently to record outcomes." >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "**Proposed:** Add to the end-of-run user message: 'Recording outcomes is what makes the council improve over time. Even a one-word note (\"worked\", \"wrong\", \"still deciding\") helps.'" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"
echo "_This file was auto-generated. Apply amendments manually to \`references/personas.md\` after review._" >> "$OUTPUT_FILE"

echo "Amendment proposal written to: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
