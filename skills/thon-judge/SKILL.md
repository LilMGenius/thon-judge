---
name: thon-judge
description: "Score hackathon submissions with the thon-judge CLI when the user provides participant repo URLs, README/commit evidence, screenshot paths, lobster usage, or asks for a one-page judging report."
---

# thon-judge

Use this skill to judge hackathon preliminary submissions from a batch file.

## Inputs
- Batch input: JSON, Markdown, or TXT.
- Criteria: `JUDJE.md`.
- Harness case studies: `cases/`.
- Optional fixture-backed GitHub evidence: `examples/github/`.
- Output HTML path and evidence JSON path.

## Workflow
1. Refresh OpenAI Codex docs grounding if this is implementation or release work.
2. Run the deterministic shell CLI:
   ```bash
   scripts/thon-judge.cmd judge \
     --input examples/submissions.json \
     --criteria JUDJE.md \
     --cases cases \
     --github-fixtures examples/github \
     --output reports/example.html \
     --evidence .omo/evidence/final-judge.json
   ```
3. Summarize the top scores and warnings from the evidence JSON.
4. Keep the HTML report as the review artifact; do not replace it with prose.

## Guardrails
- Do not mutate participant repositories.
- Do not require private GitHub access.
- Do not do screenshot visual scoring in v1.
- Keep scoring deterministic and evidence-backed.
- Keep the plugin shell-native; do not add Python runtime dependencies.
