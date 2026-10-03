#!/usr/bin/env bash
# Тесты качают чужие скрипты и исполняют их от root — только по https.
. "$(dirname "$0")/lib.sh"
bad=$(grep -nE '(wget[[:space:]]+-qO-|curl[[:space:]]+-(sL|Ls))[[:space:]]+[^[:space:]]' "$T_ROOT/multitest.sh" \
    | grep -vE '^[0-9]+:[[:space:]]*#' \
    | grep -vE '(wget[[:space:]]+-qO-|curl[[:space:]]+-(sL|Ls))[[:space:]]+("?\$|https://)')
check "все загрузки скриптов — по https" '[ -z "$bad" ]'
[ -n "$bad" ] && printf '      %s\n' "$bad"
t_finish
