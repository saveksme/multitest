#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
check "в каталоге 13 тестов"              '[ ${#MT_CAT_FUNCS[@]} = 13 ]'
check "имена и время той же длины"         '[ ${#MT_CAT_NAMES[@]} = 13 ] && [ ${#MT_CAT_SECS[@]} = 13 ]'
undef=""; for f in "${MT_CAT_FUNCS[@]}"; do declare -F "$f" >/dev/null || undef+=" $f"; done
check "каждая функция каталога определена" '[ -z "$undef" ]'
check "первый — IP Region"                 '[ "${MT_CAT_FUNCS[0]}" = run_ip_region ] && [ "${MT_CAT_NAMES[0]}" = "IP Region" ]'
check "последний — ТСПУ, 120 c"            '[ "${MT_CAT_FUNCS[12]}" = run_tspu_check ] && [ "${MT_CAT_SECS[12]}" = 120 ]'
check "mt_is_test_fn: свой"                'mt_is_test_fn run_yabs'
check "mt_is_test_fn: чужое и мусор"       '! mt_is_test_fn run_nope && ! mt_is_test_fn "run_yabs;id"'
capture_test "run_ip_region;touch $T_W/pwn" "$T_W/log" >/dev/null 2>&1; rc=$?
check "capture_test не запускает чужое"    '[ $rc -ne 0 ] && [ ! -e "$T_W/pwn" ]'
t_finish
