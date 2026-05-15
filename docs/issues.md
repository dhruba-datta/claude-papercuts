# Issues — The Receipts

Every skill in this plugin maps to one or more real GitHub issues on
`anthropics/claude-code`. This is the public version of that table.
**Last verified:** 2026-05-15.

## Verification protocol

Before commenting on any issue with a backlink, re-run:

```bash
for n in 30387 34648 16575 14227 27298 43696 39686 5052 10628 20350 \
         39975 4182 5528 19077 24686 26061; do
  echo "--- #$n ---"
  gh issue view "$n" --repo anthropics/claude-code \
    --json state,title,closedAt
done
```

## The 16 issues

### Skills silently vanish past the ~15K char budget
- [`#30387`](https://github.com/anthropics/claude-code/issues/30387) — closed as not planned — Custom skills not reliably auto-triggered (training-time knowledge competes with skill instructions)
- [`#34648`](https://github.com/anthropics/claude-code/issues/34648) — closed as not planned — Skills never trigger in `-p` mode with 40+ skills + 8 MCP servers
- [`#16575`](https://github.com/anthropics/claude-code/issues/16575) — closed as duplicate — User-defined plugin skills not appearing in `available_skills`

### No cross-session memory
- [`#14227`](https://github.com/anthropics/claude-code/issues/14227) — **OPEN** — Feature Request: Persistent Memory Between Sessions
- [`#27298`](https://github.com/anthropics/claude-code/issues/27298) — closed as not planned — Layered memory system proposal (reporter's PoC showed 81% reduction in always-loaded tokens)
- [`#43696`](https://github.com/anthropics/claude-code/issues/43696) — closed as duplicate — `--continue` and `--resume` do not restore prior context

### Auto-injected cloud skills waste tokens
- [`#39686`](https://github.com/anthropics/claude-code/issues/39686) — closed as not planned — 43 cloud skills + 26 plugins silently inject ~6k tokens per session with no opt-out

### Claude lies about completion
- [`#5052`](https://github.com/anthropics/claude-code/issues/5052) — closed as duplicate — Claude claimed 95-100% complete; actual was 40-50%
- [`#10628`](https://github.com/anthropics/claude-code/issues/10628) — closed as not planned — Claude hallucinated fake user input, then doubled down
- [`#20350`](https://github.com/anthropics/claude-code/issues/20350) — closed as not planned — Delivers 10% of requested thinking budget at full price

### `/clear` has no undo
- [`#39975`](https://github.com/anthropics/claude-code/issues/39975) — **OPEN** — Feature Request: Add `/unclear` command

### Subagent delegation broken
- [`#4182`](https://github.com/anthropics/claude-code/issues/4182) — closed as duplicate — Sub-Agent Task tool not exposed when launching nested agents
- [`#5528`](https://github.com/anthropics/claude-code/issues/5528) — closed as duplicate — Sub-agents ignore configuration and CRITICAL directives
- [`#19077`](https://github.com/anthropics/claude-code/issues/19077) — **OPEN** — Sub-agents can't create sub-sub-agents even with Task tool access

### Plan/decision loss on `/compact`
- [`#24686`](https://github.com/anthropics/claude-code/issues/24686) — closed as not planned — Plans made in plan mode lost after compacting
- [`#26061`](https://github.com/anthropics/claude-code/issues/26061) — closed — Plan mode state lost after context compression

## State summary

| State | Count |
|---|---|
| Open | 3 |
| Closed (not planned) | 8 |
| Closed (duplicate) | 4 |
| Closed (other) | 1 |
| **Total** | **16** |
