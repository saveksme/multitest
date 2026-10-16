#!/usr/bin/env bash
# Пинг в сетевых тестах: разбор таблиц iPerf3 (russian-iperf3-servers и bench.tlab.pw),
# YABS и bench.sh в строки «приём · отдача · пинг» и пилюли пинга на странице.
. "$(dirname "$0")/lib.sh"
export LC_ALL=C.UTF-8
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
declare -A MT_STATUS=()
MT_FLAG_FETCH=0
SUMMARY_DIR="$T_W"; US=$'\x1f'; E=$'\033'

parse() {   # <тест> — лог из stdin -> $T_W/<тест>.metrics/.services
    cat > "$T_W/$1.log"
    parse_test_output "$1" "$T_W/$1.log" "$T_W/$1.metrics" "$T_W/$1.services"
}
row()    { grep -qxF "bar${US}$2${US}$3${US}ok${US}$4${US}-1${US}$5${US}$6" "$T_W/$1.services"; }
metric() { grep -qxF "$2${US}$3${US}$4" "$T_W/$1.metrics"; }
rows()   { [ "$(grep -c '' "$T_W/$1.services")" = "$2" ]; }

# russian-iperf3-servers: printf "%-18s %-15s %-15s %-10s" — приём, отдача, пинг
{
    printf '%-18s %-15s %-15s %-10s\n' Server Download Upload Ping ------ -------- ------ ----
    printf '%-18s %-15s %-15s %-10s\n' "Moscow" "942.0 Mbps" "610.5 Mbps" "12 ms"
    printf '%-18s %-15s %-15s %-10s\n' "Saint Petersburg (F)" "880.4 Mbps" "590.0 Mbps" "18 ms"
    printf '%-18s %-15s %-15s %-10s\n' "Yekaterinburg" "700.1 Mbps" "402.3 Mbps" "N/A ms"
    printf '%-18s %-15s %-15s %-10s\n' "Novosibirsk" "${E}[31m-${E}[0m" "${E}[31m-${E}[0m" "N/A"
} | parse run_iperf3_ru
check "iPerf3 РФ: город, приём, отдача, пинг"   'row run_iperf3_ru Moscow "" 942.0 610.5 12'
check "iPerf3 РФ: длинный город с (F)"          'row run_iperf3_ru "Saint Petersburg (F)" "" 880.4 590.0 18'
check "iPerf3 РФ: N/A ms — без пинга"           'row run_iperf3_ru Yekaterinburg "" 700.1 402.3 ""'
check "iPerf3 РФ: упавший узел пропущен"        'rows run_iperf3_ru 3'
check "iPerf3 РФ: метрики"                      'metric run_iperf3_ru "Макс ↓" "942.0 Mbps" ok && metric run_iperf3_ru "Мин ping" "12 ms" pri && metric run_iperf3_ru "Серверов" 3 ""'

# bench.tlab.pw: «%-17s%9s %-8s%7s %-8s%13s» — отдача, приём, пинг; перед строкой
# в логе остаётся спиннер, затёртый \r
{
    printf '%-15s%19s%18s%11s\n' " Node Name" "Upload Speed" "Download Speed" "Latency"
    printf '%s|%s\r%s' "${E}[0;33m Moscow, Hostkey   ${E}[0m" $'\b/\b' "${E}[K"
    printf "${E}[0;33m%-17s${E}[0;32m%9s %-8s${E}[0;31m%7s %-8s${E}[0;36m%13s${E}[0m\n" " Moscow, Hostkey" 912 Mbit/s 941 Mbit/s "12.34 ms"
    printf '%-17s%9s %-8s%7s %-8s%13s\n' " SPB, Er-com" 850 Mbit/s 901 Mbit/s "18.20 ms"
    printf '%-17s%9s %-8s%7s %-8s%13s\n' " Voronezh,Beeline" 700 Mbit/s 810 Mbit/s "N/A"
    printf '%-17s%9s %-8s%7s %-8s%13s\n' " NL Amsterdam" 2400 Mbit/s 2350 Mbit/s "1.05 ms"
} | parse run_iperf3_tlab
check "tlab: Mbit/s, отдача перед приёмом, провайдер — подпись" 'row run_iperf3_tlab "Moscow, RU" Hostkey 941 912 12.34'
check "tlab: провайдер без пробела после запятой"               'row run_iperf3_tlab "Voronezh, RU" Beeline 810 700 ""'
check "tlab: зарубежный узел — «Amsterdam, NL»"                 'row run_iperf3_tlab "Amsterdam, NL" "" 2350 2400 1.05'
check "tlab: метрики только по России"                          'metric run_iperf3_tlab "Макс ↓" "941 Mbps" ok && metric run_iperf3_tlab "Мин ping" "12.34 ms" pri && metric run_iperf3_tlab "Серверов" 4 ""'
mt_read_rows run_iperf3_tlab; mt_speed_rows ru
check "tlab: лучший — российский, шкала — по всем"              '[ "$IMX" = 941 ] && [ "$IMX_CITY" = "Moscow, RU" ] && [ "$IDOM" = 3 ] && [ "$IMXA10" = 24000 ]'
mt_speed_rows
check "без «ru» лучший — по всем строкам"                       '[ "$IMX" = 2400 ] && [ "$IMX_DIR" = отдача ]'

