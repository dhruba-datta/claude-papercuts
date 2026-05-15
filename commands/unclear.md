---
description: Restore conversation context from the most recent automatic snapshot
allowed-tools: Bash(ls:*), Bash(cat:*), Bash(head:*), Read
---

You are the `/unclear` recovery command for `claude-papercuts`. The user
has invoked you, likely after an accidental `/clear` wiped their
conversation. Your job is to find the most recent snapshot of the
prior conversation and reconstruct enough context that work can
continue.

## Step 1 — Locate snapshots

Run this in the shell:

```bash
ls -1t .papercuts/snapshots/*.jsonl 2>/dev/null | head -5
```

If the output is empty, the Stop hook has not run yet in this project.
Tell the user:

> No snapshots found in `.papercuts/snapshots/`. The Stop hook writes a
> snapshot at the end of every assistant turn, so a brand-new session
> has no recovery point. Future sessions in this project will be
> recoverable.

Then stop.

## Step 2 — Read the newest snapshot

Use the Read tool to load the most recent snapshot file (the first line
of the `ls` output). It's a JSONL file where each line is one JSON
object representing a turn in the prior conversation. The schema
roughly:

```jsonc
{"type": "user" | "assistant" | "summary" | "tool_use" | "tool_result",
 "message": {"role": "...", "content": [...]},
 "timestamp": "ISO-8601",
 ...}
```

Different Claude Code versions may use slightly different schemas. Be
permissive — read whatever's there.

## Step 3 — Summarize the prior conversation

Extract from the snapshot:

- **What was being worked on** — read the first 2-3 user messages and
  the last assistant message to bracket the topic
- **Files being edited** — scan tool_use entries for `Edit`, `Write`,
  `Read` and collect unique paths
- **Recent decisions** — look for lines in assistant messages starting
  with "Decision:", "Next:", "Blocker:", or for explicit conclusions
- **Anything the user explicitly asked you not to do** — these are
  often the most important signals to preserve

## Step 4 — Present the recap

Output exactly this format (terminal-friendly, no emoji, no
exclamation marks):

```
─── /unclear: snapshot restored ───
Source: <relative path to snapshot file>
Timestamp: <ISO-8601 from the snapshot filename, decoded>
Turns recovered: <count>

Last topic
  <one-sentence summary>

Files in play
  <path 1>
  <path 2>
  ...

Recent decisions
  • <decision 1>
  • <decision 2>
  • <decision 3>

Picking up from
  "<verbatim final user message, or final assistant turn if no
   pending user turn>"
─────────────────────────────────
```

## Step 5 — Wait

After printing the recap, do not take any further action. Wait for the
user to confirm or redirect. They may want to:

- Resume exactly where they left off (most common)
- Pick one of the listed decisions to revisit
- Discard the recap and start fresh

Match the user's intent on the next turn. Do not assume.

## Edge cases

- **Multiple snapshots in a single second**: pick the alphabetically
  last one (timestamps are UTC and lexicographically ordered).
- **Snapshot is empty or malformed JSON**: try the next-newest. If all
  recent snapshots are unreadable, tell the user honestly and stop.
- **Snapshot is from a different cwd than the current one**: still
  read it, but flag in the recap: "Note: snapshot was taken from
  `<other path>` — context may not match this directory."
