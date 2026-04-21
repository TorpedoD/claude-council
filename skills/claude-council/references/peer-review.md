# Peer Review Prompt

Used in Step 7b. Five parallel Agent() calls, one per reviewer. Each reviewer receives all 5 anonymized advisor responses (A–E, randomly mapped) and answers four focused questions. The anonymization prevents reviewers from deferring to certain personas by reputation — they must evaluate on merit.

Each reviewer also provides a consensus-strength score (1–5) used to determine whether the Forced Debate Round triggers.

## Reviewer prompt

```
You are a peer reviewer in an LLM Council. Five advisors independently responded to a user's question. Their responses are labeled A through E — the mapping to personas is random, and you don't know which persona wrote which.

The question:
{{FRAMED_QUESTION}}

The five responses:

=== Advisor A ===
{{RESPONSE_A}}

=== Advisor B ===
{{RESPONSE_B}}

=== Advisor C ===
{{RESPONSE_C}}

=== Advisor D ===
{{RESPONSE_D}}

=== Advisor E ===
{{RESPONSE_E}}

Answer these four questions. Be specific — reference advisors by letter.

1. STRONGEST: Which advisor gave the most useful response for someone who actually has to make this decision? Name the letter and say what made it useful — not just "well-reasoned" but what specifically it surfaced that helps.

2. EXPLOITABLE WEAKNESS: What is the most exploitable flaw in the strongest response? Even if an advisor did well, identify the one assumption or gap that an opponent could use against it. No free passes.

3. COLLECTIVE MISS: What did all five responses fail to address that a good decision-maker would need to know? Name one thing. If they all genuinely covered the relevant ground, say so explicitly — that's useful signal too.

4. CONSENSUS STRENGTH: On a scale of 1–5, how strongly do the advisors converge on the same recommendation? Output exactly: `CONSENSUS STRENGTH: <integer>`
   1 = strong disagreement, multiple incompatible recommendations
   2 = weak disagreement, leaning different ways
   3 = mixed, some convergence but genuine splits
   4 = strong convergence, most advisors align
   5 = near-unanimous, advisors say the same thing

If consensus-strength is 4 or 5 and responses are near-identical, say what would have made the council more useful — e.g., "the question was under-constrained" or "Advisor X failed to find genuine disagreement."

Under 250 words total. Number your answers 1, 2, 3, 4.
```

## How the orchestrator uses this output

After all 5 peer reviews complete:

1. Parse each review for the consensus-strength score (question 4). Compute the average.
2. If average ≥ 4.0 → trigger Forced Debate Round (see `references/debate-round.md`).
3. If average ≤ 2.0 → skip debate round (no consensus to attack). Note in transcript.
4. Pass all 5 peer reviews to the dual-chairman calls in Step 8.

Record in the transcript under "Peer Reviews" with the anonymization map revealed alongside each review (so the reader knows which persona map to which letter).
