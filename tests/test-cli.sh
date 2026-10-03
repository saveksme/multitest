#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
t_need timeout
bash "$T_ROOT/multitest.sh" --nope </dev/null >/dev/null 2>&1; rc=$?
check "незнакомый флаг → 2"            '[ $rc = 2 ]'
bash "$T_ROOT/multitest.sh" --help </dev/null > "$T_W/help" 2>&1; rc=$?
check "--help → 0 и справка"           '[ $rc = 0 ] && grep -q -- "--help" "$T_W/help"'
TERM=dumb timeout 10 bash "$T_ROOT/multitest.sh" </dev/null >/dev/null 2>&1; rc=$?
check "конец ввода в меню → выход 0"   '[ $rc = 0 ]'
out=$(MULTITEST_TEST=1 bash -c 'source "$1" --nope; echo SOURCED_OK' _ "$T_ROOT/multitest.sh" 2>&1)
check "source флаги не разбирает"       '[ "$(printf "%s\n" "$out" | tail -n1)" = SOURCED_OK ]'
t_finish
