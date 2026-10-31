#!/usr/bin/env bash
# ТСПУ: определение SSH-порта машины, один запрос к нашему боту, разбор
# канонических строк в метрики/чипы, ключевая цифра и страница сводки,
# нейтральная ошибка и guard против возврата внешнего протокола в исходники.
. "$(dirname "$0")/lib.sh"
export LC_ALL=C.UTF-8
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
declare -A MT_STATUS=()
SUMMARY_DIR="$T_W"; US=$'\x1f'
mt_style_init

chip()   { grep -qxF "chip${US}$2${US}${US}$3${US}$4${US}-1${US}${US}" "$T_W/$1.services"; }
metric() { grep -qxF "$2${US}$3${US}$4" "$T_W/$1.metrics"; }
rows()   { [ "$(grep -c '' "$T_W/$1.services")" = "$2" ]; }
parse()  { parse_test_output "$1" "$T_W/$1.log" "$T_W/$1.metrics" "$T_W/$1.services"; }
no_markers() {
    local bad
    for bad in "iwt""sy" "/api/""check" "node_""result" "check_""done" \
               "iwt""sy_consent" "aHR0cHM6""Ly9p" "aXd0""c3lf"; do
        grep -qiF "$bad" "$T_ROOT/multitest.sh" "$T_ROOT/tests/test-tspu-check.sh" && return 1
    done
    return 0
}

t_fake_curl
export SSH_CONNECTION="10.0.0.2 51111 203.0.113.7 2222"
MT_API=https://bot.test

# Ответ нашего бэкенда: версия формата, маскированная цель, площадки и итог
t_respond 200 'v 1
  Цель: 203.0.*.*:2222
  Moscow · Demo ISP · open · 24.0 мс
  Ufa · JSC · dpi · 41.0 мс
  Итог: РАБОТАЕТ С ПОТЕРЯМИ · 1/2 · 50%'

run_tspu_check > "$T_W/run_tspu_check.log" 2>&1; rc=$?
check "прогон: код 0"                     '[ $rc = 0 ]'
check "прогон: порт из SSH_CONNECTION"    'grep -q "203.0.\*.\*:2222" "$T_W/run_tspu_check.log"'
check "прогон: строка ноды каноническая"  'grep -q "^  Moscow · Demo ISP · open · 24.0 мс$" "$T_W/run_tspu_check.log"'
check "прогон: итоговая строка"           'grep -q "Итог: РАБОТАЕТ С ПОТЕРЯМИ · 1/2 · 50%" "$T_W/run_tspu_check.log"'
check "прогон: один запрос к нашему боту" '[ "$(t_calls)" = 1 ] && grep -qxF "https://bot.test/v1/tspu" "$T_W/curl/argv.1" && grep -qxF "port=2222" "$T_W/curl/argv.1"'
check "прогон: цель наружу не передаётся" '! grep -q "target\|203.0.113.7" "$T_W/curl/argv.1"'
check "скрытность: протокола в исходниках нет" 'no_markers'

parse run_tspu_check
check "метрика: SSH порт"      'metric run_tspu_check "SSH порт" 2222 pri'
check "метрика: вердикт"       'metric run_tspu_check "Вердикт" "РАБОТАЕТ С ПОТЕРЯМИ" warn'
check "метрика: доступно"      'metric run_tspu_check "Доступно" "1/2 · 50%" warn'
check "метрика: DPI-обрывы"    'metric run_tspu_check "DPI-обрывы" 1 bad'
check "чипы: две площадки"     'rows run_tspu_check 2'
check "чип: открытая площадка" 'chip run_tspu_check "Moscow · Demo ISP" ok "открыт"'
check "чип: DPI, кавычки в имени провайдера обрезаны" 'chip run_tspu_check "Ufa · JSC" bad "DPI"'

MT_STATUS[run_tspu_check]="выполнен"   # иначе mt_test_key отвечает «пропущен»
mt_read_metrics run_tspu_check; mt_read_rows run_tspu_check; mt_test_key run_tspu_check
check "ключ: доля и DPI красным" '[ "$K" = "1/2 · 50% · DPI: 1" ] && [ "$KC" = "$C_ERR" ]'

page() {
    local i
    for i in "${!MT_CAT_FUNCS[@]}"; do [[ "${MT_CAT_FUNCS[i]}" == "$1" ]] && break; done
    MT_STATUS[$1]="выполнен"; MT_PAGE_N=2; MT_PAGE_I=2
    build_page_test "$i" > "$T_W/$1.svg"
}
page run_tspu_check
check "страница: герой про площадки"   'grep -q "площадок РФ видят SSH-порт сервера" "$T_W/run_tspu_check.svg"'
check "страница: кто не видит SSH"     'grep -q "Не видят SSH" "$T_W/run_tspu_check.svg"'
check "страница: пилюля DPI"           'grep -q ">DPI<" "$T_W/run_tspu_check.svg"'

# Бэкенд вернул нейтральную ошибку — неудача без следов внешнего протокола
t_respond 502 "err unavailable"
run_tspu_check > "$T_W/err.log" 2>&1; rc=$?
check "ошибка: код 1"                  '[ $rc = 1 ]'
check "ошибка: маркер в логе"          'grep -q "\[TSPU\] ОШИБКА: площадка проверки недоступна" "$T_W/err.log"'
check "ошибка: нет деталей протокола"  '! grep -qiE "SSE|node_""result|check_""done" "$T_W/err.log"'
cp "$T_W/err.log" "$T_W/run_tspu_check.log"; parse run_tspu_check
check "ошибка: метрика недоступности"  'metric run_tspu_check "Проверка" "недоступна" bad'
mt_read_metrics run_tspu_check; mt_read_rows run_tspu_check; mt_test_key run_tspu_check
check "ошибка: ключ «сервис недоступен»" '[ "$K" = "сервис недоступен" ] && [ "$KC" = "$C_ERR" ]'
t_finish
