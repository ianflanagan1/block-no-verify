#!/bin/sh
# Behaviour of scripts/block-no-verify.sh. Run with `devbox run -- task test`.

root=${ROOT:?run the tests with devbox run -- task test}
hook=$root/scripts/block-no-verify.sh

# run command: the hook's exit status for the Bash tool running command.
run() {
    jq --null-input --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}' \
        | bash "$hook" 2>/dev/null
}

assertBlocked() {
    run "$1"
    assertEquals "should block: $1" 2 $?
}

assertAllowed() {
    run "$1"
    assertEquals "should allow: $1" 0 $?
}

test_git_commands_that_skip_hooks_are_blocked() {
    assertBlocked 'git commit --no-verify -m x'
    assertBlocked 'git commit -n -m x'
    assertBlocked 'git push --no-verify'
    assertBlocked 'git -c core.hooksPath=/dev/null commit -m x'
    assertBlocked 'git config core.hooksPath /dev/null'
}

test_git_is_found_wherever_the_command_runs_it() {
    assertBlocked 'cd repo && git commit -n -m x'
    assertBlocked 'make || git push --no-verify'
    assertBlocked '/usr/bin/git commit -n -m x'
    assertBlocked 'devbox run -- git commit -n -m x'
    assertBlocked "echo \"\$(git commit -n -m x)\""
    assertBlocked 'git rebase main --exec "git commit --amend -n --no-edit"'
}

test_setting_variables_that_skip_hooks_is_blocked() {
    assertBlocked 'HUSKY=0 git commit -m x'
    assertBlocked 'export HUSKY=0'
    assertBlocked "GIT_CONFIG_PARAMETERS=\"'core.hooksPath'='/dev/null'\" git commit -m x"
    assertBlocked 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null git push'
}

test_git_commands_that_keep_hooks_are_allowed() {
    assertAllowed 'git commit -m x'
    assertAllowed 'git commit -F /tmp/message'
    assertAllowed 'git push -n'
    assertAllowed 'git config --get core.hooksPath'
    assertAllowed 'HUSKY=1 git commit -m x'
}

test_commands_that_only_mention_git_are_allowed() {
    assertAllowed 'grep -rn digit src'
    assertAllowed 'ls ~/.gitconfig'
}

test_a_blocked_command_tells_claude_not_to_skip_hooks_and_to_ask() {
    reason=$(jq --null-input '{tool_name:"Bash",tool_input:{command:"git commit -n -m x"}}' | bash "$hook" 2>&1 >/dev/null)
    assertContains "$reason" 'git commit -n'
    assertContains "$reason" 'ask the user'
    assertContains "$reason" '-F'
}

test_input_without_a_command_is_allowed() {
    printf '{"tool_name":"Bash","tool_input":{}}' | bash "$hook" 2>/dev/null
    assertEquals 0 $?
}
