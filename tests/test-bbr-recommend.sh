#!/bin/bash
# Проверка recommend_bbr_cake из multitest.sh.
# TTY-фильтр «[[ -t 0 ]] || return 0» в копии скрипта обходится sed-ом, чтобы
# прокормить ответы через пайп; сам фильтр проверяется отдельно на оригинале.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)/multitest.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Копия, где приглашение показывается даже без терминала (только для теста).
sed 's@^\([[:space:]]*\)\[\[ -t 0 \]\] || return 0$@\1: # TTY guard bypassed for test@' \
    "$SRC" > "$WORK/tty.sh"
grep -q "TTY guard bypassed for test" "$WORK/tty.sh" || { echo "FAIL: sed не нашёл TTY-фильтр"; exit 1; }

fail=0
check() { # $1=что проверяем, $2=условие
    if eval "$2"; then echo "  ok: $1"; else echo "  FAIL: $1"; fail=1; fi
}

stub_and_source() { # $1=путь к скрипту
    MULTITEST_TEST=1 source "$1"
    sysctl() {
        case "$2" in
            net.ipv4.tcp_congestion_control) echo "${STUB_CC:-cubic}" ;;
            net.core.default_qdisc)          echo "${STUB_QD:-fq_codel}" ;;
        esac
    }
    ENABLE_CALLS=0
    enable_bbr_cake() { ENABLE_CALLS=$((ENABLE_CALLS + 1)); echo "ENABLE_CALLED"; }
}

count_str() { printf '%s' "$1" | grep -c "$2" || true; }

echo "S1: согласие «y» — включает ровно один раз, второй вызов молчит"
out=$(printf 'y\n' | { stub_and_source "$WORK/tty.sh"; recommend_bbr_cake; recommend_bbr_cake; echo "CALLS=$ENABLE_CALLS"; } 2>&1)
check "показано одно приглашение"        '[ "$(count_str "$out" "рекомендуем включить")" = 1 ]'
check "enable_bbr_cake вызван"           '[ "$(count_str "$out" "ENABLE_CALLED")" = 1 ]'
check "флаг: CALLS=1"                    '[ "$(printf "%s" "$out" | grep -o "CALLS=[0-9]*")" = "CALLS=1" ]'

echo "S2: отказ (Enter) — не включает, приглашение одно, подсказка про Утилиты"
out=$(printf '\n' | { stub_and_source "$WORK/tty.sh"; recommend_bbr_cake; recommend_bbr_cake; echo "CALLS=$ENABLE_CALLS"; } 2>&1)
check "enable_bbr_cake НЕ вызван"        '[ "$(count_str "$out" "ENABLE_CALLED")" = 0 ]'
check "подсказка «Оставляем как есть»"   '[ "$(count_str "$out" "Оставляем как есть")" -ge 1 ]'
check "приглашение показано один раз"    '[ "$(count_str "$out" "рекомендуем включить")" = 1 ]'

echo "S3: уже bbr/cake — молча, без приглашения"
out=$(printf 'y\n' | { stub_and_source "$WORK/tty.sh"; STUB_CC=bbr; STUB_QD=cake; recommend_bbr_cake; echo "CALLS=$ENABLE_CALLS"; } 2>&1)
check "нет приглашения"                  '[ "$(count_str "$out" "рекомендуем включить")" = 0 ]'
check "enable_bbr_cake НЕ вызван"        '[ "$(count_str "$out" "ENABLE_CALLED")" = 0 ]'

echo "S4: не-TTY (оригинальный скрипт, stdin — пайп) — тихий пропуск"
out=$(printf 'y\n' | { stub_and_source "$SRC"; recommend_bbr_cake; recommend_bbr_cake; echo "CALLS=$ENABLE_CALLS FLAG=$MT_BBR_PROMPTED"; } 2>&1)
check "нет приглашения"                  '[ "$(count_str "$out" "рекомендуем включить")" = 0 ]'
check "enable_bbr_cake НЕ вызван"        '[ "$(count_str "$out" "ENABLE_CALLED")" = 0 ]'
check "после пропуска флаг стоит"        '[ "$(printf "%s" "$out" | grep -o "FLAG=[0-9]*")" = "FLAG=1" ]'

echo "S5: согласие «д» (русская раскладка)"
out=$(printf 'д\n' | { stub_and_source "$WORK/tty.sh"; recommend_bbr_cake; echo "CALLS=$ENABLE_CALLS"; } 2>&1)
check "enable_bbr_cake вызван"           '[ "$(count_str "$out" "ENABLE_CALLED")" = 1 ]'

echo "S6: список сетевых тестов"
out=$(MULTITEST_TEST=1 bash -c 'source "$1";
    for f in run_iperf3_ru run_iperf3_tlab run_yabs run_bench_sh; do
        [[ "$MT_BBR_SPEED_TESTS" == *" $f "* ]] || { echo "NO:$f"; exit 1; }
    done
    for f in run_ip_region run_censorcheck_dpi run_ip_check_place run_ip_quality run_sysbench_cpu run_ping_map; do
        [[ "$MT_BBR_SPEED_TESTS" != *" $f "* ]] || { echo "NO:$f"; exit 1; }
    done
    echo LIST_OK' _ "$SRC" 2>&1)
check "ровно 4 сетевых теста в списке"   '[ "$out" = "LIST_OK" ]'

echo "S7: зацеплено в меню и в run_all"
menu=$(grep -cE '^[[:space:]]*[5679]\)[[:space:]]+recommend_bbr_cake; ' "$SRC")
runall=$(grep -c 'recommend_bbr_cake; break' "$SRC")
check "меню: пункты 5,6,7,9"             '[ "$menu" = 4 ]'
check "run_all: один вызов с break"      '[ "$runall" = 1 ]'

echo ""
[ $fail -eq 0 ] && echo "ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ" || { echo "ЕСТЬ ОШИБКИ"; exit 1; }
