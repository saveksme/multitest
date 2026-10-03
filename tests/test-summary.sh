#!/usr/bin/env bash
# summary.txt (данные для поста в Telegram) — по сценариям A и B стенда превью.
. "$(dirname "$0")/lib.sh"
US=$'\x1f'
date() { printf '2026-01-02 03:04\n'; }; export -f date
export LC_ALL=C.UTF-8
( cd "$T_ROOT" && bash .preview/gen.sh >/dev/null 2>&1 )
A="$T_ROOT/.preview/out/data-a/summary.txt"; B="$T_ROOT/.preview/out/data-b/summary.txt"
first_ok()   { [ "$(head -n1 "$1")" = "v${US}1" ]; }
kinds_ok()   { ! cut -d"$US" -f1 "$1" | grep -qvxE 'v|sys|test|metric|best|svc'; }
no_full_ip() { ! grep -qE '203\.0\.113\.42|2001:db8:4f8::2' "$1"; }
no_ctrl()    { ! LC_ALL=C grep -q "$(printf '[\001-\011\013-\036\177]')" "$1"; }
short()      { local l x; while IFS= read -r l; do IFS="$US" read -ra fs <<< "$l"
                 for x in "${fs[@]}"; do (( ${#x} <= 200 )) || return 1; done; done < "$1"; }
check "A = фикстура" 'diff -u "$T_ROOT/tests/fixtures/summary-a.txt" "$A"'
check "B = фикстура" 'diff -u "$T_ROOT/tests/fixtures/summary-b.txt" "$B"'
for f in "$A" "$B"; do n=$(basename "$(dirname "$f")")
    check "$n: v␟1 первой строкой"          "first_ok '$f'"
    check "$n: только известные виды строк" "kinds_ok '$f'"
    check "$n: полного IP нет"              "no_full_ip '$f'"
    check "$n: управляющих символов нет"    "no_ctrl '$f'"
    check "$n: поля ≤ 200 символов"         "short '$f'"
done
check "A: ключевая цифра IP Region"   "grep -qx 'test${US}ip_region${US}ok${US}NL · 26/30${US}1' '$A'"
check "A: лучшая скорость iPerf3"     "grep -qx 'best${US}iperf3_ru${US}2140.5${US}Chelyabinsk${US}up' '$A'"
check "A: Netflix из IP Check Place"  "grep -qx 'svc${US}ip_check_place${US}Netflix${US}ok${US}NL' '$A'"
check "B: упавший iPerf3 tlab — err"  "grep -q '^test${US}iperf3_tlab${US}err${US}' '$B'"
check "B: маска IPv6"                 "grep -qx 'sys${US}ip6${US}2001:db8::\*' '$B'"
t_finish
