---
name: skill-budget
description: Audit installed Claude Code skills against the system-prompt char budget and show which ones may have silently fallen out of the model's visible list. Use this skill when the user runs /claude-papercuts:skill-budget, asks why their skills stopped triggering, mentions installed-but-invisible skills, or wants a Monday-morning health check of their Claude setup. Runs the audit.py script in this skill's directory and presents the result.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/skill-budget/audit.py:*)
---

# skill-budget — audit your installed skills

**Fixes:**
[`#30387`](https://github.com/anthropics/claude-code/issues/30387),
[`#34648`](https://github.com/anthropics/claude-code/issues/34648),
[`#16575`](https://github.com/anthropics/claude-code/issues/16575)

## What this prevents

> *"In environments with many skills (40+) and rich configuration, the
> model bypasses the Skill tool entirely and uses built-in tools
> directly, even when skill descriptions explicitly state 'ALWAYS use
> this skill.'"* — issue #34648

You install 40 skills. The system prompt has a limited budget for
skill descriptions. The excess falls off silently — no warning, no
error. Claude can't see them, and you don't know it.

## What this skill does

When invoked, run the bundled `audit.py` script (next to this
SKILL.md) and present its output to the user verbatim.

The script scans three locations:

- `~/.claude/skills/<name>/SKILL.md` — your global skills
- `.claude/skills/<name>/SKILL.md` — project-level skills
- `~/.claude/plugins/**/skills/<name>/SKILL.md` — plugin-installed skills

It parses each `SKILL.md`'s YAML frontmatter, sums the
`name + description` chars (the approximate per-skill cost in the
system prompt), and ranks skills by weight. Skills whose cumulative
sum exceeds the budget are marked `INVISIBLE TO CLAUDE`.

## How to invoke (the actual procedure)

1. Run the audit script with the user's current settings:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/skill-budget/audit.py
   ```

2. If the user passed arguments (e.g. `--budget 12000`, `--json`),
   forward them.

3. Show the script's output verbatim. Do not summarize or rewrite —
   the bar chart and the suggested `mv ... .disabled` commands are
   the value. Reformatting them defeats the purpose.

4. After showing the output, if any skills are marked INVISIBLE:
   - Ask the user if they want help deciding which ones to disable.
   - If asked, recommend disabling the largest-char skills first
     (highest information density per char freed) or the ones
     the user uses least often.

5. Never auto-disable a skill without explicit user consent. The
   suggested `mv` commands in the output are for the user to
   inspect and run themselves.

## When to auto-invoke

- User runs `/claude-papercuts:skill-budget`
- User asks "are my skills loaded?"
- User mentions a specific skill not triggering when they expect
- User says they recently installed N new skills and notices
  degraded behavior
- User asks for a "Monday morning check" or "skill audit"

## What this skill does NOT do

- It does not run the actual model to test which skills trigger;
  it estimates based on char budget. The 15,000-char default is
  inferred from issue discussions, not officially documented.
- It does not modify any files. The suggested `mv ... .disabled`
  commands are for the user to copy-paste if they choose.
- It does not include skills that have already been `.disabled`'d
  (renamed). Those are off-budget by definition.

## Configuration

```bash
# Use a different budget (e.g. if you know your environment's cap)
${CLAUDE_PLUGIN_ROOT}/skills/skill-budget/audit.py --budget 12000

# Machine-readable output (for piping into other tools)
${CLAUDE_PLUGIN_ROOT}/skills/skill-budget/audit.py --json
```

## Make it a habit

The retention play: run this every Monday morning, after every
skill install, or whenever Claude stops triggering a skill you
expect. Same flywheel as `npm outdated` or `brew doctor` — a
weekly health check.
