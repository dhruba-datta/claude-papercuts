#!/usr/bin/env bash
# scenario-onboard.sh — scripted "movie" for the onboard GIF.

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

say "${DIM}claude-code v2.1.4 — fresh install of claude-papercuts${RESET}"
say ""
pause 0.3

say "${USER}>${RESET} I just installed claude-papercuts. Where do I start?"
pause 0.7

say ""
say "${USER}>${RESET} /claude-papercuts:onboard"
pause 0.8

say ""
say "${ACCENT}● Running onboarding walkthrough...${RESET}"
pause 0.6

say ""
say "${BOLD}claude-papercuts — onboarding walkthrough${RESET}"
say "${DIM}────────────────────────────────────────────────────────────${RESET}"
say ""
say "These are the nine papercut skills, in the order we recommend"
say "enabling them for a new install. Order matters — earlier ones"
say "are higher-leverage for more workflows."
say ""
pause 0.4

say "  ${GREEN}✓${RESET} ${BOLD}1.${RESET} ${BOLD}safe-shell${RESET}                        ${DIM}installed${RESET}"
say "      ${DIM}Refuses rm -rf ~/, git push --force, mkfs, etc.${RESET}"
say "      ${DIM}for: everyone${RESET}"
say ""
say "  ${GREEN}✓${RESET} ${BOLD}2.${RESET} ${BOLD}token-x-ray${RESET}                       ${DIM}installed${RESET}"
say "      ${DIM}Shows you exactly which MCP server / skill / CLAUDE.md is eating your context.${RESET}"
say "      ${DIM}for: everyone${RESET}"
say ""
say "  ${AMBER}○${RESET} ${BOLD}3.${RESET} ${BOLD}amnesia-fix${RESET}                       ${AMBER}not installed${RESET}"
say "      ${DIM}Cross-session memory. Every new session starts knowing what the last one decided.${RESET}"
say "      ${DIM}for: anyone running multiple Claude sessions per day${RESET}"
say ""
say "  ${AMBER}○${RESET} ${BOLD}4.${RESET} ${BOLD}compact-guard${RESET}                     ${AMBER}not installed${RESET}"
say "      ${DIM}Snapshots your plan and active todos before /compact so you don't lose them.${RESET}"
say "      ${DIM}for: anyone who hits /compact at all${RESET}"
say ""
say "  ${DIM}... 5 more (done-prover, unclear, skill-doctor, skill-budget, subagent-broker)${RESET}"
say ""
say "${DIM}────────────────────────────────────────────────────────────${RESET}"
say "${CYAN}Next to enable: ${BOLD}amnesia-fix${RESET}"
say "${DIM}  → Cross-session memory. Every new session starts knowing what the last one decided.${RESET}"
pause 1.5

say ""
say "${USER}>${RESET} I run ~3 Claude sessions a day and rarely /clear. What do I really need?"
pause 0.8

say ""
say "${ACCENT}● Given that workflow, enable in this order:${RESET}"
say "${ACCENT}  1. amnesia-fix     — you'll feel it within the first week${RESET}"
say "${ACCENT}  2. compact-guard   — auto-compact will eventually catch you${RESET}"
say "${ACCENT}  3. done-prover     — if you ship code Claude writes${RESET}"
say ""
say "${ACCENT}  Skip ${BOLD}unclear${RESET}${ACCENT} for now (you said you rarely /clear).${RESET}"
say "${ACCENT}  Revisit ${BOLD}skill-doctor${RESET}${ACCENT} only if you start writing SKILL.md files.${RESET}"
pause 3.0
