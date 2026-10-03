#!/usr/bin/env bash
# Доставка сводки в Telegram — на поддельном curl.
. "$(dirname "$0")/lib.sh"
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
t_fake_curl
MT_STATE_DIR="$T_W/state"; MT_CONF="$MT_STATE_DIR/agent.conf"
sleep() { :; }
pair()  { MT_SRV_ID=AbCdEf123456; MT_SRV_TOKEN="mtk_$(printf 'e%.0s' {1..64})"; MT_API=https://bot.test; MT_BOT=test_bot; mt_conf_save; }
fresh() { rm -rf "$T_W/curl"; mkdir -p "$T_W/curl"; }
newrun() { SUMMARY_DIR=$(mktemp -d "$T_W/run.XXXX"); printf 'v\0371\n' > "$SUMMARY_DIR/summary.txt"
    mkdir -p "$SUMMARY_DIR/pages"; : > "$SUMMARY_DIR/pages.list"
    for p in 01-cover 02-ip_region 03-yabs; do printf '\211PNG\r\n\032\n' > "$SUMMARY_DIR/pages/$p.png"
        echo "$SUMMARY_DIR/pages/$p.png" >> "$SUMMARY_DIR/pages.list"; done; }
fparts() { awk 'p{print;p=0} $0=="-F"{p=1}' "$1"; }

pair; newrun; fresh; t_respond 200 "ok R1a2b3c4d5"
step_tg_deliver; rc=$?; a="$T_W/curl/argv.1"
check "ok → rc 0 и tg.ok с run_id"      '[ $rc = 0 ] && [ "$(cat "$SUMMARY_DIR/tg.ok")" = R1a2b3c4d5 ]'
check "части: summary, key, страницы"   '[ "$(fparts "$a" | cut -d= -f1 | tr "\n" " ")" = "summary key page page page " ]'
check "первая страница — обложка"       'fparts "$a" | grep -m1 "^page=" | grep -q 01-cover'
check "ключ идемпотентности"            'fparts "$a" | grep -qxE "key=run-[0-9a-f]{16}"'
check "адрес runs"                      'grep -qx "https://bot.test/v1/agent/runs" "$a"'

newrun; fresh; t_respond 200 "retry 1"; t_respond 200 "ok R2"
step_tg_deliver; rc=$?
check "retry → повтор с тем же ключом"  '[ $rc = 0 ] && [ "$(fparts "$T_W/curl/argv.1" | grep ^key=)" = "$(fparts "$T_W/curl/argv.2" | grep ^key=)" ]'

newrun; fresh; t_respond 200 "blocked"
step_tg_deliver; rc=$?
check "blocked → маркер, конфиг цел"    '[ $rc != 0 ] && [ -e "$SUMMARY_DIR/tg.blocked" ] && [ -e "$MT_CONF" ]'

newrun; fresh; t_respond 401 "err auth"
step_tg_deliver; rc=$?
check "голый 401 → tg.err, ключ цел"    '[ $rc != 0 ] && [ -e "$SUMMARY_DIR/tg.err" ] && [ -e "$MT_CONF" ] && [ "$(t_calls)" = 1 ]'

newrun; fresh; t_respond 200 "revoked"
step_tg_deliver; rc=$?
check "revoked → маркер, конфиг стёрт"  '[ $rc != 0 ] && [ -e "$SUMMARY_DIR/tg.revoked" ] && [ ! -e "$MT_CONF" ]'
mt_tg_report > "$T_W/rep" 2>&1
check "revoked → одна понятная строка"  'grep -qF "сервер отвязан в боте" "$T_W/rep"'

pair; newrun; rm "$SUMMARY_DIR/pages.list"; fresh; t_respond 200 "ok R3"
step_tg_deliver
check "без страниц — только сводка"     '[ -e "$SUMMARY_DIR/tg.ok" ] && ! fparts "$T_W/curl/argv.1" | grep -q "^page="'

newrun; fresh; t_respond 502 "<html>502</html>"; t_respond 502 "<html>502</html>"; t_respond 502 "<html>502</html>"
step_tg_deliver; rc=$?
check "502 → tg.err, без HTML внутри"   '[ $rc != 0 ] && [ -e "$SUMMARY_DIR/tg.err" ] && ! grep -q "<html>" "$SUMMARY_DIR/tg.err"'

MT_TG=0; check "MT_TG=0 → выключено"     '! mt_tg_enabled'; MT_TG=1

# --- один альбом в Telegram: склейка лишних страниц --------------------------------------
plan=$(mt_tg_plan 1280 2107 1817 1579 1674 1427 1733 1053)
check "≤ 9 страниц — без склеек"            '[ "$(printf "%s\n" "$plan" | tr "\n" " ")" = "1 2 3 4 5 6 7 " ]'
plan=$(mt_tg_plan 1280 2107 1817 847 847 1579 1674 1427 1733 1053 1503 1273 2445)
order=$(printf '%s\n' "$plan" | awk '{print $1; if ($2) print $2}' | tr '\n' ' ')
check "12 страниц → 9 картинок"             '[ "$(printf "%s\n" "$plan" | wc -l | tr -d " ")" = 9 ]'
check "все страницы по порядку, по разу"    '[ "$order" = "1 2 3 4 5 6 7 8 9 10 11 12 " ]'
check "две короткие — одна под другой"      'printf "%s\n" "$plan" | grep -qx "3 4 stack"'
check "две длинные — рядом"                 'printf "%s\n" "$plan" | grep -qx "1 2 side"'

SUMMARY_DIR=$(mktemp -d "$T_W/alb.XXXX"); mkdir -p "$SUMMARY_DIR/pages"; : > "$SUMMARY_DIR/pages.dim"
for i in 0 1 2 3 4 5 6 7 8 9 10 11 12; do
    f=$(printf '%s/pages/%02d.png' "$SUMMARY_DIR" $(( i + 1 ))); printf '\211PNG\r\n\032\n' > "$f"
    printf '%s\t1280\t%s\n' "$f" $(( 900 + i * 100 )) >> "$SUMMARY_DIR/pages.dim"
done
cut -f1 "$SUMMARY_DIR/pages.dim" > "$SUMMARY_DIR/pages.list"
mt_join_pages() { printf '%s %s %s %s\n' "$2" "${3##*/}" "${5##*/}" "$7" >> "$SUMMARY_DIR/joins"; printf 'j' > "$1"; }
mt_tg_pages; rc=$?
check "13 картинок → 10 для бота"           '[ $rc = 0 ] && [ "$(wc -l < "$SUMMARY_DIR/tg-pages.list" | tr -d " ")" = 10 ]'
check "обложка — первой и без склейки"      '[ "$(head -1 "$SUMMARY_DIR/tg-pages.list")" = "$SUMMARY_DIR/pages/01.png" ]'
check "три склейки соседних страниц"        '[ "$(wc -l < "$SUMMARY_DIR/joins" | tr -d " ")" = 3 ] && ! grep -q " 01.png " "$SUMMARY_DIR/joins"'
pair; fresh; t_respond 200 "ok R5"; printf 'v\0371\n' > "$SUMMARY_DIR/summary.txt"
step_tg_deliver
check "бот получает склеенный список"       '[ "$(fparts "$T_W/curl/argv.1" | grep -c "^page=")" = 10 ] && fparts "$T_W/curl/argv.1" | grep -q "tg-"'
rm -f "$SUMMARY_DIR/pages.list"; fresh; t_respond 200 "ok R6"; rm -f "$SUMMARY_DIR/tg.key"
step_tg_deliver
check "нет страниц — склейки не шлются"     '! fparts "$T_W/curl/argv.1" | grep -q "^page="'

SUMMARY_DIR=$(mktemp -d "$T_W/alb.XXXX"); mkdir -p "$SUMMARY_DIR/pages"; : > "$SUMMARY_DIR/pages.dim"
for i in 1 2 3; do printf '%s/pages/%02d.png\t1280\t1500\n' "$SUMMARY_DIR" "$i" >> "$SUMMARY_DIR/pages.dim"; done
mt_tg_pages
check "≤ 10 картинок — список как есть"     '[ "$(wc -l < "$SUMMARY_DIR/tg-pages.list" | tr -d " ")" = 3 ] && [ ! -e "$SUMMARY_DIR/joins" ]'


pair; newrun
mt_album_plan()     { MT_PAGE_IDX=(0 1); MT_OFF_NAMES=(); }
step_build_pages()  { return 0; }
step_tg_deliver()   { echo R9 > "$SUMMARY_DIR/tg.ok"; }
step_upload_album() { return 1; }
render_album_summary > "$T_W/out" 2>&1; rc=$?
check "TG есть, imgdb упал → 0, без простыни" '[ $rc = 0 ] && ! grep -qF "одной картинкой" "$T_W/out" && grep -qF "Сводка отправлена в Telegram" "$T_W/out"'
t_finish
