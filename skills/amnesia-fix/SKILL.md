---
name: amnesia-fix
description: Persistent cross-session memory for Claude Code. Use this skill when the user wants to see their session journal, asks what was worked on in prior sessions, mentions Claude forgetting context, or runs /claude-papercuts:amnesia-fix. A Stop hook silently appends a compact entry (files touched, decisions, next steps, blockers) to .papercuts/journal.md after every turn; a SessionStart hook injects the last 3 entries as context at the top of every session — survives /clear and /compact.
allowed-tools: Bash(cat:*), Bash(ls:*), Bash(head:*), Bash(tail:*), Read
---

# amnesia-fix — cross-session memory

**Fixes:**
[`#14227`](https://github.com/anthropics/claude-code/issues/14227) (OPEN),
[`#27298`](https://github.com/anthropics/claude-code/issues/27298),
[`#43696`](https://github.com/anthropics/claude-code/issues/43696)

## What this prevents

> *"Every Claude Code session starts amnesiac. You get MEMORY.md
> (capped at 200 lines) and CLAUDE.md, and that's it."* — issue #14227

> *"`claude --continue` and `claude --resume` do not restore prior
> conversation context."* — issue #43696

Every session you start in a project forgets what the previous one
did. Decisions, blockers, and "next steps" you wrote down in
conversation vanish when the session ends. `amnesia-fix` makes them
persist across sessions automatically — no manual `notes.md`
maintenance.

## How it works (zero manual work for the user)

```
End of every assistant turn
        │
        ▼
   Stop hook fires
        │
        ▼
Read transcript → extract:
  • Files touched (tool_use Edit/Write)
  • "Decision:" lines
  • "Next:" lines
  • "Blocker:" lines
  • Topic (first user message)
        │
        ▼
Append compact entry to .papercuts/journal.md
(capped at ~500 chars per entry)


Start of every session (startup, resume, clear, compact)
        │
        ▼
SessionStart hook fires
        │
        ▼
Read last 3 journal entries
        │
        ▼
Print to stdout → Claude Code auto-injects
as additional context at session start
```

## When you (the model) should invoke this skill manually

- User runs `/claude-papercuts:amnesia-fix`
- User asks "what was I working on?"
- User asks to see the journal / project history
- User mentions wanting to "pick up where I left off"

## Manual invocation procedure

When asked to recap journal contents:

1. Check if `.papercuts/journal.md` exists in the project root.
2. If not, tell the user the journal will start populating after the
   first assistant turn in this project. Then stop.
3. Otherwise, read the journal. Tell the user:
   - How many total entries are recorded
   - The date range covered
   - A summary of the last 5 entries (or all of them if fewer)
4. Offer to look up a specific entry by date or topic if the user
   wants to dig into one.
5. Never modify or delete journal entries on your own.

## Journal entry format

Each entry is a markdown section in `.papercuts/journal.md`:

```markdown
## 2026-05-15 17:23 UTC | main | <topic from first user message>
- Files: <up to 5 paths>
- Decisions:
  - <up to 5 decisions, extracted via regex>
- Next:
  - <up to 5 next steps>
- Blockers:
  - <up to 5 blockers>
```

Sections that have nothing useful are omitted.

## Trigger phrases the Stop hook looks for

These are scanned in the final assistant message. They work whether
in bulleted lists or inline prose:

- `Decision:` / `Decided:`
- `Next:` / `Next step:` / `TODO:`
- `Blocker:` / `Blocked by:`

If none are found AND no files were edited, the hook writes nothing
(silent — avoids polluting the journal with trivial exchanges).

## What this skill does NOT do

- It does not surface the journal mid-conversation. The SessionStart
  hook only fires once per session, at the start. If you want to
  see the journal mid-session, invoke this skill manually.
- It does not deduplicate entries that look similar. The full
  append-only history is preserved so you can audit it later.
- It does not modify or delete entries. The user is the only one
  who edits `.papercuts/journal.md`.
- Per-project only. The journal lives in your project's
  `.papercuts/` directory. It does not sync across projects.

## Configuration

Optional `.papercuts/config.json` (planned for future versions —
defaults work fine today):

```json
{
  "amnesia_fix": {
    "load_entries": 3,
    "max_entry_chars": 500,
    "max_items_per_section": 5
  }
}
```

## Privacy

The journal is written to a local file in your project's
`.papercuts/` directory. No network calls. Add `.papercuts/` to
your `.gitignore` if not already.

## Deprecation plan

If Anthropic ships first-class persistent cross-session memory
(per issue #14227's feature request), this skill becomes a no-op
and gets deprecated in the next monthly release with the date.
