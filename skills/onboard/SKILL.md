---
name: onboard
description: First-run walkthrough of the claude-papercuts plugin. Use this skill when the user runs /claude-papercuts:onboard, asks what claude-papercuts does, says they're new to the plugin, asks which papercut skill they should enable first, or wants the curated install order. Runs recommend.py to detect which of the nine papercut skills are already installed, picks the next one to enable, and explains why — opinionated ordering, not exhaustive list.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/onboard/recommend.py:*)
---

# onboard — first-run walkthrough

**Fixes:** new-user churn documented in
[MindStudio's Claude Code onboarding analysis](https://app.mindstudio.ai/blog/claude-code-skills-explained)
and Medium "I installed 40 skills and Claude got worse" reports — users
install too many skills at once, can't tell what's working, and bounce.

## What this prevents

> *"I followed a tutorial, installed 25 skills, and now Claude is
> noticeably slower and ignores half of them. I uninstalled
> everything."* — common Medium / Reddit complaint, Dec 2025

The claude-papercuts plugin ships nine skills. Most users don't need
all nine on day one. `onboard` is the curated install order: which
skill solves which problem, in priority order, with a one-sentence
"why" each.

## What it does

Runs the bundled `recommend.py`, which:

1. Detects which of the nine papercut skills are already installed
2. Picks the next one to enable based on order
3. Shows the install commands

## How to invoke (the actual procedure)

1. Run the recommend script:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/onboard/recommend.py
   ```

2. If the user asked something specific (e.g. "what's the next one?"),
   forward the matching flag:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/onboard/recommend.py --next
   ```

3. Show the script's output verbatim. Then ask the user:
   - Which workflows do they actually do? (sessions/day, /compact use,
     run YOLO mode, ship code Claude wrote, author skills, etc.)
   - Based on their answers, suggest the next 1–3 from the ordered list
     that match their workflow.

4. Never auto-install. The user runs the install command themselves —
   we're advisors, not installers.

## The opinionated order (and why)

| # | Skill | When to enable |
|---|---|---|
| 1 | `safe-shell` | Always first — irreversible-command refusal, no downside |
| 2 | `token-x-ray` | Visibility into what's eating your context — informs all other decisions |
| 3 | `amnesia-fix` | If you run >1 Claude session per day |
| 4 | `compact-guard` | If you ever hit `/compact` (most users will) |
| 5 | `done-prover` | If you ship code Claude writes (high-impact, mildly noisy) |
| 6 | `unclear` | If you've ever run `/clear` and regretted it |
| 7 | `skill-doctor` | If you author your own SKILL.md files |
| 8 | `skill-budget` | If you have 10+ skills installed |
| 9 | `subagent-broker` | Power-user — multi-stage agentic delegation |

## When to auto-invoke

- User runs `/claude-papercuts:onboard`
- User asks what claude-papercuts does
- User asks which skill to enable first / how to start
- User says they're new to the plugin
- User asks for the install order or "what should I turn on?"

## What this skill does NOT do

- It does not install skills. The user runs install commands themselves.
- It does not modify settings. No auto-config.
- It does not interview the user with a fixed quiz. You (Claude) tailor
  the recommendation to their actual workflow after running the script.
- It does not recommend skills outside the nine papercuts. For broader
  ecosystem recommendations, point users at
  https://github.com/dhruba-datta/claude-papercuts/discussions.

## Configuration

```bash
# Full walkthrough
${CLAUDE_PLUGIN_ROOT}/skills/onboard/recommend.py

# Just the next skill to enable
${CLAUDE_PLUGIN_ROOT}/skills/onboard/recommend.py --next

# Machine-readable JSON
${CLAUDE_PLUGIN_ROOT}/skills/onboard/recommend.py --json
```

## Deprecation plan

If the claude-papercuts plugin grows past nine skills, the
recommendation list needs to be re-curated. This file's `SKILLS` list
is the source of truth.
