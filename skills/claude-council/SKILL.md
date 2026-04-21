---
name: claude-council
description: |
  Convene a structured LLM Council — five thinking-lens advisors (Red Team, First Principles, Expansionist, Outsider, Executor) plus anonymised peer review, forced debate on consensus, dual-chairman synthesis with dissent preservation, and optional Codex-powered Decision Science pass — to pressure-test high-stakes decisions. Adaptive modes (Quick/Standard/Deep) keep cost bounded; a persistent journal enables learning across runs. Mandatory triggers: /claude-council, "convene the council", "run this by the council", "I need the council", "council this", "pressure-test this", "stress-test this", "war room this", "debate this". Strong triggers: "I'm torn between X and Y", "this is a big decision", "help me think this through from multiple angles", "I need outside perspectives", "should I X or Y" (with real stakes — if binary with obvious answer, triage rejects per Step 1 rule 4). Do NOT invoke for factual questions, coding help, debugging, quick yes/no decisions, emotional support, or questions with one right answer — answer those directly. Optional suffixes: "with codex" enables Decision Science pass; "deep" forces Deep mode; "quick" forces Quick mode. Secondary invocation: /claude-council outcome <sha1> <note> records decision outcome. /claude-council meta runs journal meta-analysis.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, AskUserQuestion
---

# LLM Council

> **Install path assumption:** This skill assumes installation at `~/.claude/skills/claude-council/`. If installed elsewhere (e.g., `~/.claude/plugins/<name>/skills/claude-council/`), adjust script paths in Steps 0, 2, and 10 accordingly.

Run any high-stakes decision through five structured thinking lenses, a peer-review round, a forced debate when consensus is too clean, and a dual-chairman synthesis that preserves dissent. Every run logs to a journal; outcomes feed a self-improvement loop that proposes persona refinements over time.

**Not for:** factual lookups, debugging, single-domain technical questions, quick yes/no decisions, emotional support. If none of the options feel genuinely hard, just answer directly.

---

## Step 0 — Handle special invocations first

- `/claude-council outcome <sha1> <note>` — look up the run in `~/.claude/skills/claude-council/journal/council-log.jsonl` by sha1 prefix, update its `outcome` field, and confirm. Done.
- `/claude-council meta` — run `bash ~/.claude/skills/claude-council/scripts/meta_analysis.sh` and surface the resulting amendment file path. Done.
- Any other invocation → continue to Step 1.

---

## Step 1 — Triage

Reject and answer directly if ANY applies:
1. Factual / one right answer ("capital of France?")
2. Single-domain technical — a competent practitioner tweets it
3. No stakes named — ask once via AskUserQuestion "what makes this high-stakes?"; if user shrugs, drop
4. Binary with obvious answer ("ship untested code to prod Friday?")
5. Already decided and seeking validation — ask: challenge or confirm? If confirm, skip
6. Emotional-support framing — say so kindly, don't council it

---

## Step 2 — Pre-run journal lookup

