#!/usr/bin/env bash
# Враждебные данные: подстановки команд, «a[$(…)]» для арифметики bash, \x1f, разметка SVG и
# bidi в выводе тестов и в готовых .metrics/.services. Разбор и отрисовка не должны ничего
# выполнить, сдвинуть поля или вставить в SVG свою разметку.
. "$(dirname "$0")/lib.sh"
export LC_ALL=C.UTF-8
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
declare -A MT_STATUS=()
MT_FLAG_FETCH=0
SUMMARY_DIR="$T_W/d"; mkdir -p "$SUMMARY_DIR"; cd "$T_W" || exit 1
US=$'\x1f'; RLO=$'‮'

# Подстановки команд создают файлы pwn* в текущем каталоге — их не должно появиться
P1='a[$(touch pwn1)]'; P2='`touch pwn2`'; P3='$(touch pwn3)'; P4='</text><image href="x.png"/><text>'
EVIL="$P1 $P2 $P3 $P4 $RLO"

parse() {   # <тест> — лог из stdin
    cat > "$T_W/$1.log"
    parse_test_output "$1" "$T_W/$1.log" "$SUMMARY_DIR/$1.metrics" "$SUMMARY_DIR/$1.services"
}
fields_ok() {   # в каждой строке .metrics ровно 3 поля, в .services — 8
    local f="$SUMMARY_DIR/$1" n="$2" l
    [[ -f "$f" ]] || return 0
    while IFS= read -r l; do
        [[ "$(printf '%s' "$l" | tr -cd "$US" | wc -c)" -eq $(( n - 1 )) ]] || return 1
    done < "$f"
}

{
    printf '%-18s %-15s %-15s %-10s\n' Server Download Upload Ping
    printf '%-18s %-15s %-15s %-10s\n' "$P1" "942.0 Mbps" "610.5 Mbps" "12 ms"
    printf '%s%s%s %-15s %-15s %-10s\n' "X$US$US$US$US$US" "$P1" "$US" "880.4 Mbps" "590.0 Mbps" "18 ms"
    printf '%-18s %-15s %-15s %-10s\n' "$P3" "1.0 Mbps" "2.0 Mbps" "$P2 ms"
} | parse run_iperf3_ru
{
    echo "Processor  : $EVIL"
    echo "iperf3 Network Speed Tests (IPv4):"
    printf '%-15s | %-25s | %-15s | %-15s | %-15s\n' Provider "Location (Link)" "Send Speed" "Recv Speed" Ping
    printf '%-15s | %-25s | %-15s | %-15s | %-15s\n' "$P1" "$P3, NL (10G)" "1.61 Gbits/sec" "1.58 Gbits/sec" "$P2 ms"
} | parse run_yabs
{
    printf '%-18s%-18s%-20s%-12s\n' " Node Name" "Upload Speed" "Download Speed" Latency
    printf '%-18s%-18s%-20s%-12s\n' " $P1" "939.63 Mbps" "941.49 Mbps" "0.43 ms"
    echo " CPU Model          : $EVIL"
} | parse run_bench_sh
{
    printf 'Service\tIPv4\n%s\tNL\n%s\t%s\n' "$P1" "Netflix" "$P3"
    echo "ASN: $EVIL"
} | parse run_ip_region
for f in run_censorcheck_geoblock run_ip_check_place run_ip_quality run_sysbench_cpu run_ping_map; do
    printf '%s\n%s  Available\nRisk: %s\nevents per second: %s\n' "$EVIL" "$P1" "$P3" "$P1" | parse "$f"
done

check "разбор: ничего не выполнилось"            '! ls "$T_W"/pwn* >/dev/null 2>&1'
for f in "${MT_CAT_FUNCS[@]}"; do
    check "разбор $f: поля не сдвинуты"           "fields_ok $f.metrics 3 && fields_ok $f.services 8"
done

# Готовые данные «от клиента» — каждое поле враждебное
for f in "${MT_CAT_FUNCS[@]}"; do
    for k in "Консенсус" "Совпадений" "Доступно" "Заблокировано" "Мин ping" "Макс ↓" "fio 4k" "fio 1m" \
             "I/O сред." "Ядер" "events/s" "lat avg" "РФ avg" "Потери" "Худший" "Риск" "Usage" "DNSBL"; do
        printf '%s\x1f%s\x1f%s\n' "$k" "$P1" "$P3" >> "$SUMMARY_DIR/$f.metrics"
    done
    # у DPI строк-сайтов нет: страница берёт счётчики из метрик — путь, где они шли в $(( ))
    [[ "$f" == run_censorcheck_dpi ]] && { : > "$SUMMARY_DIR/$f.services"; MT_STATUS[$f]="выполнен"; continue; }
    for k in chip bar net ping sep; do
        printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$k" "$EVIL" "$P1" "$P3" "$P1" "$P1" "$P1|$P3" "$P1" \
            >> "$SUMMARY_DIR/$f.services"
    done
    MT_STATUS[$f]="выполнен"
