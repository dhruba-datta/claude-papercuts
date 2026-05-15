#!/usr/bin/env bash
# scenario-amnesia-fix.sh — scripted "movie" for the amnesia-fix GIF.
#
# Shows two sessions: Session A ends with decisions recorded; Session
# B (the next day) starts fresh but the journal context is auto-loaded.
# Real plumbing is tested in tests/run-all.sh.

set -u

GREEN=$'\033[38;5;114m'
AMBER=$'\033[38;5;179m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
USER=$'\033[38;5;111m'
ACCENT=$'\033[38;5;180m'
SYS=$'\033[38;5;141m'
RESET=$'\033[0m'

pause() { sleep "$1"; }
say()   { printf '%s\n' "$*"; }

# --- Session A: Tuesday afternoon ---

say "${DIM}claude-code v2.1.4 — connected to claude-opus-4-7${RESET}"
say "${DIM}session A · Tuesday 14:23${RESET}"
say ""
pause 0.5

say "${USER}>${RESET} Refactor the auth middleware to use bearer tokens."
pause 0.8

say ""
say "${ACCENT}● Edit  src/middleware/auth.ts${RESET}"
say "${ACCENT}● Edit  src/__tests__/auth.test.ts${RESET}"
pause 0.6

say ""
say "${ACCENT}● Done. Decision: keep the rate limiter unchanged.${RESET}"
say "${ACCENT}  Decision: bearer tokens validated against the existing${RESET}"
say "${ACCENT}  in-memory store. Next: invalidate active cookie sessions${RESET}"
say "${ACCENT}  in a migration before we ship.${RESET}"
pause 1.2

say ""
say "${DIM}── session ends ──${RESET}"
say ""
say "${SYS}[ amnesia-fix Stop hook ]${RESET}"
say "${DIM}  ✎ appended to .papercuts/journal.md${RESET}"
pause 2.0

# --- Session B: Wednesday morning, fresh session ---

say ""
say "${DIM}═══════════════════════════════════════════════════════${RESET}"
say "${DIM}claude-code v2.1.4 — connected to claude-opus-4-7${RESET}"
say "${DIM}session B · Wednesday 09:14 (next day, fresh terminal)${RESET}"
say ""
pause 0.5

say "${SYS}[ amnesia-fix SessionStart hook ]${RESET}"
say "${SYS}  ↓ injecting last 3 journal entries as context${RESET}"
pause 0.8

say ""
say "${DIM}── injected context ─────────────────────────────────${RESET}"
say "${BOLD}## 2026-05-13 14:23 UTC | main | Refactor auth middleware${RESET}"
say "${DIM}- Files: src/middleware/auth.ts, src/__tests__/auth.test.ts${RESET}"
say "${DIM}- Decisions:${RESET}"
say "${DIM}  - keep the rate limiter unchanged${RESET}"
say "${DIM}  - bearer tokens validated against the existing in-memory store${RESET}"
say "${DIM}- Next:${RESET}"
say "${DIM}  - invalidate active cookie sessions in a migration before we ship${RESET}"
say "${DIM}─────────────────────────────────────────────────────${RESET}"
pause 1.2

say ""
say "${USER}>${RESET} What were we doing yesterday?"
pause 0.8

say ""
say "${ACCENT}● Picking up the auth-middleware refactor. You decided${RESET}"
say "${ACCENT}  to keep the rate limiter unchanged and validate bearer${RESET}"
say "${ACCENT}  tokens against the existing in-memory store. The next${RESET}"
say "${ACCENT}  blocker was invalidating active cookie sessions in a${RESET}"
say "${ACCENT}  migration before ship. Want me to draft that migration?${RESET}"
pause 2.5
