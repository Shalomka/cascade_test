#!/usr/bin/env python3
"""PreToolUse guardrail for the vgv-wingspan-auto run.

Deterministically BLOCKS the autonomous pipeline's hard boundaries regardless of
what any worker decides. Exit code 2 = block (stable convention); 0 = allow.
Reads the tool call as JSON on stdin: {tool_name, tool_input: {...}}.
"""
import json
import re
import sys


def block(msg: str) -> None:
    sys.stderr.write("\U0001F6D1 wingspan-guardrail: " + msg + "\n")
    sys.stderr.write(
        "   This run stops at a local unmerged branch; it must not merge, deploy, "
        "push to protected branches, or touch secrets/flags/CI/deploy config.\n"
    )
    sys.exit(2)


def main() -> None:
    try:
        d = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # unparseable -> don't block

    ti = d.get("tool_input", {}) or {}
    tool = d.get("tool_name") or ""
    cmd = ti.get("command") or ""
    path = ti.get("file_path") or ti.get("path") or ""
    low = cmd.lower()

    if tool == "Bash":
        dangerous = [
            (r"gh\s+pr\s+merge", "PR merge is not allowed"),
            (r"\bgit\s+merge\b", "branch merge is not allowed"),
            (r"git\s+push\b.*--force|git\s+push\s+-f\b|--force-with-lease",
             "force-push is not allowed"),
            (r"git\s+push\b.*\b(origin\s+)?(main|master)\b|push\b.*release/",
             "push to a protected branch is not allowed"),
            (r"firebase\s+deploy|gcloud\s+.*deploy|kubectl\s+apply|terraform\s+apply|"
             r"\bvercel\b|netlify\s+deploy|\bfastlane\b",
             "deploy commands are not allowed"),
        ]
        for pat, msg in dangerous:
            if re.search(pat, low):
                block(msg)
        if re.search(r">|>>|\btee\b|sed\s+-i|\bcp\b|\bmv\b|\btruncate\b", low):
            if re.search(
                r"\.env\b|secrets|feature[_-]?flag|/workflows/|dependabot|"
                r"firebase\.json|\.firebaserc|/deploy/|/infra/|dockerfile",
                low,
            ):
                block("shell write to a secrets/flag/CI/deploy/infra file is not allowed")

    if tool in ("Write", "Edit", "NotebookEdit"):
        p = path.lower()
        sensitive = [
            r"\.env$", r"\.env\.", r"secrets", r"feature[_-]?flag",
            r"/\.github/workflows/", r"dependabot", r"firebase\.json$",
            r"\.firebaserc$", r"/deploy/", r"/infra/", r"dockerfile$",
        ]
        for pat in sensitive:
            if re.search(pat, p):
                block("writing to a secrets/flag/CI/deploy/infra file is not allowed: " + path)

    sys.exit(0)


if __name__ == "__main__":
    main()
