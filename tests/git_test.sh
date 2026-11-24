#!/bin/sh
# Behaviour of bin/git, the wrapper. Run with `devbox run -- task test`.

root=${ROOT:?run the tests with devbox run -- task test}

# A stand-in for the real git, after the wrapper on PATH, that prints its arguments.
setUp() {
    real=$SHUNIT_TMPDIR/real
    mkdir -p "$real"
    printf '#!/bin/sh\necho "real git $*"\n' >"$real/git"
    chmod +x "$real/git"
    # Bash alone, for a PATH that must hold no other git.
    shell=$SHUNIT_TMPDIR/shell
    mkdir -p "$shell"
    ln -sf "$(command -v bash)" "$shell/bash"
}

# wrapped args…: the wrapper run with these arguments, with only the wrapper and the stand-in on PATH.
wrapped() {
    env -u HUSKY -u GIT_CONFIG_PARAMETERS PATH="$root/bin:$real:/usr/bin:/bin" git "$@"
}

test_a_command_that_keeps_hooks_runs_the_next_git_on_path_with_the_same_arguments() {
    output=$(wrapped commit -m 'two words' 2>&1)
    assertEquals 0 $?
    assertEquals 'real git commit -m two words' "$output"
}

test_a_command_that_skips_hooks_is_refused_without_running_git() {
    output=$(wrapped commit -n -m x 2>&1)
    assertEquals 1 $?
    assertNotContains "$output" 'real git'
    assertContains "$output" 'git commit -n'
}

test_no_verify_from_a_script_is_refused() {
    printf '#!/bin/sh\ngit push --no-verify\n' >"$SHUNIT_TMPDIR/script.sh"
    output=$(env PATH="$root/bin:$real:/usr/bin:/bin" sh "$SHUNIT_TMPDIR/script.sh" 2>&1)
    assertEquals 1 $?
    assertNotContains "$output" 'real git'
}

test_an_environment_that_skips_hooks_is_refused() {
    HUSKY=0 PATH="$root/bin:$real:/usr/bin:/bin" git commit -m x >/dev/null 2>&1
    assertEquals 'HUSKY=0' 1 $?
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null \
        PATH="$root/bin:$real:/usr/bin:/bin" git commit -m x >/dev/null 2>&1
    assertEquals 'GIT_CONFIG_KEY_0' 1 $?
}

test_the_wrapper_listed_twice_on_path_still_reaches_the_real_git() {
    output=$(env PATH="$root/bin:$root/bin:$real:$shell" git status 2>&1)
    assertEquals 'real git status' "$output"
}

test_without_another_git_on_path_it_says_so() {
    output=$(env PATH="$root/bin:$shell" "$root/bin/git" status 2>&1)
    assertEquals 127 $?
    assertContains "$output" 'no git found'
}
