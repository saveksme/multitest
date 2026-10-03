# Общие помощники тестов. Подключать: . "$(dirname "$0")/lib.sh"
# Скрипт подключать на верхнем уровне теста, не из функции (иначе declare -A станут локальными):
#   MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
T_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T_W="$(mktemp -d)"; trap 'rm -rf "$T_W"' EXIT
T_FAIL=0

check() { if eval "$2"; then echo "  ok: $1"; else echo "  FAIL: $1"; T_FAIL=1; fi; }
t_need() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || { echo "SKIP: нет $c"; exit 77; }; done; }
t_is_linux() { [[ "$(uname -s)" == Linux ]]; }
t_python() {
    local c; for c in python3 python "py -3"; do
        if $c -c 'import ssl, email' >/dev/null 2>&1; then read -ra T_PY <<< "$c"; return 0; fi
    done
    echo "SKIP: нет python3"; exit 77
}
t_finish() { echo; if (( T_FAIL )); then echo "ЕСТЬ ОШИБКИ"; exit 1; fi; echo "ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ"; }

# Поддельный curl: каждый вызов №N пишет argv (по аргументу в строке) в curl/argv.N, stdin при
# «-K -» — в curl/stdin.N; отдаёт тело curl/resp.N.body в файл из «-o» и печатает код из
# curl/resp.N.code, если есть «-w». T_CURL_KILL_AT=N — перед ответом №N послать SIGINT в
# T_CURL_KILL_PID (имитация Ctrl+C).
t_fake_curl() {
    mkdir -p "$T_W/bin" "$T_W/curl"
    cat > "$T_W/bin/curl" <<'EOF'
#!/usr/bin/env bash
d="${T_CURL_DIR:?}"; n=$(( $(cat "$d/n" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$d/n"
printf '%s\n' "$@" > "$d/argv.$n"
[[ " $* " == *" -K - "* ]] && cat > "$d/stdin.$n"
out=""; fmt=""; prev=""
for a in "$@"; do case "$prev" in -o) out="$a" ;; -w) fmt="$a" ;; esac; prev="$a"; done
[[ -n "${T_CURL_KILL_AT:-}" && "$T_CURL_KILL_AT" == "$n" ]] && kill -INT "$T_CURL_KILL_PID"
[[ -e "$d/resp.$n.body" ]] || { echo "fake curl: нет ответа №$n" >&2; [[ -n "$fmt" ]] && printf '000'; exit 7; }
if [[ -n "$out" ]]; then cp "$d/resp.$n.body" "$out"; else cat "$d/resp.$n.body"; fi
[[ -n "$fmt" ]] && cat "$d/resp.$n.code"
exit 0
EOF
    chmod +x "$T_W/bin/curl"
    export T_CURL_DIR="$T_W/curl"
    MT_CURL="$T_W/bin/curl"
}
t_respond() {   # <код> <строка>… — следующий по счёту ответ
    local d="$T_W/curl" i
    i=$(( $(ls "$d"/resp.*.code 2>/dev/null | wc -l) + 1 ))
    printf '%s' "$1" > "$d/resp.$i.code"; shift
    printf '%s\n' "$@" > "$d/resp.$i.body"
}
t_calls() { cat "$T_W/curl/n" 2>/dev/null || echo 0; }