# YABS: «Provider | Location (Link) | Send | Recv | Ping»; busy и -- — пусто
{
    echo "iperf3 Network Speed Tests (IPv4):"
    echo "---------------------------------"
    printf '%-15s | %-25s | %-15s | %-15s | %-15s\n' Provider "Location (Link)" "Send Speed" "Recv Speed" Ping
    printf '%-15s | %-25s | %-15s | %-15s | %-15s\n' ----- ----- ---- ---- ----
    printf '%-15s | %-25s | %-15s | %-15s | %-15s\n' Clouvider "London, UK (10G)" "1.61 Gbits/sec" "1.58 Gbits/sec" "7.38 ms"
    printf '%-15s | %-25s | %-15s | %-15s | %-15s\n' Uztelecom "Tashkent, UZ (10G)" "busy " "905 Mbits/sec" "--"
    printf '%-15s | %-25s | %-15s | %-15s | %-15s\n' Leaseweb "Singapore, SG (10G)" "820 Mbits/sec" "busy " "157 ms"
    echo
    echo "Geekbench 6 Benchmark Test:"
} | parse run_yabs
check "YABS: приём, отдача в Мбит/с, пинг, провайдер"   'row run_yabs "London, UK" Clouvider 1580 1610 7.38'
check "YABS: busy и -- — пусто"                         'row run_yabs "Tashkent, UZ" Uztelecom 905 "" ""'
check "YABS: без приёма строки нет"                     'rows run_yabs 2'

# bench.sh: «%-18s%-18s%-20s%-12s» — узел, отдача, приём, пинг
{
    printf '%-18s%-18s%-20s%-12s\n' " Node Name" "Upload Speed" "Download Speed" Latency
    printf '%-18s%-18s%-20s%-12s\n' " Speedtest.net" "939.63 Mbps" "941.49 Mbps" "0.43 ms"
    printf '%-18s%-18s%-20s%-12s\n' " Paris, FR" "925.80 Mbps" "931.00 Mbps" "10.50 ms"
} | parse run_bench_sh
check "bench.sh: пинг узла"   'row run_bench_sh Speedtest.net "" 941.49 939.63 0.43 && row run_bench_sh "Paris, FR" "" 931.00 925.80 10.50'

# Пинг для пилюли: до 10 мс с десятыми, дальше целым
ms() { num10 "$1"; mt_ms $N10; [ "$MS" = "$2" ]; }
check "пинг: 0.43 → 0.4, 7.38 → 7.3, 10.50 → 11, 46 → 46"   'ms 0.43 0.4 && ms 7.38 7.3 && ms 10.50 11 && ms 46 46'

# Страница: пилюли пинга, лучший — в цвете; без пинга — прежняя подпись секции
page() {   # <тест> -> SVG страницы в $T_W/<тест>.svg
    local i
    for i in "${!MT_CAT_FUNCS[@]}"; do [[ "${MT_CAT_FUNCS[i]}" == "$1" ]] && break; done
    MT_STATUS[$1]="выполнен"; MT_PAGE_N=2; MT_PAGE_I=2
    build_page_test "$i" > "$T_W/$1.svg"
}
mt_style_init
page run_iperf3_ru
check "страница: пилюли «12 ms» и «18 ms»"       'grep -q ">12 ms<" "$T_W/run_iperf3_ru.svg" && grep -q ">18 ms<" "$T_W/run_iperf3_ru.svg"'
check "страница: лучший пинг — в цвете"          'grep -q "fill=\"$C_ONPRIC\">12 ms<" "$T_W/run_iperf3_ru.svg" && grep -q "fill=\"$C_ON2\">18 ms<" "$T_W/run_iperf3_ru.svg"'
check "страница: узел без пинга — «—»"           'grep -q "fill=\"$C_OUT\">—<" "$T_W/run_iperf3_ru.svg"'
check "страница: подпись секции с ping"          'grep -q ">ping · скорость в Мбит/с · шкала 1000<" "$T_W/run_iperf3_ru.svg"'
page run_iperf3_tlab
check "страница tlab: провайдер под городом"     'grep -q ">Hostkey<" "$T_W/run_iperf3_tlab.svg"'
check "страница tlab: «в России» — без зарубежных" 'grep -q ">3 сервера в России<" "$T_W/run_iperf3_tlab.svg"'
check "страница tlab: лучший пинг — среди России" 'grep -q "fill=\"$C_ONPRIC\">12 ms<" "$T_W/run_iperf3_tlab.svg" && grep -q "fill=\"$C_ON2\">1.0 ms<" "$T_W/run_iperf3_tlab.svg"'
sed -i "s/${US}[^${US}]*\$//" "$T_W/run_bench_sh.services"   # старый формат: без поля пинга
page run_bench_sh
check "без пинга: ни пилюль, ни «ping ·»"        '! grep -q " ms<" "$T_W/run_bench_sh.svg" && grep -q ">Мбит/с · шкала 1000<" "$T_W/run_bench_sh.svg"'
t_finish
