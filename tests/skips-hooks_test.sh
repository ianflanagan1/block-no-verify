#!/bin/sh
# Behaviour of scripts/skips-hooks.sh. Run with `devbox run -- task test`.

root=${ROOT:?run the tests with devbox run -- task test}
lib=$root/scripts/skips-hooks.sh

# skips args…: whether git with these arguments skips hooks, by git_skips_hooks.
skips() {
    bash -c '. "$0"; git_skips_hooks "$@"' "$lib" "$@" >/dev/null
}

assertSkips() {
    skips "$@"
    assertEquals "should skip hooks: git $*" 0 $?
}

assertKeeps() {
    skips "$@"
    assertEquals "should keep hooks: git $*" 1 $?
}

# env_skips husky parameters keys…: whether that environment skips hooks, by env_skips_hooks.
env_skips() {
    bash -c '. "$0"; env_skips_hooks "$@"' "$lib" "$@" >/dev/null
}

test_no_verify_skips_hooks_on_any_command_and_in_any_position() {
    assertSkips commit --no-verify -m x
    assertSkips commit -m x --no-verify
    assertSkips push --no-verify
    assertSkips merge --no-verify topic
    assertSkips -C /tmp/repo rebase --no-verify main
}

test_an_abbreviated_no_verify_skips_hooks() {
    assertSkips commit --no-verif -m x
    assertSkips push --no-veri
}

test_an_alias_that_holds_no_verify_skips_hooks() {
    assertSkips -c 'alias.c=commit --no-verify' c -m x
    assertSkips config alias.c 'commit --no-verify'
}

test_commit_n_skips_hooks_alone_or_in_a_cluster() {
    assertSkips commit -n -m x
    assertSkips commit -an -m x
    assertSkips commit -anm x
    assertSkips -C /tmp/repo commit -n
}

test_an_n_that_is_an_options_value_keeps_hooks() {
    assertKeeps commit -m -n
    assertKeeps commit -mn
    assertKeeps commit --message -n
    assertKeeps commit -am -n
    assertKeeps commit -- -n
}

test_n_on_other_commands_keeps_hooks() {
    assertKeeps push -n
    assertKeeps merge -n topic
    assertKeeps clean -n
}

test_setting_hooks_path_for_one_command_skips_hooks() {
    assertSkips -c core.hooksPath=/dev/null commit -m x
    assertSkips -c core.hookspath=/dev/null commit -m x
    assertSkips -ccore.hooksPath=/dev/null push
    assertSkips --config-env core.hooksPath=EMPTY commit -m x
    assertSkips --config-env=core.hooksPath=EMPTY commit -m x
}

test_other_settings_for_one_command_keep_hooks() {
    assertKeeps -c user.name=x commit -m x
    assertKeeps -c core.hooksPathless=x status
}

test_changing_hooks_path_with_git_config_skips_hooks() {
    assertSkips config core.hooksPath /dev/null
    assertSkips config --global core.hooksPath /dev/null
    assertSkips config --unset core.hooksPath
    assertSkips config set core.hooksPath /dev/null
}

test_reading_hooks_path_keeps_hooks() {
    assertKeeps config --get core.hooksPath
    assertKeeps config get core.hooksPath
    assertKeeps config --list
}

test_ordinary_commands_keep_hooks() {
    assertKeeps commit -m 'Add a feature'
    assertKeeps commit -F message.txt
    assertKeeps push origin main
    assertKeeps status
    assertKeeps
}

test_a_skipping_command_says_why() {
    reason=$(bash -c '. "$0"; git_skips_hooks "$@"' "$lib" commit -n)
    assertContains "$reason" 'git commit -n'
}

test_husky_off_skips_hooks() {
    env_skips 0 ''
    assertEquals 0 $?
    env_skips 1 ''
    assertEquals 1 $?
}

test_hooks_path_in_git_config_variables_skips_hooks() {
    env_skips '' "'core.hooksPath'='/dev/null'"
    assertEquals 'GIT_CONFIG_PARAMETERS' 0 $?
    env_skips '' '' user.name core.hooksPath
    assertEquals 'GIT_CONFIG_KEY_<n>' 0 $?
}

test_an_ordinary_environment_keeps_hooks() {
    env_skips '' "'user.name'='x'" user.email
    assertEquals 1 $?
}
