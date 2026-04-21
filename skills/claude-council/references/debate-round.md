# Forced Debate Round — Protocol & Prompts

The Forced Debate Round triggers when peer-review consensus-strength average ≥ 4/5, or always in Deep mode. It is the corrective mechanism for peer-review degeneracy — when advisors converge so strongly that reviewers just confirm consensus, adversarial dynamics surface hidden flaws that perspective-only councils miss.

## Trigger logic

After Step 7b (peer review), compute the average consensus-strength score across all 5 reviewers (each scores 1–5). If average ≥ 4.0 → trigger. In Deep mode, always trigger regardless of score.

If consensus-strength ≤ 2.0 → skip debate (no consensus to attack — the council already disagrees). If skipped, note in transcript: "Debate round skipped — insufficient consensus (score: X/5)."

## Prosecutor prompt

```
You are the Prosecutor in an LLM Council Debate Round. The council has reached unusually strong consensus on a recommendation. Your job: attack it.

The question the council was answering:
{{FRAMED_QUESTION}}

The consensus recommendation (from peer reviews):
{{CONSENSUS_SUMMARY}}

The Red Team's pre-mortem from the initial round:
{{RED_TEAM_RESPONSE}}

Your task: produce the strongest possible case AGAINST the consensus recommendation. Use the Red Team's failure mode as your starting ammunition, then go further. Look for:
- Hidden assumptions the consensus depends on that aren't stated
- Second-order effects the council didn't model
- A world where the consensus recommendation leads to the worst outcome — trace how
- Any data point or signal the council collectively ignored

You are not trying to be balanced. You are trying to find the one argument that, if true, would make the consensus catastrophically wrong.

200 words max. Lead with the sharpest attack, support it, then name the single piece of evidence that would confirm your case.
```

## Defender prompt

```
You are the Defender in an LLM Council Debate Round. A Prosecutor has just attacked the council's consensus recommendation. Your job: rebut the attack.

The question:
{{FRAMED_QUESTION}}

The consensus recommendation:
{{CONSENSUS_SUMMARY}}

The Prosecutor's attack:
{{PROSECUTOR_RESPONSE}}

Your task: rebut the Prosecutor's case using data-grounded arguments only. No rhetoric, no character attacks, no "but the council carefully considered." Show your work.

Structure your rebuttal:
1. CONCEDE: what part of the Prosecutor's case is actually valid? (Concede something real — a Defender who concedes nothing is not credible.)
2. REBUT: why the conceded point doesn't change the core recommendation
3. COUNTER-EVIDENCE: what evidence or signal makes the consensus more robust than the Prosecutor claims
4. REMAINING RISK: what residual risk survives your rebuttal — and how should the user monitor for it?

200 words max. The goal is not to win — it is to surface what survives adversarial pressure.
```

## How the orchestrator uses this

Run **sequentially** — Prosecutor first, then Defender:

1. Dispatch Prosecutor as one Agent() call. Wait for it to return.
2. Substitute `{{PROSECUTOR_RESPONSE}}` with the Prosecutor's actual output. Dispatch Defender as a second Agent() call.

The Defender must see the Prosecutor's output to produce a grounded rebuttal — parallel dispatch is not possible here. The total latency cost is two serial Agent calls (~15-20s), not one parallel pair.

Pass both transcripts to the dual chairman in Step 8. Include them in the HTML report as a collapsible "Debate Round" section. Include them in the full transcript under "Debate Round."

If Prosecutor explicitly says it cannot find a genuine attack, record that verbatim — it is itself a useful signal (the consensus survived adversarial pressure).
