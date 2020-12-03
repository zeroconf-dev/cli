#!/bin/bash
# Copyright 2020 ZeroConf OSS. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Only define the zc functino if it is called directly
# or if the invocation if zc is nested due to local copy invocation,
# or if there is no zc excutable in PATH.
if [[ $_ZC_LOCAL_INVOKE || "$(realpath "$0")" = "$(realpath "${BASH_SOURCE[0]}")" ]] || ! type -P zc &> /dev/null; then
zc() {
    if [ -z "$1" ]; then
        printf -- 'Usage: zc TASK [ TASKARGS... ]\n' >&2
        return 1
    fi

    if [ "$1" = '--install' ]; then
        local install_cmd=() prefix=${2:-/usr/local/bin}

        # Prepend sudo to the command in case
        # of non root user is invoking install.
        if (( "$(id -u)" != 0 )); then
            install_cmd+=( "sudo" )
        fi

        if [[ -d "$prefix" ]]; then
            install_cmd+=( "cp" "${BASH_SOURCE[0]}" "$prefix/zc" )
        else
            printf 'Could not install zc in PREFIX %s
It must be a writable target directory\n' "$prefix" >&2
            return 1
        fi

        if (
            set -e
            "${install_cmd[@]}"
        ); then
            # Unset the function definition after successful installation.
            unset zc
            return 0
        else
            printf -- 'Could not install zc in PREFIX %s\n' "$prefix" >&2
            return 1
        fi
    fi

    find_project_root() {
        local path
        path="$(pwd)"
        while [ "$path" != '/' ] ; do
            if [[ -d "$path/.git" || -f "$path/.env" || -f "$path/package.json" ]]; then
                printf -- '%s' "$path"
                return 0
            fi
            path="$(dirname "$path")"
        done
        return 1
    }

    find_tasks() {
        local maxdepth=${ZC_BIN_PATH_RECURSE:-false} perm task_name=$1 unamestr

        unamestr=$(uname)
        if [[ $unamestr == 'Darwin' || $unamestr == 'FreeBSD' ]]; then
            perm='+ugo+x'
        else
            perm='/ugo+x'
        fi

        if $maxdepth; then
            maxdepth=''
        else
            maxdepth="-maxdepth 1"
        fi

        # shellcheck disable=2086
        find \
            "${ZC_BIN_PATHS[@]}" \
            $maxdepth \
            -perm "$perm" \
            \( -name "$task_name" -o -name "$task_name.*" \) \
            -not -type d \
            -print0
    }

    load_dotenv() {
        if [ -f "$ZC_PROJECT_PATH/.env" ]; then
            read_dotenv_file "$ZC_PROJECT_PATH/.env"
        elif [ -f "$ZC_PROJECT_PATH/config/.env" ]; then
            read_dotenv_file "$ZC_PROJECT_PATH/config/.env"
        elif [ -f "$ZC_PROJECT_PATH/config/env" ]; then
            read_dotenv_file "$ZC_PROJECT_PATH/config/env"
        elif [ -f "$ZC_PROJECT_PATH/.config/env" ]; then
            read_dotenv_file "$ZC_PROJECT_PATH/.config/env"
        elif [ -f "$ZC_PROJECT_PATH/.config/.env" ]; then
            read_dotenv_file "$ZC_PROJECT_PATH/.config/.env"
        fi
    }

    read_dotenv_file() {
        local raw_env_line dotenv_file=$1
        while IFS= read -r raw_env_line; do
            [[ -z $raw_env_line || $raw_env_line = '#'* ]] && continue
            eval "export $raw_env_line"
        done < "$dotenv_file"
    }

    get_task_path() {
        local task_path task_name=$1
        task_path=$(find_tasks "$task_name" | tr '\0' '\n')

        if [[ -z $task_path ]]; then
            printf -- 'Unable to find any tasks matching "%s"\n' "$task_name" >&2
            printf -- 'Searched for task in:\n' >&2
            printf -- '- %s\n' "${ZC_BIN_PATHS[@]}" >&2
            return 1
        fi

        if (( $(wc -l <<< "$task_path") > 1 )); then
            printf -- 'Found multiple tasks matching "%s":\n' "$task_name" >&2
            printf -- '%s\n' "${task_path[@]}" >&2
            return 1
        fi

        printf -- '%s\n' "$task_path"
        return 0
    }

    run_task() {
        local task_name=$1 task_path
        if ! task_path=$(get_task_path "$task_name"); then
            return 1
        fi

        shift
        exec "$task_path" "$@"
    }

    if [ -z "$ZC_PROJECT_PATH" ]; then
        if [ -n "$PROJECT_PATH" ]; then
            ZC_PROJECT_PATH="$PROJECT_PATH"
        else
            ZC_PROJECT_PATH=$(find_project_root)
            export PROJECT_PATH=$ZC_PROJECT_PATH
        fi
    fi

    load_dotenv

    if [ -z "$ZC_BIN_PATHS" ]; then
        ZC_BIN_PATHS=()
        [ -d "$ZC_PROJECT_PATH/.bin" ] && ZC_BIN_PATHS+=( "$ZC_PROJECT_PATH/.bin" )
        [ -d "$ZC_PROJECT_PATH/bin" ] && ZC_BIN_PATHS+=( "$ZC_PROJECT_PATH/bin" )
        [ -d "$ZC_PROJECT_PATH/scripts" ] && ZC_BIN_PATHS+=( "$ZC_PROJECT_PATH/scripts" )
        [ -d "$ZC_PROJECT_PATH/tasks" ] && ZC_BIN_PATHS+=( "$ZC_PROJECT_PATH/tasks" )
        [ -d "$ZC_PROJECT_PATH/tools" ] && ZC_BIN_PATHS+=( "$ZC_PROJECT_PATH/tools" )
    fi

    if [[ $ZC_NODE_MODULES ]]; then
        [ -d "$ZC_PROJECT_PATH/node_modules/.bin" ] && ZC_BIN_PATHS+=( "$ZC_PROJECT_PATH/node_modules/.bin" )
    fi

    if [[ $ZC_HOME_BIN ]]; then
        [ -d "$HOME/.local/bin" ] && ZC_BIN_PATHS+=( "$HOME/.local/bin" )
        [ -d "$HOME/.bin" ] && ZC_BIN_PATHS+=( "$HOME/.bin" )
        [ -d "$HOME/bin" ] && ZC_BIN_PATHS+=( "$HOME/bin" )
    fi

    if [ -z "$_ZC_LOCAL_INVOKE" ]; then
        if [ -t 1 ] && ! type -P zc &>/dev/null; then
            printf -- 'Warning: zc was not found in PATH
consider installing it by running

$ %s --install [PREFIX]

if PREFIX is not provided it will default to /usr/local/bin
' "${BASH_SOURCE[0]}" >&2
        fi

        local local_zc
        while IFS= read -r -d '' local_zc; do
            if [ "$(realpath "$local_zc")" = "$(realpath "${BASH_SOURCE[0]}")" ]; then
                break
            fi

            (
                set -e
                _ZC_LOCAL_INVOKE=true "$local_zc" "$@"
            )
            return $?
        done < <(find_tasks zc)
    fi

    (
        set -e
        run_task "$@"
    )
}
fi

# Only invoke the zc function this script is called directly.
if [[ $_ZC_LOCAL_INVOKE || "${BASH_SOURCE[0]}" = 'zc' || "$(realpath "$0")" = "$(realpath "${BASH_SOURCE[0]}")" ]]; then
    zc "$@"
fi
