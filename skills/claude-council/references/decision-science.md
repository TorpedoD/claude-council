# Decision Science Pass — Prompt & Protocol

This pass runs when the user adds "with codex" or in Deep mode. Rather than replacing an advisor, it acts as a structured Decision Theory layer — quantifying options using expected value, reversibility, and opportunity cost. Codex is well-suited to this because it naturally produces structured, constraint-oriented output; a Claude Agent() fallback works when Codex is unavailable.

## When to run

- User suffix "with codex" — run after Step 5 fan-out returns (sequential, before peer review)
- Deep mode — always runs (same timing)
- Standard mode without Codex opt-in — skip this step

## Input

After advisor responses return, extract a clean list of options from `{{FRAMED_QUESTION}}` (the OPTIONS field) **plus any new options the advisors introduced** (especially Expansionist and First Principles reframings). This is the primary reason Codex runs after fan-out, not in parallel with it — Codex should evaluate the full option space the council surfaced, not just what the user named.

## Codex invocation

```bash
timeout 120 codex exec --sandbox read-only --skip-git-repo-check - <<'CODEX_EOF'
<full prompt below with substitutions applied>
CODEX_EOF
```

On timeout or non-zero exit: run the same prompt as `Agent(subagent_type="general-purpose", prompt=<prompt>)`. Note in the transcript which path ran.

## Prompt

```
You are running a Decision Science analysis as part of an LLM Council. Your job is to apply structured decision theory to the options in front of the user — not to give opinions, but to produce a quantified comparison.

The decision:
{{FRAMED_QUESTION}}

Options to evaluate:
{{OPTIONS_LIST}}

For each option, produce a JSON block in this exact schema:
{
  "option": "<option name>",
  "expected_value": {
    "best_case": "<outcome + rough magnitude if estimable>",
    "likely": "<most probable outcome>",
    "worst_case": "<downside outcome>"
  },
  "downside_risk": "<magnitude description + rough probability>",
  "reversibility": "one_way | reversible_with_cost | easily_reversible",
  "opportunity_cost": "<what the user cannot do or gives up by choosing this>",
  "data_confidence": "high | medium | low",
  "dominance": "dominated | competitive | dominant"
}

After all option blocks, add:

RANKING: [list options from best to worst RICE equivalent — most upside/reversibility per unit of downside risk]
DOMINATED OPTIONS: [options that are strictly worse than another on all dimensions — candidates to eliminate]
KEY ASSUMPTION: [the single assumption that, if wrong, would most change this ranking]

Use "high" data_confidence only when the magnitudes can be grounded in something concrete from the question. Use "low" when you are largely speculating.

Produce valid JSON blocks only — no prose wrapping the blocks. The ranking and dominated options sections are plain text after the JSON.
```

## How the orchestrator uses this output

Parse the JSON blocks. If parsing fails, capture the raw text — don't crash the council.

Render in the HTML report as a Decision Science matrix table: rows = options, columns = EV best/likely/worst, reversibility, opportunity cost, dominance. Color-code: green = dominant, gray = dominated, white = competitive. Use a collapsible section if Codex was not used (less prominent).

In the transcript, record the full raw output under "Decision Science Pass."

Pass the ranking and key assumption to both chairmen in Step 8 as additional structured context.
