#!/usr/bin/env bash
# Параметры и запуск без терминала: незнакомый флаг — справка и код 2, без TTY меню нет.
# Сюда из прода: служба со StandardInput=null запустила версию без разбора флагов, та ушла
# в меню и крутила его на EOF — 700 КБ/с в журнал.
. "$(dirname "$0")/lib.sh"
t_need timeout
MT="$T_ROOT/multitest.sh"
# своё состояние: ни ключа, ни unit, ни systemd с хоста
export MT_STATE_DIR="$T_W/state" MT_AGENT_DIR="$T_W/agent" MT_SYSTEMD="$T_W/nosystemd"
export MT_AGENT_UNIT="$T_W/unit/multitest-agent.service" MT_AGENT_BIN="$T_W/lib/multitest"
run() { timeout 10 bash "$MT" "$@" </dev/null >"$T_W/o" 2>"$T_W/e"; }

run --nope; rc=$?
check "незнакомый флаг → 2"                 '[ $rc = 2 ]'
check "незнакомый флаг: справка в stderr"   'grep -q "неизвестный параметр" "$T_W/e" && grep -q -- "--agent" "$T_W/e" && [ ! -s "$T_W/o" ]'
run --agent extra; rc=$?
check "лишний аргумент → 2, не молча"       '[ $rc = 2 ] && [ ! -s "$T_W/o" ]'
run --verify; rc=$?
check "без обязательного аргумента → 2"     '[ $rc = 2 ]'
run -x --help; rc=$?
check "флаг не первым → тоже 2"             '[ $rc = 2 ]'
run --help; rc=$?
check "--help → 0 и справка"                '[ $rc = 0 ] && grep -q -- "--help" "$T_W/o" && grep -q -- "--version" "$T_W/o"'
run --version; rc=$?
check "--version → 0 и версия"              '[ $rc = 0 ] && grep -qE "^multitest [0-9]+\.[0-9]+" "$T_W/o"'
run -V; rc=$?
check "-V — то же"                          '[ $rc = 0 ] && grep -qE "^multitest [0-9]" "$T_W/o"'

# без терминала меню нет: понятная ошибка и ненулевой код, на stdout — ничего
run; rc=$?
check "без TTY → ошибка, не меню"           '[ $rc != 0 ] && [ $rc != 124 ] && [ ! -s "$T_W/o" ] && grep -q "терминал" "$T_W/e"'
TERM=dumb run; rc=$?
check "dumb-терминал без TTY — так же"      '[ $rc != 0 ] && [ $rc != 124 ] && [ ! -s "$T_W/o" ]'

# --agent без терминала: служба, не меню; сервер не привязан — 78 (systemd не перезапускает)
run --agent; rc=$?
check "--agent </dev/null → 78, без меню"   '[ $rc = 78 ] && ! grep -q "Выберите" "$T_W/o" "$T_W/e"'
n=$(timeout 2 bash "$MT" --agent </dev/null 2>&1 | wc -c)
check "--agent: вывод — строка, не поток"   '[ "$n" -lt 2000 ]'
n=$(timeout 2 bash "$MT" </dev/null 2>&1 | wc -c)
check "без TTY: вывод — строка, не поток"   '[ "$n" -lt 2000 ]'

out=$(MULTITEST_TEST=1 bash -c 'source "$1" --nope; echo SOURCED_OK' _ "$MT" 2>&1)
check "source флаги не разбирает"           '[ "$(printf "%s\n" "$out" | tail -n1)" = SOURCED_OK ]'
t_finish