Escape the raw question for safe shell passing: replace all single quotes with `'\''`, then wrap in single quotes. Store as `$ESCAPED_QUESTION`. Never pass raw user text directly to bash — `$(...)`, backticks, and `\` sequences in the question would execute.

```bash
bash ~/.claude/skills/claude-council/scripts/journal_search.sh "$ESCAPED_QUESTION"
```

If ≥1 prior run matches on sha1-prefix or keyword overlap: surface a one-line summary ("Related council on DATE — recommended X — outcome: Y") and inject up to 2 prior verdicts as **"Prior council context"** in the framed question.

---

## Step 3 — Frame the question + Bias Audit

**3a. Workspace scan** — Glob for `CLAUDE.md`, `memory/`, any user-referenced files. Cap at 3 files chosen by recency + CLAUDE.md precedence. Cap framed question at ~4k tokens; note truncation in transcript. If no `CLAUDE.md` or `memory/` files are found, include in the transcript: "Workspace scan: no project context found. Council proceeds with user-provided context only."

If question is vague, use AskUserQuestion **once** to clarify. Then produce `{{FRAMED_QUESTION}}`:
```
DECISION: <core question>
CONTEXT: <workspace + user context>
STAKES: <what's at stake>
OPTIONS: <options named by user, if any>
PRIOR: <prior council context if any>
```

Store the full framed question text as the shell variable `FRAMED_QUESTION` for use in Step 9 SHA computation. Escape single quotes in the text (`'` → `'\''`).

**3b. Bias Audit** — **skip in Quick mode** (latency cost is not justified; see `references/modes.md`). In Standard/Deep: single Agent() call using the prompt in `references/bias-audit.md`. Pass `{{FRAMED_QUESTION}}`. Receives back a structured bias-flags list. Append to framed question as:
```
BIAS FLAGS: <list — these are signals, not verdicts>
```

If the bias audit returns "BIAS AUDIT: Clean — no significant distortions detected.", omit the `BIAS FLAGS:` section from the framed question entirely. In the HTML report, render `{{BIAS_FLAGS_HTML}}` as an empty string.

---

## Step 4 — Mode selection

Read `references/modes.md` for full escalation logic. Summary:

| Mode | When | ~Calls |
|---|---|---|
| Quick | "quick" suffix / stakes < $1k / ≤ 1-day reversible | 4 |
| Standard | default | 13–15 |
| Deep | "deep" / high stakes / auto-escalate from low confidence | 16 + 1 Codex |

---

## Step 5 — Fan-out (parallel Agent calls)

Read `references/personas.md` for all five persona prompts. Dispatch in a **single turn**:

- **Standard/Deep:** 5 parallel `Agent(subagent_type="general-purpose", description="<persona>", prompt=<persona_prompt with FRAMED_QUESTION substituted>)` calls
- **Quick:** 3 advisors (Red Team, Executor, First Principles)

**Deep mode enhancement:** For Deep mode, append to First Principles and Expansionist prompts: "Return ALL three reframings/options with full reasoning for each, not just the strongest + runner-up."

Every persona prompt mandates this appendix at the end of the response:
```
=== CONFIDENCE ===
confidence: high | medium | low
assumptions: <bulleted premises>
what_would_change_my_mind: <1-3 signals>
unknowns: <missing facts>
```

For Deep mode, the **Codex Decision Science pass** runs after advisors return (Step 6) — not in parallel — so Codex can evaluate advisor-surfaced options, not just the options the user named.

---

## Step 6 — Codex Decision Science pass (Deep mode / "with codex")

Read `references/decision-science.md`. Extract the options from `{{FRAMED_QUESTION}}` + advisors' responses.

**Codex invocation:**

Detect available timeout command; fall back gracefully on stock macOS:

```bash
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout 120"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout 120"
else
  TIMEOUT_CMD=""
fi

if command -v codex >/dev/null 2>&1; then
  CODEX_OUTPUT=$(printf '%s' "$DECISION_SCIENCE_PROMPT" \
    | $TIMEOUT_CMD codex exec --sandbox read-only --skip-git-repo-check -) \
    || CODEX_OUTPUT=""
