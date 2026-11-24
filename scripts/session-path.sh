#!/usr/bin/env bash
# SessionStart hook. It puts bin/, which holds the git wrapper, first on the PATH of every Bash
# command Claude runs in the session, by writing an export to the file Claude Code names in
# CLAUDE_ENV_FILE. The user's own shells are unaffected. Without CLAUDE_ENV_FILE it can't, so it
# says so (exit 1) rather than leave git unwrapped silently.

bin=$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)

if [ -z "${CLAUDE_ENV_FILE:-}" ]; then
    echo "block-no-verify: CLAUDE_ENV_FILE is not set, so the git wrapper is not on Claude's PATH" >&2
    exit 1
fi

line="export PATH=\"$bin:\$PATH\""
# SessionStart runs again on resume and after compaction; one export is enough.
grep --quiet --fixed-strings --line-regexp -- "$line" "$CLAUDE_ENV_FILE" 2>/dev/null \
    || printf '%s\n' "$line" >>"$CLAUDE_ENV_FILE"
exit 0
