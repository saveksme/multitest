#!/bin/bash
# Локальный стенд: подставляет фиктивные данные прогона и рендерит страницы
# альбома в .preview/out/ — чтобы смотреть вёрстку сводки, не запуская тесты.
# Запуск:  bash .preview/gen.sh
cd "$(dirname "$0")/.." || exit 1

MULTITEST_TEST=1 source ./multitest.sh ""

SYS_CPU="AMD Ryzen 9 9950X 16-Core Processor"; SYS_CORES="1"
SYS_RAM="1.9 GiB"; SYS_DISK="30G · 15%"
SYS_OS="Debian GNU/Linux 13 (trixie)"; SYS_KERNEL="6.12.107+deb13-amd64"
# Адрес — из документационной сети RFC 5737, чтобы в репозитории не лежал
# чей-то настоящий сервер; ASN и город такие же выдуманные.
SYS_VIRT="kvm"; SYS_IP4="203.0.113.42"; SYS_IP6=""
SYS_COUNTRY="NL"; SYS_CITY="Amsterdam"; SYS_ASN="AS64496 Example Hosting B.V."
SYS_CC="bbr"; SYS_QDISC="fq"; SYS_UPTIME="25 minutes"; SYS_LOAD="1.23 0.55 0.30"

MT_CAT_FUNCS=( run_ip_region run_censorcheck_geoblock run_censorcheck_dpi \
    run_censorcheck_tlab run_iperf3_ru run_iperf3_tlab run_yabs \
    run_ip_check_place run_bench_sh run_ip_quality run_sysbench_cpu )
MT_CAT_NAMES=( "IP Region" "Censorcheck — проверка геоблока" "Censorcheck — DPI (серверы РФ)" \
    "Censorcheck — censorcheck.tlab.pw" "iPerf3 — тест до российских серверов" \
    "iPerf3 — bench.tlab.pw (РФ)" "YABS — бенчмарк сервера" \
    "IP Check Place — блокировки зарубежными сервисами" "bench.sh — параметры сервера и скорость" \
    "IPQuality" "sysbench CPU — тест процессора" )

declare -A MT_STATUS=()
for f in run_ip_region run_censorcheck_tlab run_iperf3_ru run_iperf3_tlab \
         run_ip_check_place run_bench_sh run_ip_quality run_sysbench_cpu; do
    MT_STATUS["$f"]="выполнен"
done

SUMMARY_DIR="$PWD/.preview/out/data"
rm -rf "$PWD/.preview/out"; mkdir -p "$SUMMARY_DIR"

US=$'\x1f'
{ printf 'Консенсус%sNL%sok\n' "$US" "$US"
  printf 'Совпало%s12/14%sok\n' "$US" "$US"
  printf 'Гео%sconsistent%sok\n' "$US" "$US"; } > "$SUMMARY_DIR/run_ip_region.metrics"
{ printf 'chip%sNetflix%snetflix%sok%sдоступен\n' "$US" "$US" "$US" "$US"
  printf 'chip%sSpotify%sspotify%sok%sдоступен\n' "$US" "$US" "$US" "$US"
  printf 'chip%sTikTok%stiktok%sbad%sблок\n' "$US" "$US" "$US" "$US"
  printf 'chip%sDiscord%sdiscord%swarn%sчастично\n' "$US" "$US" "$US" "$US"
  printf 'chip%sReddit%sreddit%sok%sдоступен\n' "$US" "$US" "$US" "$US"
  printf 'chip%sTwitch%stwitch%sok%sдоступен\n' "$US" "$US" "$US" "$US"
  printf 'sep%sСкорость\n' "$US"
  printf 'bar%sМосква (Ростелеком)%s%s%s412 Мбит/с%s0.72\n' "$US" "$US" "$US" "$US" "$US"
  printf 'bar%sСПб (МТС)%s%s%s388 Мбит/с%s0.65\n' "$US" "$US" "$US" "$US" "$US"; } \
    > "$SUMMARY_DIR/run_ip_region.services"
cp "$SUMMARY_DIR/run_ip_region.metrics" "$SUMMARY_DIR/run_ip_check_place.metrics"
cp "$SUMMARY_DIR/run_ip_region.services" "$SUMMARY_DIR/run_ip_check_place.services"

mt_style_init; mt_album_plan; mt_run_counters
MT_PAGE_N=$(( ${#MT_PAGE_IDX[@]} + 1 ))

out="$PWD/.preview/out"
build_page_cover > "$out/01-cover.svg"
MT_PAGE_I=2; build_page_test "${MT_PAGE_IDX[0]}" > "$out/02-test.svg"
MT_PAGE_I=3; build_page_test "${MT_PAGE_IDX[1]}" > "$out/03-skip.svg"
MT_ALBUM=0 build_summary_svg > "$out/long.svg"

for f in "$out"/*.svg; do printf '%s  %s bytes\n' "$(basename "$f")" "$(wc -c < "$f")"; done
