#!/usr/bin/env bash
# Decides whether a git command would skip git's hooks. Sourced by the PreToolUse hook
# (scripts/block-no-verify.sh) and the git wrapper (bin/git), so both refuse the same commands.
# Each function only reads its arguments: it prints why to stdout and returns 0 when the command
# skips hooks, and prints nothing and returns 1 when it doesn't. They use only bash's builtins, so
# the wrapper works on any PATH.

# names_hooks_path setting: whether a -c or --config-env setting (key=value, or key alone) is
# core.hooksPath, in any case, as git's config section and key names ignore case.
names_hooks_path() {
    case ${1%%=*} in
        [Cc][Oo][Rr][Ee].[Hh][Oo][Oo][Kk][Ss][Pp][Aa][Tt][Hh]) return 0 ;;
        *) return 1 ;;
    esac
}

# commit_skips_hooks args…: whether git commit's arguments include -n, alone or in a cluster of
# short options (-an). A short option that takes a value ends the cluster, and takes the next
# argument when the cluster ends with it.
commit_skips_hooks() {
    local arg letters letter skip_next=false
    for arg in "$@"; do
        if [ "$skip_next" = true ]; then
            skip_next=false
            continue
        fi
        case $arg in
            --) return 1 ;;
            --message | --file | --reuse-message | --reedit-message | --template | --author | --date \
                | --fixup | --squash | --trailer | --cleanup | --pathspec-from-file)
                skip_next=true
                ;;
            --*) ;;
            -?*)
                letters=${arg#-}
                while [ -n "$letters" ]; do
                    letter=${letters:0:1}
                    letters=${letters:1}
                    case $letter in
                        n)
                            echo "git commit -n, which is --no-verify,"
                            return 0
                            ;;
                        m | F | c | C | t)
                            [ -z "$letters" ] && skip_next=true
                            break
                            ;;
                        S | u) break ;;
                    esac
                done
                ;;
        esac
    done
    return 1
}

# config_skips_hooks args…: whether git config's arguments change core.hooksPath. Reading it passes.
config_skips_hooks() {
    local arg names=false
    for arg in "$@"; do
        case $arg in
            --get | --get-all | --get-regexp | --list | -l | get | list) return 1 ;;
        esac
        names_hooks_path "$arg" && [ "$arg" = "${arg%%=*}" ] && names=true
    done
    if [ "$names" = true ]; then
        echo "git config changing core.hooksPath"
        return 0
    fi
    return 1
}

# git_skips_hooks args…: whether git, run with these arguments (the words after `git`), skips hooks.
git_skips_hooks() {
    local arg
    for arg in "$@"; do
        case $arg in
            # Git takes any unambiguous prefix of a long option, and an alias can hide one in its value.
            *--no-veri*)
                echo "--no-verify"
                return 0
                ;;
        esac
    done
    # Git's own options come before the command.
    while [ $# -gt 0 ]; do
        case $1 in
            -c | --config-env)
                if names_hooks_path "${2:-}"; then
                    echo "git $1 core.hooksPath"
                    return 0
                fi
                shift 2
                ;;
            -c* | --config-env=*)
                arg=${1#-c}
                arg=${arg#--config-env=}
                if names_hooks_path "$arg"; then
                    echo "git -c core.hooksPath"
                    return 0
                fi
                shift
                ;;
            -C | --git-dir | --work-tree | --namespace | --super-prefix) shift 2 ;;
            -*) shift ;;
            *) break ;;
        esac
    done
    [ $# -gt 0 ] || return 1
    local command=$1
    shift
    case $command in
        commit) commit_skips_hooks "$@" ;;
        config) config_skips_hooks "$@" ;;
        *) return 1 ;;
    esac
}

# env_skips_hooks husky config_parameters config_key…: whether the environment git runs in skips
# hooks: HUSKY=0, which husky's hooks obey, or core.hooksPath set through GIT_CONFIG_PARAMETERS or
# a GIT_CONFIG_KEY_<n>.
env_skips_hooks() {
    local husky=$1 parameters=$2 key
    shift 2
    if [ "$husky" = 0 ]; then
        echo "HUSKY=0"
        return 0
    fi
    # Git quotes each key: 'core.hooksPath'='…'. The pattern is names_hooks_path's.
    case $parameters in
        *\'[Cc][Oo][Rr][Ee].[Hh][Oo][Oo][Kk][Ss][Pp][Aa][Tt][Hh]\'*)
            echo "core.hooksPath in GIT_CONFIG_PARAMETERS"
            return 0
            ;;
    esac
    for key in "$@"; do
        if names_hooks_path "$key"; then
            echo "core.hooksPath in a GIT_CONFIG_KEY_<n>"
            return 0
        fi
    done
    return 1
}
