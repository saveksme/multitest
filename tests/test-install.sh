#!/usr/bin/env bash
# Установка и агент: служба живёт в своей копии скрипта, которую обычная установка не трогает;
# ставится только сборка с агентом. Сюда из прода: /usr/local/bin/multitest переписали версией
# 2.0 без агента, служба (--agent, stdin=/dev/null) ушла в меню и залила диск журналом.
. "$(dirname "$0")/lib.sh"
t_need timeout cksum
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
t_fake_curl
MT_STATE_DIR="$T_W/state"; MT_CONF="$MT_STATE_DIR/agent.conf"
MT_AGENT_DIR="$T_W/agent"; MT_SYSTEMD="$T_W/systemd"; MT_LOCK_FILE="$T_W/lock"
MT_AGENT_UNIT="$T_W/unit/multitest-agent.service"
MT_CLI_BIN="$T_W/usr/bin/multitest"; MT_AGENT_BIN="$T_W/usr/lib/multitest/multitest"
mkdir -p "$MT_AGENT_DIR" "$T_W/unit" "$MT_SYSTEMD" "$T_W/usr/bin"
# T_ACTIVE=1 — служба уже идёт (is-active отвечает «да»)
systemctl() { echo "systemctl $*" >> "$T_W/systemctl"; [[ "$1" != is-active || "${T_ACTIVE:-0}" == 1 ]]; }
mt_agent_reexec() { echo "REEXEC $MT_AGENT_BIN" >> "$T_W/calls"; }
cp "$T_ROOT/multitest.sh" "$T_W/new.sh"
# Версия 2.0 как на проде: флаги не разбирает, меню крутит на EOF.
cat > "$T_W/old.sh" <<'EOF'
#!/bin/bash
SCRIPT_VERSION="2.0"
pause_prompt() { echo "Нажмите Enter для возврата в меню..."; read -r; }
while true; do
    printf '%s\n' "== MULTITEST ==" " 1) IP Region" " 0) Выход"
    printf 'Выберите пункт [0-14]: '
    read -r choice
    case "$choice" in 0) exit 0 ;; *) echo "Неверный выбор. Попробуйте снова."; pause_prompt ;; esac
done
EOF
fresh() { rm -rf "$T_W/curl" "$T_W/systemctl" "$T_W/calls" "$MT_AGENT_UNIT" "$MT_CLI_BIN" "$T_W/usr/lib"; mkdir -p "$T_W/curl"; }
same() { [ -f "$1" ] && [ -f "$2" ] && [ "$(cksum < "$1")" = "$(cksum < "$2")" ]; }
unit_ok() {
    grep -qx "ExecStart=$MT_AGENT_BIN --agent" "$MT_AGENT_UNIT" && grep -qx "StandardInput=null" "$MT_AGENT_UNIT" \
        && grep -qx "LogRateLimitIntervalSec=30s" "$MT_AGENT_UNIT" && grep -qx "LogRateLimitBurst=1000" "$MT_AGENT_UNIT" \
        && grep -qx "RestartPreventExitStatus=78" "$MT_AGENT_UNIT" && grep -qx "StartLimitBurst=5" "$MT_AGENT_UNIT"
}

# 0. Фикстура и правда воспроизводит прод: ~мегабайт за пару секунд
n=$(timeout 2 bash "$T_W/old.sh" --agent </dev/null 2>&1 | wc -c)
check "фикстура 2.0: --agent на /dev/null — поток меню"  '[ "$n" -gt 100000 ]'

# 1. Проверка кандидата: старая версия не проходит, быстро и без залитой памяти
check "новая сборка умеет агента"                      'mt_agent_ok "$T_W/new.sh"'
t0=$SECONDS; mt_agent_ok "$T_W/old.sh"; rc=$?
check "2.0 — не умеет, проверка не виснет"              '[ $rc != 0 ] && [ $(( SECONDS - t0 )) -lt 20 ]'
printf '<html>404</html>\n' > "$T_W/html.sh"; printf '#!/bin/bash\nif then\n' > "$T_W/broken.sh"
check "страница ошибки и битый скрипт — не умеют"      '! mt_agent_ok "$T_W/html.sh" && ! mt_agent_ok "$T_W/broken.sh"'

