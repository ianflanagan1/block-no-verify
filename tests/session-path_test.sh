#!/bin/sh
# Behaviour of scripts/session-path.sh. Run with `devbox run -- task test`.

root=${ROOT:?run the tests with devbox run -- task test}
script=$root/scripts/session-path.sh

setUp() {
    env_file=$SHUNIT_TMPDIR/env
    : >"$env_file"
}

test_it_puts_the_wrapper_first_on_the_sessions_path() {
    CLAUDE_ENV_FILE=$env_file bash "$script"
    assertEquals 0 $?
    path=$(env -i PATH=/usr/bin:/bin sh -c ". \"$env_file\"; printf %s \"\$PATH\"")
    assertEquals "$root/bin:/usr/bin:/bin" "$path"
}

test_running_again_adds_nothing() {
    CLAUDE_ENV_FILE=$env_file bash "$script"
    CLAUDE_ENV_FILE=$env_file bash "$script"
    assertEquals 1 "$(wc -l <"$env_file" | tr -d ' ')"
}

test_it_keeps_what_other_hooks_wrote() {
    echo 'export OTHER=1' >"$env_file"
    CLAUDE_ENV_FILE=$env_file bash "$script"
    assertContains "$(cat "$env_file")" 'export OTHER=1'
}

test_without_an_env_file_it_says_so() {
    output=$(env -u CLAUDE_ENV_FILE bash "$script" 2>&1)
    assertEquals 1 $?
    assertContains "$output" 'CLAUDE_ENV_FILE'
}
