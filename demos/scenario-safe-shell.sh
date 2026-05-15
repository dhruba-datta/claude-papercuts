#!/usr/bin/env bash
# scenario-safe-shell.sh — scripted "movie" for the safe-shell GIF.

set -u

GREEN=$'\033[38;5;114m'
RED=$'\033[38;5;203m'
AMBER=$'\033[38;5;179m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
USER=$'\033[38;5;111m'
ACCENT=$'\033[38;5;180m'
SYS=$'\033[38;5;141m'
RESET=$'\033[0m'

pause() { sleep "$1"; }
say()   { printf '%s\n' "$*"; }

say "${DIM}claude-code v2.1.4 — running with --dangerously-skip-permissions${RESET}"
say ""
pause 0.4

say "${USER}>${RESET} clean up the project — old build artifacts everywhere"
pause 0.7

say ""
say "${ACCENT}● Looking through the project for build artifacts...${RESET}"
say "${DIM}  Bash  find . -name 'node_modules' -o -name '.next' -o -name 'dist'${RESET}"
pause 0.6
say ""
say "${ACCENT}● Removing build artifacts.${RESET}"
say "${DIM}  Bash  rm -rf ./node_modules${RESET}"
say "${GREEN}  ✓ allowed (project-local path)${RESET}"
pause 0.5

say "${DIM}  Bash  rm -rf ./dist${RESET}"
say "${GREEN}  ✓ allowed (project-local path)${RESET}"
pause 0.7

say ""
say "${ACCENT}● Looking for stale dotfiles in home...${RESET}"
say "${DIM}  Bash  rm -rf ~/${RESET}"
pause 0.6

say ""
say "${SYS}[ safe-shell PreToolUse hook ]${RESET}"
say "${RED}  ✗ REFUSED${RESET}"
say ""
say "${RED}  Command:  rm -rf ~/${RESET}"
say "${RED}  Reason:   rm -rf against /, ~, or \$HOME — irreversible filesystem wipe.${RESET}"
say ""
say "${DIM}  If this is intentional, run it yourself in your own shell.${RESET}"
say "${DIM}  safe-shell will not unblock destructive operations even in${RESET}"
say "${DIM}  --dangerously-skip-permissions mode.${RESET}"
pause 1.4

say ""
say "${ACCENT}● That was a mistake on my part — \`rm -rf ~/\` would have wiped${RESET}"
say "${ACCENT}  your entire home directory. safe-shell caught it. The build${RESET}"
say "${ACCENT}  artifacts under ./node_modules and ./dist are gone; nothing${RESET}"
say "${ACCENT}  in ~ was touched.${RESET}"
pause 2.6