# 2. Включение агента: копия службы отдельно от /usr/local/bin, unit с потолком журнала
fresh; MT_SELF="$T_W/new.sh"
mt_agent_install > "$T_W/out" 2>&1; rc=$?
check "агент: установлен"                              '[ $rc = 0 ] && grep -q "enable --now multitest-agent" "$T_W/systemctl"'
check "агент: своя копия и команда multitest"          'same "$MT_AGENT_BIN" "$T_W/new.sh" && same "$MT_CLI_BIN" "$T_W/new.sh" && [ -x "$MT_AGENT_BIN" ]'
check "unit: копия службы, stdin=null, потолок журнала" 'unit_ok'
check "unit: SHELL и рабочий каталог"                  'grep -q "^Environment=SHELL=/bin/bash HOME=/root" "$MT_AGENT_UNIT" && grep -qx "WorkingDirectory=$MT_AGENT_DIR/work" "$MT_AGENT_UNIT"'
fresh; MT_SELF="$T_W/old.sh"
mt_agent_install > "$T_W/out" 2>&1; rc=$?
check "агент из 2.0 — отказ, ничего не записано"       '[ $rc != 0 ] && [ ! -e "$MT_AGENT_UNIT" ] && [ ! -e "$MT_AGENT_BIN" ] && [ ! -e "$T_W/systemctl" ]'
# «Обновить агент» при работающей службе: новая копия и перезапуск, без enable --now
fresh; MT_SELF="$T_W/new.sh"; mt_agent_install >/dev/null 2>&1; rm -f "$T_W/systemctl"
T_ACTIVE=1 mt_agent_install > "$T_W/out" 2>&1; rc=$?
check "обновить агент: перезапуск без enable --now"    '[ $rc = 0 ] && grep -q "try-restart multitest-agent" "$T_W/systemctl" && ! grep -q -- "--now" "$T_W/systemctl"'

# 3. Инцидент: агент стоит, /usr/local/bin переписали версией 2.0 — служба не задета
fresh; MT_SELF="$T_W/new.sh"; mt_agent_install >/dev/null 2>&1
cp "$T_W/old.sh" "$MT_CLI_BIN"
exe=$(sed -n 's/^ExecStart=\(.*\) --agent$/\1/p' "$MT_AGENT_UNIT")
n=$(MT_STATE_DIR="$T_W/nostate" timeout 5 bash "$exe" --agent </dev/null 2>&1 | wc -c); rc=${PIPESTATUS[0]}
check "старый /usr/local/bin: служба — своя копия"      '[ "$exe" = "$MT_AGENT_BIN" ] && same "$exe" "$T_W/new.sh"'
check "служба после этого: выход 78, не меню"           '[ "$n" -lt 2000 ]'