done
SYS_CPU="$EVIL"; SYS_CORES="$P1"; SYS_RAM="$P3"; SYS_DISK="$P1"; SYS_OS="$EVIL"; SYS_KERNEL="$P1"
SYS_VIRT="$P3"; SYS_IP4="$P1"; SYS_IP6="$P3"; SYS_COUNTRY="$P1"; SYS_CITY="$EVIL"; SYS_ASN="$EVIL"
SYS_CC="$P1"; SYS_QDISC="$P3"; SYS_UPTIME="$P1"; SYS_UP_S="$P1"; SYS_LOAD="$P1"
mt_style_init; mt_album_plan; mt_run_counters
MT_PAGE_N=$(( ${#MT_PAGE_IDX[@]} + 1 )); MT_PAGE_I=1
build_page_cover > "$T_W/p-cover.svg" 2>/dev/null
for i in "${!MT_PAGE_IDX[@]}"; do
    MT_PAGE_I=$(( i + 2 )); build_page_test "${MT_PAGE_IDX[$i]}" > "$T_W/p-$i.svg" 2>/dev/null
done
mt_write_summary "$T_W/summary.txt" 2>/dev/null

check "отрисовка: ничего не выполнилось"         '! ls "$T_W"/pwn* >/dev/null 2>&1'
check "отрисовка: все страницы собраны"           '[ "$(ls "$T_W"/p-*.svg | wc -l)" -eq $(( ${#MT_PAGE_IDX[@]} + 1 )) ] && ! grep -L "</svg>" "$T_W"/p-*.svg | grep -q .'
check "отрисовка: чужой разметки в SVG нет"       '! grep -q "<image\|<script\|href=\"x.png" "$T_W"/p-*.svg'
check "summary.txt: управляющих символов нет"     '! LC_ALL=C grep -q "$(printf "[\001-\011\013-\036\177]")" "$T_W/summary.txt"'
check "summary.txt: bidi вырезан"                 '! LC_ALL=C grep -q "$RLO" "$T_W/summary.txt"'

# Текст от бэкенда/хостинга: mt_clean обязан убрать и «\», иначе echo -e/printf %b
# соберёт из него ESC уже после чистки (\033 -> 0x1b = OSC-52, запись в буфер обмена).
CLEAN=$(mt_clean '\033]52;c;QUJD\007')
check "mt_clean: слэш вырезан"                    '[[ "$CLEAN" != *\\* ]]'
check "mt_clean: echo -e не оживляет ESC"         '! echo -e "$CLEAN" | LC_ALL=C grep -q "$(printf "\033")"'
check "mt_clean: bidi вырезан"                    '[[ "$(mt_clean "abc${RLO}def")" == abcdef ]]'
check "mt_clean: кириллица цела"                  '[ "$(mt_clean "Москва · open · 24.0 мс")" == "Москва · open · 24.0 мс" ]'

# Тело ответа ТСПУ и ссылка хостинга — тоже недоверенный текст
t_fake_curl
MT_API=https://bot.test; export SSH_CONNECTION="10.0.0.2 51111 203.0.113.7 2222"
t_respond 200 'v 1' "  Цель: 203.0.*.*:2222" \
    "$(printf '  Moscow \033]52;c;QUJD\007 · ISP · open · 24.0 мс')" '  Итог: ДОСТУП ЕСТЬ · 1/1 · 100%'
run_tspu_check > "$T_W/tspu.out" 2>&1
grep -a "Moscow" "$T_W/tspu.out" > "$T_W/tspu.node"
check "ТСПУ: в строке узла нет ESC/BEL"            '! LC_ALL=C grep -q "$(printf "[\001-\010\013-\037\177]")" "$T_W/tspu.node"'
check "ТСПУ: строка узла цела"                    'grep -q "Moscow .*· ISP · open · 24.0 мс" "$T_W/tspu.out"'
check "ТСПУ: разбор всё ещё работает"             'parse_test_output run_tspu_check "$T_W/tspu.out" "$T_W/t.m" "$T_W/t.s" && grep -q "Доступно" "$T_W/t.m"'

up_imgdb() { printf 'https://x.test/a\\033]52;c;QUJD\\007'; }
check "хостинг: ссылка обезврежена"               '[[ "$(upload_report /dev/null 2>/dev/null)" != *\\* ]]'
t_finish