fi
```

**Safety note:** The prompt is piped via stdin using `printf '%s'`, not a heredoc — this avoids shell expansion of any `$`, backticks, or metacharacters in the prompt text. The orchestrator must pre-build `$DECISION_SCIENCE_PROMPT` as a shell variable containing the full decision-science prompt (from `references/decision-science.md`) with `{{FRAMED_QUESTION}}` and `{{OPTIONS_LIST}}` already substituted in as literal text.

**Fallback** (Codex absent, timed out, or errored): `Agent(subagent_type="general-purpose", prompt=<decision-science prompt>)`. Set `CODEX_USED=false`. If Codex ran successfully, set `CODEX_USED=true`. These must be the literal JSON booleans `true` or `false` (no quotes) — `--argjson` in Step 10 requires valid JSON.

**Parsing Decision Science output:** The output contains JSON blocks followed by plain-text RANKING/DOMINATED/KEY ASSUMPTION sections. Parse JSON blocks by matching `{` ... `}` boundaries (the schema has no nested objects). If JSON parsing fails on any block, capture the raw text and present it in the transcript — do not crash the council. The plain-text sections follow the last JSON block.

---

## Step 7 — Anonymize + Peer review + Forced Debate

**7a. Anonymize** — Steps:
1. Generate a random A-E permutation seeded from the first 4 hex digits of `$SHA` (deterministic per question, reduces journal diff noise). Record the mapping in the transcript.
2. Strip each response's first line if it contains a self-identification.
3. **Structural sanitisation** — regex-replace persona-signature patterns that leak identity through anonymised text:
   - `THE FAILURE MODE` / `THE ROOT CAUSE` / `THE MISSED SIGNAL` / `THE ALTERNATIVE` → `POINT 1` / `POINT 2` / `POINT 3` / `POINT 4`
   - `REFRAMING [ABC]` → `PERSPECTIVE [1/2/3]`; `STRONGEST:` / `RUNNER-UP:` → `PRIMARY:` / `SECONDARY:`
   - `OPTION [XYZ]` → `ALTERNATIVE [1/2/3]`; `DOMINANT:` → `RECOMMENDED:`
   - `FIELD:` / `NAIVE READ:` / `BUBBLE SPOTS:` / `CROSS-DOMAIN INSIGHT:` → `LENS:` / `INITIAL READ:` / `ASSUMPTIONS:` / `INSIGHT:`
   - `OODA STAGE` → `PHASE ASSESSMENT`; `RICE SCORING` / `RICE Score` → `PRIORITY SCORING` / `Priority Score`; `STATUS: DRAFT` → `NOTE: INCOMPLETE DATA`
4. Preserve `=== CONFIDENCE ===` blocks unchanged (all personas share this format).

**7b. Peer review (Standard/Deep)** — Read `references/peer-review.md` for the full reviewer prompt. Dispatch 5 parallel Agent() calls, each receiving all anonymized A–E responses plus the reviewer prompt.

**Score extraction:** Each reviewer's Q4 answer must be a single integer 1–5. Extract using regex: `CONSENSUS STRENGTH:\s*(\d)` (case-insensitive). If a reviewer outputs a non-integer or out-of-range value, default to 3 (neutral) and log a warning in the transcript. Compute the arithmetic mean of all 5 extracted scores, rounded to one decimal.

**Consensus summary synthesis:** After collecting peer reviews, produce a 2-3 sentence `CONSENSUS_SUMMARY` capturing: (a) what the majority of advisors recommend, (b) the dominant reasoning, (c) any conditions or caveats shared across reviews. Store as the variable `$CONSENSUS_SUMMARY` — this is substituted into the Prosecutor and Defender prompts in `references/debate-round.md`.

**7c. Forced Debate** — if consensus-strength average ≥ 4.0 (or always in Deep): run two **sequential** Agent() calls using `references/debate-round.md`. If average is > 2.0 but < 4.0 in Standard mode: skip debate (healthy disagreement that doesn't need adversarial pressure). If average ≤ 2.0: skip debate and note in transcript: "Debate round skipped — insufficient consensus (score: X/5)."
1. Prosecutor — attacks the consensus. Wait for response.
2. Defender — substitutes `{{PROSECUTOR_RESPONSE}}` with the Prosecutor's output, then dispatches. Defender cannot run until Prosecutor returns.

Read `references/debate-round.md` for full prompts.

---

## Step 8 — Dual Chairman + Dissent Preservation

**De-anonymize before chairman dispatch:** Using the A-E mapping from Step 7a, restore persona labels on each response. The chairman prompts in `references/chairman.md` expect persona-labelled inputs (`Red Team: ...`, `First Principles: ...`, etc.) — substitute the original (un-anonymised) response text, not the sanitised peer-review version.

Read `references/chairman.md`. Three Agent() calls in two waves:

**Wave A (parallel):** dispatch both in a single turn:

1. **Chairman-Consensus** (majority-biased) — standard 5-section verdict
2. **Chairman-Dissent** (minority-biased) — same structure, anchored on dissent

**Wave B (sequential, after both return):**
3. **Dissent Preservation Pass** — receives both chairmen outputs; produces Dissent Ledger (2–5 bullets of insights Consensus softened)

Final verdict = Chairman-Consensus output + Dissent Ledger appended.

Mandate verdict header:
```
Council confidence: high | medium | low  (n/5 high, n/5 medium, n/5 low)
Dominant assumption: <single shared premise>
Breakers: <top 2 signals that flip the recommendation>
```

**Escalation check (Standard mode only — Deep does not re-escalate):**

Trigger escalation if ANY of:
- `chairman_confidence` is `low`
- 3 or more advisors output `confidence: low`
- "Where the council clashes" section has ≥2 items where neither side was found "more persuasive"

If triggered: `AskUserQuestion` — *"Council confidence is low (reason: {which trigger}). Escalate to Deep mode for a more thorough analysis?"*
- If yes: re-run from Step 5 in Deep mode, passing prior advisor outputs as context so advisors refine rather than restart.
- If no: proceed with Standard verdict; render the confidence header with `confidence-low` (red) styling in the HTML report.
- If mode is already Deep: do not re-escalate. Proceed with low-confidence verdict and note it prominently.

---

## Step 9 — Generate outputs

**Timestamp + sha1:**
```bash
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FILE_TS=$(date -u +%Y%m%d-%H%M%SZ)
SHA=$(printf '%s' "$FRAMED_QUESTION" | shasum | cut -c1-8)
```

The orchestrator must have `FRAMED_QUESTION` set as a shell variable from Step 3 output. `printf '%s'` avoids a trailing newline affecting the hash. `-u` forces UTC. `FILE_TS` is the filename-safe variant; `TS` is ISO 8601 for the journal.

**Filenames:** `council-report-${FILE_TS}-q${SHA}.html`, `council-transcript-${FILE_TS}-q${SHA}.md`

**Output directory:** `$PWD` — test write access first. Fallback: `~/Documents/claude-council-reports/`

**HTML token → source mapping:**

| Token | Source | Notes |
|---|---|---|
| `{{TITLE}}` | First 80 chars of DECISION line from framed question | **HTML-escape** all `<>&"'` |
| `{{TIMESTAMP}}` | `$TS` (ISO 8601 UTC) | |
| `{{MODE_LABEL}}` | `"Quick"` / `"Standard"` / `"Deep"` | |
| `{{MODE_CLASS}}` | `"quick"` / `"standard"` / `"deep"` (lowercase for CSS) | |
| `{{CODEX_BADGE_HTML}}` | `<span class="badge codex">Decision Science</span>` if codex ran; empty string otherwise | |
| `{{CONFIDENCE_HEADER_HTML}}` | Render verdict confidence header as `<div class="confidence-block confidence-{level}">` with Council confidence line, Dominant assumption, Breakers | Use `confidence-high`, `confidence-medium`, or `confidence-low` class |
| `{{QUESTION_HTML}}` | Full framed question text | **HTML-escape** all `<>&"'` to prevent XSS |
| `{{BIAS_FLAGS_HTML}}` | Bias audit output in `<div class="bias-flags"><strong>Pre-council bias scan</strong>...</div>`; empty string if Quick or clean audit | |
| `{{VERDICT_HTML}}` | Chairman-Consensus verdict (markdown → HTML: `## H2` → `<h2>`, `- bullet` → `<ul><li>`, paragraphs → `<p>`) | |
| `{{DISSENT_LEDGER_HTML}}` | Dissent bullets in `<div class="dissent-ledger"><strong>Dissent Ledger</strong><ul><li>...</li></ul></div>`; empty if Clean or Quick | |
| `{{AGREEMENT_GRID_HTML}}` | "Where the council agrees" as `<div class="card">` with `<table class="grid-table">` showing advisor agreement; empty if Quick | |
| `{{RICE_TABLE_HTML}}` | Executor RICE as `<div class="card"><div class="card-title">RICE Analysis</div><div class="card-body"><table class="rice-table">...</table></div></div>`; empty if no RICE data | |
| `{{DECISION_SCIENCE_MATRIX_HTML}}` | Decision Science JSON as `<div class="card"><div class="card-title">Decision Science</div><div class="card-body"><table class="ds-table">...</table></div></div>`; empty if not ran | Rows: `dominant` class for dominant, `dominated` for dominated |
| `{{DEBATE_HTML}}` | Debate as `<div class="card"><div class="card-title">Debate Round</div><div class="card-body"><div class="debate-callout">...</div></div></div>` with prosecutor/defender sides; empty if skipped | |
| `{{ADVISORS_HTML}}` | Each advisor as `<details class="advisor-{kebab}"><summary>{Name} <span class="conf-{level}">{level}</span></summary><div class="detail-body">{text}</div></details>` | kebab: `red-team`, `first-principles`, `expansionist`, `outsider`, `executor` |
| `{{REVIEWS_HTML}}` | Each review as `<details><summary>Reviewer {N}</summary><div class="detail-body">{text}</div></details>`; empty if Quick | |
| `{{FOOTER_HTML}}` | `LLM Council &middot; Mode: {mode} &middot; SHA: {sha} &middot; <a href="{transcript_path}">Full transcript</a>` | |

