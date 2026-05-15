#!/usr/bin/env python3
"""
templates.py — battle-tested Task-tool delegation templates.

Issues anthropics/claude-code#4182, #5528, and #19077 report that
sub-agent delegation is unreliable: subagents ignore CRITICAL
directives, lose the tool inventory advertised in their config, and
generally produce shallow output unless their prompt is structured
in a specific way.

This script ships the prompt templates that *do* work — distilled
from the issue threads and our own delegation experiments. Each
template is a Task-tool prompt skeleton with the load-bearing parts
called out.

Usage:
    templates.py                  # list every template (name + one-liner)
    templates.py <name>           # print one template, ready to paste
    templates.py --json           # machine-readable list
    templates.py --search KEYWORD # filter by keyword in name or use-case
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, asdict


@dataclass
class Template:
    name: str
    use_case: str  # one-line "when to use this"
    pitfall: str   # the failure mode this avoids
    body: str      # the actual delegation prompt template


TEMPLATES: list[Template] = [
    Template(
        name="parallel-search",
        use_case="Spawning N independent searches at once (e.g. find all callers across a monorepo)",
        pitfall=(
            "Sequential bash greps are slow; serial agents inflate cost. "
            "Parallel delegation only works if each subagent's prompt is "
            "self-contained — they cannot see each other's results."
        ),
        body=(
            "Use the Task tool to spawn N subagents in PARALLEL. Each "
            "should be given a SELF-CONTAINED prompt — they cannot share "
            "state. Each subagent gets:\n"
            "  - subagent_type: 'general-purpose' (or 'Explore' for "
            "    read-only searches)\n"
            "  - description: 3-5 word task summary\n"
            "  - prompt: a complete brief stating:\n"
            "      * what to find (be specific: regex, file glob)\n"
            "      * where to look (paths, exclusions)\n"
            "      * what to report back (format, max length)\n"
            "      * how to handle 'not found' (return empty list, not error)\n"
            "\n"
            "Example call for one of N parallel agents:\n"
            "  Task({\n"
            "    subagent_type: 'Explore',\n"
            "    description: 'Find auth-middleware callers',\n"
            "    prompt: 'Find every file that imports or calls "
            "authMiddleware from src/middleware/auth.ts. Search "
            "src/**/*.{ts,tsx,js,jsx}. Return up to 50 file paths, "
            "one per line, no prose. If none found, return the string "
            "\"NONE\".'\n"
            "  })\n"
            "\n"
            "Make all N Task calls in a SINGLE message to run them in "
            "parallel — sequential tool calls run sequentially.\n"
        ),
    ),
    Template(
        name="single-research",
        use_case="One deep research task that's noisy in the main context (long file reads, many greps)",
        pitfall=(
            "Without an explicit response-format directive, subagents "
            "return verbose prose. Without a length cap, they exhaust "
            "tokens reading every file they find."
        ),
        body=(
            "Use the Task tool to delegate one open-ended research "
            "question. The subagent will burn through file reads and "
            "grep calls in its own context, then return a structured "
            "report to ours. Cap the report length explicitly.\n"
            "\n"
            "Task({\n"
            "  subagent_type: 'general-purpose',\n"
            "  description: 'Audit X for Y',\n"
            "  prompt: 'Investigate <question>. Background context: "
            "<2–3 sentences of what we already know and what we've "
            "ruled out>. Return a report with: (1) answer in 1 "
            "sentence; (2) up to 3 supporting file paths with "
            "line numbers; (3) up to 2 follow-ups we did not check. "
            "Total under 200 words. Do not paste large code blocks.'\n"
            "})\n"
        ),
    ),
    Template(
        name="cross-file-audit",
        use_case="Reviewing a change for consistency across the codebase (style, imports, conventions)",
        pitfall=(
            "Issue #5528: subagents ignore 'CRITICAL' directives. "
            "Front-loading the most important rule in the prompt body "
            "and re-asserting it in the response-format section makes "
            "compliance significantly more reliable."
        ),
        body=(
            "Use the Task tool for an independent consistency review. "
            "Critical: state the single most-important constraint TWICE "
            "in the prompt — once near the top, once in the "
            "response-format section.\n"
            "\n"
            "Task({\n"
            "  subagent_type: 'code-reviewer',  # or 'general-purpose'\n"
            "  description: 'Cross-file consistency review',\n"
            "  prompt: 'Review <files> for <specific concern>. "
            "MUST CHECK: <single most-important rule, e.g. \"every "
            "async fn must have a corresponding _sync wrapper\">. "
            "Do not check unrelated style issues. Background: <2–3 "
            "sentences>. Return: (1) MUST CHECK rule — pass/fail "
            "with reason; (2) up to 5 other issues. Total under 150 "
            "words.'\n"
            "})\n"
        ),
    ),
    Template(
        name="known-target",
        use_case="When you already know the file/symbol — skip delegation, use Read or Grep directly",
        pitfall=(
            "Issue #4182: spawning a subagent for a known-target lookup "
            "burns context without benefit. The subagent does the same "
            "Read call you would have."
        ),
        body=(
            "DO NOT DELEGATE. Call Read or Grep directly.\n"
            "\n"
            "When to use a subagent: open-ended exploration where you "
            "don't know which files you need.\n"
            "When NOT to delegate:\n"
            "  - You have a specific file path → use Read\n"
            "  - You have a specific symbol/string → use Bash with grep "
            "    or the Grep tool\n"
            "  - The task is one tool call deep → just call it\n"
            "\n"
            "Cost rule of thumb: a subagent has ~5-10x the overhead "
            "of a direct tool call. Delegate when the subagent will "
            "make 3+ tool calls of its own.\n"
        ),
    ),
    Template(
        name="independent-verification",
        use_case="Getting a second opinion on a decision (don't tell the subagent your conclusion)",
        pitfall=(
            "If you brief the subagent with your existing analysis, "
            "they will anchor on it (sycophancy). Independent review "
            "requires withholding your conclusion."
        ),
        body=(
            "Use the Task tool for independent verification. CRITICAL: "
            "do NOT tell the subagent what you think the answer is. "
            "State the question, give them the same context the user "
            "has, and ask for their independent read.\n"
            "\n"
            "Task({\n"
            "  subagent_type: 'general-purpose',  # or 'code-reviewer'\n"
            "  description: 'Independent X review',\n"
            "  prompt: 'Review <artifact: file path, PR number, etc.>. "
            "Background: <neutral framing — what is being changed and "
            "why, with NO opinion on whether it's correct>. Question: "
            "<the specific question you want answered>. Do not assume "
            "any particular answer is correct. Return: (1) your answer "
            "in 1 sentence; (2) the strongest evidence for it; (3) the "
            "strongest evidence against it. Under 200 words.'\n"
            "})\n"
        ),
    ),
]


def find(name: str) -> Template | None:
    for t in TEMPLATES:
        if t.name == name:
            return t
    return None


def render_list():
    print("subagent-broker — Task-tool delegation templates")
    print("─" * 60)
    print()
    for t in TEMPLATES:
        print(f"  {t.name:<28}  {t.use_case}")
    print()
    print(f"Run: templates.py <name>   to print one ready to paste.")
    print(f"Run: templates.py --json   for machine-readable output.")


def render_one(t: Template):
    print(f"# {t.name}")
    print(f"# Use case: {t.use_case}")
    print(f"# Pitfall:  {t.pitfall}")
    print("# " + "─" * 58)
    print()
    print(t.body)


def main():
    p = argparse.ArgumentParser(description="Task delegation templates.")
    p.add_argument("name", nargs="?", help="Template name (omit to list all)")
    p.add_argument("--json", action="store_true")
    p.add_argument("--search", help="Filter templates by keyword in name or use-case")
    args = p.parse_args()

    matching = TEMPLATES
    if args.search:
        kw = args.search.lower()
        matching = [t for t in TEMPLATES
                    if kw in t.name.lower() or kw in t.use_case.lower()]

    if args.json:
        out = [asdict(t) for t in matching]
        print(json.dumps(out, indent=2))
        return

    if args.name:
        t = find(args.name)
        if not t:
            print(f"unknown template: {args.name}", file=sys.stderr)
            print("available:", ", ".join(t.name for t in TEMPLATES), file=sys.stderr)
            sys.exit(1)
        render_one(t)
        return

    if matching != TEMPLATES:
        # Filtered list
        for t in matching:
            print(f"  {t.name:<28}  {t.use_case}")
        return

    render_list()


if __name__ == "__main__":
    main()
