---
name: subagent-broker
description: Battle-tested Task-tool delegation templates that survive the subagent-delegation pitfalls reported in issues #4182, #5528, and #19077. Use this skill when the user runs /claude-papercuts:subagent-broker, asks how to delegate work to subagents reliably, asks when to use the Task tool, says their subagents ignore configuration or CRITICAL directives, or wants a template for parallel search / independent review / cross-file audit. Runs templates.py to list named delegation patterns and prints the one matching the user's situation.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/subagent-broker/templates.py:*)
---

# subagent-broker — Task-tool delegation patterns that actually work

**Fixes:**
[`#4182`](https://github.com/anthropics/claude-code/issues/4182),
[`#5528`](https://github.com/anthropics/claude-code/issues/5528),
[`#19077`](https://github.com/anthropics/claude-code/issues/19077)

## What this prevents

> *"Sub-agents claim no Task tool access despite configuration stating
> tools: Read, Write, Edit, Task. CRITICAL rules are completely
> disregarded. No actual delegation occurs."* — issue #5528

> *"Sub-Agent Task tool not exposed when launching nested agents."*
> — issue #4182

The Task tool is the official delegation mechanism, but it fails
silently when the delegation prompt isn't structured right:

- Open-ended prompts return shallow output
- "CRITICAL" / "ALWAYS" directives are ignored
- Briefed-with-conclusion prompts produce sycophantic "yes" answers
- Subagent results aren't shared between subagents (people assume they are)

`subagent-broker` ships the prompt skeletons that survive these
pitfalls — distilled from the issue threads themselves.

## The templates

| Template | When to use |
|---|---|
| `parallel-search` | N independent searches at once (call all Task tools in one message) |
| `single-research` | One open-ended exploration noisy in the main context |
| `cross-file-audit` | Consistency review across files (front-load + re-assert the rule) |
| `known-target` | **Don't delegate** — use Read/Grep directly |
| `independent-verification` | Second opinion without anchoring on your conclusion |

## How to invoke (the actual procedure)

1. Run the templates script to see what's available:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/subagent-broker/templates.py
   ```

2. Ask the user which delegation flavor matches their task:
   - Parallel search across the codebase → `parallel-search`
   - One deep research question → `single-research`
   - Cross-file consistency check → `cross-file-audit`
   - "I know exactly which file I need" → `known-target` (don't delegate)
   - Second opinion / independent review → `independent-verification`

3. Print the chosen template:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/subagent-broker/templates.py <name>
   ```

4. Adapt the placeholders (`<files>`, `<specific concern>`, etc.) to
   the user's actual task. Then make the Task call yourself.

5. Never invoke `Task` blindly. The user should see the proposed
   delegation prompt and approve it before you fire.

## The non-obvious rules (from the issues)

- **State the most-important constraint twice.** Once near the top of
  the prompt, once in the response-format section. `CRITICAL` /
  `ALWAYS` keywords don't help; placement does. (issue #5528)
- **Cap the response length explicitly.** Subagents will read every
  file they find if you don't tell them not to.
- **Parallelize in a single message.** Two `Task` calls in two
  consecutive messages run sequentially. Two `Task` calls in the same
  message run in parallel.
- **Don't tell the subagent your conclusion.** They'll anchor on it.
  For verification, withhold your analysis.
- **Subagents are 5-10× more expensive than a direct tool call.**
  Delegate only when the subagent will make 3+ tool calls.

## When to auto-invoke

- User runs `/claude-papercuts:subagent-broker`
- User asks how to use Task / subagents / delegation
- User says subagents ignore their config / CRITICAL rules
- User wants a template for parallel work / cross-file review

## What this skill does NOT do

- **It does not fire the Task tool for you.** You (Claude) call Task
  yourself with the adapted template — the user reviews the prompt
  first.
- **It does not validate that your delegation succeeded.** The
  subagent's own output is the verdict.
- **It is not a queue / dispatcher.** Earlier drafts of this skill
  shipped a queue + spawn system; we cut it because it duplicates
  what Anthropic's Task tool already does.

## Configuration

```bash
# List every template
${CLAUDE_PLUGIN_ROOT}/skills/subagent-broker/templates.py

# Print one ready to paste
${CLAUDE_PLUGIN_ROOT}/skills/subagent-broker/templates.py parallel-search

# Filter by keyword
${CLAUDE_PLUGIN_ROOT}/skills/subagent-broker/templates.py --search research

# Machine-readable
${CLAUDE_PLUGIN_ROOT}/skills/subagent-broker/templates.py --json
```

## Deprecation plan

If Anthropic ships first-class delegation reliability (per issues
#4182, #5528, #19077), the templates become less load-bearing and
this skill can simplify or deprecate.
