---
name: token-x-ray
description: X-ray every source of auto-injected context Claude Code loads at session start — MCP servers, CLAUDE.md files, skills, subagents, and slash commands — and report estimated tokens per source. Use this skill when the user runs /claude-papercuts:token-x-ray, asks where their context tokens went, says Claude feels slow or expensive, mentions /context showing surprising numbers, or wants to know what to disable. Runs the audit.py script in this skill's directory and presents the result verbatim.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/token-x-ray/audit.py:*)
---

# token-x-ray — see where your context tokens went

**Fixes:**
[`#39686`](https://github.com/anthropics/claude-code/issues/39686)

## What this prevents

> *"43 claude.ai Skills (~3,950 tokens) and 26 Cowork plugins (~2,020
> tokens) silently injected into Claude Code context — no opt-out, ~6k
> tokens wasted per session."* — issue #39686

Claude Code's `/context` shows category totals but no per-item
breakdown. You see "Skills: 4,200 tokens" with no idea which of your
forty skills is doing the damage. `token-x-ray` itemizes every
auto-injected source so you can decide what to cut.

## What this skill does

When invoked, run the bundled `audit.py` script (next to this
SKILL.md) and present its output verbatim. The script discovers:

| Source | Where it looks |
|---|---|
| MCP servers | `~/.claude.json`, `~/.claude/settings.json`, `<cwd>/.claude/settings*.json`, `<cwd>/.mcp.json` |
| CLAUDE.md | `~/.claude/CLAUDE.md`, `<cwd>/CLAUDE.md`, `<cwd>/.claude/CLAUDE.md` |
| Skills | `~/.claude/skills/`, `<cwd>/.claude/skills/`, `~/.claude/plugins/*/skills/` |
| Subagents | `~/.claude/agents/`, `<cwd>/.claude/agents/` |
| Slash commands | `~/.claude/commands/`, `<cwd>/.claude/commands/` |

For each source, it estimates tokens using the
4-chars-per-token heuristic. MCP servers are flagged separately
because their tool schemas can only be measured by invoking the
server — the script uses a per-server estimate and points the
user at `/context` for the authoritative number.

## How to invoke (the actual procedure)

1. Run the audit script with the user's current settings:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/token-x-ray/audit.py
   ```

2. If the user passed arguments (e.g. `--json`, `--cwd`, `--home`),
   forward them.

3. Show the script's output verbatim. The bar chart, the per-source
   table, and the suggested cut commands are the value — reformatting
   them defeats the purpose.

4. After showing the output, if the user asks "what should I cut?":
   - Point them at the "Top cuts" section
   - Note that MCP servers are the highest-leverage cut (1500+ tokens
     each by heuristic) but require you to actually remove the server
     entry from settings
   - Recommend cutting unused skills/agents/commands first if MCP
     servers are in active use

5. Never auto-disable anything. The suggested `mv` and "remove from
   settings" hints are for the user to inspect and run themselves.

## When to auto-invoke

- User runs `/claude-papercuts:token-x-ray`
- User asks "where did my context go" / "what's eating my tokens"
- User says Claude feels slow, expensive, or laggy
- User mentions `/context` showing surprising numbers
- User asks for a "context audit" or "token diet"

## What this skill does NOT do

- It does not actually invoke MCP servers to measure their real tool
  schemas. That would be slow and can fail; we use a heuristic and
  flag it explicitly.
- It does not modify any files or settings. Suggestions are
  copy-paste, not auto-apply.
- It does not count the conversation/transcript itself — that's
  visible in `/context` directly and changes every turn.
- It does not count fixed prompt overhead (Anthropic's system
  prompt, tool catalog, etc.). Those are not user-controllable.

## Configuration

```bash
# Machine-readable JSON for piping into other tools
${CLAUDE_PLUGIN_ROOT}/skills/token-x-ray/audit.py --json

# Audit a different project directory
${CLAUDE_PLUGIN_ROOT}/skills/token-x-ray/audit.py --cwd /path/to/project
```

## Make it a habit

Run after every plugin/MCP install. If `/context` ever surprises you,
this is the first thing to run.