**HTML:** Read `assets/report-template.html`, substitute all tokens per the table above, Write. Open with `open <path>` on darwin.

**Transcript:** Write a markdown file with: invocation timestamp, framed question, anonymization map, all advisor responses with persona names, all peer reviews, debate transcript (if ran), both chairman outputs, dissent ledger, full verdict, Decision Science matrix (if ran).

**HTML sanitisation note:** Tokens marked "HTML-escape" in the table (`TITLE`, `QUESTION_HTML`) contain raw user text and must have `<>&"'` escaped. The remaining `*_HTML` tokens (`VERDICT_HTML`, `ADVISORS_HTML`, `REVIEWS_HTML`, `DEBATE_HTML`, `BIAS_FLAGS_HTML`, `FOOTER_HTML`) are orchestrator-generated HTML — they are safe because the orchestrator constructs them from controlled templates and never inserts raw user text directly. If any user-provided text appears inside these tokens (e.g., the question echoed in the verdict), it must be HTML-escaped at the point of insertion, not at the token level.

**After substitution, verify:** `grep '{{' <html_path>` must return zero matches. If any token remains unfilled, replace it with an empty string and log a warning in the transcript.

---

## Step 10 — Journal append + user prompt

Construct the journal payload from values collected during this run. All fields are required:

