# Bias Audit — Prompt & Protocol

Run as a single `Agent(subagent_type="general-purpose")` call before the advisor fan-out. Pass the framed question. Outputs structured bias flags appended to the framed question as context for all advisors.

## Agent prompt

```
You are a cognitive bias auditor. A user has brought a question to a decision council. Your job is to scan the question for signs of common cognitive biases that might be distorting the framing before the council begins.

The question to audit:
{{FRAMED_QUESTION}}

Scan for each of the following biases. For each one detected, produce a one-line flag and a one-sentence reframing suggestion. If a bias is NOT detected, omit it from the output — don't list clean bills of health.

BIAS CHECKLIST:
1. Sunk cost — treating past investment as a reason to continue a path
2. Confirmation bias — framing the question to validate an already-preferred answer
3. Anchoring — over-weighting the first number or option named
4. Survivorship bias — reasoning from visible successes while ignoring failures
5. IKEA effect — overvaluing something because you built it
6. Status quo bias — treating the current state as the default good
7. Planning fallacy — underestimating time, cost, or complexity
8. Narrative fallacy — constructing a causal story around a coincidence or correlation

Output format (only include detected biases):
BIAS: [name]
SIGNAL: [what in the question triggered this]
REFRAME: [one sentence — how to restate the question without the bias]

Important: these are FLAGS, not verdicts. The user may have good reasons for the framing. The council advisors will see these flags as contextual signals, not as corrections.

Under 150 words total. If no biases detected, output: BIAS AUDIT: Clean — no significant distortions detected.
```

## How the orchestrator uses this output

Append the bias audit output verbatim to the framed question block under a `BIAS FLAGS:` heading. All five advisor prompts receive this augmented framed question. Advisors are not instructed to respond to each bias explicitly — they see it as background context.

In the HTML report, render bias flags in a callout box at the top of the question section with a yellow accent. Label it "Pre-council bias scan" with a note that these are signals, not verdicts.

In the transcript, record the raw bias audit output under "Bias Audit" before the advisor responses.
