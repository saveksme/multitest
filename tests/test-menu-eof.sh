#!/usr/bin/env bash
# Конец ввода в любом меню и вопросе — выход, а не круг: ни один цикл меню не крутится на
# EOF (на проде меню на stdin=/dev/null давало ~500 перерисовок в секунду).
. "$(dirname "$0")/lib.sh"
t_need timeout
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
MT_STATE_DIR="$T_W/state"; MT_CONF="$MT_STATE_DIR/agent.conf"; MT_SYSTEMD="$T_W/nosystemd"
MT_AGENT_UNIT="$T_W/unit/multitest-agent.service"
clear() { :; }
missing_deps_for() { :; }
eof() {   # <команда…> — на /dev/null: код и объём вывода; 124 — повисла
    ( timeout 5 bash -c 'source "$1"; shift; "$@"; echo "RETURNED $?"' _ "$T_W/env.sh" "$@" ) </dev/null >"$T_W/o" 2>&1
    echo $?
}
# функции и переменные этой оболочки — в дочернюю (timeout запускает отдельный bash)
{ declare -p | grep -vE '^declare -[a-zA-Z-]*r'; declare -f; } > "$T_W/env.sh" 2>/dev/null

rc=$(eof pause_prompt)
check "pause_prompt: EOF — выход, не возврат"    '[ "$rc" = 0 ] && ! grep -q RETURNED "$T_W/o"'
rc=$(eof show_utilities_menu)
check "Утилиты: EOF — выход"                     '[ "$rc" = 0 ] && [ "$(grep -c "Выберите" "$T_W/o")" = 1 ]'
rc=$(eof mt_tg_menu)
check "Telegram-бот: EOF — выход"               '[ "$rc" = 0 ] && [ "$(grep -c "Выберите" "$T_W/o")" = 1 ]'
# выбор тестов стрелками: EOF — не «запустить всё» и не круг
all_funcs=(run_ip_region run_yabs); all_names=("IP Region" "YABS"); all_secs=(10 600)
{ declare -p all_funcs all_names all_secs; } >> "$T_W/env.sh"
rc=$(eof mt_select_tests)
check "выбор тестов: EOF — выход, тесты не идут" '[ "$rc" = 0 ] && ! grep -q RETURNED "$T_W/o" && [ "$(grep -c "что запускать" "$T_W/o")" = 1 ]'
# вопрос о BBR — только при TTY; запасной ввод номеров тестов — тоже
rc=$(eof recommend_bbr_cake)
check "BBR без TTY: молча дальше"                '[ "$rc" = 0 ] && grep -q "RETURNED 0" "$T_W/o"'

# Меню в настоящем терминале (pty): работает как раньше, Ctrl+D на приглашении — выход 0.
if t_is_linux && command -v python3 >/dev/null 2>&1; then
    cat > "$T_W/pty.py" <<'EOF'
import os, pty, select, sys, time
script, = sys.argv[1:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash", script])
buf = b""
def wait_for(token, t=15):
    global buf
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                return False
            if not chunk:
                return False
            buf += chunk
            if token.encode() in buf:
                return True
    return False
ok = wait_for("Выберите пункт")
os.write(fd, b"99\r")
ok = ok and wait_for("Неверный выбор")
os.write(fd, b"\r")
n = buf.count("Выберите пункт".encode())
ok = ok and wait_for("Выберите пункт") and buf.count("Выберите пункт".encode()) > n
os.write(fd, b"\x04")                                  # Ctrl+D на пустой строке — EOF
end, status = time.time() + 5, None
while time.time() < end and status is None:
    try:
        os.read(fd, 65536)
    except OSError:
        pass
    p, st = os.waitpid(pid, os.WNOHANG)
    if p:
        status = os.waitstatus_to_exitcode(st)
    time.sleep(0.05)
print("menu=%s exit=%s bytes=%d" % (ok, status, len(buf)))
EOF
    out=$(MT_STATE_DIR="$T_W/state" MT_SYSTEMD="$T_W/nosystemd" MT_AGENT_UNIT="$T_W/unit/x.service" \
        TERM=xterm timeout 40 python3 "$T_W/pty.py" "$T_ROOT/multitest.sh" 2>&1)
    check "TTY: меню, «Неверный выбор», Enter — как раньше" '[[ "$out" == *"menu=True"* ]]'
    check "TTY: Ctrl+D на приглашении — выход 0"          '[[ "$out" == *"exit=0"* ]]'
else
    echo "  skip: pty-проверка меню — нужен Linux и python3"
fi
t_finish
