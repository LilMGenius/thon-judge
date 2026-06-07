# thon-judge Codex Plugin Work Plan

## TL;DR
Build `github.com/LilMGenius/thon-judge` as a repository-local Codex plugin that runs entirely through Windows-compatible shell scripts. The plugin ingests JSON, Markdown, or TXT submission batches, scores them against `JUDJE.md` plus `cases/*-harness-case-study.md`, and writes an aligned one-page HTML report with evidence JSON.

## User Requirements
- Create the `thon-judge agent` Codex plugin for hackathon preliminary judging.
- Inputs include participant git remote URLs, screenshot paths and filenames, public README evidence, commit-process evidence, and lobster usage.
- Score Product 35, Creativity/Originality 20, Harness Understanding 25, and Lobster Count 20.
- Lobster score is `max(0, 20 - 4 * lobster_count)`, where each lobster means the laptop was touched for 10 minutes.
- Extract Harness Understanding from `cases/*-harness-case-study.md`.
- Use `grep_app` or GitHub URL discovery first; clone into Desktop only if available evidence is insufficient.
- Keep OpenAI Codex docs grounding in the plan and implementation workflow.
- Use Conventional Commits with concise one-line body bullets.
- New pivot: no Python. Use a Codex-native plugin shape with 100% shell implementation and Windows support.

## Codex Docs Grounding
Before implementation waves, run:

```bash
node C:/Users/LilMG/.codex/skills/.system/openai-docs/scripts/fetch-codex-manual.mjs
```

Read and record decisions from:
- `Agent Skills` (`/codex/skills.md`): focused `SKILL.md`, `name`, `description`, and progressive disclosure.
- `Build plugins` (`/codex/plugins/build.md`): `.codex-plugin/plugin.json`, stable kebab-case plugin names, skills and scripts directories.
- `Plugins` (`/codex/plugins.md`): plugins bundle local skills, scripts, apps, and optional MCP servers.
- `Model Context Protocol` (`/codex/mcp.md`): do not add MCP in v1 unless shell GitHub collection cannot satisfy the workflow.
- `Slash commands in Codex CLI` (`/codex/cli/slash-commands.md`): `/plugins`, `/skills`, `/mcp`, `/status`, and `/review` are operator verification surfaces.

Wave evidence belongs in `.omo/evidence/openai-docs-wave-{N}.md`.

## Architecture
- `.codex-plugin/plugin.json`: Codex plugin manifest named `thon-judge`.
- `.agents/plugins/marketplace.json`: repo-local marketplace entry for Codex CLI plugin discovery.
- `skills/thon-judge/SKILL.md`: operator workflow and exact shell command.
- `scripts/thon-judge.cmd`: Windows wrapper that prefers `pwsh` and falls back to Windows PowerShell.
- `scripts/thon-judge.ps1`: deterministic CLI with `parse`, `criteria`, `judge`, `fixtures`, and `doctor` commands.
- `tests/run-tests.ps1`: PowerShell test harness, no external package manager.
- `JUDJE.md`: English source-of-truth rubric and lobster formula.
- `cases/`: harness understanding source material.
- `examples/`: JSON, Markdown, TXT, malformed, boundary, malicious, and GitHub fixture inputs.
- `reports/`: ignored generated HTML and JSON reports.

## Must Have
- Batch input support for `.json`, `.md`, and `.txt`.
- Normalized participant/team name, repo URL, screenshot paths, lobster usage, and evidence warnings.
- Offline GitHub fixtures for tests, with warning mode for missing live evidence.
- Live public GitHub README and recent commit evidence collection without a Python runtime.
- Deterministic scoring that never exceeds 100 or drops below 0.
- Harness signal catalog derived from the case studies.
- HTML output that escapes untrusted text and is readable as a standalone one-pager.
- Windows PowerShell 5.1+ and PowerShell 7 compatibility.

## Must Not Have
- No Python runtime, Python package manager, or Python test dependency.
- No live-network dependency in the default tests.
- No private GitHub access requirement.
- No participant repository mutation.
- No screenshot visual ML scoring in v1.
- No scoring logic hidden inside `SKILL.md`.

## Verification Commands
```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1
scripts/thon-judge.cmd doctor --plugin-root . --strict --pretty
scripts/thon-judge.cmd judge --input examples/submissions.json --criteria JUDJE.md --cases cases --github-fixtures examples/github --output reports/example.html --evidence .omo/evidence/final-judge.json
scripts/thon-judge.cmd judge --input .omo/evidence/live-submissions.json --criteria JUDJE.md --cases cases --output reports/live.html --evidence .omo/evidence/live-judge.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/thon-judge.ps1 parse --input examples/submissions.json
```

For report QA, serve `reports/example.html` with a short PowerShell `HttpListener` or open the file directly. Do not use a Python HTTP server.

## Task Plan
1. Initialize repo and plugin scaffold.
   - Acceptance: git repo exists, `origin` points at `LilMGenius/thon-judge`, manifest parses with `ConvertFrom-Json`, and scaffold test passes.
   - Commit: `chore(repo): initialize thon-judge plugin scaffold`.

2. Define `JUDJE.md` and harness criteria.
   - Acceptance: exact weights are present, total weight is 100, and at least 10 harness signals are extracted from `cases/`.
   - Commit: `docs(criteria): define judging rubric and harness signals`.

3. Add offline fixtures and schema examples.
   - Acceptance: JSON, Markdown, and TXT fixtures normalize to the same participant records; malformed input fails with a clear validation error.
   - Commit: `test(fixtures): add submission schema examples`.

4. Implement shell-native parser and GitHub fixture adapter.
   - Acceptance: `parse` handles all fixture formats and missing GitHub fixtures produce participant warnings rather than batch failure.
   - Commit: `feat(input): parse shell-native submission batches`.

5. Implement scoring and HTML rendering.
   - Acceptance: Product, Creativity, Harness, and Lobster category scores are present; lobster floor is tested; report escapes malicious input.
   - Commit: `feat(judge): score submissions and render report`.

6. Wire Codex skill and release checks.
   - Acceptance: skill references the exact `.cmd` command, `doctor` passes, README quickstart works, and CI runs the PowerShell test harness.
   - Commit: `docs(plugin): document shell-native judge workflow`.

## Completion Status
- Done: repository scaffold, plugin manifest, repo marketplace, skill workflow, Windows `.cmd` wrapper, PowerShell CLI, rubric, case-study harness signals, fixtures, shell tests, HTML report, CI, live GitHub evidence, local commit, GitHub repo creation, and push.
- Done: official Codex manual was refreshed and used for skill, plugin, marketplace, MCP, and slash-command decisions.
- Not included by design: screenshot visual scoring, private repository access, participant repository mutation, bundled MCP server, and Python runtime dependencies.

## Final Verification
- `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1` exits 0.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/thon-judge.ps1 parse --input examples/submissions.json` exits 0.
- `scripts/thon-judge.cmd judge ...` writes `reports/example.html` and evidence JSON.
- Local HTTP or direct browser QA confirms the report contains participant names, Product, Creativity, Harness, Lobster, Total, warnings, screenshots, and evidence notes.
- A source scan confirms no non-shell implementation artifacts or stale runtime references in plugin, docs, scripts, or tests.

## Commit Strategy
Use Conventional Commits:

```text
feat(plugin): build shell-native thon judge

- Adds Windows PowerShell CLI and cmd wrapper for judging batches
- Defines rubric, fixtures, skill manifest, and shell test harness
- Generates evidence JSON and aligned HTML reports without Python runtime
- Plan: .omo/plans/thon-judge-codex-plugin.md
```
