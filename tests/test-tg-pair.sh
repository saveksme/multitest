#!/usr/bin/env bash
# Привязка к Telegram-боту, отвязка, статус, пункт меню — на поддельном curl.
. "$(dirname "$0")/lib.sh"
export LC_ALL=C.UTF-8                        # QR печатается только в UTF-8-локали
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
t_fake_curl
MT_STATE_DIR="$T_W/state"; MT_CONF="$MT_STATE_DIR/agent.conf"
gather_system_facts() { SYS_IP4=203.0.113.42; SYS_IP6=""; SYS_COUNTRY=NL; SYS_CITY=Amsterdam
    SYS_ASN="AS64496 Example Hosting B.V."; SYS_CPU="AMD Ryzen 9 9950X 16-Core Processor"; SYS_CORES=2
    SYS_RAM="3.8 GiB"; SYS_DISK="59G · 6%"; SYS_OS="Ubuntu 24.04"; SYS_VIRT=$'none\nunknown'; }
sleep() { :; }
answers() { printf '%s\n' "$@" > "$T_W/tty"; MT_TTY="$T_W/tty"; }
fresh() { rm -rf "$T_W/curl"; mkdir -p "$T_W/curl"; }
paired() { MT_SRV_ID=AbCdEf123456; MT_SRV_TOKEN="mtk_$(printf "$1%.0s" {1..64})"; MT_API=https://bot.test; MT_BOT=test_bot; mt_conf_save; }
CODE=Ab3dE5gH7jK9mN1pQ3sT5v

MT_BOT_API=""; MT_BOT_USERNAME=""; fresh; answers y
mt_tg_pair > "$T_W/out" 2>&1; rc=$?
check "не настроен → 1, без запросов"   '[ $rc = 1 ] && [ "$(t_calls)" = 0 ] && grep -qF "ещё не настроен" "$T_W/out"'
MT_BOT_API="https://bot.test"; MT_BOT_USERNAME="test_bot"

fresh; answers y
t_respond 200 "ok $CODE 600 47" "█▀▀▀█" "█ ▀ █"
t_respond 200 "pending"
t_respond 200 "approved %D0%98%D0%B2%D0%B0%D0%BD%20(%40ivan)"
t_respond 200 "ok AbCdEf123456"
mt_tg_pair > "$T_W/out" 2>&1; rc=$?
check "привязка: rc 0 и конфиг"         '[ $rc = 0 ] && grep -qx "MT_SRV_ID=AbCdEf123456" "$MT_CONF"'
check "ссылка на бота"                  'grep -qF "https://t.me/test_bot?start=p_$CODE" "$T_W/out"'
check "код для бота и QR"               'grep -qF "Код для бота: 47" "$T_W/out" && grep -qF "█ ▀ █" "$T_W/out"'
check "кто подтвердил"                  'grep -qF "Иван (@ivan)" "$T_W/out"'
tok=$(sed -n "s/^MT_SRV_TOKEN=//p" "$MT_CONF")
check "один ключ во всех запросах"      '[ "$(cat "$T_W"/curl/stdin.* | sort -u | wc -l)" = 1 ] && grep -qF "$tok" "$T_W/curl/stdin.1"'
check "маска IP вместо адреса"          'grep -qx "ip4=203.0.\*.\*" "$T_W/curl/argv.1" && ! grep -qF "203.0.113.42" "$T_W/curl/argv.1"'
check "перевод строки в virt убран"     'grep -qx "virt=none unknown" "$T_W/curl/argv.1"'
check "confirm с answer=yes"            'grep -qx "answer=yes" "$T_W/curl/argv.4"'

rm -f "$MT_CONF"; fresh; answers n
t_respond 200 "ok $CODE 600 47"; t_respond 200 "approved %40mallory"; t_respond 200 "cancelled"
mt_tg_pair > "$T_W/out" 2>&1; rc=$?
check "«нет» → 1, answer=no, конфига нет" '[ $rc = 1 ] && [ ! -e "$MT_CONF" ] && grep -qx "answer=no" "$T_W/curl/argv.3"'

for v in denied expired; do
    fresh; answers y; t_respond 200 "ok $CODE 600 47"; t_respond 200 "$v"
    mt_tg_pair > "$T_W/out" 2>&1; rc=$?
    check "$v → 1, конфига нет" '[ $rc = 1 ] && [ ! -e "$MT_CONF" ]'
done

fresh; answers y; t_respond 502 "<html><body>502 Bad Gateway</body></html>"
mt_tg_pair > "$T_W/out" 2>&1; rc=$?
check "502 → понятная строка без HTML"   '[ $rc = 1 ] && grep -qF "HTTP 502" "$T_W/out" && ! grep -qF "<html>" "$T_W/out" && [ ! -e "$MT_CONF" ]'

fresh; answers n
t_respond 200 "ok $CODE 600 47" "$(printf '\033[2J')"; t_respond 200 "approved %1B%5B2Jx"; t_respond 200 "cancelled"
mt_tg_pair > "$T_W/out" 2>&1
check "ESC от бэкенда не доходит до терминала" '! grep -q "$(printf "\033\\[2J")" "$T_W/out"'

# Имя подтвердившего приходит в %-кодировке. Обратный слэш в нём mt_clean не трогает,
# и после `printf '%b'` из имени собирались `\e`, `\c`, `\n` — а `echo -e` в подсказке
# их исполнял: «\e[2J» чистил экран, «\c» обрывал вопрос, «\n» рвал его на строки.
# Идём быстрой привязкой (как в блоке ниже): там имя стоит в вопросе «Привязать сервер…».
JOIN="mtp_$(printf 'A%.0s' {1..24})"
rm -f "$MT_CONF"; fresh; answers n
t_respond 200 "approved %5Ce%5B2Jx"; t_respond 200 "cancelled"
mt_tg_pair "$JOIN" > "$T_W/out" 2>&1; rc=$?
check "«\\e» в имени не чистит экран"      '[ $rc = 1 ] && ! grep -q "$(printf "\033\\[2J")" "$T_W/out"'

fresh; answers n
t_respond 200 "approved %5Cc"; t_respond 200 "cancelled"
mt_tg_pair "$JOIN" > "$T_W/out" 2>&1; rc=$?
check "«\\c» в имени не обрывает вопрос"   '[ $rc = 1 ] && grep -qF "Привязать сервер" "$T_W/out"'

fresh; answers n
t_respond 200 "approved %5Cn"; t_respond 200 "cancelled"
mt_tg_pair "$JOIN" > "$T_W/out" 2>&1; rc=$?
check "«\\n» в имени не рвёт вопрос"       '[ $rc = 1 ] && grep -q "Команда из Telegram-аккаунта.*Привязать сервер.*Enter" "$T_W/out"'
check "цвета не печатаются текстом"        '! grep -qF "\033[" "$T_W/out"'

fresh; MT_TTY="$T_W/нет-такого"
mt_tg_pair > "$T_W/out" 2>&1; rc=$?
check "без терминала → 1, запросов нет"  '[ $rc = 1 ] && [ "$(t_calls)" = 0 ] && grep -qF "только из терминала" "$T_W/out"'

fresh; answers n; t_respond 200 "ok $CODE 600 47"; t_respond 200 "approved %40ivan"; t_respond 200 "cancelled"
printf 'y\ny\n' | mt_tg_pair > "$T_W/out" 2>&1; rc=$?
check "ответ из терминала, не из stdin"  '[ $rc = 1 ] && [ ! -e "$MT_CONF" ]'

# --- быстрая привязка по коду из бота ------------------------------------------------------
JOIN="mtp_$(printf 'A%.0s' {1..24})"
rm -f "$MT_CONF"; fresh; answers y
t_respond 200 "approved %D0%98%D0%B2%D0%B0%D0%BD%20(%40ivan)"
t_respond 200 "ok AbCdEf123456"
mt_tg_pair "$JOIN" > "$T_W/out" 2>&1; rc=$?
check "код из бота: rc 0 и конфиг"         '[ $rc = 0 ] && grep -qx "MT_SRV_ID=AbCdEf123456" "$MT_CONF"'
check "код — только в stdin curl"          'grep -qF "X-Pair-Token: $JOIN" "$T_W/curl/stdin.1" && ! grep -qF "$JOIN" "$T_W/curl/argv.1"'
check "claim вместо ссылки и QR"           'grep -qx "https://bot.test/v1/pair/claim" "$T_W/curl/argv.1" && ! grep -qF "start=p_" "$T_W/out"'
check "спросил про аккаунт, answer=yes"    'grep -qF "Telegram-аккаунта" "$T_W/out" && grep -qF "Иван (@ivan)" "$T_W/out" && grep -qx "answer=yes" "$T_W/curl/argv.2"'
check "в confirm кода уже нет"             '! grep -qF "X-Pair-Token" "$T_W/curl/stdin.2"'

rm -f "$MT_CONF"; fresh; answers n; t_respond 200 "approved %40mallory"; t_respond 200 "cancelled"
mt_tg_pair "$JOIN" > "$T_W/out" 2>&1; rc=$?
check "чужой аккаунт → «нет», конфига нет" '[ $rc = 1 ] && [ ! -e "$MT_CONF" ] && grep -qx "answer=no" "$T_W/curl/argv.2"'

rm -f "$MT_CONF"; fresh; answers y; t_respond 404 "err token"
mt_tg_pair "$JOIN" > "$T_W/out" 2>&1; rc=$?
check "устаревший код → понятно"           '[ $rc = 1 ] && [ ! -e "$MT_CONF" ] && grep -qF "устарела или уже использована" "$T_W/out" && ! grep -qF "Время вышло" "$T_W/out"'

fresh; answers y
mt_tg_pair 'mtp_bad;rm -rf /' > "$T_W/out" 2>&1; rc=$?
check "кривой код → 1, без запросов"        '[ $rc = 1 ] && [ "$(t_calls)" = 0 ] && grep -qF "не код из бота" "$T_W/out"'

paired a; before=$(cat "$MT_CONF"); fresh; answers n
mt_tg_pair > "$T_W/out" 2>&1
check "перепривязка «нет»: конфиг цел, запросов нет" '[ "$(cat "$MT_CONF")" = "$before" ] && [ "$(t_calls)" = 0 ]'

rm -f "$MT_CONF"; fresh; answers y
t_respond 200 "ok $CODE 600 47"; t_respond 200 "pending"; t_respond 200 "pending"; t_respond 200 "pending"
( export T_CURL_KILL_AT=2 T_CURL_KILL_PID=$BASHPID; mt_tg_pair ) > "$T_W/out" 2>&1; rc=$?
check "Ctrl+C → 1, конфига нет"          '[ $rc = 1 ] && [ ! -e "$MT_CONF" ] && grep -qF "прервана" "$T_W/out"'

paired b; fresh; answers y; t_respond 200 "ok"
mt_tg_unpair > "$T_W/out" 2>&1; rc=$?
check "отвязка: bye и конфиг удалён"     '[ $rc = 0 ] && [ ! -e "$MT_CONF" ] && grep -qx "https://bot.test/v1/agent/bye" "$T_W/curl/argv.1"'

paired c; fresh; t_respond 200 "revoked"
mt_tg_status > "$T_W/out" 2>&1; rc=$?
check "статус: revoked стирает конфиг"   '[ $rc = 1 ] && [ ! -e "$MT_CONF" ]'

paired d
check "бот — в утилитах, со статусом"   'show_utilities_menu </dev/null 2>/dev/null | grep -q "3).*Telegram-бот.*привязан к @test_bot"'
check "в главном меню пункта 15 нет"     '! show_menu </dev/null 2>/dev/null | grep -q "15)" && show_menu </dev/null 2>/dev/null | grep -q "14).*Telegram-бот"'
t_finish