# 4. --install: только сборка с агентом; есть служба — обновляет и её
fresh; MT_SELF="$T_W/new.sh"
mt_install > "$T_W/out" 2>&1; rc=$?
check "--install: файл → /usr/local/bin"               '[ $rc = 0 ] && same "$MT_CLI_BIN" "$T_W/new.sh" && [ ! -e "$MT_AGENT_UNIT" ] && [ ! -e "$T_W/systemctl" ]'
fresh; MT_SELF="$T_W/old.sh"
mt_install > "$T_W/out" 2>&1; rc=$?
check "--install 2.0 — отказ"                          '[ $rc != 0 ] && [ ! -e "$MT_CLI_BIN" ]'
fresh; MT_SELF="$T_W/new.sh"; mt_agent_install >/dev/null 2>&1
echo "# правка" >> "$T_W/new.sh"; rm -f "$T_W/systemctl"
mt_install > "$T_W/out" 2>&1; rc=$?
check "--install при службе: обе копии свежие"          '[ $rc = 0 ] && same "$MT_CLI_BIN" "$T_W/new.sh" && same "$MT_AGENT_BIN" "$T_W/new.sh" && unit_ok'
check "--install при службе: перезапуск, раз простаивает" 'grep -q "daemon-reload" "$T_W/systemctl" && grep -q "try-restart multitest-agent" "$T_W/systemctl"'
fresh; MT_SELF="$T_W/old.sh"; printf '[Service]\nExecStart=%s --agent\n' "$MT_AGENT_BIN" > "$MT_AGENT_UNIT"
mkdir -p "${MT_AGENT_BIN%/*}"; cp "$T_W/new.sh" "$MT_AGENT_BIN"
mt_install > "$T_W/out" 2>&1; rc=$?
check "--install 2.0 при службе: отказ, служба цела"   '[ $rc != 0 ] && [ ! -e "$MT_CLI_BIN" ] && same "$MT_AGENT_BIN" "$T_W/new.sh" && grep -q "multitest-agent" "$T_W/out"'
# запущен через bash <(curl …) — файла нет, качаем; пришла 2.0 — отказ
fresh; MT_SELF="/dev/fd/63"; t_respond 200 "$(cat "$T_W/old.sh")"
mt_install > "$T_W/out" 2>&1; rc=$?
check "--install из pipe: скачанная 2.0 — отказ"        '[ $rc != 0 ] && [ ! -e "$MT_CLI_BIN" ] && [ "$(t_calls)" = 1 ]'

# 5. Старый unit (ExecStart=/usr/local/bin/multitest) — агент сам переезжает в свою копию
fresh; cp "$T_W/new.sh" "$MT_CLI_BIN"; MT_SELF="$MT_CLI_BIN"
printf '[Service]\nExecStart=%s --agent\nStandardInput=null\n' "$MT_CLI_BIN" > "$MT_AGENT_UNIT"
pair() { MT_SRV_ID=AbCdEf123456; MT_SRV_TOKEN="mtk_$(printf 'f%.0s' {1..64})"; MT_API=https://bot.test; MT_BOT=test_bot; mt_conf_save; }
pair; t_respond 200 "ok"; MT_AGENT_POLLS=0
( mt_agent_main ) > "$T_W/out" 2>&1
check "старый unit: копия службы создана"              'same "$MT_AGENT_BIN" "$T_W/new.sh" && unit_ok'
check "старый unit: агент ушёл в свою копию"           'grep -qx "REEXEC $MT_AGENT_BIN" "$T_W/calls" && grep -q "daemon-reload" "$T_W/systemctl"'

# 6. Обычное обновление: новая версия в /usr/local/bin при запуске меню догоняет службу
fresh; MT_SELF="$T_W/new.sh"; mt_agent_install >/dev/null 2>&1; rm -f "$T_W/systemctl"
mt_agent_sync
check "та же версия — службу не трогаем"               '[ ! -e "$T_W/systemctl" ]'
echo "# ещё правка" >> "$T_W/new.sh"; cp "$T_W/new.sh" "$MT_CLI_BIN"; MT_SELF="$MT_CLI_BIN"
mt_agent_sync
check "новая версия — служба обновлена"                'same "$MT_AGENT_BIN" "$T_W/new.sh" && grep -q "try-restart multitest-agent" "$T_W/systemctl"'
cp "$T_W/old.sh" "$MT_CLI_BIN"; rm -f "$T_W/systemctl"
mt_agent_sync
check "2.0 в /usr/local/bin — служба не тронута"       'same "$MT_AGENT_BIN" "$T_W/new.sh" && [ ! -e "$T_W/systemctl" ]'
t_finish
