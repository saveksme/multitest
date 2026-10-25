#!/usr/bin/env bash
# --render-data с единственным тестом ТСПУ: renderer должен отдать не только
# обложку, но и страницу теста с метриками/чипами и строками в summary.txt.
# MT_RENDER_SCRIPT позволяет прогнать тот же стенд против вендоренной копии
# рендера из amber-relay (по умолчанию — текущий multitest.sh).
. "$(dirname "$0")/lib.sh"
export LC_ALL=C.UTF-8
MT_RENDER_SCRIPT="${MT_RENDER_SCRIPT:-$T_ROOT/multitest.sh}"
MULTITEST_TEST=1 source "$MT_RENDER_SCRIPT" ""
cd "$T_W" || exit 1
US=$'\x1f'
curl() { return 7; }
wget() { return 4; }
# rsvg в CI может не быть: PNG подменяем, SVG рисуется по-настоящему
mt_render_page() {
    printf 'PNG' > "$1.png"
    printf '%s\n' "$1.png" >> "$SUMMARY_DIR/pages.list"
    printf '%s\t1280\t%s\n' "$1.png" "${MT_PAGE_H:-1000}" >> "$SUMMARY_DIR/pages.dim"
}

mkdir -p d
{
    printf 'id\t7K2Q9XWAPD3M\ncode\tMT-7K2Q-9XWA-PD3M\nbot\tmultitestus_bot\ndate\t2026-10-22 01:41\n'
    printf 'ip4\t217.60.*.*\ncountry\tEE\nasn\tAS197666 STENCLOUD LLC\n'
} > d/manifest
{
    printf 'SYS_CPU\tAMD EPYC 7643 48-Core Processor\nSYS_CORES\t2\nSYS_RAM\t3.8 GiB\nSYS_DISK\t40G · 10%%\n'
    printf 'SYS_OS\tUbuntu 24.04.4 LTS\nSYS_KERNEL\t6.8.0-111-generic\nSYS_UP_S\t3600\n'
} > d/facts
printf 'run_tspu_check\tвыполнен\n' > d/status
{
    printf 'SSH порт%s22%spri\n' "$US" "$US"
    printf 'Вердикт%sРАБОТАЕТ С ПОТЕРЯМИ%swarn\n' "$US" "$US"
    printf 'Доступно%s1/2 · 50%%%swarn\n' "$US" "$US"
    printf 'DPI-обрывы%s1%sbad\n' "$US" "$US"
} > d/run_tspu_check.metrics
{
    printf 'chip%sMoscow · Demo ISP%s%sok%sоткрыт%s-1%s%s\n' "$US" "$US" "$US" "$US" "$US" "$US" "$US"
    printf 'chip%sUfa · JSC%s%sbad%sDPI%s-1%s%s\n' "$US" "$US" "$US" "$US" "$US" "$US" "$US"
} > d/run_tspu_check.services

mt_render_data "$T_W/d"; rc=$?
check "рендер без ошибок"                    '[ "$rc" = 0 ]'
check "обложка и страница ТСПУ"              '[ "$(grep -c . "$T_W/d/pages.list")" = 2 ]'
check "SVG ТСПУ-страницы существует"         'ls "$T_W"/d/pages/*tspu_check.svg >/dev/null 2>&1'
check "на странице герой ТСПУ"               'grep -q "площадок РФ видят SSH-порт сервера" "$T_W"/d/pages/*tspu_check.svg'
check "на странице чип DPI"                  'grep -q ">DPI<" "$T_W"/d/pages/*tspu_check.svg'
check "summary: тест с ключевой цифрой"      'grep -qx "test${US}tspu_check${US}ok${US}1/2 · 50% · DPI: 1${US}1" "$T_W/d/summary.txt"'
check "summary: метрика SSH-порта"           'grep -qx "metric${US}tspu_check${US}SSH порт${US}22" "$T_W/d/summary.txt"'
check "summary: svc-строка DPI"              'grep -qx "svc${US}tspu_check${US}Ufa · JSC${US}bad${US}DPI" "$T_W/d/summary.txt"'
check "склейки для бота собраны"             '[ -s "$T_W/d/tg-pages.list" ]'
t_finish
