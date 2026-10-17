#!/usr/bin/env bash
# Подпись Multitest — клиент: код прогона, данные тестов, finish, ожидание картинок бота и
# запасные пути. На поддельном curl: токены только в stdin-конфиге, вызовы — одним семейством.
. "$(dirname "$0")/lib.sh"
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
t_fake_curl
export MT_PROOF=1 MT_PROOF_POLL=0
MT_STATE_DIR="$T_W/state"; MT_CONF="$MT_STATE_DIR/agent.conf"; MT_HEADLESS=1
sleep() { :; }
pair()  { MT_SRV_ID=AbCdEf123456; MT_SRV_TOKEN="mtk_$(printf 'e%.0s' {1..64})"; MT_API=https://bot.test; MT_BOT=test_bot; mt_conf_save; }
fresh() { rm -rf "$T_W/curl"; mkdir -p "$T_W/curl"; SUMMARY_DIR=$(mktemp -d "$T_W/run.XXXX"); }
PID=7K2Q9XWAPD3M; TOK="prf_$(printf 'a%.0s' {1..32})"
test_funcs=(run_ip_region run_iperf3_ru)
has()  { grep -qxF -- "$2" "$T_W/curl/argv.$1"; }
no_tok() { ! grep -rqF -- "$TOK" "$T_W"/curl/argv.* && ! grep -rqF -- "mtk_" "$T_W"/curl/argv.*; }

pair
# 1. start: код, токен 0600, семейство -4, без прокси; токен сервера — только в stdin
fresh; t_respond 200 "ok $PID $TOK 0"
mt_proof_start
check "start: код и токен сохранены"          'mt_proof_on && [ "$(cat "$SUMMARY_DIR/proof/id")" = $PID ] && [ "$(cat "$SUMMARY_DIR/proof/fam")" = 4 ]'
check "start: токен прогона — 0600"           '! t_is_linux || [ "$(stat -c %a "$SUMMARY_DIR/proof/token")" = 600 ]'
check "start: -4, без прокси, план"           'has 1 -4 && has 1 --noproxy && has 1 "plan=ip_region,iperf3_ru" && has 1 "https://bot.test/v1/proof/start"'
check "start: ключ сервера только в stdin"    'grep -qF "Authorization: Bearer mtk_" "$T_W/curl/stdin.1" && no_tok'

# 2. step: данные теста; токен прогона — заголовком из stdin
printf 'Консенсус\x1fNL\x1fpri\n' > "$SUMMARY_DIR/run_ip_region.metrics"
t_respond 200 "ok"; t_respond 200 "ok"
mt_proof_begin 1 run_ip_region
mt_proof_step 1 run_ip_region выполнен
check "begin: событие начала"                 'has 2 "event=begin" && has 2 "n=1" && has 2 "t=ip_region"'
check "step: статус и файлы данных"           'has 3 "status=ok" && has 3 "metrics@$SUMMARY_DIR/run_ip_region.metrics" && has 3 "services@$SUMMARY_DIR/run_ip_region.services"'
check "step: токен прогона в stdin, не в argv" 'grep -qx "header = \"X-Proof-Token: $TOK\"" "$T_W/curl/stdin.3" && no_tok && has 3 -4'

# 3. шаг не дошёл — отложен до finish; отказ бота (409) — без повторов
t_respond 000 ""; t_respond 000 ""; t_respond 000 ""
mt_proof_step 2 run_iperf3_ru ошибка
check "нет связи — 3 попытки и отложенный шаг" '[ "$(t_calls)" = 6 ] && grep -qxF "2	run_iperf3_ru	ошибка" "$SUMMARY_DIR/proof/late"'
t_respond 409 "err ip"
mt_proof_step 1 run_ip_region выполнен
check "409 — без повторов и отложенного шага"  '[ "$(t_calls)" = 7 ] && [ "$(grep -c . "$SUMMARY_DIR/proof/late")" = 1 ]'

# 4. finish: поздний шаг, факты, ожидание — done → tg.ok с id поста
t_respond 200 "ok"; t_respond 200 "ok queued 0"; t_respond 200 "rendering 0"; t_respond 200 "done RUNabc123456"
step_proof_finish; rc=$?
check "finish: дослан поздний шаг"            'has 8 "n=2" && has 8 "status=err"'
check "finish: факты и адрес finish"          'has 9 "https://bot.test/v1/proof/$PID/finish" && grep -q "^SYS_CPU	" "$SUMMARY_DIR/proof/facts"'
check "finish: done → tg.ok"                  '[ $rc = 0 ] && [ "$(cat "$SUMMARY_DIR/tg.ok")" = RUNabc123456 ] && [ -e "$SUMMARY_DIR/proof/done" ]'
mt_tg_report > "$T_W/rep" 2>&1
check "отчёт: подписанная сводка и код"       'grep -qF "Подписанная сводка отправлена" "$T_W/rep" && grep -qF "MT-7K2Q-9XWA-PD3M" "$T_W/rep"'

# 5. бот не нарисовал — failed: шаг падает, причина для человека
fresh; t_respond 200 "ok $PID $TOK 0"; mt_proof_start
t_respond 200 "ok queued 0"; t_respond 200 "failed render"
step_proof_finish; rc=$?
check "failed → rc 1 и причина"               '[ $rc = 1 ] && grep -qF "render" "$SUMMARY_DIR/proof/fail" && [ ! -e "$SUMMARY_DIR/tg.ok" ]'

# 6. отказ на start — без подписи и без следов
fresh; t_respond 200 "off busy"; mt_proof_start
check "off busy → без подписи"                '! mt_proof_on && [ ! -d "$SUMMARY_DIR/proof" ] && [ "$(t_calls)" = 1 ]'
fresh; mt_proof_start
check "нет связи по IPv4 — пробует IPv6"      '[ "$(t_calls)" = 2 ] && has 1 -4 && has 2 -6 && ! mt_proof_on'
fresh; t_respond 200 "ok short $TOK 0"; mt_proof_start
check "кривой код — без подписи"              '! mt_proof_on'
fresh; MT_PROOF=0 mt_proof_start
check "MT_PROOF=0 — ни одного вызова"         '[ "$(t_calls)" = 0 ] && ! mt_proof_on'
fresh; MT_ALBUM=0 mt_proof_start
check "длинная картинка — без подписи"        '[ "$(t_calls)" = 0 ]'
rm -f "$MT_CONF"; fresh; mt_proof_start
check "сервер не привязан — ни одного вызова"  '[ "$(t_calls)" = 0 ] && ! mt_proof_on'

# 7. альбом: подписано — агенту (без imgdb) свои картинки не нужны; не вышло — как раньше
pair
step_build_pages() { echo BUILD >> "$T_W/steps"; return 1; }
step_tg_deliver()  { echo DELIVER >> "$T_W/steps"; return 1; }
spin_run() { shift; "$@"; }
MT_STATUS=([run_ip_region]=выполнен [run_iperf3_ru]=выполнен)
fresh; rm -f "$T_W/steps"; t_respond 200 "ok $PID $TOK 0"; mt_proof_start
t_respond 200 "ok queued 0"; t_respond 200 "done RUN1"
MT_IMGDB=0 render_album_summary > "$T_W/out" 2>&1
check "подписано, без imgdb — без своих картинок" '[ ! -e "$T_W/steps" ] && grep -qF "Подписанная сводка" "$T_W/out"'
fresh; rm -f "$T_W/steps"; t_respond 200 "ok $PID $TOK 0"; mt_proof_start
t_respond 200 "ok queued 0"; t_respond 200 "failed render"
MT_IMGDB=0 render_album_summary > "$T_W/out" 2>&1
check "не нарисовал — как раньше: свои картинки"  'grep -qx BUILD "$T_W/steps" && grep -qF "Без подписи" "$T_W/out"'
t_finish
