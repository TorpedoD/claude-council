# claude-council

> Pressure-test high-stakes decisions with a structured LLM Council — 5 advisors, peer review, forced debate, dual-chairman synthesis with dissent preservation.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-8A2BE2.svg)](https://claude.ai/code)
[![Last commit](https://img.shields.io/github/last-commit/TorpedoD/claude-council)](https://github.com/TorpedoD/claude-council/commits/main)
[![Issues](https://img.shields.io/github/issues/TorpedoD/claude-council)](https://github.com/TorpedoD/claude-council/issues)

**claude-council** is an open-source, multi-agent decision framework that runs **entirely inside [Claude Code](https://claude.ai/code)**. One slash command — `/claude-council` — runs your question through five structured thinking lenses, anonymized peer review, a forced adversarial debate when consensus is suspiciously clean, and dual-chairman synthesis that preserves minority dissent. Three adaptive modes (Quick / Standard / Deep) keep cost bounded; a persistent JSONL journal enables learning across runs. MIT licensed.

---

## Install

```bash
npx skills add TorpedoD/claude-council
```

This installs the `claude-council` skill into `~/.claude/skills/` via the [skills](https://www.npmjs.com/package/skills) CLI.

### Prerequisites

| Tool | Install |
|------|---------|
| [Claude Code](https://claude.ai/code) | Pro plan or higher |
| [jq](https://jqlang.github.io/jq/) | `brew install jq` (required for journal) |

### Verify

Open Claude Code and type `/claude-council` — the council should prompt you for a decision.

---

## Usage

### Basic

```
/claude-council I'm torn between staying at my stable job or joining an early-stage startup as cofounder
```

### Modes

| Mode | When | Advisors | Peer Review | Debate | ~Time |
|------|------|----------|-------------|--------|-------|
| **Quick** | `quick` suffix, low stakes, reversible in 1 day | 3 | No | No | ~30s |
| **Standard** | Default | 5 | Yes (5 reviewers) | If consensus ≥ 4/5 | ~90s |
| **Deep** | `deep` suffix, high stakes, irreversible | 5 (expanded) | Yes | Always + Decision Science | ~150s |

Force a mode by appending it to your prompt:

```
/claude-council should I pivot from B2C to B2B? deep
```

### Recording outcomes

After the decision plays out, tell the council how it went:

```
/claude-council outcome <sha> went_with_startup_worked_well
```

### Meta-analysis

After 5+ runs with recorded outcomes, surface persona calibration patterns:

```
/claude-council meta
```

---

## How It Works

```
+------------------------------------------------------------------+
|                        10-Step Pipeline                           |
+------------------------------------------------------------------+
|  1. Triage          - reject factual/obvious questions            |
|  2. Journal lookup  - find prior runs on similar questions        |
|  3. Frame + Bias    - workspace scan, cognitive bias audit        |
|  4. Mode selection  - Quick / Standard / Deep                     |
|  5. Fan-out         - 3-5 parallel advisor agents                 |
|  6. Decision Science- Codex/Claude structured comparison (Deep)   |
|  7. Peer review     - 5 anonymized reviewers + forced debate      |
|  8. Dual chairman   - consensus + dissent synthesis               |
|  9. Generate outputs- HTML report + markdown transcript           |
| 10. Journal append  - atomic JSONL write + outcome tracking       |
+------------------------------------------------------------------+
```

## The Five Advisors

Each brings a distinct cognitive lens to the decision:

| Advisor | Role | Method |
|---------|------|--------|
| **Red Team** | Adversarial attack | Pre-mortem: assumes failure, traces root cause backwards |
| **First Principles** | Assumption buster | Tree-of-Thoughts: 3 reframings from ground up |
| **Expansionist** | Option multiplier | Finds options the user didn't list; scores upside/effort |
| **Outsider** | Cross-domain wisdom | Channels an unrelated field's methodology |
| **Executor** | Feasibility check | OODA stage + RICE scoring + data completeness audit |

All five mandate a structured **CONFIDENCE** block: confidence level, assumptions, what-would-change-my-mind, unknowns.

## Output Files

Each run produces two files in the current directory:

- **`council-report-{timestamp}-q{sha}.html`** — visual report with colored advisor cards, collapsible sections, agreement grid, RICE table, debate transcript, and confidence header
- **`council-transcript-{timestamp}-q{sha}.md`** — full step-by-step transcript with anonymization map revealed

---

## Credits & Inspiration

This project draws on research and prior work from:

- **[karpathy/llm-council](https://github.com/karpathy/llm-council)** — Andrej Karpathy's LLM council research on multi-model evaluation
- **[@alex_prompter](https://x.com/alex_prompter/status/2043011383457964460)** — prompt engineering research and inspiration
- **[@itsolelehmann](https://x.com/itsolelehmann/status/2038661433626333649)** — claude council skill concept and design inspiration

---

## Uninstall

```bash
npx skills remove claude-council
```

## Contributing

Issues and PRs welcome. The skill is structured so each component (personas, peer review, debate, chairman prompts) can be improved independently without touching the orchestrator contract.

## License

MIT — see [LICENSE](LICENSE).
