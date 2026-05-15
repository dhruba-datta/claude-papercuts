---
name: compact-guard
description: Survive /compact and auto-compact without losing the plan. Use this skill when the user runs /claude-papercuts:compact-guard, asks why Claude lost their plan after a compact, mentions plan-mode state vanishing mid-session, or wants to see the latest pre-compact snapshot. A PreCompact hook silently captures the current task, active todos, files edited, and the last assistant plan to .papercuts/compact-snapshots/ right before compaction runs; a SessionStart hook (only when source=compact) injects that snapshot back as context so the post-compact session knows what it was doing.
allowed-tools: Bash(cat:*), Bash(ls:*), Bash(head:*), Read
---

# compact-guard — survive /compact

**Fixes:**
[`#24686`](https://github.com/anthropics/claude-code/issues/24686),
[`#26061`](https://github.com/anthropics/claude-code/issues/26061)

## What this prevents

> *"After context compaction occurs during plan mode execution, Claude
> Code fails to re-read or reference the existing plan."* — issue #24686

> *"Plan mode state lost after context compression."* — issue #26061

You're 30 turns into a careful refactor. `/compact` runs (manually or
because you hit the auto-compact threshold). The summarizer
condenses *everything*, including the plan you were halfway through.
Claude wakes up on the other side without the plan, and you have to
re-prompt from scratch.

`compact-guard` snapshots the plan *before* compaction touches it,
then re-injects the snapshot as context immediately after, so the
post-compact turn starts knowing the current task, active todos,
files touched, and the most recent plan.

## How it works (zero manual work for the user)

```
/compact (manual)  or  auto-compact at threshold
        │
        ▼
   PreCompact hook fires
        │
        ▼
Read transcript → extract:
  • Most recent user message     (the current task)
  • Latest TodoWrite todos       (pending + in_progress only)
  • Files edited this session    (Edit / Write / MultiEdit)
  • Last assistant text block    (likely the working plan)
        │
        ▼
Write .papercuts/compact-snapshots/<timestamp>.md
(keeps 5 most recent — oldest pruned)


Compaction runs. The summarizer eats most of the context.


Next session start with source="compact"
        │
        ▼
   SessionStart hook fires
        │
        ▼
Read the latest snapshot → print to stdout
Claude Code auto-injects stdout as additional context
```

## When you (the model) should invoke this skill manually

- User runs `/claude-papercuts:compact-guard`
- User asks "what was I doing before the compact?"
- User asks to see the latest pre-compact snapshot
- User says they lost their plan / their todos / their work after a
  compact ran

## Manual invocation procedure

When asked to show compact-guard state:

1. Check if `.papercuts/compact-snapshots/` exists in the project root.
2. If not, tell the user no compaction has happened yet in this project
   — the directory will populate on the first PreCompact. Then stop.
3. Otherwise, list the snapshots (sorted newest first). Tell the user:
   - How many snapshots are stored
   - The timestamp of each
4. If asked for a specific snapshot, cat it to the user verbatim. The
   format is plain markdown — don't summarize.
5. Never modify or delete snapshots automatically. If the user asks
   you to clean them up, ask for explicit confirmation first.

## Snapshot format

Each snapshot is a markdown file in
`.papercuts/compact-snapshots/<UTC-timestamp>.md`:

```markdown
# compact-guard snapshot

- **When:** 2026-05-16 09:14 UTC
- **Trigger:** auto-compact
- **Session:** abc123def456

## Current task (last user message)
> <the most recent user prompt>

## Active todos
- [in_progress] <todo content>
- [pending] <todo content>

## Files edited this session
- `src/middleware/auth.ts`
- `src/__tests__/auth.test.ts`

## Last assistant message (plan / summary)

<the last assistant text block — usually the working plan, capped at 1500 chars>
```

Sections that have nothing useful are omitted. Total snapshot file
is uncapped because it's read on demand, not auto-injected into the
system prompt.

## What this skill does NOT do

- It does not block compaction. PreCompact runs read-only and exits 0.
- It does not modify the transcript. The snapshot is a separate file.
- It does not deduplicate snapshots. Five most-recent are kept, in
  case you want to inspect a series of compactions.
- It does not survive across projects. Snapshots live in
  `.papercuts/compact-snapshots/` relative to the project's cwd.
- It does not inject context on `/clear`, `/resume`, or startup —
  only post-compact. Use `amnesia-fix` for cross-session continuity.

## Privacy

Snapshots are written to a local file in your project's `.papercuts/`
directory. No network calls. Add `.papercuts/` to your `.gitignore` if
not already.

## Deprecation plan

If Anthropic ships a compact-resilient plan-mode (per issues #24686
and #26061), this skill becomes a no-op and gets deprecated in the
next monthly release with the date.
