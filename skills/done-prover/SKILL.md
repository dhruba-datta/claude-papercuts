---
name: done-prover
description: Verify Claude's claim that tests are passing. Use this skill when the user wants to know whether a recent "all tests pass" or "feature complete" statement was honest, or when the user mentions Claude lied about completion. Reads the most recent test output from the conversation transcript and surfaces any discrepancy between what Claude claimed and what the test runner actually reported. Auto-triggered by a Stop hook whenever Claude makes a test-pass claim in its final message.
allowed-tools: Bash(ls:*), Bash(cat:*), Read
---

# done-prover — verify Claude's "done"

**Fixes:**
[`#5052`](https://github.com/anthropics/claude-code/issues/5052),
[`#10628`](https://github.com/anthropics/claude-code/issues/10628),
[`#20350`](https://github.com/anthropics/claude-code/issues/20350)

## What this prevents

> *"Tests pass because they test structure and mock implementations
> rather than actual functionality."*
> — common pattern in #5052

Claude Code can declare "all 47 tests pass" when 2 actually failed,
1 was skipped, and the integration suite never ran. This skill catches
that.

## How it works

A `Stop` hook (`hooks/verify-claims.sh`) fires at the end of every
assistant turn. It:

1. Reads the final assistant message from the transcript
2. Looks for completion-claim phrases ("all tests pass",
   "everything green", "X tests passing", etc.)
3. If a claim is found, scans recent `tool_result` entries for the
   actual test output Claude already ran
4. If the test output shows failures, the hook **blocks** the stop
   and surfaces a verdict to the conversation

If no claim is found, or no test output is in scope, the hook exits
silently. It never re-runs tests on its own — it only verifies the
output Claude already saw.

## When you (the model) should invoke this skill manually

The Stop hook handles auto-invocation. You should manually invoke
this skill if the user:

- Asks "did Claude actually test that?"
- Says "verify the last claim"
- Mentions Claude lied about completion
- Asks for a proof artifact of a recent test run

## Verification procedure (when manually invoked)

1. Read `.papercuts/proofs/` (most recent file). Each verdict the
   Stop hook generated is saved here. If empty, tell the user no
   recent claim has been verified yet.
2. List the most recent 3 verdicts with timestamps.
3. For each, show:
   - The claim that was made (verbatim from the assistant message)
   - The discrepancy that was detected
   - The path to the original test output

## Verdict format

The hook (and any manual invocation) emits this exact format:

```
─── done-prover: verdict ───
Claim:    "<verbatim phrase from assistant>"
Evidence: <path to tool_result that was checked>

Reported by Claude:
  <Claude's count, e.g. "all 47 tests pass">

Actual test output:
  ✓ <passed>
  ✗ <failed>
  ◌ <skipped>

Discrepancy:
  <one-sentence summary>
─────────────────────────────
```

## What this skill does NOT do

- It does not re-run tests. It only verifies the output Claude
  already saw, which is faster and matches what the user observed.
- It does not block normal "done" claims (e.g. "I finished the
  refactor"). It only blocks claims about TEST RESULTS.
- It does not handle every test framework's output format
  perfectly. It looks for common failure signals (`FAIL`, `ERROR`,
  `failed:`, `\d+ failed`). False negatives are possible; false
  positives are designed to be rare.

## Configuration

Optional `.papercuts/config.json`:

```json
{
  "done_prover": {
    "claim_phrases": ["all tests pass", "all green", "..."],
    "failure_patterns": ["FAIL", "ERROR", "\\d+ failed"],
    "verdict_dir": ".papercuts/proofs"
  }
}
```

Defaults are sensible. Most users never need to touch this.

## Trust, then verify

This skill is the "verify" half of the project's voice. Every claim
the assistant makes that something is done gets a receipt.
