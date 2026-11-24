`devbox run -- task check` lints and tests, and fails on any problem. `devbox run -- task lint-file -- <files>` runs ShellCheck on just the files given.

`scripts/skips-hooks.sh` holds the one decision both the hook and `bin/git` apply; change what is blocked there, never in either of them. Everything `bin/git` runs before it execs the real git must be a bash builtin, and work in bash 3.2, since it runs on whatever PATH and bash a command has. The tests run through `task test`, which passes the repository root as `ROOT`.
