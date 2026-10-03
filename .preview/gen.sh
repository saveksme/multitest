#!/bin/bash
# Локальный стенд: подставляет фиктивные данные прогона и рендерит страницы
# альбома в .preview/out/ — чтобы смотреть вёрстку сводки, не запуская тесты.
#   a-* — сценарий «как в макете 5b»: те же семь тестов и те же данные;
#   b-* — остальные виды страниц: bench.sh, Censorcheck tlab, Ping-карта,
#         пропущенный и упавший тесты, IP Region с двойным стеком.
# Запуск:  bash .preview/gen.sh   (потом .preview/index.html через server.js)
cd "$(dirname "$0")/.." || exit 1

MULTITEST_TEST=1 source ./multitest.sh ""
MT_FLAG_FETCH=0   # стенд не ходит в сеть: редкие флаги — монограммами

SYS_CPU="AMD Ryzen 9 9950X 16-Core Processor"; SYS_CORES="2"
SYS_RAM="3.8 GiB"; SYS_DISK="59G · 6%"
SYS_OS="Ubuntu 24.04.4 LTS"; SYS_KERNEL="6.8.0-111-generic"
# Адрес — из документационной сети RFC 5737, чтобы в репозитории не лежал
# чей-то настоящий сервер; ASN такой же выдуманный.
SYS_VIRT="kvm"; SYS_IP4="203.0.113.42"; SYS_IP6=""
SYS_COUNTRY="NL"; SYS_CITY="Amsterdam"; SYS_ASN="AS64496 Example Hosting B.V."
SYS_CC="cubic"; SYS_QDISC="fq_codel"; SYS_UPTIME="17 minutes"; SYS_UP_S=1020
SYS_LOAD="0.70 0.38 0.14"

MT_CAT_FUNCS=( run_ip_region run_censorcheck_geoblock run_censorcheck_dpi \
    run_censorcheck_tlab run_iperf3_ru run_iperf3_tlab run_yabs \
    run_ip_check_place run_bench_sh run_ip_quality run_sysbench_cpu run_ping_map )
MT_CAT_NAMES=( "IP Region" "Censorcheck — проверка геоблока" "Censorcheck — DPI (серверы РФ)" \
    "Censorcheck — censorcheck.tlab.pw" "iPerf3 — тест до российских серверов" \
    "iPerf3 — bench.tlab.pw (РФ)" "YABS — бенчмарк сервера" \
    "IP Check Place — блокировки зарубежными сервисами" "bench.sh — параметры сервера и скорость" \
    "IPQuality" "sysbench CPU — тест процессора" "Ping-карта — check-host.net" )

out="$PWD/.preview/out"
rm -rf "$out"; mkdir -p "$out"
US=$'\x1f'

