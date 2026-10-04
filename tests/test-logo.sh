#!/usr/bin/env bash
# Шапка меню: Мику + MULTITEST — маска цвета совпадает с рисунком, каждый вариант
# укладывается в свою ширину терминала.
. "$(dirname "$0")/lib.sh"
export LC_ALL=C.UTF-8
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
stty() { return 1; }

mask_ok() {   # у каждого непробельного символа рисунка есть цвет в маске
    local i j k
    (( ${#MT_LOGO_ART[@]} == ${#MT_LOGO_MASK[@]} )) || return 1
    for i in "${!MT_LOGO_ART[@]}"; do
        for (( j = 0; j < ${#MT_LOGO_ART[i]}; j++ )); do
            [[ ${MT_LOGO_ART[i]:j:1} == ' ' ]] && continue
            k=${MT_LOGO_MASK[i]:j:1}; [[ -n $k && $k != ' ' ]] || return 1
        done
    done
}
tput() { echo "$T_COLS"; }
logo_at() {   # <колонки> → строки шапки в $T_W/logo.<колонки>
    T_COLS=$1; MT_LOGO_KEY=""; mt_logo_lines
    printf '%s\n' "${MT_LOGO[@]}" > "$T_W/logo.$1"
}
widest() { local l m=0; while IFS= read -r l; do (( ${#l} > m )) && m=${#l}; done < "$1"; echo "$m"; }

column_ok() { # надпись и подпись — одной колонкой, от рисунка ≥ 2 пробелов
    local k line pre col=""
    for k in 1 2 3 4 6; do
        line=$(sed -n "$((k + 1))p" "$T_W/logo.120")
        if (( k < 6 )); then pre=${line%%"${MT_LOGO_WORD[k-1]}"*}; else pre=${line%%v3.0*}; fi
        [[ $pre != "$line" && $pre == *"  " ]] || return 1
        [[ -z $col || ${#pre} == "$col" ]] || return 1
        col=${#pre}
    done
}

for c in 120 78 77 60 48 47 30; do logo_at "$c"; done
check "маска покрывает рисунок"        mask_ok
check "текст — одной колонкой"         column_ok
check "версия 3.0"                     '[ "$SCRIPT_VERSION" = 3.0 ]'
check "120 кол.: Мику и надпись"       'grep -qF "O   O" "$T_W/logo.120" && grep -qF "|_|  |_|\___/" "$T_W/logo.120"'
check "120 кол.: версия в подписи"     'grep -qF "v3.0 ─ диагностика" "$T_W/logo.120"'
check "78 кол.: влезает (≤ 77)"        '[ "$(widest "$T_W/logo.78")" -le 77 ] && grep -qF "|_|  |_|" "$T_W/logo.78"'
check "77 кол.: без большой надписи"   '! grep -qF "|_|  |_|" "$T_W/logo.77" && grep -qF "M U L T I" "$T_W/logo.77"'
check "48 кол.: влезает (≤ 47)"        '[ "$(widest "$T_W/logo.48")" -le 47 ] && grep -qF "O   O" "$T_W/logo.48"'
check "47 кол.: одна строка текстом"   '! grep -qF "O   O" "$T_W/logo.47" && grep -qxF "  MULTITEST v3.0" "$T_W/logo.47"'
check "без терминала — без цвета"      '! grep -q $'"'"'\033'"'"' "$T_W"/logo.*'
check "хвостов пробелов нет"           '! grep -q " $" "$T_W"/logo.*'
t_finish
