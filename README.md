# block-no-verify

Stops Claude Code skipping git's hooks, so a `commit-msg` or `pre-push` hook always gets its say over what Claude commits and pushes.

## What it blocks

A git command that would skip its hooks:

- `--no-verify` on any git command, or any abbreviation of it git accepts (`--no-verif`), or inside an alias's value
- `git commit -n`, alone or in a cluster (`-an`), but not an `-n` that is an option's value (`-m -n`) or on another command (`git push -n` is `--dry-run`)
- `core.hooksPath` set for one command (`git -c core.hooksPath=… commit`, `--config-env`), or changed with `git config`; reading it passes
- `HUSKY=0`, or `core.hooksPath` set through `GIT_CONFIG_PARAMETERS` or `GIT_CONFIG_KEY_<n>`

`scripts/skips-hooks.sh` decides, and two layers apply its decision:

- **The PreToolUse hook** (`scripts/block-no-verify.sh`) reads every Bash command Claude is about to run and refuses it (exit 2) when any `git` in it, by name or full path, in a chain, a subshell or `$(…)`, or under `devbox run`, skips hooks. The refusal tells Claude to fix what the hook reports, or ask you.
- **The git wrapper** (`bin/git`) is first on the PATH of every command Claude runs, so it also sees git run from a script or a program, which the hook only sees the name of. It refuses (exit 1) a command that skips hooks and otherwise runs the next `git` on PATH with the same arguments. It uses only bash's builtins before that, and adds about 10 ms to a git call.
- **The SessionStart hook** (`scripts/session-path.sh`) puts `bin/` first on that PATH, by writing an export to the file Claude Code names in `CLAUDE_ENV_FILE`. Your own shells are unaffected.

Like block-global-installs, the hook can't tell a quoted string from a command, so `git commit -m "explain --no-verify"` is refused too; put such a message in a file and commit with `-F`.

What it doesn't stop: git run by its full path from a script (the wrapper is skipped, and the hook only sees the script), a devbox environment whose own `git` comes before the wrapper on PATH, and settings that hide global config from git (`GIT_CONFIG_GLOBAL`, `HOME`). The hooks it protects are the guarantee; this stops Claude's habit of skipping them.

The hook needs `jq`. Without it the hook lets every call through and reports an error on each one, so a missing `jq` is visible rather than silently unchecked; the wrapper still works.

## Install

Clone to `~/projects/claude/block-no-verify`, then add both hooks to `~/.claude/settings.json`. They run straight from the clone, so changes apply from the next command (the PATH from the next session):

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash \"$HOME/projects/claude/block-no-verify/scripts/block-no-verify.sh\""
        }
      ]
    }
  ],
  "SessionStart": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "bash \"$HOME/projects/claude/block-no-verify/scripts/session-path.sh\""
        }
      ]
    }
  ]
}
```

## Development

```sh
devbox run -- task test        # shunit2
devbox run -- task lint        # shellcheck
devbox run -- task check       # lint, then test, failing on any problem
devbox run -- task lint-file -- <files>
```