# m <файл> <подпись> <значение> [цвет] ; s <файл> <вид> <имя> <slug> <состояние> <значение> [доп.]
m() { printf '%s\x1f%s\x1f%s\n' "$2" "$3" "${4:-}" >> "$SUMMARY_DIR/$1.metrics"; }
s() { printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$2" "$3" "$4" "$5" "$6" "-1" "${7:-}" >> "$SUMMARY_DIR/$1.services"; }
chip() { s "$1" chip "$2" "$(brand_slug_for "$2")" "$3" "$4"; }

render() {   # <префикс> — обложка и страница на каждый тест, как step_build_pages
    local pre="$1" i idx
    mt_style_init; mt_album_plan; mt_run_counters
    MT_PAGE_N=$(( ${#MT_PAGE_IDX[@]} + 1 )); MT_PAGE_I=1
    build_page_cover > "$out/$pre-01-cover.svg"
    for i in "${!MT_PAGE_IDX[@]}"; do
        idx="${MT_PAGE_IDX[$i]}"; MT_PAGE_I=$(( i + 2 ))
        build_page_test "$idx" > "$(printf '%s/%s-%02d-%s.svg' "$out" "$pre" "$MT_PAGE_I" "${MT_CAT_FUNCS[$idx]#run_}")"
    done
}

# ---------------- сценарий A: данные макета 5b ----------------
SUMMARY_DIR="$out/data-a"; mkdir -p "$SUMMARY_DIR"
declare -A MT_STATUS=()
for f in run_ip_region run_censorcheck_geoblock run_iperf3_ru run_yabs \
         run_ip_check_place run_ip_quality run_sysbench_cpu; do MT_STATUS[$f]="выполнен"; done

m run_ip_region "Консенсус" NL pri; m run_ip_region ASN "AS64496 Example Hosting B.V."
m run_ip_region "Сервисов" 21; m run_ip_region "GeoIP-баз" 16; m run_ip_region "Совпадений" 26/30 ok
while IFS='|' read -r n v st; do chip run_ip_region "$n" "$st" "$v"; done <<'EOF'
Google|GB|warn
Google Search Captcha|нет|ok
YouTube|GB|warn
YouTube Premium|да|ok
YouTube Music|да|ok
Twitch|NL|ok
ChatGPT|NL|ok
Netflix|NL|ok
Spotify|NL|ok
Spotify Signup|да|ok
Reddit|NL|ok
Reddit (Guest Access)|да|ok
Amazon Prime|NL|ok
Apple|NL|ok
Steam|NL|ok
PlayStation|NL|ok
Tiktok|NL|ok
Ookla Speedtest|NL|ok
JetBrains|NL|ok
Deezer|NL|ok
Microsoft (Bing)|NL|ok
EOF
s run_ip_region sep "GeoIP-базы" "" "" ""
while IFS='|' read -r n v st; do s run_ip_region chip "$n" "" "$st" "$v"; done <<'EOF'
maxmind.com|NL|ok
ipinfo.io|NL|ok
ipregistry.co|NL|ok
iplocation.com|NL|ok
geoapify.com|IT|warn
ipapi.is|N/A|na
ipquery.io|IT|warn
ip-api.com|NL|ok
rdap.db.ripe.net|NL|ok
cloudflare.com|NL|ok
ipapi.co|N/A|na
country.is|NL|ok
geojs.io|NL|ok
ipbase.com|NL|ok
ipwho.is|NL|ok
2ip.io|NL|ok
EOF

m run_censorcheck_geoblock "Доступно" 22 ok; m run_censorcheck_geoblock "Заблокировано" 2 bad
for d in spotify.com netflix.com patreon.com swagger.io snyk.io mongodb.com autodesk.com graylog.org \
         redis.io copilot.microsoft.com intel.com docker.com hashicorp.com jetbrains.com nvidia.com \
         amd.com unity.com notion.so figma.com canva.com twitch.tv; do
    chip run_censorcheck_geoblock "$d" ok "доступен"
done
chip run_censorcheck_geoblock "oracle.com" bad "блок"
chip run_censorcheck_geoblock "cisco.com" bad "блок"
chip run_censorcheck_geoblock "dell.com" ok "доступен"

m run_iperf3_ru "Макс ↓" "2140.5 Mbps" ok; m run_iperf3_ru "Мин ping" "46 ms" pri; m run_iperf3_ru "Серверов" 5
while IFS='|' read -r c d u; do s run_iperf3_ru bar "$c" "" ok "$d" "$u"; done <<'EOF'
Moscow|2065.4|2079.3
Saint Petersburg|2074.3|2094.8
Nizhny Novgorod|1906.9|1928.7
Chelyabinsk|2120.7|2140.5
Tyumen|716.5|735.4
EOF

m run_yabs CPU "AMD Ryzen 9 9950X 16-Core Processor"; m run_yabs "Ядер" 2; m run_yabs RAM "3.8 GiB"
m run_yabs "Диск" "59.0 GiB"; m run_yabs "fio 4k" "1.09 GB/s" pri; m run_yabs "fio 1m" "5.99 GB/s" pri
while IFS='|' read -r p l v; do s run_yabs net "$l" "" ok "$v" "$p"; done <<'EOF'
Eranium|Amsterdam, NL|1930
Clouvider|London, UK|1920
Leaseweb|NYC, NY, US|1720
Leaseweb|Singapore, SG|1260
Uztelecom|Tashkent, UZ|1180
Edgoo|Sao Paulo, BR|436
Clouvider|Los Angeles, CA, US|187
EOF

m run_ip_check_place "Риск" Low ok; m run_ip_check_place "Баз" 9; m run_ip_check_place DNSBL 0 ok
while IFS='|' read -r n v st; do chip run_ip_check_place "$n" "$st" "$v"; done <<'EOF'
TikTok|NL|ok
Netflix|NL|ok
Youtube|GB|ok
AmazonPV|блок|bad
Reddit|NL|ok
ChatGPT|NL|ok
Disney+|NL|ok
EOF

m run_ip_quality Usage Hosting; m run_ip_quality Company Hosting; m run_ip_quality "Гео" consistent ok
m run_ip_quality "Аноним" "нет" ok; m run_ip_quality "Port 25" "закрыт" warn; m run_ip_quality DNSBL 0 ok
while IFS='|' read -r n v st; do s run_ip_quality chip "$n" "" "$st" "$v"; done <<'EOF'
IP2Location|3 · Low|ok
Scamalytics|0 · Low|ok
ipapi|0.00% · VeryLow|ok
IPQS|0 · Low|ok
DB-IP|Low|ok
EOF
s run_ip_quality sep "Доступ к сервисам и AI" "" "" ""
while IFS='|' read -r n v st; do chip run_ip_quality "$n" "$st" "$v"; done <<'EOF'
TikTok|NL|ok
Netflix|NL|ok
Youtube|GB|ok
AmazonPV|NL|ok
Reddit|NL|ok
ChatGPT|NL|ok
Disney+|NL|ok
EOF

m run_sysbench_cpu events/s 6268.20 ok; m run_sysbench_cpu "событий" 62701
m run_sysbench_cpu "время" "10.0002 s"; m run_sysbench_cpu "lat avg" "0.16 ms" pri; m run_sysbench_cpu "lat 95th" "0.17 ms" pri

render a
mt_write_summary "$SUMMARY_DIR/summary.txt"

# ---------------- сценарий B: остальные виды страниц ----------------
SUMMARY_DIR="$out/data-b"; mkdir -p "$SUMMARY_DIR"
SYS_IP6="2001:db8:4f8::2"; SYS_CPU="Intel(R) Xeon(R) Gold 6248R CPU @ 3.00GHz"; SYS_CORES=4; SYS_UP_S=$(( 3*86400 + 5*3600 ))
MT_STATUS=()
for f in run_ip_region run_censorcheck_tlab run_bench_sh run_ping_map; do MT_STATUS[$f]="выполнен"; done
MT_STATUS[run_censorcheck_dpi]="пропущен"; MT_STATUS[run_iperf3_tlab]="ошибка"

m run_ip_region "Консенсус IPv4" DE pri; m run_ip_region "Консенсус IPv6" DE pri
m run_ip_region "Совпадений v4" 9/12 ok; m run_ip_region "Совпадений v6" 8/10 ok; m run_ip_region "v4≠v6" 2 bad
while IFS='|' read -r n v st; do chip run_ip_region "$n" "$st" "$v"; done <<'EOF'
Google|DE · US|warn
YouTube|DE|ok
Netflix|DE|ok
Cloudflare CDN|DE (FRA)|ok
ChatGPT|DE · NL|warn
Spotify|DE|ok
Google Search Captcha|есть|bad
Reddit|Rate-limit|warn
EOF
s run_ip_region sep "GeoIP-базы" "" "" ""
while IFS='|' read -r n v st; do s run_ip_region chip "$n" "" "$st" "$v"; done <<'EOF'
maxmind.com|DE|ok
ipinfo.io|DE|ok
ipregistry.co|SC|warn
ip-api.com|DE|ok
ipapi.co|N/A|na
EOF

while IFS='|' read -r d v st; do chip run_censorcheck_tlab "$d" "$st" "$v"; done <<'EOF'
youtube.com|доступен|ok
instagram.com|блок|bad
x.com|блок|bad
facebook.com|блок|bad
discord.com|доступен|ok
linkedin.com|редирект|warn
rutracker.org|N/A|na
telegram.org|доступен|ok
EOF

m run_bench_sh CPU "Intel Xeon Gold 6248R CPU @ 3.00GHz"; m run_bench_sh "Ядер" 4; m run_bench_sh RAM "7.8 GB"
m run_bench_sh "Диск" "80.0 GB"; m run_bench_sh "I/O сред." "1.2 GB/s" pri; m run_bench_sh CC bbr; m run_bench_sh "Сеть" "AS64496 Example Hosting B.V."
while IFS='|' read -r n u d; do s run_bench_sh bar "$n" "" ok "$d" "$u"; done <<'EOF'
Speedtest.net|939.89|936.66
Paris, FR|912.40|925.11
Amsterdam, NL|938.02|941.53
Los Angeles, US|455.10|803.33
Singapore, SG|350.77|601.20
Tokyo, JP|300.12|452.80
EOF

m run_ping_map "РФ avg" "41.3 ms" pri; m run_ping_map "ЕС avg" "8.2 ms" ok; m run_ping_map "США avg" "112.6 ms" warn
m run_ping_map "Азия avg" "214.0 ms" bad; m run_ping_map "Худший" "Токио · 248.7 ms" warn; m run_ping_map "Потери" "1/14 (Стамбул)" bad
while IFS='|' read -r node city st avg loss grp; do s run_ping_map ping "$city" "$node" "$st" "$avg" "$loss|$grp"; done <<'EOF'
ru1|Москва|ok|38.4|0%|Россия
ru2|Москва|ok|39.1|0%|Россия
ru3|Санкт-Петербург|ok|46.5|0%|Россия
kz1|Караганда|warn|96.2|0%|Соседи
tr1|Стамбул|bad|71.8|25%|Соседи
de4|Франкфурт|ok|7.9|0%|Европа
fi1|Хельсинки|ok|24.3|0%|Европа
pl2|Варшава|ok|21.0|0%|Европа
nl1|Амстердам|ok|1.2|0%|Европа
uk1|Лондон|ok|8.4|0%|Европа
us5|Нью-Йорк|warn|79.0|0%|Мир
us1|Лос-Анджелес|warn|146.2|0%|Мир
sg1|Сингапур|bad|179.4|0%|Мир
jp1|Токио|bad|248.7|0%|Мир
EOF

render b
mt_write_summary "$SUMMARY_DIR/summary.txt"

# Одна длинная картинка (MT_ALBUM=0) — на данных сценария A
SUMMARY_DIR="$out/data-a"
MT_STATUS=()
for f in run_ip_region run_censorcheck_geoblock run_iperf3_ru run_yabs \
         run_ip_check_place run_ip_quality run_sysbench_cpu; do MT_STATUS[$f]="выполнен"; done
build_summary_svg > "$out/long.svg"

: > "$out/pages.txt"   # список для index.html: статический сервер каталоги не отдаёт
for f in "$out"/*.svg; do
    basename "$f" >> "$out/pages.txt"
    printf '%-28s %7s bytes\n' "$(basename "$f")" "$(wc -c < "$f")"
done
