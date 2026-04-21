# Council Modes — Selection, Escalation, Early Stopping

Three modes trade off thoroughness against cost and latency. The right mode depends on stakes, reversibility, and available time.

## Mode definitions

### Quick
- **Advisors:** 3 (Red Team, Executor, First Principles)
- **Peer review:** none
- **Debate round:** no
- **Bias audit:** skipped (saves one call; speed is the point of Quick)
- **Codex Decision Science:** no
- **Chairman:** single (Consensus only, no Dissent pass)
- **Dissent Ledger:** no
- **~Calls:** 4 (3 advisors + 1 chairman)
- **~Wall-clock:** 25-40 seconds

**When Quick is appropriate:**
- User explicitly says "quick" or "fast"
- Time-pressured framing in the question ("I need to decide in an hour", "meeting in 30 mins")
- Stakes are clearly bounded: reversible within 1 day, or below ~$1k in consequence
- The question is genuinely constrained — not much to debate

**Quick verdict structure:** same 5 H2 sections but from a single chairman. No confidence header, no Dissent Ledger. Tell the user at the end: "This was a Quick council. Run `/claude-council [same question] deep` if you want full analysis."

### Standard
- **Advisors:** 5 (all)
- **Peer review:** 5 parallel calls
- **Debate round:** conditional (triggers if consensus-strength average ≥ 4.0)
- **Codex Decision Science:** optional ("with codex" suffix)
- **Chairman:** dual (Consensus + Dissent in parallel) + Dissent Preservation Pass
- **Dissent Ledger:** yes
- **~Calls:** 13-15 (including conditional debate, excluding Codex)
- **~Wall-clock:** 75-110 seconds

Standard is the default for most real decisions. Use it when you don't know which mode fits — the escalation logic below will auto-escalate if needed.

### Deep
- **Advisors:** 5 (all, with expanded Tree-of-Thoughts — all 3 reframings returned for First Principles, all 3 options returned for Expansionist)
- **Peer review:** 5 parallel calls
- **Debate round:** always runs
- **Codex Decision Science:** always runs (Claude fallback if Codex unavailable)
- **Chairman:** dual + Dissent Preservation Pass
- **Dissent Ledger:** yes
- **~Calls:** 16 + 1 Codex
- **~Wall-clock:** 130-180 seconds

**When Deep is appropriate:**
- User explicitly says "deep"
- High-stakes markers: irreversible decisions, large financial/organizational consequences, team-affecting calls
- Standard returned low confidence (see escalation below)
- User opted in after being offered escalation

## Mode selection logic

The orchestrator picks mode in this order:

1. **Explicit suffix wins:** "quick" → Quick, "deep" → Deep, "with codex" → Standard + Codex pass
2. **Stake markers in the framed question:** look for: "can't undo", "irreversible", "bet the company", "my career", "we only get one shot", "six figures", "everyone is watching" → auto-select Deep
3. **Default:** Standard

## Escalation after Standard

After the dual-chairman step, compute:
- `advisor_confidence_low_count`: number of advisors who output `confidence: low`
- `chairman_confidence`: the level in the verdict header

Escalation triggers if: `chairman_confidence` is `low`, OR `advisor_confidence_low_count ≥ 3`, OR the Clashes section has ≥ 2 genuinely unresolved items (no "more persuasive" conclusion reached).

When escalation triggers: use AskUserQuestion — "Council confidence is low. Escalate to Deep mode for a more thorough analysis?" If yes, re-run from the fan-out step in Deep mode, passing prior results as context so advisors can refine rather than restart.

If the user declines escalation: proceed with the Standard verdict and note the low confidence in the HTML report header in red.

## Early stopping

Quick: if the single chairman's verdict has `confidence: high` and no Dissent Ledger is warranted, stop immediately after Step 8. Don't run anything extra.

Standard: if peer-review consensus-strength average is ≤ 2.0, skip the debate round — there's no consensus to attack. Note in transcript: "Debate round skipped — insufficient consensus for forced debate (avg score: X/5)."

Standard: if all 5 advisor confidence blocks are `high`, the Dissent Preservation Pass may return "Clean" — that's fine. Don't force debate to manufacture drama.

## Mode in the transcript

Always log the mode used and whether it was auto-selected or user-specified. Format:
```
MODE: Standard (auto-selected — default)
MODE: Deep (user-specified "deep" suffix)
MODE: Quick (auto-selected — stakes markers: "need answer in 10 mins")
MODE: Deep (escalated from Standard — chairman confidence: low)
```