```json
{
  "ts": "$TS",
  "question_sha1_prefix": "$SHA",
  "mode": "<Quick|Standard|Deep — the mode actually used, including escalation>",
  "codex_used": <true if Decision Science ran via Codex; false otherwise>,
  "biases_flagged": [<list of bias names from Step 3b, or empty array if Quick/clean>],
  "advisors_confidence": {
    "red_team": "<high|medium|low from Red Team's CONFIDENCE block>",
    "first_principles": "<from First Principles>",
    "expansionist": "<from Expansionist>",
    "outsider": "<from Outsider>",
    "executor": "<from Executor>"
  },
  "chairman_confidence": "<high|medium|low from the verdict header>",
  "recommendation_one_liner": "<one sentence — the Recommendation section's first sentence>",
  "dissent_ledger": [<each DISSENT PRESERVED bullet as a string, or empty array if Clean>],
  "html_path": "<absolute path to the HTML report written in Step 9>",
  "transcript_path": "<absolute path to the transcript written in Step 9>",
  "outcome": null
}
```

Build this as a valid JSON string. Use `jq -n` to construct it safely (handles quotes and special characters in recommendation text):

```bash
PAYLOAD=$(jq -n \
  --arg ts "$TS" \
  --arg sha "$SHA" \
  --arg mode "$MODE" \
  --argjson codex "$CODEX_USED" \
  --argjson biases "$BIASES_JSON" \
  --argjson conf "$ADVISORS_CONF_JSON" \
  --arg chair_conf "$CHAIRMAN_CONF" \
  --arg rec "$RECOMMENDATION" \
  --argjson dissent "$DISSENT_JSON" \
  --arg html "$HTML_PATH" \
  --arg transcript "$TRANSCRIPT_PATH" \
  '{ts:$ts, question_sha1_prefix:$sha, mode:$mode, codex_used:$codex,
    biases_flagged:$biases, advisors_confidence:$conf,
    chairman_confidence:$chair_conf, recommendation_one_liner:$rec,
    dissent_ledger:$dissent, html_path:$html, transcript_path:$transcript,
    outcome:null}')
bash ~/.claude/skills/claude-council/scripts/journal_append.sh "$PAYLOAD"
```

Where the shell variables are set from the run's outputs:
- `$TS`, `$SHA` — from Step 9
- `$MODE` — `"Quick"`, `"Standard"`, or `"Deep"`
- `$CODEX_USED` — `true` or `false` (JSON boolean, no quotes)
- `$BIASES_JSON` — JSON array, e.g. `'["anchoring","sunk cost"]'` or `'[]'`
- `$ADVISORS_CONF_JSON` — JSON object, e.g. `'{"red_team":"high","first_principles":"medium","expansionist":"high","outsider":"low","executor":"medium"}'`
- `$CHAIRMAN_CONF` — `"high"`, `"medium"`, or `"low"`
- `$RECOMMENDATION` — first sentence of the Recommendation section
- `$DISSENT_JSON` — JSON array of dissent bullets, or `'[]'`
- `$HTML_PATH`, `$TRANSCRIPT_PATH` — absolute paths from Step 9

Tell the user: *"Council logged (sha: `$SHA`). To record how it turned out: `/claude-council outcome $SHA <short note>`. Run `/claude-council meta` after 5+ runs for persona refinement suggestions (requires `jq`)."*

Then show the HTML file path and a one-paragraph chat summary (recommendation + one thing to do first). No longer.
