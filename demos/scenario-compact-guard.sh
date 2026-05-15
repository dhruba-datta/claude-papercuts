#!/usr/bin/env bash
# scenario-compact-guard.sh — scripted "movie" for the compact-guard GIF.
#
# Shows a working session about to hit auto-compact, the PreCompact hook
# saving state, then the post-compact session resuming cleanly with the
# snapshot injected. Real plumbing is tested in tests/run-all.sh.

set -u

GREEN=$'\033[38;5;114m'
AMBER=$'\033[38;5;179m'
CYAN=$'\033[38;5;111m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
USER=$'\033[38;5;111m'
ACCENT=$'\033[38;5;180m'
SYS=$'\033[38;5;141m'
RESET=$'\033[0m'

pause() { sleep "$1"; }
say()   { printf '%s\n' "$*"; }

# --- Before compaction: deep into work ---

say "${DIM}claude-code v2.1.4 — context 91% full · auto-compact imminent${RESET}"
say ""
pause 0.4

say "${USER}>${RESET} okay, now add tests for the new bearer flow"
pause 0.6
say ""
say "${ACCENT}● TodoWrite${RESET}"
say "${DIM}  - [in_progress] Add positive-case test for valid bearer${RESET}"
say "${DIM}  - [pending]     Add negative-case test for malformed token${RESET}"
say "${DIM}  - [pending]     Add edge-case test for missing Authorization${RESET}"
pause 0.6
say "${ACCENT}● Edit  src/__tests__/auth.test.ts${RESET}"
pause 0.6

say ""
say "${AMBER}⚠ Context 92% full — auto-compact triggered${RESET}"
pause 0.8

# --- PreCompact fires ---

say ""
say "${SYS}[ compact-guard PreCompact hook ]${RESET}"
say "${DIM}  ✎ snapshotting plan-mode state...${RESET}"
say "${DIM}    → current task           ✓${RESET}"
say "${DIM}    → 2 active todos         ✓${RESET}"
say "${DIM}    → 2 files edited         ✓${RESET}"
say "${DIM}    → last plan (837 chars)  ✓${RESET}"
say "${DIM}  ✎ wrote .papercuts/compact-snapshots/2026-05-16T09-14-32Z.md${RESET}"
pause 1.2

say ""
say "${DIM}═══ /compact running... summarizing 47 turns into 8 lines ═══${RESET}"
pause 1.2

# --- After compaction: SessionStart load-state fires ---

say ""
say "${SYS}[ compact-guard SessionStart hook  ·  source=compact ]${RESET}"
say "${SYS}  ↓ injecting pre-compact snapshot as context${RESET}"
pause 0.6

say ""
say "${DIM}── injected context ─────────────────────────────────${RESET}"
say "${BOLD}# compact-guard snapshot${RESET}"
say "${DIM}- When:     2026-05-16 09:14 UTC${RESET}"
say "${DIM}- Trigger:  auto-compact${RESET}"
say ""
say "${DIM}## Current task${RESET}"
say "${DIM}> okay, now add tests for the new bearer flow${RESET}"
say ""
say "${DIM}## Active todos${RESET}"
say "${DIM}- [in_progress] Add positive-case test for valid bearer${RESET}"
say "${DIM}- [pending]     Add negative-case test for malformed token${RESET}"
say "${DIM}- [pending]     Add edge-case test for missing Authorization${RESET}"
say ""
say "${DIM}## Files edited this session${RESET}"
say "${DIM}- src/middleware/auth.ts${RESET}"
say "${DIM}- src/__tests__/auth.test.ts${RESET}"
say "${DIM}─────────────────────────────────────────────────────${RESET}"
pause 1.2

say ""
say "${USER}>${RESET} where were we?"
pause 0.6
say ""
say "${ACCENT}● Mid-way through adding bearer-token tests. The positive-${RESET}"
say "${ACCENT}  case test is in progress; the malformed-token and missing-${RESET}"
say "${ACCENT}  Authorization-header tests are queued. Continuing from${RESET}"
say "${ACCENT}  src/__tests__/auth.test.ts.${RESET}"
pause 2.8
