#!/usr/bin/env bash
# scenario-unclear.sh — scripted "movie" played back during vhs recording.
#
# This is NOT how the skill actually works — it's a deterministic
# simulation of a real Claude Code session so the GIF demonstrates the
# user experience. The skill's real plumbing is tested in tests/run-all.sh.
#
# Designed to play back inside `vhs demos/unclear.tape`.

set -u

# Colors (xterm-256 — render nicely in vhs's GitHub Dark theme)
GREEN=$'\033[38;5;114m'
RED=$'\033[38;5;203m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
USER=$'\033[38;5;111m'
ASSISTANT=$'\033[38;5;180m'
RESET=$'\033[0m'

pause() { sleep "$1"; }
say()   { printf '%s\n' "$*"; }

# --- Frame 1: a normal Claude Code session in progress ---

say "${DIM}claude-code v2.1.4 — connected to claude-opus-4-7${RESET}"
say ""
pause 0.6

say "${USER}>${RESET} Refactor the auth middleware to drop cookie sessions"
say "${USER} ${RESET} in favor of bearer tokens. Keep the rate limiter."
pause 0.8

say ""
say "${ASSISTANT}● I'll touch three files:${RESET}"
say "    src/middleware/auth.ts"
say "    src/middleware/rateLimit.ts (read-only, keep as-is)"
say "    src/middleware/__tests__/auth.test.ts"
pause 0.5

say ""
say "${DIM}  Edit  src/middleware/auth.ts                        +47 -23${RESET}"
say "${DIM}  Edit  src/middleware/__tests__/auth.test.ts          +12 -8${RESET}"
pause 0.4

say ""
say "${ASSISTANT}● Done. Decision: bearer tokens validated against the${RESET}"
say "${ASSISTANT}  same in-memory store. Next: invalidate active cookie${RESET}"
say "${ASSISTANT}  sessions in a migration before we ship.${RESET}"
pause 1.2

# --- Frame 2: the accidental /clear ---

say ""
say "${USER}>${RESET} /clear"
pause 0.5

# Simulate Claude Code clearing the screen
printf '\033[2J\033[H'
say "${DIM}— context cleared —${RESET}"
say ""
pause 1.8  # the horror beat

# --- Frame 3: recovery ---

say "${USER}>${RESET} /claude-papercuts:unclear"
pause 0.6

say ""
say "${GREEN}─── /unclear: snapshot restored ───${RESET}"
say "Source:       .papercuts/snapshots/20260515T143012Z.jsonl"
say "Timestamp:    2026-05-15T14:30:12Z"
say "Turns recovered: 6"
say ""
say "${BOLD}Last topic${RESET}"
say "  Refactoring auth middleware from cookies to bearer tokens"
say ""
say "${BOLD}Files in play${RESET}"
say "  src/middleware/auth.ts"
say "  src/middleware/__tests__/auth.test.ts"
say "  src/middleware/rateLimit.ts (read-only)"
say ""
say "${BOLD}Recent decisions${RESET}"
say "  • Keep rate limiter unchanged"
say "  • Bearer tokens validate against existing in-memory store"
say "  • Active cookie sessions invalidated via migration before ship"
say ""
say "${BOLD}Picking up from${RESET}"
say "  \"Next: invalidate active cookie sessions in a migration\""
say "${GREEN}─────────────────────────────────${RESET}"

pause 2.5  # hold on the recap so it shows as the preview thumbnail
