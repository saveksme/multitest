#!/usr/bin/env bash
# Агент: задания из Telegram, лимиты, revoked, backoff, служба — на поддельном curl.
. "$(dirname "$0")/lib.sh"
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
t_fake_curl
MT_STATE_DIR="$T_W/state"; MT_CONF="$MT_STATE_DIR/agent.conf"
MT_AGENT_DIR="$T_W/agent"; MT_AGENT_UNIT="$T_W/unit/multitest-agent.service"; MT_SYSTEMD="$T_W/systemd"
MT_LOCK_FILE="$T_W/lock"
mkdir -p "$MT_AGENT_DIR" "$T_W/unit" "$MT_SYSTEMD"
sleep() { :; }
systemctl() { echo "systemctl $*" >> "$T_W/systemctl"; }
capture_test()      { echo "CAPTURE $1" >> "$T_W/calls"; echo "вывод" > "$2"; }
parse_test_output() { :; }
install_deps_for()  { :; }
render_and_upload_summary() { echo "RENDER job=$MT_JOB_ID imgdb=$MT_IMGDB" >> "$T_W/calls"; : > "$SUMMARY_DIR/tg.ok"; }
fresh() { rm -rf "$T_W/curl" "$T_W/calls" "$T_W/systemctl"; mkdir -p "$T_W/curl"; }
pair()  { MT_SRV_ID=AbCdEf123456; MT_SRV_TOKEN="mtk_$(printf 'f%.0s' {1..64})"; MT_API=https://bot.test; MT_BOT=test_bot; mt_conf_save; }
JID=Jx7Kp2Lm9Qr4St6Uv8Wz
pair; mt_headless_init

# 1. Задание целиком: start, progress по тесту, сводка с job_id, без imgdb
fresh; rm -f "$MT_AGENT_DIR/agent.runs"
t_respond 200 "ok"; t_respond 200 "ok"; t_respond 200 "ok"
mt_agent_job "job $JID ip_region,sysbench_cpu" > "$T_W/out" 2>&1
check "оба теста прогнаны"               'grep -c "^CAPTURE" "$T_W/calls" | grep -qx 2'
check "сводка с job_id и без imgdb"      'grep -qx "RENDER job=$JID imgdb=0" "$T_W/calls"'
check "события: start, progress ×2"      '[ "$(grep -hx "type=start\|type=progress" "$T_W"/curl/argv.* | sort | uniq -c | tr -s " " | sed "s/^ //")" = "1 type=progress
1 type=start" ] || [ "$(grep -hx "type=progress" "$T_W"/curl/argv.* | wc -l)" = 2 ]'
check "адрес события — своё задание"     'grep -qx "https://bot.test/v1/agent/jobs/$JID/event" "$T_W/curl/argv.1"'
check "запуск записан в лимиты"          '[ "$(wc -l < "$MT_AGENT_DIR/agent.runs")" = 1 ]'

# 2. То же задание второй раз — игнор
fresh
mt_agent_job "job $JID ip_region" > "$T_W/out" 2>&1
check "повтор задания игнорируется"      '[ ! -e "$T_W/calls" ] && [ "$(t_calls)" = 0 ]'

# 3. Кривые строки и инъекции — ничего не запускаем
for bad in "job short ip_region" "job ${JID}X0000000000000 ip_region" "job $JID ip_region;rm" \
           "job $JID run_ip_region" "job $JID ip_region extra" 'job '"$JID"' $(id)'; do
    fresh
    mt_agent_job "$bad" > "$T_W/out" 2>&1
    check "отказ: $bad" '[ ! -e "$T_W/calls" ]'
done

# 4. Незнакомый тест — failed bad_tests
fresh; t_respond 200 "ok"
mt_agent_job "job Jaaaaaaaaaaaaaaaaaaa nope_test" > "$T_W/out" 2>&1
check "незнакомый тест → bad_tests"      '[ ! -e "$T_W/calls" ] && grep -qx "reason=bad_tests" "$T_W/curl/argv.1"'

# 5. Лимиты: раньше 15 минут — отказ с ожиданием
fresh; t_respond 200 "ok"
mt_agent_job "job Jbbbbbbbbbbbbbbbbbbb ip_region" > "$T_W/out" 2>&1
check "лимит частоты → local_limit"      '[ ! -e "$T_W/calls" ] && grep -qx "reason=local_limit" "$T_W/curl/argv.1" && grep -qE "^wait=[0-9]+$" "$T_W/curl/argv.1"'
printf -v now '%(%s)T' -1
printf '%s 1\n%s 1\n' $(( now - 7200 )) $(( now - 5000 )) > "$MT_AGENT_DIR/agent.runs"
w=$(mt_agent_limits "yabs"); rc=$?
check "тяжёлых больше двух в сутки — нельзя" '[ $rc = 1 ] && [ "$w" = 3600 ]'
w=$(mt_agent_limits "ip_region"); rc=$?
check "лёгкий тест при этом можно"       '[ $rc = 0 ]'
printf '%s 0\n' $(( now + 99999 )) > "$MT_AGENT_DIR/agent.runs"
w=$(mt_agent_limits "ip_region"); rc=$?
check "время из будущего не ломает лимит" '[ $rc = 1 ] && [ "$w" -le 900 ]'
rm -f "$MT_AGENT_DIR/agent.runs"

# 6. «Остановить» между тестами: ответ cancel на progress — дальше не идём
fresh
t_respond 200 "ok"; t_respond 200 "cancel"; t_respond 200 "ok"
mt_agent_job "job Jccccccccccccccccccc ip_region,sysbench_cpu,ping_map" > "$T_W/out" 2>&1
check "после cancel тест не начат"       '[ "$(grep -c "^CAPTURE" "$T_W/calls")" = 1 ]'
check "сводка из готового всё равно ушла" 'grep -q "^RENDER" "$T_W/calls"'
rm -f "$MT_AGENT_DIR/agent.runs"

# 7. Главный цикл: голый 401 ключ не трогает
fresh; t_respond 200 "ok"; t_respond 401 "err auth"; t_respond 401 "err auth"
MT_AGENT_POLLS=2 mt_agent_main > "$T_W/out" 2>&1; rc=$?
check "401 → ключ цел, служба на месте"  '[ -e "$MT_CONF" ] && [ ! -e "$T_W/systemctl" ]'
check "hello с agent=1 и лимитами"       'grep -qx "agent=1" "$T_W/curl/argv.1" && grep -qx "lim=900,6,2" "$T_W/curl/argv.1"'
check "опрос — GET с wait"               'grep -qx -- "-G" "$T_W/curl/argv.2" && grep -qx "wait=25" "$T_W/curl/argv.2"'

# 8. revoked → ключ и служба прочь, выход 78
fresh; : > "$MT_AGENT_UNIT"; t_respond 200 "ok"; t_respond 200 "revoked"
MT_AGENT_POLLS=5 mt_agent_main > "$T_W/out" 2>&1; rc=$?
check "revoked → 78, ключа и unit нет"   '[ $rc = 78 ] && [ ! -e "$MT_CONF" ] && [ ! -e "$MT_AGENT_UNIT" ] && grep -q "disable multitest-agent" "$T_W/systemctl"'
check "disable без --now (не убить себя)" '! grep -q -- "--now" "$T_W/systemctl"'

# 9. Нет конфига → 78, без запросов
fresh
mt_agent_main > "$T_W/out" 2>&1; rc=$?
check "без ключа → 78"                   '[ $rc = 78 ] && [ "$(t_calls)" = 0 ]'

# 10. Установка службы: unit с нужными строками
pair; fresh
bash() { if [[ "${2:-}" == --agent-selftest ]]; then echo agent-ok; else command bash "$@"; fi; }
install() { cp "${@: -2:1}" "${@: -1}" 2>/dev/null || true; }
mt_agent_install > "$T_W/out" 2>&1; rc=$?
unset -f bash install
check "служба установлена"               '[ $rc = 0 ] && [ -f "$MT_AGENT_UNIT" ] && grep -q "enable --now multitest-agent" "$T_W/systemctl"'
check "unit: --agent, 78 без рестарта"   'grep -q "^ExecStart=/usr/local/bin/multitest --agent$" "$MT_AGENT_UNIT" && grep -q "^RestartPreventExitStatus=78$" "$MT_AGENT_UNIT"'
check "unit: SHELL и рабочий каталог"    'grep -q "^Environment=SHELL=/bin/bash HOME=/root" "$MT_AGENT_UNIT" && grep -q "^WorkingDirectory=$MT_AGENT_DIR/work$" "$MT_AGENT_UNIT"'
check "unit: без Nice/ProtectSystem"     '! grep -qE "^(Nice|IOSchedulingClass|ProtectSystem|UMask)=" "$MT_AGENT_UNIT"'
t_finish
