#!/usr/bin/env bash
# PreToolUse hook for Bash. It blocks git commands that skip git's hooks: --no-verify, git commit -n,
# core.hooksPath set with -c or git config, and HUSKY=0 or core.hooksPath set through git's config
# environment variables. scripts/skips-hooks.sh decides; bin/git, the wrapper on Claude's PATH,
# applies the same decision to git run from scripts this hook can't see into.
# Exit 2 blocks the tool call and shows stderr to Claude. Without jq it can't read the call, so
# it lets it through with a visible error (exit 1) rather than block every call.

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/skips-hooks.sh
. "$here/skips-hooks.sh"

jq=$(command -v jq || echo /usr/bin/jq)
if [ ! -x "$jq" ]; then
    echo "block-no-verify: jq not found, so git commands that skip hooks are not being checked" >&2
    exit 1
fi

cmd=$("$jq" --raw-output '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

block() {
    echo "Blocked: $1 skips git's hooks. Don't skip them: fix what the hook reports, or if the hook is wrong, ask the user. A commit message that mentions --no-verify goes in a file passed with -F." >&2
    exit 2
}

# The command's words, with the quotes, brackets and $( a word can start with removed, so a git
# inside $(…), "…" or a subshell still counts.
while IFS= read -r seg; do
    read -r -a words <<<"$seg"
    i=0
    for word in "${words[@]}"; do
        i=$((i + 1))
        case $word in
            export) continue ;;
            HUSKY=0 | GIT_CONFIG_PARAMETERS=* | GIT_CONFIG_COUNT=* | GIT_CONFIG_KEY_*=*)
                block "setting ${word%%=*}"
                ;;
        esac
        while true; do
            case $word in
                [\"\'\`\(\$]*) word=${word:1} ;;
                *) break ;;
            esac
        done
        [ "${word##*/}" = git ] || continue
        if reason=$(git_skips_hooks "${words[@]:i}"); then
            block "$reason"
        fi
    done
done < <(printf '%s\n' "$cmd" | tr ';&|' '\n')

exit 0
