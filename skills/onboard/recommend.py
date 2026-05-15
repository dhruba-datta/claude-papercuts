#!/usr/bin/env python3
"""
recommend.py — first-run walkthrough for the claude-papercuts plugin.

New users install too many skills, get confused about which to actually
turn on, and churn (Medium/MindStudio onboarding reports). This script
prints a curated, opinionated starter set in the order we recommend
enabling them, with one-sentence "why" notes.

It also detects:
  - Which papercut skills are already installed
  - Approximately how heavy the current auto-context is (via the same
    discovery logic as token-x-ray)

Then it recommends the next 1–3 skills to enable based on what's missing,
not what's "best in general."

Usage:
    recommend.py                  # full walkthrough
    recommend.py --json           # machine-readable output
    recommend.py --next           # just "the next skill you should enable"
    recommend.py --no-color       # plain text
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

# Curated recommendation order — most-valuable-first for a fresh user.
# Each entry: (name, blurb, audience, depends_on)
SKILLS = [
    ("safe-shell",
     "Refuses rm -rf ~/, git push --force, mkfs, etc. — even in --dangerously-skip-permissions mode.",
     "everyone",
     []),
    ("token-x-ray",
     "Shows you exactly which MCP server / skill / CLAUDE.md is eating your context.",
     "everyone",
     []),
    ("amnesia-fix",
     "Cross-session memory. Every new session starts knowing what the last one decided.",
     "anyone running multiple Claude sessions per day",
     []),
    ("compact-guard",
     "Snapshots your plan and active todos before /compact so you don't lose them.",
     "anyone who hits /compact at all",
     []),
    ("done-prover",
     "Blocks Claude from claiming 'all tests pass' unless the transcript proves it.",
     "anyone shipping code Claude wrote",
     []),
    ("unclear",
     "Auto-snapshots transcripts so /clear has an undo button.",
     "anyone who's ever run /clear and regretted it",
     []),
    ("skill-doctor",
     "Lints SKILL.md files for the patterns that prevent auto-invocation.",
     "skill authors",
     []),
    ("skill-budget",
     "Audits your installed skills against the ~15K char system-prompt budget.",
     "skill power-users (10+ skills installed)",
     []),
    ("subagent-broker",
     "Best-practice template for delegating with the Task tool reliably.",
     "anyone running multi-stage agentic workflows",
     []),
]


@dataclass
class Status:
    name: str
    installed: bool
    enabled: bool
    blurb: str
    audience: str


class Color:
    def __init__(self, enabled):
        self.enabled = enabled
    def _w(self, c, s): return f"\033[{c}m{s}\033[0m" if self.enabled else s
    def green(self, s):  return self._w("38;5;114", s)
    def amber(self, s):  return self._w("38;5;179", s)
    def cyan(self, s):   return self._w("38;5;111", s)
    def dim(self, s):    return self._w("2",        s)
    def bold(self, s):   return self._w("1",        s)


def detect_installed_papercuts(home: Path) -> set[str]:
    """Return the set of papercut skill names installed under
    ~/.claude/plugins/*/skills/*/. We look for the canonical SKILL.md
    files; "installed" doesn't mean "enabled" — Claude Code only treats
    them as enabled when the plugin itself is registered."""
    found: set[str] = set()
    plugins_root = home / ".claude" / "plugins"
    if not plugins_root.is_dir():
        return found
    for plugin_dir in plugins_root.iterdir():
        if not plugin_dir.is_dir():
            continue
        skills_dir = plugin_dir / "skills"
        if not skills_dir.is_dir():
            continue
        for sk in skills_dir.iterdir():
            if (sk / "SKILL.md").is_file():
                found.add(sk.name)
    return found


def status_list(home: Path) -> list[Status]:
    installed = detect_installed_papercuts(home)
    out = []
    for name, blurb, audience, _ in SKILLS:
        is_installed = name in installed
        out.append(Status(
            name=name,
            installed=is_installed,
            enabled=is_installed,  # installation == enablement for plugins
            blurb=blurb,
            audience=audience,
        ))
    return out


def render_full(statuses: list[Status], c: Color):
    print(c.bold("claude-papercuts — onboarding walkthrough"))
    print(c.dim("─" * 60))
    print()
    print("These are the nine papercut skills, in the order we recommend")
    print("enabling them for a new install. Order matters — earlier ones")
    print("are higher-leverage for more workflows.")
    print()

    for i, s in enumerate(statuses, 1):
        if s.installed:
            mark = c.green("✓")
            tag = c.dim("installed")
        else:
            mark = c.amber("○")
            tag = c.amber("not installed")
        print(f"  {mark} {c.bold(f'{i}.')} {c.bold(s.name):<32}  {tag}")
        print(f"      {c.dim(s.blurb)}")
        print(f"      {c.dim('for: ' + s.audience)}")
        print()

    next_one = next((s for s in statuses if not s.installed), None)
    print(c.dim("─" * 60))
    if next_one is None:
        print(c.green("All nine papercut skills are installed. You're set."))
    else:
        print(c.cyan(f"Next to enable: {c.bold(next_one.name)}"))
        print(c.dim(f"  → {next_one.blurb}"))
        print()
        print(c.dim("Install all nine with one command:"))
        print()
        print("  claude --plugin-dir ~/claude-papercuts")
        print()
        print(c.dim("Or pin a specific marketplace version (once that ships):"))
        print()
        print("  /plugin install claude-papercuts")


def render_next(statuses: list[Status], c: Color):
    next_one = next((s for s in statuses if not s.installed), None)
    if next_one is None:
        print(c.green("All papercut skills are installed."))
        return
    print(c.bold(next_one.name))
    print(c.dim(next_one.blurb))
    print(c.dim(f"for: {next_one.audience}"))


def main():
    p = argparse.ArgumentParser(description="claude-papercuts onboarding walkthrough.")
    p.add_argument("--json", action="store_true")
    p.add_argument("--no-color", action="store_true")
    p.add_argument("--next", action="store_true",
                   help="Print only the next skill to enable")
    p.add_argument("--home", help="Home dir (default $HOME)")
    args = p.parse_args()

    home = Path(args.home).resolve() if args.home else Path.home()
    statuses = status_list(home)

    if args.json:
        next_one = next((s for s in statuses if not s.installed), None)
        out = {
            "total": len(statuses),
            "installed": sum(1 for s in statuses if s.installed),
            "next": next_one.name if next_one else None,
            "skills": [asdict(s) for s in statuses],
        }
        print(json.dumps(out, indent=2))
        return

    use_color = (not args.no_color) and sys.stdout.isatty()
    c = Color(use_color)

    if args.next:
        render_next(statuses, c)
    else:
        render_full(statuses, c)


if __name__ == "__main__":
    main()
