# thon-judge

`thon-judge` is a repo-local Codex plugin and shell-native CLI for preliminary hackathon judging. It scores participant batches from JSON, Markdown, or TXT, combines `JUDJE.md` with harness case-study signals, uses public GitHub evidence or offline fixtures, and writes a self-contained HTML one-pager.

## Quickstart

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1
scripts/thon-judge.cmd judge \
  --input examples/submissions.json \
  --criteria JUDJE.md \
  --cases cases \
  --github-fixtures examples/github \
  --output reports/example.html \
  --evidence .omo/evidence/final-judge.json
```

Markdown and TXT inputs use the same labels as the examples:

```bash
scripts/thon-judge.cmd judge --input examples/submissions.md --criteria JUDJE.md --cases cases --github-fixtures examples/github --output reports/readme-md.html
scripts/thon-judge.cmd judge --input examples/submissions.txt --criteria JUDJE.md --cases cases --github-fixtures examples/github --output reports/readme-txt.html
```

For live public GitHub evidence, omit `--github-fixtures`. The CLI fetches README and recent commit metadata with PowerShell's built-in web APIs:

```bash
scripts/thon-judge.cmd judge --input examples/submissions.json --criteria JUDJE.md --cases cases --output reports/live.html --evidence .omo/evidence/live-judge.json
```

## OpenAI/Codex Docs Grounding

Before implementation waves, refresh the Codex manual:

```bash
node C:/Users/LilMG/.codex/skills/.system/openai-docs/scripts/fetch-codex-manual.mjs
```

Record wave notes in `.omo/evidence/openai-docs-wave-{N}.md`. The plugin follows the official `Agent Skills`, `Build plugins`, `Plugins`, `Model Context Protocol`, and `Slash commands in Codex CLI` sections.

## Scoring

- Product: 35
- Creativity: 20
- Harness: 25
- Lobster: `max(0, 20 - 4 * lobster_count)`

Screenshots are validated/listed and linked in the HTML report. They are not visually scored in v1.

## Plugin

The plugin id is `thon-judge`; the display name is `thon-judge agent`. The reusable workflow lives in `skills/thon-judge/SKILL.md`, while deterministic behavior lives in `scripts/thon-judge.ps1` and the Windows wrapper `scripts/thon-judge.cmd`.

## Codex CLI Use

The repo includes `.agents/plugins/marketplace.json` so Codex CLI can discover this plugin from a local marketplace. Add or inspect the marketplace with:

```bash
codex plugin marketplace add .
codex
/plugins
/skills
```

After installing/enabling the plugin, invoke the bundled skill explicitly from the composer with `$thon-judge:thon-judge` when plugin-qualified skill names are shown, or choose `thon-judge` from `/skills`. Some Codex plugin surfaces also expose explicit plugin selection with `@thon-judge`; the underlying reusable workflow is still the `thon-judge` skill.

## Runtime

No Python runtime is required. The CLI uses PowerShell built-ins and supports Windows PowerShell 5.1+ and PowerShell 7.
