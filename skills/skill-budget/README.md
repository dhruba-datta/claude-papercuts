# `skill-budget` — audit your installed skills

**Fixes:**
[`anthropics/claude-code#30387`](https://github.com/anthropics/claude-code/issues/30387),
[`anthropics/claude-code#34648`](https://github.com/anthropics/claude-code/issues/34648),
[`anthropics/claude-code#16575`](https://github.com/anthropics/claude-code/issues/16575)

## What this prevents

> *"In environments with many skills (40+) and rich configuration, the
> model bypasses the Skill tool entirely."* — issue #34648

The system prompt that Claude Code injects has a finite char budget
for skill descriptions. Install too many skills, and the rest fall
off silently — no warning, no error, no way to tell.

`skill-budget` shows you the current load and flags which skills are
above the threshold.

## How it works

```
User runs /claude-papercuts:skill-budget
        │
        ▼
Run audit.py with whatever flags the user passed
        │
        ▼
Discover skill files:
  ~/.claude/skills/*/SKILL.md
  .claude/skills/*/SKILL.md
  ~/.claude/plugins/**/skills/*/SKILL.md
        │
        ▼
Parse YAML frontmatter (name + description)
        │
        ▼
Sort by char cost (highest first)
        │
        ▼
Cumulative-sum check vs budget:
  ✓ visible    — cum ≤ 80% of budget
  ⚠ at risk    — cum > 80% of budget
  ✗ INVISIBLE  — cum > budget
        │
        ▼
Render colored bar chart + per-skill table + actionable mv suggestions
```

## What's installed

| Path | What |
|---|---|
| `skills/skill-budget/SKILL.md` | Auto-invocation description + invoke procedure |
| `skills/skill-budget/audit.py` | Standalone Python script — no deps, works on macOS / Linux / WSL |

## Sample output

```text
Skill budget audit
────────────────────────────────────────────────────────────
Budget:  15,000 chars (override with --budget)
Usage:   12,847 chars  (85.6%)

  █████████████████████████████████████████░░░░░░░░░  12,847 / 15,000

22 skills across 3 source(s):
  user      8 skill(s)
  project   6 skill(s)
  plugin    8 skill(s)

By char weight:
  doc-writer            ██████████████████   1,234 ch  ✓ visible
  pdf-extractor         ████████████░         987 ch  ✓ visible
  ...
  legacy-helper         █                     120 ch  ✗ INVISIBLE
  ...

3 skill(s) are INVISIBLE TO CLAUDE right now:
  ✗ legacy-helper   (~/.claude/skills/legacy-helper/SKILL.md)
  ✗ test-runner     (.claude/skills/test-runner/SKILL.md)
  ✗ old-pdf         (~/.claude/plugins/document/skills/old-pdf/SKILL.md)

Suggested actions:
  Disable a skill by renaming its SKILL.md:
    mv ~/.claude/skills/legacy-helper/SKILL.md ~/.claude/skills/legacy-helper/SKILL.md.disabled
```

## Trying it locally

```bash
claude --plugin-dir ~/claude-papercuts
/claude-papercuts:skill-budget
```

Or run the script directly:

```bash
~/claude-papercuts/skills/skill-budget/audit.py
~/claude-papercuts/skills/skill-budget/audit.py --budget 12000
~/claude-papercuts/skills/skill-budget/audit.py --json
```

## Configuration

| Flag | Default | What |
|---|---|---|
| `--budget N` | 15000 | Override the char budget (your environment may differ) |
| `--json` | off | Emit machine-readable JSON instead of the text report |
| `--no-color` | off | Disable ANSI colors (auto-disabled when stdout is not a tty) |

## What this skill does NOT do

- **It does not actually test which skills trigger.** It estimates
  based on char budget. The 15,000-char default is inferred from
  issue discussions and may not match your specific environment.
- **It does not modify any files.** The `mv ... .disabled`
  suggestions are for you to copy-paste if you choose.
- **It does not include already-disabled skills** (files ending in
  `.disabled` are skipped by Claude Code itself).

## Make it a habit

Run it weekly. Run it after every skill install. Run it whenever
Claude stops triggering a skill you expect. Same flywheel as
`npm outdated` or `brew doctor`.

## Deprecation plan

If Anthropic ships a first-class budget warning (e.g. `claude plugin
details` showing per-plugin budget impact, or a `--validate-skills`
flag that flags excess), this skill becomes a UI duplicate. We'll
mark it deprecated in the next monthly drop and update this README
with the date.
