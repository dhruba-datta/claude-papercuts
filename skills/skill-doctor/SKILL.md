---
name: skill-doctor
description: Diagnose why a SKILL.md isn't auto-invoking. Use this skill when the user runs /claude-papercuts:skill-doctor, asks why their skill won't trigger, mentions a skill that Claude keeps ignoring, or wants a lint pass on a SKILL.md they're writing. Runs lint.py to flag missing trigger phrases, vague descriptions, descriptions that overlap with built-in tool training (the root cause of issue #30387), names that aren't kebab-case, and length issues outside Anthropic's 50–1024 char bound.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/skill-doctor/lint.py:*)
---

# skill-doctor — why isn't my skill auto-invoking?

**Fixes:** root cause of
[`#30387`](https://github.com/anthropics/claude-code/issues/30387) —
*"Custom skills not reliably auto-triggered. The model's training-time
knowledge competes with and takes precedence over skill instructions."*

## What this prevents

> *"Skills for git/shell operations are ignored ~50% of the time."*
> — issue #30387

When a SKILL.md description says *"use for git operations"*, the
model's training-time knowledge of git wins. The skill is never
invoked. `skill-doctor` lints SKILL.md files against the same
heuristics Anthropic's own template authors apply implicitly:

| Check | Severity | Why it matters |
|---|---|---|
| `name:` present and kebab-case | error | Plugin loader rejects otherwise |
| `description:` length 50–1024 | error | Anthropic's published bound |
| Description has trigger phrase | warn | Without "Use this when …", the model has nothing to route on |
| Description avoids vague words | info | "helper", "utility", "manager", "toolkit" — too generic |
| Description avoids training overlap | warn | "edits files", "git operations", "runs shell" — built-in tool wins |
| Description under 80 chars | warn | Not enough context to route to the right skill |

## How to invoke (the actual procedure)

1. If the user names a specific SKILL.md path, run:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/skill-doctor/lint.py <path>
   ```

2. If the user wants a sweep of every installed skill, run:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/skill-doctor/lint.py --all
   ```

3. Show the script's output verbatim. The severity glyphs (`✗` error,
   `⚠` warn, `·` info) and the issue codes (e.g. `training-overlap`,
   `no-trigger`) are the value. Don't summarize the categories — the
   per-skill report is what the user came for.

4. If the user asks for help fixing a specific issue:
   - For `training-overlap`: rewrite the description to name the
     specific workflow the skill owns ("apply database migrations"
     not "for database operations").
   - For `no-trigger`: add a sentence starting with "Use this when …".
   - For `desc-thin`: expand to include one concrete invocation
     example and one trigger phrase.

5. Never auto-modify a SKILL.md. Suggestions are for the user to
   apply themselves.

## What gets discovered by `--all`

The same locations as `skill-budget`:
- `~/.claude/skills/<name>/SKILL.md`
- `<cwd>/.claude/skills/<name>/SKILL.md`
- `~/.claude/plugins/*/skills/<name>/SKILL.md`

## When to auto-invoke

- User runs `/claude-papercuts:skill-doctor`
- User asks "why isn't my skill triggering?"
- User mentions a skill that Claude keeps ignoring
- User says they just wrote a new SKILL.md and wants it reviewed

## What this skill does NOT do

- It does not modify SKILL.md files. Suggestions only.
- It does not lint the *body* of the SKILL.md (the markdown after
  the frontmatter) — only the frontmatter and description.
- It does not validate `allowed-tools:` glob syntax. Claude Code's
  plugin loader does that.
- It does not (yet) run the skill to verify it triggers. A
  "trigger-fuzz" mode is planned for a future release.

## Configuration

```bash
# JSON output for piping into other tools / CI
${CLAUDE_PLUGIN_ROOT}/skills/skill-doctor/lint.py --all --json

# Lint a specific path
${CLAUDE_PLUGIN_ROOT}/skills/skill-doctor/lint.py path/to/SKILL.md

# Scan a different project
${CLAUDE_PLUGIN_ROOT}/skills/skill-doctor/lint.py --all --cwd /path/to/proj
```

## Deprecation plan

If Anthropic ships a built-in SKILL.md linter (e.g. via
`claude plugin validate`), this skill becomes a duplicate and gets
deprecated in the next monthly release with the date.
