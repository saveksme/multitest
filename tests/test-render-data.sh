#!/usr/bin/env bash
# --render-data: бот рисует подписанные страницы из присланных данных — без сети, с полосой
# подписи (QR, код, номер страницы), адресами и временем из манифеста бота.
. "$(dirname "$0")/lib.sh"
export LC_ALL=C.UTF-8
( cd "$T_ROOT" && bash .preview/gen.sh >/dev/null 2>&1 )
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
cd "$T_W" || exit 1
NET=0
curl() { NET=$(( NET + 1 )); return 7; }
wget() { NET=$(( NET + 1 )); return 4; }
# rsvg в CI может не быть: PNG подменяем, а SVG рисуется по-настоящему
mt_render_page() {
    printf 'PNG' > "$1.png"
    printf '%s\n' "$1.png" >> "$SUMMARY_DIR/pages.list"
    printf '%s\t1280\t%s\n' "$1.png" "${MT_PAGE_H:-1000}" >> "$SUMMARY_DIR/pages.dim"
}
US=$'\x1f'
QR=$(sed -n 's/^qr="\(.*\)"$/\1/p; s/^qr+="\(.*\)"$/\1/p' "$T_ROOT/.preview/gen.sh" | tr -d '\n')

mkdir -p d
cp "$T_ROOT"/.preview/out/data-a/run_*.{metrics,services} d/ 2>/dev/null
{
    printf 'id\t7K2Q9XWAPD3M\ncode\tMT-7K2Q-9XWA-PD3M\nbot\tmultitestus_bot\ndate\t2026-10-17 13:41\n'
    printf 'ip4\t198.51.*.*\nip6\t2001:db8::*\ncountry\tDE\nasn\tAS64500 Proof Hosting GmbH\n'
    for i in $(seq 1 13); do printf 'qr\t%s\t%s\n' "$i" "$QR"; done
    printf 'ip4\t198.51.100.7\n'                     # полный адрес — не принимается
} > d/manifest
{
    printf 'SYS_CPU\tAMD EPYC 9654 96-Core Processor\nSYS_CORES\t4\nSYS_RAM\t7.8 GiB\nSYS_DISK\t80G · 9%%\n'
    printf 'SYS_OS\tDebian GNU/Linux 12\nSYS_UP_S\t3600\nSYS_IP4\t5.6.7.8\nSYS_EVIL\t$(touch pwn)\nSYS_KERNEL\t$(touch pwn)\n'
} > d/facts
for f in run_ip_region run_censorcheck_geoblock run_iperf3_ru run_yabs run_ip_check_place run_ip_quality run_sysbench_cpu; do
    printf '%s\tвыполнен\n' "$f"
done > d/status
printf 'run_nope\tвыполнен\nrun_bench_sh\tзаражён\n' >> d/status

mt_render_data "$T_W/d"; rc=$?
P="$T_W/d/pages"
qr_back() {   # путь QR из SVG -> матрица строками «0/1» через запятую
    local svg="$1" m x0 y0
    grep -o '<path d="M[0-9][^"]*z" fill="#000000"/>' "$svg" | head -1 | sed 's/<path d="//; s/" fill.*//' |
        awk -v n=33 '{
            gsub(/z/, "z\n"); split($0, segs, "\n"); minx=1e9; miny=1e9
            for (i in segs) if (match(segs[i], /^M[0-9]+ [0-9]+h[0-9]+v[0-9]+/)) {
                split(substr(segs[i], 2), a, /[ hv]/); x[i]=a[1]; y[i]=a[2]; w[i]=a[3]; m=a[4]
                if (a[1] < minx) minx=a[1]; if (a[2] < miny) miny=a[2] }
            for (i in x) { r=(y[i]-miny)/m; c0=(x[i]-minx)/m; for (c=0; c<w[i]/m; c++) g[r, c0+c]=1 }
            out=""; for (r=0; r<n; r++) { row=""; for (c=0; c<n; c++) row=row ((r SUBSEP c) in g ? 1 : 0); out=out (r ? "," : "") row }
            print out }'
}

check "рисует без ошибок"                       '[ "$rc" = 0 ]'
check "обложка и 7 страниц"                      '[ "$(grep -c . "$T_W/d/pages.list")" = 8 ]'
check "ни одного сетевого вызова"                '[ "$NET" = 0 ]'
check "полоса подписи: код и номер страницы"     'grep -q ">MT-7K2Q-9XWA-PD3M<" "$P/04-iperf3_ru.svg" && grep -q "стр. 4/8" "$P/04-iperf3_ru.svg"'
check "полоса подписи: бот из манифеста"         'grep -q "@multitestus_bot" "$P/01-cover.svg"'
check "QR на странице — та же матрица"           '[ "$(qr_back "$P/02-ip_region.svg")" = "$QR" ]'
check "дата — из манифеста"                       'grep -q "2026-10-17 13:41" "$P/03-censorcheck_geoblock.svg"'
check "адрес и страна — из манифеста, не от сервера" 'grep -q "198.51.\*.\*" "$P/01-cover.svg" && ! grep -q "5.6.7.8\|198.51.100.7" "$P"/*.svg'
check "summary: адрес и страна бота"              'grep -qx "sys${US}ip4${US}198.51.*.*" "$T_W/d/summary.txt" && grep -qx "sys${US}country${US}DE" "$T_W/d/summary.txt"'
check "summary: факты сервера"                    'grep -qx "sys${US}cpu${US}AMD EPYC 9654" "$T_W/d/summary.txt" && grep -qx "sys${US}cores${US}4" "$T_W/d/summary.txt"'
check "чужие ключи и тесты не берутся"           '! ls "$T_W"/pwn >/dev/null 2>&1 && [ -z "${MT_STATUS[run_nope]:-}${MT_STATUS[run_bench_sh]:-}" ]'
check "склейки для бота собраны"                  '[ -s "$T_W/d/tg-pages.list" ]'

# без матрицы QR — страницы без полосы подписи
mkdir -p e; cp d/run_* d/facts d/status e/; grep -v '^qr' d/manifest > e/manifest
mt_render_data "$T_W/e" >/dev/null
check "без QR — полосы нет"                       '! grep -q "Подпись Multitest" "$T_W/e/pages/01-cover.svg"'
check "неполный манифест — отказ"                 '! mt_render_data "$T_W/nope" 2>/dev/null && printf "code\tx\n" > "$T_W/f" && mkdir -p "$T_W/g" && cp "$T_W/f" "$T_W/g/manifest" && ! mt_render_data "$T_W/g" 2>/dev/null'
( cd "$T_ROOT" && bash multitest.sh --render-data "$T_W/none" >/dev/null 2>&1 ); rc=$?
check "CLI: нет каталога — код 2"                 '[ "$rc" = 2 ]'
t_finish
