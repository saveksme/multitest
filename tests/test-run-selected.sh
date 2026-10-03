#!/usr/bin/env bash
# Выбор тестов по списку id, безголовый прогон, блокировка, каталог прогона.
. "$(dirname "$0")/lib.sh"
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
capture_test()              { echo "CAPTURE $1" >> "$T_W/calls"; echo "вывод $1" > "$2"; echo "ЭКРАН $1"; }
parse_test_output()         { :; }
render_and_upload_summary() { echo "RENDER" >> "$T_W/calls"; }
install_deps_for()          { :; }
read() { echo "READ $*" >> "$T_W/reads"; return 1; }
MT_SUMMARY_ROOT="$T_W"; MT_LOCK_FILE="$T_W/lock"

mt_sel_from_spec "";                    rc=$?; check "пустой выбор → 1"          '[ $rc = 1 ]'
mt_sel_from_spec "ip_region,nope";      rc=$?; check "незнакомый id → 1, пусто"  '[ $rc = 1 ] && [ ${#test_funcs[@]} = 0 ]'
mt_sel_from_spec "run_ip_region";       rc=$?; check "имя функции вместо id → 1" '[ $rc = 1 ]'
mt_sel_from_spec "ip_region;id";        rc=$?; check "мусор → 1"                 '[ $rc = 1 ]'
mt_sel_from_spec "ip_region,,yabs";     rc=$?; check "пустой элемент → 1"        '[ $rc = 1 ]'
mt_sel_from_spec "yabs,ip_region,yabs"; rc=$?
check "порядок каталога, без повторов"   '[ $rc = 0 ] && [ "${test_funcs[*]}" = "run_ip_region run_yabs" ] && [ "${test_names[0]}" = "IP Region" ]'

mt_headless_init
mt_sel_from_spec "ip_region,sysbench_cpu"
mt_run_selected > "$T_W/out1" 2>&1; rc=$?
check "прогон без вопросов"              '[ $rc = 0 ] && [ ! -s "$T_W/reads" ]'
check "оба теста запущены, сводка собрана" 'grep -q "CAPTURE run_ip_region" "$T_W/calls" && grep -q "CAPTURE run_sysbench_cpu" "$T_W/calls" && grep -q RENDER "$T_W/calls"'
check "статусы проставлены"              '[ "${MT_STATUS[run_ip_region]}" = "выполнен" ] && [ "${MT_STATUS[run_sysbench_cpu]}" = "выполнен" ]'
check "без ANSI в выводе"                '! grep -q "$(printf "\033")" "$T_W/out1"'
check "вывод тестов не на экране"        '! grep -q "ЭКРАН" "$T_W/out1"'
check "SHELL для script -c"              '[ "$SHELL" = /bin/bash ]'
d1="$SUMMARY_DIR"; mt_run_selected >/dev/null 2>&1; d2="$SUMMARY_DIR"
check "каталог прогона уникален"         '[ "$d1" != "$d2" ] && [[ "$d1" == "$T_W"/multitest-summary-* ]] && [ -d "$d2" ]'
if command -v flock >/dev/null; then
    ( exec 9>"$MT_LOCK_FILE"; flock 9; command sleep 3 ) & command sleep 0.5
    mt_run_selected >/dev/null 2>&1; rc=$?
    check "занято другим прогоном → 3"   '[ $rc = 3 ]'
    wait
fi
t_finish
