#!/usr/bin/env bash
# Шапка меню: мику слева от надписи MULTITEST и подпись — каждый вариант
# укладывается в свою ширину терминала.
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
mono() {   # пиксель-арт без цвета: буквы → █, глаза и пусто → пробел
    local out='' c i
    for (( i = 0; i < ${#1}; i++ )); do
        c=${1:i:1}
        case $c in .|E) out+=' ' ;; *) out+='█' ;; esac
    done
    printf '%s' "$out"
}

for c in 120 68 67 50 49 30; do logo_at "$c"; done
{ for i in "${!MT_LOGO_MIKU[@]}"; do
      printf '  %s  %s\n' "$(mono "${MT_LOGO_MIKU[$i]}")" "${MT_LOGO_WORD[$i]}"
  done
  echo
  echo "  v3.3 ─ диагностика и тестирование сервера"; echo "  IP · DPI · iPerf3 · YABS · Telegram"; } > "$T_W/want"
{ printf '  %s\n' "${MT_LOGO_WORD[@]}"; echo
  echo "  v3.3 ─ диагностика и тестирование сервера"; echo "  IP · DPI · iPerf3 · YABS · Telegram"; } > "$T_W/want-word"
check "версия 3.3"                     '[ "$SCRIPT_VERSION" = 3.3 ]'
check "120 кол.: мику, надпись, подпись" 'cmp -s "$T_W/want" "$T_W/logo.120"'
check "68 кол.: мику влезает (≤ 67)"   '[ "$(widest "$T_W/logo.68")" -le 67 ] && cmp -s "$T_W/want" "$T_W/logo.68"'
check "67 кол.: только надпись"        '! grep -qF "█" "$T_W/logo.67" && cmp -s "$T_W/want-word" "$T_W/logo.67"'
check "50 кол.: влезает (≤ 49)"        '[ "$(widest "$T_W/logo.50")" -le 49 ] && cmp -s "$T_W/want-word" "$T_W/logo.50"'
check "49 кол.: две строки текстом"    '! grep -qF "|_|  |_|" "$T_W/logo.49" && grep -qxF "  MULTITEST v3.3" "$T_W/logo.49"'
check "без терминала — без цвета"      '! grep -q $'"'"'\033'"'"' "$T_W"/logo.*'
check "хвостов пробелов нет"           '! grep -q " $" "$T_W"/logo.*'
t_finish