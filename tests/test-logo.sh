#!/usr/bin/env bash
# Шапка меню: надпись MULTITEST и подпись — каждый вариант укладывается в свою
# ширину терминала.
. "$(dirname "$0")/lib.sh"
export LC_ALL=C.UTF-8
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
stty() { return 1; }
tput() { echo "$T_COLS"; }
logo_at() {   # <колонки> → строки шапки в $T_W/logo.<колонки>
    T_COLS=$1; mt_logo_lines
    printf '%s\n' "${MT_LOGO[@]}" > "$T_W/logo.$1"
}
widest() { local l m=0; while IFS= read -r l; do (( ${#l} > m )) && m=${#l}; done < "$1"; echo "$m"; }

for c in 120 50 49 30; do logo_at "$c"; done
{ printf '  %s\n' "${MT_LOGO_WORD[@]}"; echo
  echo "  v3.0 ─ диагностика и тестирование сервера"; echo "  IP · DPI · iPerf3 · YABS · Telegram"; } > "$T_W/want"
check "версия 3.0"                     '[ "$SCRIPT_VERSION" = 3.0 ]'
check "120 кол.: надпись и подпись"    'cmp -s "$T_W/want" "$T_W/logo.120"'
check "50 кол.: влезает (≤ 49)"        '[ "$(widest "$T_W/logo.50")" -le 49 ] && cmp -s "$T_W/want" "$T_W/logo.50"'
check "49 кол.: две строки текстом"    '! grep -qF "|_|  |_|" "$T_W/logo.49" && grep -qxF "  MULTITEST v3.0" "$T_W/logo.49"'
check "без терминала — без цвета"      '! grep -q $'"'"'\033'"'"' "$T_W"/logo.*'
check "хвостов пробелов нет"           '! grep -q " $" "$T_W"/logo.*'
t_finish
