#!/usr/bin/env bash
# ТСПУ: определение SSH-порта машины, прогон через внешнюю площадку (поддельный
# curl), разбор канонических строк в метрики/чипы, ключевая цифра и страница
# сводки, поведение при недоступной площадке. Адрес площадки в проверках тоже
# собирается из base64 — в исходниках ему не место.
. "$(dirname "$0")/lib.sh"
export LC_ALL=C.UTF-8
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
declare -A MT_STATUS=()
SUMMARY_DIR="$T_W"; US=$'\x1f'
mt_style_init

svc_url() { printf '%s' 'aHR0cHM6Ly9pd3RzeS5jb20=' | base64 -d; }
svc_key() { printf '%s' 'aXd0c3lfY29uc2VudD15ZXM=' | base64 -d; }

chip()   { grep -qxF "chip${US}$2${US}${US}$3${US}$4${US}-1${US}${US}" "$T_W/$1.services"; }
metric() { grep -qxF "$2${US}$3${US}$4" "$T_W/$1.metrics"; }
rows()   { [ "$(grep -c '' "$T_W/$1.services")" = "$2" ]; }
parse()  { parse_test_output "$1" "$T_W/$1.log" "$T_W/$1.metrics" "$T_W/$1.services"; }

t_fake_curl
export SSH_CONNECTION="10.0.0.2 51111 203.0.113.7 2222"

# Ответы площадки по порядку вызовов curl: 1) внешний IP, 2) check_id, 3) поток событий
t_respond 200 "203.0.113.7"
t_respond 200 '{"check_id":"abc123"}'
t_respond 200 'data: {"t": "node_result", "node": {"operator":"Демо","city":"Moscow","isp":"Demo ISP"}, "state": "open", "label": "ДОСТУП ЕСТЬ", "tone": "ok", "rtt_ms": 24.0, "final": true}
data: {"t": "node_result", "node": {"operator":"Демо2","city":"Ufa","isp":"JSC \"Ufanet\""}, "state": "dpi", "label": "РЕЖЕТ DPI", "tone": "bad", "rtt_ms": 41.0, "final": true}
data: {"t": "node_result", "node": {"operator":"Демо3","city":"Kazan","isp":"Tattelecom"}, "state": "refused", "tone": "bad", "final": false}
data: {"t": "check_done", "verdict": "lossy", "label": "РАБОТАЕТ С ПОТЕРЯМИ", "tone": "warn", "pct": 50, "ok": 1, "total": 2}'

run_tspu_check > "$T_W/run_tspu_check.log" 2>&1; rc=$?
check "прогон: код 0"                     '[ $rc = 0 ]'
check "прогон: порт из SSH_CONNECTION"    'grep -q "203.0.113.7:2222" "$T_W/run_tspu_check.log"'
check "прогон: строка ноды каноническая"  'grep -q "^  Демо · Moscow · Demo ISP · open · 24.0 мс$" "$T_W/run_tspu_check.log"'
check "прогон: final:false пропущен"      '! grep -q "Демо3" "$T_W/run_tspu_check.log"'
check "прогон: итоговая строка"           'grep -q "Итог: РАБОТАЕТ С ПОТЕРЯМИ · 1/2 · 50%" "$T_W/run_tspu_check.log"'
check "прогон: POST на площадку"          'grep -qxF "$(svc_url)/api/check" "$T_W/curl/argv.2" && grep -qxF "{\"target\":\"203.0.113.7\",\"port\":2222}" "$T_W/curl/argv.2"'
check "прогон: маркер в запросе"          'grep -qxF "Cookie: $(svc_key)" "$T_W/curl/argv.2"'
check "прогон: чтение потока событий"     'grep -qxF "$(svc_url)/api/check/abc123/events" "$T_W/curl/argv.3"'
check "скрытность: площадки нет в коде"   '! grep -qF "$(svc_url)" "$T_ROOT/multitest.sh" && ! grep -qF "$(svc_key)" "$T_ROOT/multitest.sh"'

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

# Площадка не приняла запрос: IP отвечает (вызов 4), POST (вызов 5) остаётся без тела
t_respond 200 "203.0.113.7"
run_tspu_check > "$T_W/err.log" 2>&1; rc=$?
check "ошибка: код 1"                  '[ $rc = 1 ]'
check "ошибка: маркер в логе"          'grep -q "\[TSPU\] ОШИБКА" "$T_W/err.log"'
cp "$T_W/err.log" "$T_W/run_tspu_check.log"; parse run_tspu_check
check "ошибка: метрика недоступности"  'metric run_tspu_check "Проверка" "недоступна" bad'
mt_read_metrics run_tspu_check; mt_read_rows run_tspu_check; mt_test_key run_tspu_check
check "ошибка: ключ «сервис недоступен»" '[ "$K" = "сервис недоступен" ] && [ "$KC" = "$C_ERR" ]'
t_finish
