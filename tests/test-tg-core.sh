#!/usr/bin/env bash
# Ядро клиента Telegram: ключ, curl-обёртка, разбор ответов, чистка вывода, конфиг.
. "$(dirname "$0")/lib.sh"
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
t_fake_curl
MT_STATE_DIR="$T_W/state"; MT_CONF="$MT_STATE_DIR/agent.conf"
MT_BOT_API="https://bot.test"; MT_BOT_USERNAME="test_bot"

t1=$(mt_tok_new); t2=$(mt_tok_new)
check "ключ: mtk_ + 64 hex"            '[[ "$t1" =~ ^mtk_[0-9a-f]{64}$ ]]'
check "ключи разные"                   '[ "$t1" != "$t2" ]'

MT_SRV_TOKEN="$t1"
t_respond 200 "ok"
code=$(mt_api POST /v1/agent/hello "$T_W/o" --data-urlencode "v=2.0"); rc=$?
a="$T_W/curl/argv.1"
check "код ответа и rc"                '[ "$code" = 200 ] && [ $rc = 0 ]'
check "ключа нет в argv"               '! grep -qF "$t1" "$a"'
check "ключ — в конфиге из stdin"      'grep -qxF "header = \"Authorization: Bearer $t1\"" "$T_W/curl/stdin.1"'
check "только https, без -L/-k"        'grep -qx -- "--proto" "$a" && grep -qx -- "--proto-redir" "$a" && ! grep -qxE -- "-L|-k|--insecure|--location" "$a"'
check "адрес = база + путь"            'grep -qx "https://bot.test/v1/agent/hello" "$a"'
t_respond 200 "ok"
( set -x; mt_api POST /v1/x "$T_W/o" >/dev/null ) 2> "$T_W/trace"
check "bash -x не печатает ключ"       '! grep -qF "$t1" "$T_W/trace"'

printf 'ok abc 600 47\r\nline2\n' > "$T_W/r1"; mt_resp "$T_W/r1"
check "CRLF: глагол и токены"          '[ "$MT_RESP_V" = ok ] && [ "${MT_RESP_A[0]}" = abc ] && [ "${MT_RESP_A[2]}" = 47 ]'
printf 'pending' > "$T_W/r2"; mt_resp "$T_W/r2"
check "без перевода строки в конце"    '[ "$MT_RESP_V" = pending ]'
: > "$T_W/r3"; mt_resp "$T_W/r3"; rc=$?
check "пустой ответ → 1"               '[ $rc = 1 ]'
out=$(mt_clean $'\e[2J\e]0;x\aOK\xc2\x9b[1mИван')
check "mt_clean: нет ESC/BEL"          '! printf "%s" "$out" | LC_ALL=C grep -q "$(printf "[\001-\037\177]")"'
check "mt_clean: нет CSI в UTF-8"      '! printf "%s" "$out" | LC_ALL=C grep -qF "$(printf "\302\233")"'
check "mt_clean: текст и кириллица целы" '[[ "$out" == *OK* && "$out" == *Иван ]]'

MT_SRV_ID="AbCdEf123456"; MT_API="https://bot.test"; MT_BOT="test_bot"; MT_SRV_TOKEN="$t1"
mt_conf_save; MT_SRV_ID=""; MT_SRV_TOKEN=""; MT_API=""; MT_BOT=""
mt_conf_load; rc=$?
check "конфиг: записать и прочитать"   '[ $rc = 0 ] && [ "$MT_SRV_ID" = AbCdEf123456 ] && [ "$MT_SRV_TOKEN" = "$t1" ] && [ "$MT_API" = https://bot.test ]'
t_is_linux && check "права 0600 и 0700" '[ "$(stat -c %a "$MT_CONF")" = 600 ] && [ "$(stat -c %a "$MT_STATE_DIR")" = 700 ]'
printf 'MT_SRV_ID=AbCdEf123456\nMT_SRV_TOKEN=$(touch %s/pwn)\nMT_API=https://bot.test\nMT_BOT=test_bot\n' "$T_W" > "$MT_CONF"
mt_conf_load; rc=$?
check "подстановка не исполняется → 78" '[ $rc = 78 ] && [ ! -e "$T_W/pwn" ]'
printf 'MT_SRV_ID=AbCdEf123456\nMT_SRV_TOKEN=%s\nMT_API=https://bot.test\nMT_BOT=test_bot\nPATH=/tmp\n' "$t1" > "$MT_CONF"
mt_conf_load; rc=$?
check "чужой ключ в конфиге → 78"      '[ $rc = 78 ]'
rm -f "$MT_CONF"; mt_conf_load; rc=$?
check "нет конфига → 1"                '[ $rc = 1 ]'
for f in "$T_ROOT"/tests/fixtures/protocol/*.txt; do
    mt_resp "$f"
    check "фикстура $(basename "$f")" '[[ " ok pending approved denied expired cancelled idle job revoked retry upgrade err blocked " == *" $MT_RESP_V "* ]]'
done
t_finish
