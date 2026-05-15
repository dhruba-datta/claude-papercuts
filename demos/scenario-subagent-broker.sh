#!/usr/bin/env bash
# scenario-subagent-broker.sh — scripted "movie" for the subagent-broker GIF.

set -u

GREEN=$'\033[38;5;114m'
AMBER=$'\033[38;5;179m'
CYAN=$'\033[38;5;111m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
USER=$'\033[38;5;111m'
ACCENT=$'\033[38;5;180m'
RESET=$'\033[0m'

pause() { sleep "$1"; }
say()   { printf '%s\n' "$*"; }

say "${DIM}claude-code v2.1.4 — main agent, looking at a monorepo${RESET}"
say ""
pause 0.3

say "${USER}>${RESET} find every caller of authMiddleware — about 40 files, parallel?"
pause 0.7

say ""
say "${USER}>${RESET} /claude-papercuts:subagent-broker"
pause 0.6

say ""
say "${ACCENT}● Listing delegation templates...${RESET}"
pause 0.6

say ""
say "${BOLD}subagent-broker — Task-tool delegation templates${RESET}"
say "${DIM}────────────────────────────────────────────────────────────${RESET}"
say ""
say "  ${BOLD}parallel-search${RESET}               ${DIM}Spawning N independent searches at once${RESET}"
say "  ${BOLD}single-research${RESET}               ${DIM}One deep research task noisy in main context${RESET}"
say "  ${BOLD}cross-file-audit${RESET}              ${DIM}Consistency review across files${RESET}"
say "  ${BOLD}known-target${RESET}                  ${DIM}When you already know the file — don't delegate${RESET}"
say "  ${BOLD}independent-verification${RESET}      ${DIM}Second opinion without anchoring${RESET}"
say ""
pause 1.0

say "${ACCENT}● Your task fits ${BOLD}parallel-search${RESET}${ACCENT}.${RESET}"
pause 0.4

say ""
say "${DIM}────────────────────────────────────────────────────────────${RESET}"
say "${BOLD}# parallel-search${RESET}"
say "${DIM}# Spawning N independent searches at once${RESET}"
say "${DIM}# Pitfall: Parallel delegation only works if each subagent's prompt${RESET}"
say "${DIM}#          is self-contained — they cannot see each other's results.${RESET}"
say "${DIM}────────────────────────────────────────────────────────────${RESET}"
say ""
say "Use the Task tool to spawn N subagents in PARALLEL. Each should be"
say "given a SELF-CONTAINED prompt — they cannot share state."
say ""
say "Task({"
say "  subagent_type: 'Explore',"
say "  description: 'Find authMiddleware callers',"
say "  prompt: 'Find every file that imports or calls authMiddleware"
say "    from src/middleware/auth.ts. Search src/**/*.{ts,tsx,js,jsx}."
say "    Return up to 50 file paths, one per line, no prose."
say "    If none found, return the string \"NONE\".'"
say "})"
say ""
say "${AMBER}Make all N Task calls in a SINGLE message to run them in parallel —"
say "sequential tool calls run sequentially.${RESET}"
pause 3.0
