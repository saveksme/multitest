#!/bin/bash

# ============================================================
#  Multitest — интерактивный скрипт диагностики сервера
# ============================================================

SCRIPT_VERSION="2.0"
REPO_URL="https://raw.githubusercontent.com/saveksme/multitest/master/multitest.sh"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Состояние сводки мультитеста
SUMMARY_DIR=""             # /tmp/multitest-summary-<ts>
SUMMARY_TS=""
SCRIPT_CAPTURE="util"      # util | busybox
MT_UA="Mozilla/5.0 (X11; Linux x86_64) multitest/${SCRIPT_VERSION}"  # User-Agent для хостингов

# Спонсор: строка баннера в сводке и блок в главном меню (см. print_stencloud_promo)
AD_TEXT="STENCLOUD - CHEAP SERVERS IN NETHERLANDS AND ESTONIA | PROMO 20% — BEDOLAGA"

# Марка спонсора для плашки: контур обведён с растрового логотипа и упрощён —
# держать её вектором обязательно, скрипт качают одним файлом, а PNG в base64
# весил бы больше всей таблицы Simple Icons. Система координат — высота 200,
# ширина 356; заливка evenodd, дырки внутри букв идут отдельными подпутями.
AD_LOGO_W=356
AD_LOGO_H=200
AD_LOGO_PATH="M32,23 73,23 80,26 88,32 91,41 91,48 70,48 69,44 65,42 37,42 34,43 32,46 32,49 35,52 73,52 82,56 87,60 91,65 93,70 94,73 94,82 91,90 83,98 78,101 72,103 31,103 21,99 17,97 14,93 11,87 10,82 10,77 31,77 32,82 36,84 67,84 71,83 72,80 72,76 70,74 67,72 29,72 22,69 18,66 14,62 10,54 10,43 12,38 16,32 20,28 27,25ZM96,23 172,23 172,44 143,44 143,103 121,103 121,44 96,44ZM177,23 252,23 252,43 199,43 199,54 249,54 249,72 199,72 199,83 252,83 252,103 177,103ZM260,23 287,23 320,69 322,69 322,23 343,23 343,103 316,103 285,61 283,61 283,102 260,103ZM35,112 47,112 58,115 63,118 66,123 69,128 70,133 70,137 52,137 51,133 49,130 46,128 37,127 31,130 28,135 26,142 27,153 30,158 34,161 42,162 47,160 51,157 52,151 70,151 70,158 65,168 59,173 49,177 34,177 28,176 22,173 18,171 13,165 9,154 8,137 10,130 12,125 14,122 20,117 29,113ZM74,112 92,112 92,161 121,161 121,177 74,177ZM219,112 238,113 238,154 240,158 245,161 251,161 255,160 259,154 259,113 277,112 277,157 274,166 269,171 263,175 257,177 241,177 235,176 230,174 223,168 220,162 219,157ZM295,112 318,112 325,113 334,117 341,123 346,132 348,138 348,149 346,157 343,163 335,171 328,174 320,177 284,177 284,113ZM171,113 181,113 186,114 191,117 195,121 200,129 200,139 204,140 209,143 215,150 216,154 216,160 214,168 208,174 203,176 199,177 143,177 134,174 129,169 125,159 125,150 128,141 134,134 138,132 144,130 152,130 155,123 160,118 165,115ZM303,128 303,161 314,161 321,159 326,155 328,149 328,142 325,133 323,131 318,128ZM151,154 149,155 147,158 148,162 150,164 171,164 173,163 175,161 174,156 171,154ZM182,155 179,157 179,161 182,164 185,164 187,163 188,160 188,157 186,155ZM195,155 193,156 192,161 194,163 198,164 201,161 201,157 198,155Z"

# ============================================================
#  Установка (--install)
# ============================================================

if [[ "$1" == "--install" ]]; then
    echo -e "${CYAN}Установка multitest...${NC}"
    INSTALL_PATH="/usr/local/bin/multitest"
    TMP_FILE=$(mktemp)

    if command -v curl &>/dev/null; then
        curl -sL "$REPO_URL" -o "$TMP_FILE"
    elif command -v wget &>/dev/null; then
        wget -qO "$TMP_FILE" "$REPO_URL"
    else
        echo -e "${RED}Нужен curl или wget для установки.${NC}"
        exit 1
    fi

    # Проверяем что скачался именно скрипт, а не страница ошибки
    if head -1 "$TMP_FILE" 2>/dev/null | grep -q "^#!/bin/bash"; then
        mv "$TMP_FILE" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
        echo -e "${GREEN}Установлено в ${INSTALL_PATH}${NC}"
        echo -e "${GREEN}Теперь можно запускать командой: ${BOLD}multitest${NC}"
    else
        rm -f "$TMP_FILE"
        echo -e "${RED}Ошибка: загрузка не удалась (CDN кэш). Установите напрямую:${NC}"
        echo ""
        echo "  curl -sL $REPO_URL -o /usr/local/bin/multitest && chmod +x /usr/local/bin/multitest"
        echo ""
    fi
    exit 0
fi

# ============================================================
#  Интерфейс
# ============================================================

print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║          MULTITEST v${SCRIPT_VERSION}                  ║"
    echo "  ║   Диагностика и тестирование сервера     ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Блок спонсора для терминала. Строки собираются в массив, а не печатаются на
# месте: меню выводит блок ПОД приглашением ввода и возвращает курсор обратно,
# а для этого нужна высота блока в строках.
# Цвета берём кодами 256-палитры, а не truecolor: часть профилей macOS Terminal
# ломает форму с точками с запятой.
stencloud_promo_lines() {
    local reset='' white='' violet=''

    if [[ -t 1 && "${NO_COLOR:-}" == "" ]]; then
        reset=$'\033[0m'
        white=$'\033[1;97m'
        violet=$'\033[1;38;5;99m'
    fi

    STENCLOUD_PROMO=(
        "$white"'   ___ _____ ___ _  _ '"$reset"
        "$white"'  / __|_   _| __| \| |'"$reset"
        "$white"'  \__ \ | | | _|| .` |'"$reset"
        "$white"'  |___/ |_| |___|_|\_|'"$reset"
        "$violet"'   ___ _    ___  _   _ ___ '"$reset"
        "$violet"'  / __| |  / _ \| | | |   \'"$reset"
        "$violet"' | (__| |_| (_) | |_| | |) |'"$reset"
        "$violet"'  \___|____\___/ \___/|___/ '"$reset"
        ""
        "$violet"'  STENCLOUD'"$reset$white"' - CHEAP VIRTUAL/DEDICATED SERVERS IN NETHERLANDS AND ESTONIA'"$reset"
        "$white"'  1 TB — '"$reset$violet"'1€'"$reset"
        "$white"'  UP TO '"$reset$violet"'50G'"$reset$white"' UPLINKS'"$reset"
        "$white"'  PROMO '"$reset$violet"'20%'"$reset$white"' - '"$reset$violet"'BEDOLAGA'"$reset"
        "$violet"'  @STENCLOUDBOT'"$reset$white"' / '"$reset$violet"'STENCLOUD.NET'"$reset"
    )
}

# Печать блока на месте: запасной путь для не-TTY и dumb-терминалов, где
# курсор двигать нечем.
print_stencloud_promo() {
    stencloud_promo_lines
    printf '\n'
    printf '%s\n' "${STENCLOUD_PROMO[@]}"
    printf '\n'
}

print_separator() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  >>> $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

pause_prompt() {
    echo ""
    echo -e "${YELLOW}Нажмите Enter для возврата в меню...${NC}"
    read -r
}

# ============================================================
#  Установка зависимостей
# ============================================================

detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

install_package() {
    local pkg="$1"
    local pm
    pm=$(detect_pkg_manager)

    echo -e "${YELLOW}Устанавливаю ${pkg}...${NC}"

    case "$pm" in
        apt)     DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" ;;
        dnf)     dnf install -y -q "$pkg" ;;
        yum)     yum install -y -q "$pkg" ;;
        apk)     apk add --quiet "$pkg" ;;
        pacman)  pacman -S --noconfirm --quiet "$pkg" ;;
        *)
            echo -e "${RED}Не удалось определить пакетный менеджер. Установите ${pkg} вручную.${NC}"
            return 1
            ;;
    esac
}

check_and_install() {
    local cmd="$1"
    local pkg="${2:-$1}"

    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${YELLOW}${cmd} не найден.${NC}"
        install_package "$pkg"
        if command -v "$cmd" &>/dev/null; then
            echo -e "${GREEN}${cmd} успешно установлен.${NC}"
        else
            echo -e "${RED}Не удалось установить ${cmd}.${NC}"
            return 1
        fi
    fi
    return 0
}

# Что нужно конкретному тесту. Пустая строка — тест ничего сверх базы не требует.
test_deps() {
    case "$1" in
        run_ip_region|run_censorcheck_geoblock|run_censorcheck_dpi|run_censorcheck_tlab|run_bench_sh)
            echo "wget" ;;
        run_iperf3_ru|run_iperf3_tlab)
            echo "wget iperf3 jq" ;;
        run_yabs|run_ip_check_place|run_ip_quality)
            echo "curl" ;;
        run_sysbench_cpu)
            echo "sysbench" ;;
    esac
}

# Чего не хватает для перечисленных тестов (список команд через пробел, без повторов).
# curl в базе всегда: на нём держится сама сводка — гео, аплоад картинки, шрифты.
missing_deps_for() {
    local fn d; local -a want=( curl ) out=()
    for fn in "$@"; do
        for d in $(test_deps "$fn"); do
            [[ " ${want[*]} " == *" $d "* ]] || want+=( "$d" )
        done
    done
    for d in "${want[@]}"; do
        command -v "$d" &>/dev/null || out+=( "$d" )
    done
    printf '%s' "${out[*]}"
}

# Ставит только то, что нужно выбранным тестам. Раньше здесь безусловно тянулись
# curl+wget+iperf3+sysbench — то есть sysbench приезжал на сервер, даже если из
# всего мультитеста выбрали одну проверку блокировок.
install_deps_for() {
    local miss d
    miss=$(missing_deps_for "$@")
    if [[ -z "$miss" ]]; then
        echo -e "${GREEN}Зависимости на месте — ставить нечего.${NC}"
        echo ""
        return 0
    fi
    echo -e "${CYAN}Ставлю недостающее для выбранных тестов: ${BOLD}${miss}${NC}"
    for d in $miss; do check_and_install "$d"; done
    echo ""
}

# ============================================================
#  Функции тестов
# ============================================================

run_ip_region() {
    print_separator "IP Region"
    check_and_install wget
    bash <(wget -qO- https://github.com/Davoyan/ipregion/raw/main/ipregion.sh)
}

run_censorcheck_geoblock() {
    print_separator "Censorcheck — проверка геоблока"
    check_and_install wget
    bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode geoblock
}

run_censorcheck_dpi() {
    print_separator "Censorcheck — DPI (серверы РФ)"
    check_and_install wget
    bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode dpi
}

run_censorcheck_tlab() {
    print_separator "Censorcheck — censorcheck.tlab.pw"
    check_and_install wget
    wget -qO- censorcheck.tlab.pw | bash
}

run_iperf3_ru() {
    print_separator "iPerf3 — тест до российских серверов"
    check_and_install wget
    check_and_install iperf3
    check_and_install jq
    bash <(wget -qO- https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh)
}

run_iperf3_tlab() {
    print_separator "iPerf3 — bench.tlab.pw (РФ)"
    check_and_install wget
    check_and_install iperf3
    check_and_install jq
    wget -qO- bench.tlab.pw | bash
}

run_yabs() {
    print_separator "YABS — бенчмарк сервера"
    check_and_install curl
    curl -sL yabs.sh | bash -s -- -4
}

run_ip_check_place() {
    print_separator "IP Check Place — блокировки зарубежными сервисами"
    check_and_install curl
    # -E: английский + полный прогон без меню; -n: не ставить зависимости молча;
    # </dev/null: под псевдо-TTY от `script` тулза иначе может зависнуть на read
    bash <(curl -Ls https://IP.Check.Place) -E -n </dev/null
}

run_bench_sh() {
    print_separator "bench.sh — параметры сервера и скорость"
    check_and_install wget
    wget -qO- bench.sh | bash
}

run_ip_quality() {
    print_separator "IPQuality"
    check_and_install curl
    # БЫЛО -EI: флаг -I = интерактивное меню, которое зависало под `script`.
    # -E -n + </dev/null — полный отчёт без меню и без запросов ввода.
    bash <(curl -Ls https://IP.Check.Place) -E -n </dev/null
}

run_sysbench_cpu() {
    print_separator "sysbench CPU — тест процессора"
    check_and_install sysbench
    sysbench cpu run --threads=1
}

MULTITEST_SKIPPED=0

multitest_skip_handler() {
    MULTITEST_SKIPPED=1
}

# Секунды -> «≈40 c» / «≈12 мин».
fmt_eta() {
    local v=$1
    if (( v < 90 )); then printf '≈%d c' "$v"; else printf '≈%d мин' $(( (v + 30) / 60 )); fi
}

# Дополняет строку пробелами до нужной ШИРИНЫ В СИМВОЛАХ. printf %-Ns тут не
# годится: в C/POSIX-локали он считает байты, и кириллица разъезжает вдвое.
pad_to() {
    local s="$1" w="$2" l; l=$(vlen "$s")
    printf '%s' "$s"
    while (( l < w )); do printf ' '; l=$((l+1)); done
}

# Интерактивный выбор тестов: стрелки — навигация, пробел — отметить.
# Заполняет MT_SEL (1 на выбранный тест). Возврат 1 — пользователь отменил.
# Читает all_funcs/all_names/all_secs из вызывающей run_all.
mt_select_tests() {
    local n=${#all_funcs[@]} cur=0 i key rest need eta total selected
    MT_SEL=(); for ((i=0;i<n;i++)); do MT_SEL[$i]=1; done

    trap 'printf "\033[?25h\n"; exit 130' INT
    printf '\033[?25l'
    while true; do
        printf '\033[H\033[J'
        echo -e "${CYAN}${BOLD}  МУЛЬТИТЕСТ — что запускать${NC}"
        echo ""
        echo -e "  ${BOLD}↑↓${NC} выбор  ${BOLD}ПРОБЕЛ${NC} отметить  ${BOLD}A${NC} все  ${BOLD}N${NC} снять все  ${BOLD}F${NC} только быстрые  ${BOLD}ENTER${NC} запуск  ${BOLD}Q${NC} выход"
        echo ""
        for ((i=0;i<n;i++)); do
            need=$(missing_deps_for "${all_funcs[$i]}")
            if (( i == cur )); then printf "  ${CYAN}▸${NC} "; else printf "    "; fi
            if [[ "${MT_SEL[$i]}" == "1" ]]; then printf "${GREEN}[×]${NC}"; else printf "[ ]"; fi
            printf " %2d  " "$((i+1))"
            if (( i == cur )); then printf "${BOLD}"; fi
            pad_to "$(vcut "${all_names[$i]}" 46)" 47
            if (( i == cur )); then printf "${NC}"; fi
            printf "%s" "$(pad_to "$(fmt_eta "${all_secs[$i]}")" 9)"
            [[ -n "$need" ]] && printf "${YELLOW}доставит %s${NC}" "${need// /, }"
            printf "\n"
        done

        total=0; selected=0
        for ((i=0;i<n;i++)); do
            [[ "${MT_SEL[$i]}" == "1" ]] || continue
            selected=$((selected+1)); total=$((total + all_secs[i]))
        done
        need=$(missing_deps_for $(for ((i=0;i<n;i++)); do [[ "${MT_SEL[$i]}" == "1" ]] && printf '%s ' "${all_funcs[$i]}"; done))
        echo ""
        echo -e "  Выбрано ${BOLD}${selected}${NC} из ${n} · всего $(fmt_eta $total)${need:+ · доставим: ${YELLOW}${need// /, }${NC}}"
        echo -e "  ${CYAN}Время примерное${NC} — зависит от канала и соседей по ноде."

        IFS= read -rsn1 key
        # Кириллическая раскладка: клавиша та же физически, буква другая. Ловим
        # и её, но в подсказке не показываем — там латиница, как на клавише.
        # В C-локали read -n1 отдаёт БАЙТ, а кириллица в UTF-8 двухбайтовая,
        # поэтому хвост дочитываем сами; в UTF-8-локали read вернёт символ
        # целиком и это условие просто не сработает.
        [[ "$key" == [$'\xd0'-$'\xd1'] ]] && { IFS= read -rsn1 rest 2>/dev/null; key="$key$rest"; }
        case "$key" in
            ф|Ф) key=a ;;   # A — все
            т|Т) key=n ;;   # N — снять все
            а|А) key=f ;;   # F — только быстрые
            й|Й) key=q ;;   # Q — выход
            л|Л) key=k ;;   # k — вверх
            о|О) key=j ;;   # j — вниз
        esac
        case "$key" in
            $'\e')
                IFS= read -rsn2 -t 0.05 rest
                case "$rest" in
                    '[A') (( cur = (cur - 1 + n) % n )) ;;
                    '[B') (( cur = (cur + 1) % n )) ;;
                    '')   trap - INT; printf '\033[?25h'; return 1 ;;
                esac ;;
            ' ')  MT_SEL[$cur]=$(( 1 - MT_SEL[$cur] )) ;;
            k|K)  (( cur = (cur - 1 + n) % n )) ;;
            j|J)  (( cur = (cur + 1) % n )) ;;
            a|A)  for ((i=0;i<n;i++)); do MT_SEL[$i]=1; done ;;
            n|N)  for ((i=0;i<n;i++)); do MT_SEL[$i]=0; done ;;
            f|F)  for ((i=0;i<n;i++)); do
                      if (( all_secs[i] <= 60 )); then MT_SEL[$i]=1; else MT_SEL[$i]=0; fi
                  done ;;
            q|Q)  trap - INT; printf '\033[?25h'; return 1 ;;
            '')   (( selected > 0 )) && { trap - INT; printf '\033[?25h'; return 0; } ;;
        esac
    done
}

run_all() {
    print_separator "МУЛЬТИТЕСТ — выбор тестов"

    # --- Полный каталог тестов (порядок = нумерация в главном меню) ---
    # Оценки времени грубые, порядок величины: нужны, чтобы прикинуть цену выбора.
    local all_funcs=( "run_ip_region" "run_censorcheck_geoblock" "run_censorcheck_dpi" \
                      "run_censorcheck_tlab" "run_iperf3_ru" "run_iperf3_tlab" "run_yabs" \
                      "run_ip_check_place" "run_bench_sh" "run_ip_quality" "run_sysbench_cpu" )
    local all_names=( "IP Region" \
                      "Censorcheck — проверка геоблока" \
                      "Censorcheck — DPI (серверы РФ)" \
                      "Censorcheck — censorcheck.tlab.pw" \
                      "iPerf3 — тест до российских серверов" \
                      "iPerf3 — bench.tlab.pw (РФ)" \
                      "YABS — бенчмарк сервера" \
                      "IP Check Place — блокировки зарубежными сервисами" \
                      "bench.sh — параметры сервера и скорость" \
                      "IPQuality" \
                      "sysbench CPU — тест процессора" )
    local all_secs=(  40 120 180 120 180 120 720 180 300 180 15 )
    local catalog_total=${#all_funcs[@]}

    # --- Выбор тестов ---
    local -a MT_SEL=()
    local k idx
    if [[ -t 0 && -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
        if ! mt_select_tests; then
            echo -e "\n  ${YELLOW}Мультитест отменён.${NC}"
            return 0
        fi
    else
        # Запасной путь для не-TTY и dumb-терминалов (`wget -qO- ... | bash`):
        # интерактивный список там нарисовать нечем, остаётся ввод номеров.
        local selection=""
        if [[ -t 0 ]]; then
            echo -e "  ${CYAN}${BOLD}Какие тесты включить в мультитест?${NC}"
            echo ""
            for k in $(seq 0 $((catalog_total - 1))); do
                printf "    ${GREEN}%2d)${NC} %s\n" "$((k + 1))" "${all_names[$k]}"
            done
            echo ""
            echo -e "  Номера через пробел или запятую (например: ${BOLD}1 3 5${NC}); диапазоны: ${BOLD}4-7${NC}"
            echo -ne "  ${BOLD}Выбор (Enter = все тесты): ${NC}"
            read -r selection
        fi
        for k in $(seq 0 $((catalog_total - 1))); do MT_SEL[$k]=0; done
        if [[ -z "$selection" || "$selection" =~ ^([Aa][Ll][Ll]|[Вв]се)$ ]]; then
            for k in $(seq 0 $((catalog_total - 1))); do MT_SEL[$k]=1; done
        else
            local tok start end
            for tok in $(printf '%s' "$selection" | tr ',' ' '); do
                if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    start="${BASH_REMATCH[1]}"; end="${BASH_REMATCH[2]}"
                elif [[ "$tok" =~ ^[0-9]+$ ]]; then
                    start="$tok"; end="$tok"
                else
                    continue
                fi
                for idx in $(seq "$start" "$end"); do
                    (( idx >= 1 && idx <= catalog_total )) && MT_SEL[$((idx-1))]=1
                done
            done
            local any=0
            for k in $(seq 0 $((catalog_total - 1))); do [[ "${MT_SEL[$k]}" == "1" ]] && any=1; done
            if [[ $any -eq 0 ]]; then
                echo -e "  ${YELLOW}Ничего корректного не выбрано — запускаю все тесты.${NC}"
                for k in $(seq 0 $((catalog_total - 1))); do MT_SEL[$k]=1; done
            fi
        fi
    fi

    # --- Список выбранных тестов (глобальные массивы для сводки) ---
    test_funcs=()
    test_names=()
    for k in $(seq 0 $((catalog_total - 1))); do
        [[ "${MT_SEL[$k]}" == "1" ]] || continue
        test_funcs+=( "${all_funcs[$k]}" )
        test_names+=( "${all_names[$k]}" )
    done

    print_separator "МУЛЬТИТЕСТ — запуск (${#test_funcs[@]} тест(ов))"
    for k in "${!test_names[@]}"; do
        printf "    ${GREEN}%2d.${NC} %s\n" "$((k + 1))" "${test_names[$k]}"
    done
    echo ""
    echo -e "  ${YELLOW}Ctrl+C${NC} во время теста — пропустить текущий"
    echo -e "  Тесты идут автоматически; нажмите любую клавишу, чтобы выбрать вручную."
    echo ""
    install_deps_for "${test_funcs[@]}"

    # Каталог + статусы для сводки (в картинке показываем и невыбранные тесты)
    MT_CAT_FUNCS=( "${all_funcs[@]}" )
    MT_CAT_NAMES=( "${all_names[@]}" )
    declare -gA MT_STATUS=()
    local _f
    for _f in "${test_funcs[@]}"; do MT_STATUS["$_f"]="пропущен"; done

    test_status=()
    test_metric=()
    test_log=()

    # Каталог для логов тестов и файлов сводки
    SUMMARY_TS=$(date +%Y%m%d-%H%M%S)
    SUMMARY_DIR="/tmp/multitest-summary-${SUMMARY_TS}"
    mkdir -p "$SUMMARY_DIR" 2>/dev/null
    detect_script_flavor

    local total=${#test_funcs[@]}
    local i

    for i in $(seq 0 $((total - 1))); do
        local num=$((i + 1))
        test_status[$i]="пропущен"
        test_metric[$i]=""
        test_log[$i]="$SUMMARY_DIR/test-${num}.log"

        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${CYAN}[${num}/${total}]${NC} Следующий: ${BOLD}${test_names[$i]}${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # --- Автостарт через 5 c, любая клавиша → ручной выбор ---
        local action="" _key=""
        if [[ -t 0 ]]; then
            echo -ne "  ${CYAN}Автозапуск через ${BOLD}5${NC}${CYAN}c — нажмите любую клавишу для ручного выбора...${NC} "
            if read -r -t 5 -n 1 _key; then
                echo ""
                echo -ne "  ${BOLD}Enter${NC} — запустить | ${YELLOW}s${NC} — пропустить | ${RED}q${NC} — выход: "
                read -r action
            else
                echo ""
            fi
        fi

        case "$action" in
            s|S)
                echo -e "  ${YELLOW}Пропущено.${NC}"
                continue
                ;;
            q|Q)
                echo -e "\n${GREEN}Мультитест прерван. Выполнено тестов: $((num - 1))/${total}${NC}"
                render_and_upload_summary
                return
                ;;
        esac

        # Запуск теста в подоболочке с захватом вывода, Ctrl+C убивает только тест
        MULTITEST_SKIPPED=0
        trap multitest_skip_handler INT
        ( capture_test "${test_funcs[$i]}" "${test_log[$i]}" )
        trap - INT

        if [[ $MULTITEST_SKIPPED -eq 1 ]]; then
            echo ""
            echo -e "  ${YELLOW}Тест пропущен (Ctrl+C).${NC}"
            test_status[$i]="пропущен"
        else
            test_status[$i]="выполнен"
            [[ -s "${test_log[$i]}" ]] || test_status[$i]="ошибка"
            parse_test_output "${test_funcs[$i]}" "${test_log[$i]}" \
                "$SUMMARY_DIR/${test_funcs[$i]}.metrics" "$SUMMARY_DIR/${test_funcs[$i]}.services"
        fi
        MT_STATUS["${test_funcs[$i]}"]="${test_status[$i]}"
    done

    echo ""
    echo -e "${GREEN}${BOLD}Все тесты завершены! (${total}/${total})${NC}"
    render_and_upload_summary
}

# ============================================================
#  Утилиты
# ============================================================

BBR_CONF="/etc/sysctl.d/99-bbr-cake.conf"
IPV6_CONF="/etc/sysctl.d/99-disable-ipv6.conf"

# Ищет ключ sysctl в чужих конфигах. Свой файл мы при выключении удаляем, но
# если то же значение прописано ещё где-то, после перезагрузки оно вернётся —
# и человек будет думать, что выключение не сработало. Лучше сказать сразу.
sysctl_other_sources() {
    local key="${1//./\\.}" mine="$2"
    grep -rlsE "^[[:space:]]*${key}[[:space:]]*=" \
        /etc/sysctl.conf /etc/sysctl.d /run/sysctl.d /usr/lib/sysctl.d 2>/dev/null \
        | grep -vFx "$mine" | sort -u
}

enable_bbr_cake() {
    print_separator "Включение BBR + Cake"

    # Проверяем текущее состояние
    local current_cc
    current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local current_qdisc
    current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)

    echo -e "Текущий congestion control: ${BOLD}${current_cc}${NC}"
    echo -e "Текущий qdisc:              ${BOLD}${current_qdisc}${NC}"
    echo ""

    # Загрузка модулей
    modprobe tcp_bbr 2>/dev/null
    modprobe sch_cake 2>/dev/null

    # Запоминаем, что стояло до нас: иначе выключать некуда — «обратно» у
    # congestion control нет, значение просто держится до следующей записи.
    # Метку пишем только при первом включении, иначе повторный запуск затрёт
    # исходные значения теми, что сам же и поставил.
    local prev_note
    prev_note=$(grep -m1 '^# multitest: было ' "$BBR_CONF" 2>/dev/null) \
        || prev_note="# multitest: было cc=${current_cc:-?} qdisc=${current_qdisc:-?}"

    # Записываем параметры в sysctl
    cat > "$BBR_CONF" <<EOF
${prev_note}
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl -p "$BBR_CONF"

    # Проверяем результат
    local new_cc
    new_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local new_qdisc
    new_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)

    echo ""
    if [[ "$new_cc" == "bbr" && "$new_qdisc" == "cake" ]]; then
        echo -e "${GREEN}BBR + Cake успешно включены!${NC}"
    else
        echo -e "${YELLOW}Congestion control: ${new_cc}, qdisc: ${new_qdisc}${NC}"
        echo -e "${YELLOW}Проверьте, что ядро поддерживает BBR и Cake.${NC}"
    fi
}

disable_bbr_cake() {
    print_separator "Выключение BBR + Cake"

    local cc qd
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    qd=$(sysctl -n net.core.default_qdisc 2>/dev/null)

    echo -e "Текущий congestion control: ${BOLD}${cc}${NC}"
    echo -e "Текущий qdisc:              ${BOLD}${qd}${NC}"
    echo ""

    # Куда возвращаться: значения из метки, записанной при включении. Файла нет
    # или метки в нём нет — берём то, с чем ядро живёт по умолчанию.
    local prev_cc="" prev_qd=""
    if [[ -f "$BBR_CONF" ]]; then
        prev_cc=$(sed -n 's/^# multitest: было cc=\([^ ]*\).*/\1/p'    "$BBR_CONF" | head -1)
        prev_qd=$(sed -n 's/^# multitest: было .*qdisc=\([^ ]*\).*/\1/p' "$BBR_CONF" | head -1)
    fi
    # Если и до нас стояли bbr/cake — возвращать их бессмысленно, просили выключить.
    [[ -z "$prev_cc" || "$prev_cc" == "bbr"  || "$prev_cc" == "?" ]] && prev_cc="cubic"
    [[ -z "$prev_qd" || "$prev_qd" == "cake" || "$prev_qd" == "?" ]] && prev_qd="fq_codel"

    # cubic может быть не собран в ядре — тогда берём первый доступный.
    local avail
    avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
    if [[ -n "$avail" && " $avail " != *" $prev_cc "* ]]; then
        echo -e "${YELLOW}${prev_cc} недоступен (есть: ${avail}) — ставлю ${avail%% *}.${NC}"
        prev_cc="${avail%% *}"
    fi

    rm -f "$BBR_CONF"
    sysctl -w "net.ipv4.tcp_congestion_control=$prev_cc" >/dev/null 2>&1
    sysctl -w "net.core.default_qdisc=$prev_qd"          >/dev/null 2>&1

    local new_cc new_qd
    new_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    new_qd=$(sysctl -n net.core.default_qdisc 2>/dev/null)

    echo ""
    if [[ "$new_cc" != "bbr" && "$new_qd" != "cake" ]]; then
        echo -e "${GREEN}BBR + Cake выключены: ${BOLD}${new_cc} / ${new_qd}${NC}"
    else
        echo -e "${RED}Сейчас ${new_cc} / ${new_qd} — сбросить не удалось (нужен root?).${NC}"
        return
    fi

    # default_qdisc читается в момент создания очереди. У поднятого интерфейса
    # она уже создана, поэтому cake на нём останется до перезагрузки.
    local ifc live
    ifc=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
    if [[ -n "$ifc" ]]; then
        live=$(tc qdisc show dev "$ifc" 2>/dev/null | awk 'NR==1{print $2}')
        if [[ "$live" == "cake" ]]; then
            echo ""
            echo -e "  ${YELLOW}На ${BOLD}${ifc}${NC}${YELLOW} очередь всё ещё cake: новый qdisc берётся при её создании.${NC}"
            echo -e "  Сменится после перезагрузки — или сразу: ${BOLD}tc qdisc replace dev ${ifc} root ${prev_qd}${NC}"
        fi
    fi

    local others
    others=$( { sysctl_other_sources "net.ipv4.tcp_congestion_control" "$BBR_CONF"
                sysctl_other_sources "net.core.default_qdisc"          "$BBR_CONF"; } | sort -u )
    if [[ -n "$others" ]]; then
        echo ""
        echo -e "  ${YELLOW}Эти файлы тоже задают congestion control или qdisc — после перезагрузки победят они:${NC}"
        printf '%s\n' "$others" | sed 's/^/    /'
    fi
}

disable_ipv6() {
    print_separator "Выключение IPv6"

    # Проверяем текущее состояние
    local current_state
    current_state=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)

    if [[ "$current_state" == "1" ]]; then
        echo -e "${YELLOW}IPv6 уже выключен.${NC}"
        return
    fi

    echo -e "Текущий статус IPv6: ${BOLD}включён${NC}"
    echo ""

    # Записываем параметры в sysctl
    cat > "$IPV6_CONF" <<EOF
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF

    sysctl -p "$IPV6_CONF"

    # Проверяем результат
    local new_state
    new_state=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)

    echo ""
    if [[ "$new_state" == "1" ]]; then
        echo -e "${GREEN}IPv6 успешно выключен!${NC}"
    else
        echo -e "${RED}Не удалось выключить IPv6.${NC}"
    fi
}

enable_ipv6() {
    print_separator "Включение IPv6"

    # Ядро могло стартовать с ipv6.disable=1 — тогда ключей sysctl просто нет,
    # и включать нечего: правится только параметром загрузки.
    if [[ ! -e /proc/sys/net/ipv6/conf/all/disable_ipv6 ]]; then
        echo -e "${RED}IPv6 отключён на уровне ядра (ipv6.disable=1 в параметрах загрузки).${NC}"
        echo -e "  Sysctl тут бессилен: уберите ${BOLD}ipv6.disable=1${NC} из GRUB_CMDLINE_LINUX"
        echo -e "  в ${BOLD}/etc/default/grub${NC}, выполните ${BOLD}update-grub${NC} и перезагрузитесь."
        return
    fi

    local current_state
    current_state=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)

    if [[ "$current_state" == "0" ]]; then
        echo -e "${YELLOW}IPv6 уже включён.${NC}"
        return
    fi

    echo -e "Текущий статус IPv6: ${BOLD}выключен${NC}"
    echo ""

    rm -f "$IPV6_CONF"
    sysctl -w net.ipv6.conf.all.disable_ipv6=0     >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=0      >/dev/null 2>&1

    local new_state
    new_state=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)

    echo ""
    if [[ "$new_state" == "0" ]]; then
        echo -e "${GREEN}IPv6 включён.${NC}"
    else
        echo -e "${RED}Не удалось включить IPv6 (нужен root?).${NC}"
        return
    fi

    # Адрес сам собой не возвращается: он приезжает с router advertisement, и
    # это занимает несколько секунд. Пустой список — ещё не отказ.
    local addrs
    addrs=$(ip -6 addr show scope global 2>/dev/null | awk '/inet6/{print $2}' | paste -sd' ' -)
    if [[ -n "$addrs" ]]; then
        echo -e "  Глобальные адреса: ${BOLD}${addrs}${NC}"
    else
        echo -e "  ${YELLOW}Глобального адреса пока нет — он приходит с router advertisement.${NC}"
        echo -e "  ${YELLOW}Подождите несколько секунд; если не появился — поднимите интерфейс"
        echo -e "  заново или пропишите адрес статикой, как он указан в панели хостера.${NC}"
    fi

    local others
    others=$(sysctl_other_sources "net.ipv6.conf.all.disable_ipv6" "$IPV6_CONF")
    if [[ -n "$others" ]]; then
        echo ""
        echo -e "  ${YELLOW}IPv6 выключен ещё и здесь — после перезагрузки вернётся:${NC}"
        printf '%s\n' "$others" | sed 's/^/    /'
    fi
}

show_utilities_menu() {
    while true; do
        print_header
        echo -e "  ${CYAN}${BOLD}── Утилиты ──${NC}"
        echo ""

        # Пункты — переключатели: показываем состояние и предлагаем обратное
        # действие. Иначе на два параметра пришлось бы четыре пункта, половина
        # из которых в любой момент бессмысленна.
        local cc qd bbr_on=0 v6_on=0 v6_txt
        cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
        qd=$(sysctl -n net.core.default_qdisc 2>/dev/null)
        [[ "$cc" == "bbr" && "$qd" == "cake" ]] && bbr_on=1

        if [[ ! -e /proc/sys/net/ipv6/conf/all/disable_ipv6 ]]; then
            v6_txt="выключен в ядре"
        elif [[ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" == "1" ]]; then
            v6_txt="выключен"
        else
            v6_on=1
            v6_txt="включён"
        fi

        if [[ $bbr_on -eq 1 ]]; then
            echo -e "  ${GREEN}1)${NC}  BBR + Cake — ${BOLD}выключить${NC}  ${CYAN}сейчас: ${cc} / ${qd}${NC}"
        else
            echo -e "  ${GREEN}1)${NC}  BBR + Cake — ${BOLD}включить${NC}   ${CYAN}сейчас: ${cc:-?} / ${qd:-?}${NC}"
        fi
        if [[ $v6_on -eq 1 ]]; then
            echo -e "  ${GREEN}2)${NC}  IPv6 — ${BOLD}выключить${NC}        ${CYAN}сейчас: ${v6_txt}${NC}"
        else
            echo -e "  ${GREEN}2)${NC}  IPv6 — ${BOLD}включить${NC}         ${CYAN}сейчас: ${v6_txt}${NC}"
        fi

        echo ""
        echo -e "  ${RED}0)${NC}  Назад"
        echo ""
        echo -ne "  ${BOLD}Выберите пункт [0-2]: ${NC}"
        read -r util_choice

        case "$util_choice" in
            1) if [[ $bbr_on -eq 1 ]]; then disable_bbr_cake; else enable_bbr_cake; fi; pause_prompt ;;
            2) if [[ $v6_on -eq 1 ]]; then disable_ipv6; else enable_ipv6; fi; pause_prompt ;;
            0) return ;;
            *) echo -e "${RED}Неверный выбор.${NC}"; pause_prompt ;;
        esac
    done
}

# ============================================================
#  Сводка мультитеста (изображение)
# ============================================================

detect_script_flavor() {
    if script --version 2>&1 | grep -qi 'util-linux'; then
        SCRIPT_CAPTURE='util'
    else
        SCRIPT_CAPTURE='busybox'
    fi
}

strip_ansi() {
    # 1) убираем ANSI; 2) хвостовой \r (из \r\n); 3) \r-перезаписи: оставляем только
    # текст после последнего \r в строке — как показывает терминал (иначе прогресс-
    # строки вида "Performing iperf3..." слипались с результатом "Clouvider | London ...").
    sed -r 's/\x1B\[[0-9;]*[a-zA-Z]//g; s/\x1B\][^\x07]*\x07//g; s/\r$//; s/.*\r//'
}

# Запуск теста с захватом вывода в лог (для парсинга метрик).
capture_test() {
    local fn="$1"
    local logfile="$2"

    export RED GREEN YELLOW CYAN BOLD NC SCRIPT_VERSION
    export -f print_separator check_and_install install_package detect_pkg_manager
    export -f run_ip_region run_censorcheck_geoblock run_censorcheck_dpi \
              run_censorcheck_tlab run_iperf3_ru run_iperf3_tlab run_yabs \
              run_ip_check_place run_bench_sh run_ip_quality run_sysbench_cpu

    if [[ "$SCRIPT_CAPTURE" == "util" ]]; then
        COLUMNS=200 script -q -c "stty cols 200 2>/dev/null; bash -c '$fn'" "$logfile"
    else
        COLUMNS=200 bash -c "$fn" 2>&1 | tee "$logfile"
    fi
}

# --- Загрузчики на бесплатные хостинги (каждый: файл=$1 -> URL в stdout) ---
# UA важен: 0x0.st и часть хостов отдают 403 на дефолтный User-Agent curl.
# -4 на случай сломанного IPv6 (частая причина таймаутов на VPS).

# imgdb.io — основной: анонимно (без ключа/регистрации), работает с VPS, срок
# жизни ссылки задаётся параметром ttl (секунды). Допустимы только значения из
# таблицы API: 3600 7200 18000 43200 86400 259200 604800 1209600 2592000 7776000
# и 0 = бессрочно; любое другое хостинг молча превращает в 72 часа.
# Ссылки дольше 72 ч он ужимает сильнее — карточку квантует до 9 цветов, но она
# монохромная, так что фон, рамки и текст переживают это без потерь читаемости.
MT_IMGDB_TTL="${MT_IMGDB_TTL:-0}"

up_imgdb() {
    local r url exp
    # SVG хостинг не принимает (415) — не тратим на него запрос.
    [[ "$1" == *.svg ]] && return 1
    r=$(curl -fsS -4 -A "$MT_UA" --max-time 60 -F "file=@$1" \
        "https://imgdb.io/api/v1/upload?ttl=${MT_IMGDB_TTL}" 2>/dev/null) || return 1
    url=$(printf '%s' "$r" | grep -oE '"url"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    [[ -n "$url" ]] || return 1
    # expires — epoch или null; по нему потом показываем реальный срок жизни,
    # а не тот, который мы попросили (сервер мог откатить ttl на дефолтные 72 ч).
    exp=$(printf '%s' "$r" | grep -oE '"expires"[[:space:]]*:[[:space:]]*(null|[0-9]+)' | head -1 | grep -oE '(null|[0-9]+)$')
    [[ -n "$exp" && -n "$SUMMARY_DIR" && -d "$SUMMARY_DIR" ]] && printf '%s' "$exp" > "$SUMMARY_DIR/expires.txt"
    printf '%s' "$url"
}

# imgdb.io, альбом: до 64 картинок одним запросом, в ответ одна ссылка
# https://imgdb.io/a/<id>. Ради него всё и затевалось — сводка уезжает не
# простынёй в 6000 px, которую Telegram пересчитает и зальёт JPEG поверх
# 11-пиксельного текста, а страницами: каждая своим файлом и в размере,
# который мессенджер уже не трогает.
# Двухшаговый вариант API (сначала /upload, потом сборка по id) не берём:
# он на случай запросов больше 150 МБ, а страницы весят десятки килобайт,
# зато каждый лишний запрос — это ещё один шанс упасть на полпути.
up_imgdb_album() {
    local -a args=(); local f r url exp
    (( $# > 0 )) || return 1
    for f in "$@"; do
        # SVG хостинг не принимает (415) — на таком наборе альбома не будет
        [[ -s "$f" && "$f" != *.svg ]] || return 1
        args+=( -F "file=@$f" )
    done
    r=$(curl -fsS -4 -A "$MT_UA" --max-time 180 "${args[@]}" \
        "https://imgdb.io/api/v1/album?ttl=${MT_IMGDB_TTL}" 2>/dev/null) || return 1
    # первый "url" в ответе — сам альбом; members отдаются в items как голые id
    url=$(printf '%s' "$r" | grep -oE '"url"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    [[ "$url" == https://* ]] || return 1
    exp=$(printf '%s' "$r" | grep -oE '"expires"[[:space:]]*:[[:space:]]*(null|[0-9]+)' | head -1 | grep -oE '(null|[0-9]+)$')
    [[ -n "$exp" && -n "$SUMMARY_DIR" && -d "$SUMMARY_DIR" ]] && printf '%s' "$exp" > "$SUMMARY_DIR/expires.txt"
    printf '%s' "$url"
}

# x0.at — запасной: анонимно, работает с VPS, ссылка живёт ~100 дней.
up_x0()      { curl -fsS -4 -A "$MT_UA" --max-time 60 -F "file=@$1" https://x0.at 2>/dev/null; }
# catbox: постоянные ссылки, но анонимную загрузку файлов с хостинг/VPS-IP отдаёт
# 412 "Invalid uploader" (работает только с домашних IP / с аккаунтом).
up_catbox()  { curl -fsS -4 -A "$MT_UA" --max-time 60 -F "reqtype=fileupload" -F "fileToUpload=@$1" https://catbox.moe/user/api.php 2>/dev/null; }
# litterbox — временный хостинг семейства catbox (до 72 ч), работает с VPS.
up_litterbox() { curl -fsS -4 -A "$MT_UA" --max-time 60 -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@$1" https://litterbox.catbox.moe/resources/internals/api.php 2>/dev/null; }
up_uguu()    { curl -fsS -4 -A "$MT_UA" --max-time 45 -F "files[]=@$1" "https://uguu.se/upload?output=text" 2>/dev/null | grep -oE 'https://[^[:space:]"]+' | head -1; }

up_tmpfiles() {
    local r u
    r=$(curl -fsS -4 -A "$MT_UA" --max-time 45 -F "file=@$1" https://tmpfiles.org/api/v1/upload 2>/dev/null) || return 1
    u=$(printf '%s' "$r" | grep -oE 'https?://tmpfiles\.org/[0-9]+/[^"]+' | head -1)
    [[ -n "$u" ]] && printf '%s' "$u" | sed 's#tmpfiles\.org/#tmpfiles.org/dl/#'
}

up_pixeldrain() {
    local r id
    r=$(curl -fsS -4 -A "$MT_UA" --max-time 60 -T "$1" "https://pixeldrain.com/api/file/$(basename "$1")" 2>/dev/null) || return 1
    id=$(printf '%s' "$r" | grep -oE '"id":"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    [[ -n "$id" ]] && printf 'https://pixeldrain.com/u/%s' "$id"
}

up_telegraph() {
    local r src
    r=$(curl -fsS -4 -A "$MT_UA" --max-time 45 -F "file=@$1;type=image/png" https://telegra.ph/upload 2>/dev/null) || return 1
    src=$(printf '%s' "$r" | grep -oE '"src":"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    [[ -n "$src" ]] && printf 'https://telegra.ph%s' "$src"
}

up_fileio() {
    curl -fsS -4 -A "$MT_UA" --max-time 45 -F "file=@$1" https://file.io 2>/dev/null \
        | grep -oE 'https://file\.io/[A-Za-z0-9]+' | head -1
}

# Перебирает хостинги по очереди; первый успешный URL -> stdout, статус -> stderr.
upload_report() {
    local file="$1" url name
    # imgdb.io — основной (анонимно, работает с VPS, лайфтайм ссылки задаём сами). Остальные — запас.
    for name in imgdb x0 catbox litterbox uguu tmpfiles pixeldrain fileio telegraph; do
        echo -ne "${CYAN}Загружаю на ${name}...${NC} " >&2
        url=$("up_${name}" "$file" 2>/dev/null); url=$(printf '%s' "$url" | tr -d '\r\n[:space:]')
        if [[ "$url" == https://* ]]; then echo -e "${GREEN}✓${NC}" >&2; printf '%s\n' "$url"; return 0; fi
        echo -e "${YELLOW}нет${NC}" >&2
    done
    echo -e "${RED}✗ ни один хостинг недоступен${NC}" >&2
    return 1
}

# Гарантирует наличие рендерера SVG->PNG (rsvg-convert, иначе ImageMagick).
ensure_rsvg() {
    command -v rsvg-convert &>/dev/null && return 0

    local pm
    pm=$(detect_pkg_manager)
    case "$pm" in
        apt)     check_and_install rsvg-convert librsvg2-bin ;;
        dnf|yum) check_and_install rsvg-convert librsvg2-tools ;;
        apk)     check_and_install rsvg-convert rsvg-convert ;;
        pacman)  check_and_install rsvg-convert librsvg ;;
    esac
    command -v rsvg-convert &>/dev/null && return 0

    # EPEL для RHEL-семейства
    if [[ "$pm" == "yum" || "$pm" == "dnf" ]]; then
        $pm install -y epel-release >/dev/null 2>&1
        check_and_install rsvg-convert librsvg2-tools
        command -v rsvg-convert &>/dev/null && return 0
    fi

    # Фолбэк: ImageMagick
    echo -e "${YELLOW}rsvg-convert недоступен, пробую ImageMagick...${NC}"
    case "$pm" in
        apt)     check_and_install convert imagemagick ;;
        dnf|yum) check_and_install convert ImageMagick ;;
        apk)     check_and_install convert imagemagick ;;
        pacman)  check_and_install magick imagemagick ;;
    esac
    command -v rsvg-convert &>/dev/null && return 0
    command -v convert      &>/dev/null && return 0
    command -v magick       &>/dev/null && return 0
    return 1
}

# Best-effort: ставит шрифт для сводки. Приоритет — IBM Plex Sans: рисовался под
# технические интерфейсы, у него полная кириллица и ровные цифры, которые удобно
# сканировать в столбик. Статические начертания качаем с CDN, в репозиториях
# дистрибутивов его обычно нет. Запас — Roboto/Noto/DejaVu из пакетов; кириллица
# есть во всех трёх. Никогда не фатальна: пакеты ставятся по одному, чтобы
# отсутствие одного имени не валило остальные.
# librsvg игнорирует @font-face, поэтому шрифт обязан попасть в fontconfig.
ensure_fonts() {
    command -v fc-list &>/dev/null || install_package fontconfig >/dev/null 2>&1

    local got_plex=0
    if fc-list 2>/dev/null | grep -qi 'IBM *Plex *Sans'; then
        got_plex=1
    else
        echo -e "${YELLOW}Загружаю шрифт IBM Plex Sans для сводки...${NC}"
        local fdir="/usr/share/fonts/truetype/ibm-plex-sans"
        mkdir -p "$fdir" 2>/dev/null || { fdir="$HOME/.local/share/fonts/ibm-plex-sans"; mkdir -p "$fdir" 2>/dev/null; }
        local base="https://cdn.jsdelivr.net/npm/@expo-google-fonts/ibm-plex-sans" w f
        for w in 400Regular 600SemiBold 700Bold; do
            f="$fdir/IBMPlexSans_${w}.ttf"
            if command -v curl &>/dev/null; then
                curl -fsSL --max-time 30 "$base/IBMPlexSans_${w}.ttf" -o "$f" 2>/dev/null
            else
                wget -qO "$f" "$base/IBMPlexSans_${w}.ttf" 2>/dev/null
            fi
            # держим только валидные TTF (магия 00 01 00 00), битые удаляем
            if [[ -s "$f" ]] && [[ "$(head -c4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" == "00010000" ]]; then
                got_plex=1
            else
                rm -f "$f"
            fi
        done
        [[ $got_plex -eq 1 ]] || echo -e "${YELLOW}IBM Plex Sans недоступен — использую запасной шрифт.${NC}"
    fi

    # Запасные шрифты ставим только если Plex не получен и Roboto ещё нет.
    if [[ $got_plex -eq 0 ]] && ! fc-list 2>/dev/null | grep -qi 'roboto'; then
        local pm; pm=$(detect_pkg_manager)
        case "$pm" in
            apt)
                DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fonts-roboto >/dev/null 2>&1 \
                    || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fonts-roboto-unhinted >/dev/null 2>&1
                DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fonts-noto-core fonts-dejavu-core >/dev/null 2>&1 ;;
            dnf|yum) $pm install -y -q google-roboto-fonts google-noto-sans-fonts dejavu-sans-fonts >/dev/null 2>&1 ;;
            apk)     apk add --quiet font-roboto font-noto font-dejavu >/dev/null 2>&1 ;;
            pacman)  pacman -S --noconfirm --quiet ttf-roboto noto-fonts ttf-dejavu >/dev/null 2>&1 ;;
        esac
    fi
    command -v fc-cache &>/dev/null && fc-cache -f >/dev/null 2>&1
    return 0
}

# Собирает характеристики сервера в SYS_* (надёжно, не парсит вывод тестов).
gather_system_facts() {
    SYS_OS=$(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')
    [[ -z "$SYS_OS" ]] && SYS_OS=$(uname -o 2>/dev/null || echo "unknown")
    SYS_KERNEL=$(uname -r 2>/dev/null || echo "unknown")
    SYS_ARCH=$(uname -m 2>/dev/null || echo "?")
    SYS_CPU=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')
    [[ -z "$SYS_CPU" ]] && SYS_CPU=$(lscpu 2>/dev/null | grep -m1 'Model name' | cut -d: -f2- | sed 's/^ *//')
    [[ -z "$SYS_CPU" ]] && SYS_CPU="unknown"
    SYS_CORES=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "?")
    SYS_RAM=$(awk '/MemTotal/ {printf "%.1f GiB", $2/1048576}' /proc/meminfo 2>/dev/null)
    [[ -z "$SYS_RAM" ]] && SYS_RAM=$(free -h 2>/dev/null | awk '/Mem:/ {print $2}')
    [[ -z "$SYS_RAM" ]] && SYS_RAM="—"
    # размер именно корневого ФС (df --total раздувал цифру за счёт tmpfs/overlay/devtmpfs)
    SYS_DISK=$(df -h / 2>/dev/null | awk 'NR==2 {print $2" · "$5}')
    [[ -z "$SYS_DISK" ]] && SYS_DISK="—"
    SYS_VIRT=$(systemd-detect-virt 2>/dev/null || echo "unknown")
    [[ -z "$SYS_VIRT" ]] && SYS_VIRT="unknown"
    SYS_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "?")
    SYS_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "?")
    SYS_UPTIME=$(uptime -p 2>/dev/null | sed 's/^up //')
    [[ -z "$SYS_UPTIME" ]] && SYS_UPTIME=$(awk '{d=int($1/86400);h=int(($1%86400)/3600);printf "%dd %dh", d, h}' /proc/uptime 2>/dev/null)
    [[ -z "$SYS_UPTIME" ]] && SYS_UPTIME="—"
    SYS_LOAD=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)
    [[ -z "$SYS_LOAD" ]] && SYS_LOAD="—"
    # Адреса тянем порознь: без -4/-6 curl на dual-stack идёт по IPv6, и в сводке
    # оставался только он — IPv4 сервера в отчёте не было вовсе.
    SYS_IP4=$(curl -s4 --max-time 6 https://ifconfig.me 2>/dev/null)
    [[ "$SYS_IP4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || SYS_IP4=$(curl -s4 --max-time 6 https://api.ipify.org 2>/dev/null)
    [[ "$SYS_IP4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || SYS_IP4=""
    SYS_IP6=$(curl -s6 --max-time 6 https://ifconfig.me 2>/dev/null)
    [[ "$SYS_IP6" == *:* ]] || SYS_IP6=$(curl -s6 --max-time 6 https://api6.ipify.org 2>/dev/null)
    [[ "$SYS_IP6" == *:* ]] || SYS_IP6=""
    # Гео считаем по IPv4, если он есть: у туннельных брокеров и SLAAC-префиксов
    # IPv6 нередко «прописан» в другой стране — это отдельный факт, а не гео сервера.
    local geo
    geo=$(curl -s4 --max-time 6 https://ipinfo.io/json 2>/dev/null)
    [[ -n "$geo" ]] || geo=$(curl -s6 --max-time 6 https://ipinfo.io/json 2>/dev/null)
    SYS_COUNTRY=$(printf '%s' "$geo" | grep -oE '"country"[ ]*:[ ]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    SYS_CITY=$(printf '%s' "$geo" | grep -oE '"city"[ ]*:[ ]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    SYS_ASN=$(printf '%s' "$geo" | grep -oE '"org"[ ]*:[ ]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    [[ -z "$SYS_COUNTRY" ]] && SYS_COUNTRY="—"
    [[ -z "$SYS_CITY" ]] && SYS_CITY="—"
    [[ -z "$SYS_ASN" ]] && SYS_ASN="—"
}

# Маскирует адрес: у IPv4 гасим 3-4 октет, у IPv6 — всё после второй группы.
# Картинка уходит на публичный файлообменник, полный адрес там ни к чему.
mask_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        printf '%s' "$ip" | awk -F. '{print $1"."$2".*.*"}'
    elif [[ "$ip" == *:* ]]; then
        printf '%s' "$ip" | awk -F: '{print $1":"$2"::*"}'
    else
        printf '%s' "$ip"
    fi
}

# Экранирование для вставки текста в SVG/XML.
xml_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/'/\&apos;/g" -e 's/"/\&quot;/g'
}

# ============================================================
#  Логотипы сервисов (Simple Icons, CC0). Встроены в скрипт.
#  Таблица: слаг / фирменный цвет / контур. Цвет хранится как есть —
#  это запись из апстрима, по ней удобно сверяться при обновлении, —
#  но карточка рисует марки одним серым: она черно-белая целиком.
# ============================================================
declare -A LOGO_PATH

load_logos() {
    [[ ${#LOGO_PATH[@]} -gt 0 ]] && return 0
    local s c d
    while IFS=$'\t' read -r s c d; do
        [[ -z "$s" ]] && continue
        LOGO_PATH["$s"]="$d"
    done <<'LOGOEOF'
netflix	#E50914	m5.398 0 8.348 23.602c2.346.059 4.856.398 4.856.398L10.113 0H5.398zm8.489 0v9.172l4.715 13.33V0h-4.715zM5.398 1.5V24c1.873-.225 2.81-.312 4.715-.398V14.83L5.398 1.5z
youtube	#FF0000	M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z
youtubemusic	#FF0000	M12 0C5.376 0 0 5.376 0 12s5.376 12 12 12 12-5.376 12-12S18.624 0 12 0zm0 19.104c-3.924 0-7.104-3.18-7.104-7.104S8.076 4.896 12 4.896s7.104 3.18 7.104 7.104-3.18 7.104-7.104 7.104zm0-13.332c-3.432 0-6.228 2.796-6.228 6.228S8.568 18.228 12 18.228s6.228-2.796 6.228-6.228S15.432 5.772 12 5.772zM9.684 15.54V8.46L15.816 12l-6.132 3.54z
spotify	#1ED760	M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z
tidal	#000000	M12.012 3.992L8.008 7.996 4.004 3.992 0 7.996 4.004 12l4.004-4.004L12.012 12l-4.004 4.004 4.004 4.004 4.004-4.004L12.012 12l4.004-4.004-4.004-4.004zM16.042 7.996l3.979-3.979L24 7.996l-3.979 3.979z
deezer	#A238FF	M.693 10.024c.381 0 .693-1.256.693-2.807 0-1.55-.312-2.807-.693-2.807C.312 4.41 0 5.666 0 7.217s.312 2.808.693 2.808ZM21.038 1.56c-.364 0-.684.805-.91 2.096C19.765 1.446 19.184 0 18.526 0c-.78 0-1.464 2.036-1.784 5-.312-2.158-.788-3.536-1.325-3.536-.745 0-1.386 2.704-1.62 6.472-.442-1.932-1.083-3.145-1.793-3.145s-1.35 1.213-1.793 3.145c-.242-3.76-.874-6.463-1.628-6.463-.537 0-1.013 1.378-1.325 3.535C6.938 2.036 6.262 0 5.474 0c-.658 0-1.247 1.447-1.602 3.665-.217-1.291-.546-2.105-.91-2.105-.675 0-1.221 2.807-1.221 6.272 0 3.466.546 6.273 1.221 6.273.277 0 .537-.476.736-1.273.32 2.928.996 4.938 1.776 4.938.606 0 1.143-1.204 1.507-3.11.251 3.622.875 6.195 1.602 6.195.46 0 .875-1.023 1.187-2.677C10.142 21.6 11 24 12.004 24c1.005 0 1.863-2.4 2.235-5.822.312 1.654.727 2.677 1.186 2.677.728 0 1.352-2.573 1.603-6.195.364 1.906.9 3.11 1.507 3.11.78 0 1.455-2.01 1.775-4.938.208.797.46 1.273.737 1.273.675 0 1.22-2.807 1.22-6.273-.008-3.457-.553-6.272-1.23-6.272ZM23.307 10.024c.381 0 .693-1.256.693-2.807 0-1.55-.312-2.807-.693-2.807-.381 0-.693 1.256-.693 2.807s.312 2.808.693 2.808Z
applemusic	#FA243C	M23.994 6.124a9.23 9.23 0 00-.24-2.19c-.317-1.31-1.062-2.31-2.18-3.043a5.022 5.022 0 00-1.877-.726 10.496 10.496 0 00-1.564-.15c-.04-.003-.083-.01-.124-.013H5.986c-.152.01-.303.017-.455.026-.747.043-1.49.123-2.193.4-1.336.53-2.3 1.452-2.865 2.78-.192.448-.292.925-.363 1.408-.056.392-.088.785-.1 1.18 0 .032-.007.062-.01.093v12.223c.01.14.017.283.027.424.05.815.154 1.624.497 2.373.65 1.42 1.738 2.353 3.234 2.801.42.127.856.187 1.293.228.555.053 1.11.06 1.667.06h11.03a12.5 12.5 0 001.57-.1c.822-.106 1.596-.35 2.295-.81a5.046 5.046 0 001.88-2.207c.186-.42.293-.87.37-1.324.113-.675.138-1.358.137-2.04-.002-3.8 0-7.595-.003-11.393zm-6.423 3.99v5.712c0 .417-.058.827-.244 1.206-.29.59-.76.962-1.388 1.14-.35.1-.706.157-1.07.173-.95.045-1.773-.6-1.943-1.536a1.88 1.88 0 011.038-2.022c.323-.16.67-.25 1.018-.324.378-.082.758-.153 1.134-.24.274-.063.457-.23.51-.516a.904.904 0 00.02-.193c0-1.815 0-3.63-.002-5.443a.725.725 0 00-.026-.185c-.04-.15-.15-.243-.304-.234-.16.01-.318.035-.475.066-.76.15-1.52.303-2.28.456l-2.325.47-1.374.278c-.016.003-.032.01-.048.013-.277.077-.377.203-.39.49-.002.042 0 .086 0 .13-.002 2.602 0 5.204-.003 7.805 0 .42-.047.836-.215 1.227-.278.64-.77 1.04-1.434 1.233-.35.1-.71.16-1.075.172-.96.036-1.755-.6-1.92-1.544-.14-.812.23-1.685 1.154-2.075.357-.15.73-.232 1.108-.31.287-.06.575-.116.86-.177.383-.083.583-.323.6-.714v-.15c0-2.96 0-5.922.002-8.882 0-.123.013-.25.042-.37.07-.285.273-.448.546-.518.255-.066.515-.112.774-.165.733-.15 1.466-.296 2.2-.444l2.27-.46c.67-.134 1.34-.27 2.01-.403.22-.043.442-.088.663-.106.31-.025.523.17.554.482.008.073.012.148.012.223.002 1.91.002 3.822 0 5.732z
tiktok	#000000	M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z
instagram	#FF0069	M7.0301.084c-1.2768.0602-2.1487.264-2.911.5634-.7888.3075-1.4575.72-2.1228 1.3877-.6652.6677-1.075 1.3368-1.3802 2.127-.2954.7638-.4956 1.6365-.552 2.914-.0564 1.2775-.0689 1.6882-.0626 4.947.0062 3.2586.0206 3.6671.0825 4.9473.061 1.2765.264 2.1482.5635 2.9107.308.7889.72 1.4573 1.388 2.1228.6679.6655 1.3365 1.0743 2.1285 1.38.7632.295 1.6361.4961 2.9134.552 1.2773.056 1.6884.069 4.9462.0627 3.2578-.0062 3.668-.0207 4.9478-.0814 1.28-.0607 2.147-.2652 2.9098-.5633.7889-.3086 1.4578-.72 2.1228-1.3881.665-.6682 1.0745-1.3378 1.3795-2.1284.2957-.7632.4966-1.636.552-2.9124.056-1.2809.0692-1.6898.063-4.948-.0063-3.2583-.021-3.6668-.0817-4.9465-.0607-1.2797-.264-2.1487-.5633-2.9117-.3084-.7889-.72-1.4568-1.3876-2.1228C21.2982 1.33 20.628.9208 19.8378.6165 19.074.321 18.2017.1197 16.9244.0645 15.6471.0093 15.236-.005 11.977.0014 8.718.0076 8.31.0215 7.0301.0839m.1402 21.6932c-1.17-.0509-1.8053-.2453-2.2287-.408-.5606-.216-.96-.4771-1.3819-.895-.422-.4178-.6811-.8186-.9-1.378-.1644-.4234-.3624-1.058-.4171-2.228-.0595-1.2645-.072-1.6442-.079-4.848-.007-3.2037.0053-3.583.0607-4.848.05-1.169.2456-1.805.408-2.2282.216-.5613.4762-.96.895-1.3816.4188-.4217.8184-.6814 1.3783-.9003.423-.1651 1.0575-.3614 2.227-.4171 1.2655-.06 1.6447-.072 4.848-.079 3.2033-.007 3.5835.005 4.8495.0608 1.169.0508 1.8053.2445 2.228.408.5608.216.96.4754 1.3816.895.4217.4194.6816.8176.9005 1.3787.1653.4217.3617 1.056.4169 2.2263.0602 1.2655.0739 1.645.0796 4.848.0058 3.203-.0055 3.5834-.061 4.848-.051 1.17-.245 1.8055-.408 2.2294-.216.5604-.4763.96-.8954 1.3814-.419.4215-.8181.6811-1.3783.9-.4224.1649-1.0577.3617-2.2262.4174-1.2656.0595-1.6448.072-4.8493.079-3.2045.007-3.5825-.006-4.848-.0608M16.953 5.5864A1.44 1.44 0 1 0 18.39 4.144a1.44 1.44 0 0 0-1.437 1.4424M5.8385 12.012c.0067 3.4032 2.7706 6.1557 6.173 6.1493 3.4026-.0065 6.157-2.7701 6.1506-6.1733-.0065-3.4032-2.771-6.1565-6.174-6.1498-3.403.0067-6.156 2.771-6.1496 6.1738M8 12.0077a4 4 0 1 1 4.008 3.9921A3.9996 3.9996 0 0 1 8 12.0077
x	#000000	M14.234 10.162 22.977 0h-2.072l-7.591 8.824L7.251 0H.258l9.168 13.343L.258 24H2.33l8.016-9.318L16.749 24h6.993zm-2.837 3.299-.929-1.329L3.076 1.56h3.182l5.965 8.532.929 1.329 7.754 11.09h-3.182z
facebook	#0866FF	M9.101 23.691v-7.98H6.627v-3.667h2.474v-1.58c0-4.085 1.848-5.978 5.858-5.978.401 0 .955.042 1.468.103a8.68 8.68 0 0 1 1.141.195v3.325a8.623 8.623 0 0 0-.653-.036 26.805 26.805 0 0 0-.733-.009c-.707 0-1.259.096-1.675.309a1.686 1.686 0 0 0-.679.622c-.258.42-.374.995-.374 1.752v1.297h3.919l-.386 2.103-.287 1.564h-3.246v8.245C19.396 23.238 24 18.179 24 12.044c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.628 3.874 10.35 9.101 11.647Z
reddit	#FF4500	M12 0C5.373 0 0 5.373 0 12c0 3.314 1.343 6.314 3.515 8.485l-2.286 2.286C.775 23.225 1.097 24 1.738 24H12c6.627 0 12-5.373 12-12S18.627 0 12 0Zm4.388 3.199c1.104 0 1.999.895 1.999 1.999 0 1.105-.895 2-1.999 2-.946 0-1.739-.657-1.947-1.539v.002c-1.147.162-2.032 1.15-2.032 2.341v.007c1.776.067 3.4.567 4.686 1.363.473-.363 1.064-.58 1.707-.58 1.547 0 2.802 1.254 2.802 2.802 0 1.117-.655 2.081-1.601 2.531-.088 3.256-3.637 5.876-7.997 5.876-4.361 0-7.905-2.617-7.998-5.87-.954-.447-1.614-1.415-1.614-2.538 0-1.548 1.255-2.802 2.803-2.802.645 0 1.239.218 1.712.585 1.275-.79 2.881-1.291 4.64-1.365v-.01c0-1.663 1.263-3.034 2.88-3.207.188-.911.993-1.595 1.959-1.595Zm-8.085 8.376c-.784 0-1.459.78-1.506 1.797-.047 1.016.64 1.429 1.426 1.429.786 0 1.371-.369 1.418-1.385.047-1.017-.553-1.841-1.338-1.841Zm7.406 0c-.786 0-1.385.824-1.338 1.841.047 1.017.634 1.385 1.418 1.385.785 0 1.473-.413 1.426-1.429-.046-1.017-.721-1.797-1.506-1.797Zm-3.703 4.013c-.974 0-1.907.048-2.77.135-.147.015-.241.168-.183.305.483 1.154 1.622 1.964 2.953 1.964 1.33 0 2.47-.81 2.953-1.964.057-.137-.037-.29-.184-.305-.863-.087-1.795-.135-2.769-.135Z
twitch	#9146FF	M11.571 4.714h1.715v5.143H11.57zm4.715 0H18v5.143h-1.714zM6 0L1.714 4.286v15.428h5.143V24l4.286-4.286h3.428L22.286 12V0zm14.571 11.143l-3.428 3.428h-3.429l-3 3v-3H6.857V1.714h13.714Z
telegram	#26A5E4	M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z
discord	#5865F2	M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2762-3.68-.2762-5.4868 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9942a.076.076 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1981.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189Z
whatsapp	#25D366	M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z
snapchat	#FFFC00	M12.206.793c.99 0 4.347.276 5.93 3.821.529 1.193.403 3.219.299 4.847l-.003.06c-.012.18-.022.345-.03.51.075.045.203.09.401.09.3-.016.659-.12 1.033-.301.165-.088.344-.104.464-.104.182 0 .359.029.509.09.45.149.734.479.734.838.015.449-.39.839-1.213 1.168-.089.029-.209.075-.344.119-.45.135-1.139.36-1.333.81-.09.224-.061.524.12.868l.015.015c.06.136 1.526 3.475 4.791 4.014.255.044.435.27.42.509 0 .075-.015.149-.045.225-.24.569-1.273.988-3.146 1.271-.059.091-.12.375-.164.57-.029.179-.074.36-.134.553-.076.271-.27.405-.555.405h-.03c-.135 0-.313-.031-.538-.074-.36-.075-.765-.135-1.273-.135-.3 0-.599.015-.913.074-.6.104-1.123.464-1.723.884-.853.599-1.826 1.288-3.294 1.288-.06 0-.119-.015-.18-.015h-.149c-1.468 0-2.427-.675-3.279-1.288-.599-.42-1.107-.779-1.707-.884-.314-.045-.629-.074-.928-.074-.54 0-.958.089-1.272.149-.211.043-.391.074-.54.074-.374 0-.523-.224-.583-.42-.061-.192-.09-.389-.135-.567-.046-.181-.105-.494-.166-.57-1.918-.222-2.95-.642-3.189-1.226-.031-.063-.052-.15-.055-.225-.015-.243.165-.465.42-.509 3.264-.54 4.73-3.879 4.791-4.02l.016-.029c.18-.345.224-.645.119-.869-.195-.434-.884-.658-1.332-.809-.121-.029-.24-.074-.346-.119-1.107-.435-1.257-.93-1.197-1.273.09-.479.674-.793 1.168-.793.146 0 .27.029.383.074.42.194.789.3 1.104.3.234 0 .384-.06.465-.105l-.046-.569c-.098-1.626-.225-3.651.307-4.837C7.392 1.077 10.739.807 11.727.807l.419-.015h.06z
pinterest	#BD081C	M12.017 0C5.396 0 .029 5.367.029 11.987c0 5.079 3.158 9.417 7.618 11.162-.105-.949-.199-2.403.041-3.439.219-.937 1.406-5.957 1.406-5.957s-.359-.72-.359-1.781c0-1.663.967-2.911 2.168-2.911 1.024 0 1.518.769 1.518 1.688 0 1.029-.653 2.567-.992 3.992-.285 1.193.6 2.165 1.775 2.165 2.128 0 3.768-2.245 3.768-5.487 0-2.861-2.063-4.869-5.008-4.869-3.41 0-5.409 2.562-5.409 5.199 0 1.033.394 2.143.889 2.741.099.12.112.225.085.345-.09.375-.293 1.199-.334 1.363-.053.225-.172.271-.401.165-1.495-.69-2.433-2.878-2.433-4.646 0-3.776 2.748-7.252 7.92-7.252 4.158 0 7.392 2.967 7.392 6.923 0 4.135-2.607 7.462-6.233 7.462-1.214 0-2.354-.629-2.758-1.379l-.749 2.848c-.269 1.045-1.004 2.352-1.498 3.146 1.123.345 2.306.535 3.55.535 6.607 0 11.985-5.365 11.985-11.987C23.97 5.39 18.592.026 11.985.026L12.017 0z
vk	#0077FF	m9.489.004.729-.003h3.564l.73.003.914.01.433.007.418.011.403.014.388.016.374.021.36.025.345.03.333.033c1.74.196 2.933.616 3.833 1.516.9.9 1.32 2.092 1.516 3.833l.034.333.029.346.025.36.02.373.025.588.012.41.013.644.009.915.004.98-.001 3.313-.003.73-.01.914-.007.433-.011.418-.014.403-.016.388-.021.374-.025.36-.03.345-.033.333c-.196 1.74-.616 2.933-1.516 3.833-.9.9-2.092 1.32-3.833 1.516l-.333.034-.346.029-.36.025-.373.02-.588.025-.41.012-.644.013-.915.009-.98.004-3.313-.001-.73-.003-.914-.01-.433-.007-.418-.011-.403-.014-.388-.016-.374-.021-.36-.025-.345-.03-.333-.033c-1.74-.196-2.933-.616-3.833-1.516-.9-.9-1.32-2.092-1.516-3.833l-.034-.333-.029-.346-.025-.36-.02-.373-.025-.588-.012-.41-.013-.644-.009-.915-.004-.98.001-3.313.003-.73.01-.914.007-.433.011-.418.014-.403.016-.388.021-.374.025-.36.03-.345.033-.333c.196-1.74.616-2.933 1.516-3.833.9-.9 2.092-1.32 3.833-1.516l.333-.034.346-.029.36-.025.373-.02.588-.025.41-.012.644-.013.915-.009ZM6.79 7.3H4.05c.13 6.24 3.25 9.99 8.72 9.99h.31v-3.57c2.01.2 3.53 1.67 4.14 3.57h2.84c-.78-2.84-2.83-4.41-4.11-5.01 1.28-.74 3.08-2.54 3.51-4.98h-2.58c-.56 1.98-2.22 3.78-3.8 3.95V7.3H10.5v6.92c-1.6-.4-3.62-2.34-3.71-6.92Z
line	#00C300	M19.365 9.863c.349 0 .63.285.63.631 0 .345-.281.63-.63.63H17.61v1.125h1.755c.349 0 .63.283.63.63 0 .344-.281.629-.63.629h-2.386c-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.63-.63h2.386c.346 0 .627.285.627.63 0 .349-.281.63-.63.63H17.61v1.125h1.755zm-3.855 3.016c0 .27-.174.51-.432.596-.064.021-.133.031-.199.031-.211 0-.391-.09-.51-.25l-2.443-3.317v2.94c0 .344-.279.629-.631.629-.346 0-.626-.285-.626-.629V8.108c0-.27.173-.51.43-.595.06-.023.136-.033.194-.033.195 0 .375.104.495.254l2.462 3.33V8.108c0-.345.282-.63.63-.63.345 0 .63.285.63.63v4.771zm-5.741 0c0 .344-.282.629-.631.629-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.63-.63.346 0 .628.285.628.63v4.771zm-2.466.629H4.917c-.345 0-.63-.285-.63-.629V8.108c0-.345.285-.63.63-.63.348 0 .63.285.63.63v4.141h1.756c.348 0 .629.283.629.63 0 .344-.282.629-.629.629M24 10.314C24 4.943 18.615.572 12 .572S0 4.943 0 10.314c0 4.811 4.27 8.842 10.035 9.608.391.082.923.258 1.058.59.12.301.079.766.038 1.08l-.164 1.02c-.045.301-.24 1.186 1.049.645 1.291-.539 6.916-4.078 9.436-6.975C23.176 14.393 24 12.458 24 10.314
viber	#7360F2	M11.4 0C9.473.028 5.333.344 3.02 2.467 1.302 4.187.696 6.7.633 9.817.57 12.933.488 18.776 6.12 20.36h.003l-.004 2.416s-.037.977.61 1.177c.777.242 1.234-.5 1.98-1.302.407-.44.972-1.084 1.397-1.58 3.85.326 6.812-.416 7.15-.525.776-.252 5.176-.816 5.892-6.657.74-6.02-.36-9.83-2.34-11.546-.596-.55-3.006-2.3-8.375-2.323 0 0-.395-.025-1.037-.017zm.058 1.693c.545-.004.88.017.88.017 4.542.02 6.717 1.388 7.222 1.846 1.675 1.435 2.53 4.868 1.906 9.897v.002c-.604 4.878-4.174 5.184-4.832 5.395-.28.09-2.882.737-6.153.524 0 0-2.436 2.94-3.197 3.704-.12.12-.26.167-.352.144-.13-.033-.166-.188-.165-.414l.02-4.018c-4.762-1.32-4.485-6.292-4.43-8.895.054-2.604.543-4.738 1.996-6.173 1.96-1.773 5.474-2.018 7.11-2.03zm.38 2.602c-.167 0-.303.135-.304.302 0 .167.133.303.3.305 1.624.01 2.946.537 4.028 1.592 1.073 1.046 1.62 2.468 1.633 4.334.002.167.14.3.307.3.166-.002.3-.138.3-.304-.014-1.984-.618-3.596-1.816-4.764-1.19-1.16-2.692-1.753-4.447-1.765zm-3.96.695c-.19-.032-.4.005-.616.117l-.01.002c-.43.247-.816.562-1.146.932-.002.004-.006.004-.008.008-.267.323-.42.638-.46.948-.008.046-.01.093-.007.14 0 .136.022.27.065.4l.013.01c.135.48.473 1.276 1.205 2.604.42.768.903 1.5 1.446 2.186.27.344.56.673.87.984l.132.132c.31.308.64.6.984.87.686.543 1.418 1.027 2.186 1.447 1.328.733 2.126 1.07 2.604 1.206l.01.014c.13.042.265.064.402.063.046.002.092 0 .138-.008.31-.036.627-.19.948-.46.004 0 .003-.002.008-.005.37-.33.683-.72.93-1.148l.003-.01c.225-.432.15-.842-.18-1.12-.004 0-.698-.58-1.037-.83-.36-.255-.73-.492-1.113-.71-.51-.285-1.032-.106-1.248.174l-.447.564c-.23.283-.657.246-.657.246-3.12-.796-3.955-3.955-3.955-3.955s-.037-.426.248-.656l.563-.448c.277-.215.456-.737.17-1.248-.217-.383-.454-.756-.71-1.115-.25-.34-.826-1.033-.83-1.035-.137-.165-.31-.265-.502-.297zm4.49.88c-.158.002-.29.124-.3.282-.01.167.115.312.282.324 1.16.085 2.017.466 2.645 1.15.63.688.93 1.524.906 2.57-.002.168.13.306.3.31.166.003.305-.13.31-.297.025-1.175-.334-2.193-1.067-2.994-.74-.81-1.777-1.253-3.05-1.346h-.024zm.463 1.63c-.16.002-.29.127-.3.287-.008.167.12.31.288.32.523.028.875.175 1.113.422.24.245.388.62.416 1.164.01.167.15.295.318.287.167-.008.295-.15.287-.317-.03-.644-.215-1.178-.58-1.557-.367-.378-.893-.574-1.52-.607h-.018z
signal	#3B45FD	M12 0q-.934 0-1.83.139l.17 1.111a11 11 0 0 1 3.32 0l.172-1.111A12 12 0 0 0 12 0M9.152.34A12 12 0 0 0 5.77 1.742l.584.961a10.8 10.8 0 0 1 3.066-1.27zm5.696 0-.268 1.094a10.8 10.8 0 0 1 3.066 1.27l.584-.962A12 12 0 0 0 14.848.34M12 2.25a9.75 9.75 0 0 0-8.539 14.459c.074.134.1.292.064.441l-1.013 4.338 4.338-1.013a.62.62 0 0 1 .441.064A9.7 9.7 0 0 0 12 21.75c5.385 0 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25m-7.092.068a12 12 0 0 0-2.59 2.59l.909.664a11 11 0 0 1 2.345-2.345zm14.184 0-.664.909a11 11 0 0 1 2.345 2.345l.909-.664a12 12 0 0 0-2.59-2.59M1.742 5.77A12 12 0 0 0 .34 9.152l1.094.268a10.8 10.8 0 0 1 1.269-3.066zm20.516 0-.961.584a10.8 10.8 0 0 1 1.27 3.066l1.093-.268a12 12 0 0 0-1.402-3.383M.138 10.168A12 12 0 0 0 0 12q0 .934.139 1.83l1.111-.17A11 11 0 0 1 1.125 12q0-.848.125-1.66zm23.723.002-1.111.17q.125.812.125 1.66c0 .848-.042 1.12-.125 1.66l1.111.172a12.1 12.1 0 0 0 0-3.662M1.434 14.58l-1.094.268a12 12 0 0 0 .96 2.591l-.265 1.14 1.096.255.36-1.539-.188-.365a10.8 10.8 0 0 1-.87-2.35m21.133 0a10.8 10.8 0 0 1-1.27 3.067l.962.584a12 12 0 0 0 1.402-3.383zm-1.793 3.848a11 11 0 0 1-2.345 2.345l.664.909a12 12 0 0 0 2.59-2.59zm-19.959 1.1L.357 21.48a1.8 1.8 0 0 0 2.162 2.161l1.954-.455-.256-1.095-1.953.455a.675.675 0 0 1-.81-.81l.454-1.954zm16.832 1.769a10.8 10.8 0 0 1-3.066 1.27l.268 1.093a12 12 0 0 0 3.382-1.402zm-10.94.213-1.54.36.256 1.095 1.139-.266c.814.415 1.683.74 2.591.961l.268-1.094a10.8 10.8 0 0 1-2.35-.869zm3.634 1.24-.172 1.111a12.1 12.1 0 0 0 3.662 0l-.17-1.111q-.812.125-1.66.125a11 11 0 0 1-1.66-.125
steam	#000000	M11.979 0C5.678 0 .511 4.86.022 11.037l6.432 2.658c.545-.371 1.203-.59 1.912-.59.063 0 .125.004.188.006l2.861-4.142V8.91c0-2.495 2.028-4.524 4.524-4.524 2.494 0 4.524 2.031 4.524 4.527s-2.03 4.525-4.524 4.525h-.105l-4.076 2.911c0 .052.004.105.004.159 0 1.875-1.515 3.396-3.39 3.396-1.635 0-3.016-1.173-3.331-2.727L.436 15.27C1.862 20.307 6.486 24 11.979 24c6.627 0 11.999-5.373 11.999-12S18.605 0 11.979 0zM7.54 18.21l-1.473-.61c.262.543.714.999 1.314 1.25 1.297.539 2.793-.076 3.332-1.375.263-.63.264-1.319.005-1.949s-.75-1.121-1.377-1.383c-.624-.26-1.29-.249-1.878-.03l1.523.63c.956.4 1.409 1.5 1.009 2.455-.397.957-1.497 1.41-2.454 1.012H7.54zm11.415-9.303c0-1.662-1.353-3.015-3.015-3.015-1.665 0-3.015 1.353-3.015 3.015 0 1.665 1.35 3.015 3.015 3.015 1.663 0 3.015-1.35 3.015-3.015zm-5.273-.005c0-1.252 1.013-2.266 2.265-2.266 1.249 0 2.266 1.014 2.266 2.266 0 1.251-1.017 2.265-2.266 2.265-1.253 0-2.265-1.014-2.265-2.265z
epicgames	#313131	M3.537 0C2.165 0 1.66.506 1.66 1.879V18.44a4.262 4.262 0 00.02.433c.031.3.037.59.316.92.027.033.311.245.311.245.153.075.258.13.43.2l8.335 3.491c.433.199.614.276.928.27h.002c.314.006.495-.071.928-.27l8.335-3.492c.172-.07.277-.124.43-.2 0 0 .284-.211.311-.243.28-.33.285-.621.316-.92a4.261 4.261 0 00.02-.434V1.879c0-1.373-.506-1.88-1.878-1.88zm13.366 3.11h.68c1.138 0 1.688.553 1.688 1.696v1.88h-1.374v-1.8c0-.369-.17-.54-.523-.54h-.235c-.367 0-.537.17-.537.539v5.81c0 .369.17.54.537.54h.262c.353 0 .523-.171.523-.54V8.619h1.373v2.143c0 1.144-.562 1.71-1.7 1.71h-.694c-1.138 0-1.7-.566-1.7-1.71V4.82c0-1.144.562-1.709 1.7-1.709zm-12.186.08h3.114v1.274H6.117v2.603h1.648v1.275H6.117v2.774h1.74v1.275h-3.14zm3.816 0h2.198c1.138 0 1.7.564 1.7 1.708v2.445c0 1.144-.562 1.71-1.7 1.71h-.799v3.338h-1.4zm4.53 0h1.4v9.201h-1.4zm-3.13 1.235v3.392h.575c.354 0 .523-.171.523-.54V4.965c0-.368-.17-.54-.523-.54zm-3.74 10.147a1.708 1.708 0 01.591.108 1.745 1.745 0 01.49.299l-.452.546a1.247 1.247 0 00-.308-.195.91.91 0 00-.363-.068.658.658 0 00-.28.06.703.703 0 00-.224.163.783.783 0 00-.151.243.799.799 0 00-.056.299v.008a.852.852 0 00.056.31.7.7 0 00.157.245.736.736 0 00.238.16.774.774 0 00.303.058.79.79 0 00.445-.116v-.339h-.548v-.565H7.37v1.255a2.019 2.019 0 01-.524.307 1.789 1.789 0 01-.683.123 1.642 1.642 0 01-.602-.107 1.46 1.46 0 01-.478-.3 1.371 1.371 0 01-.318-.455 1.438 1.438 0 01-.115-.58v-.008a1.426 1.426 0 01.113-.57 1.449 1.449 0 01.312-.46 1.418 1.418 0 01.474-.309 1.58 1.58 0 01.598-.111 1.708 1.708 0 01.045 0zm11.963.008a2.006 2.006 0 01.612.094 1.61 1.61 0 01.507.277l-.386.546a1.562 1.562 0 00-.39-.205 1.178 1.178 0 00-.388-.07.347.347 0 00-.208.052.154.154 0 00-.07.127v.008a.158.158 0 00.022.084.198.198 0 00.076.066.831.831 0 00.147.06c.062.02.14.04.236.061a3.389 3.389 0 01.43.122 1.292 1.292 0 01.328.17.678.678 0 01.207.24.739.739 0 01.071.337v.008a.865.865 0 01-.081.382.82.82 0 01-.229.285 1.032 1.032 0 01-.353.18 1.606 1.606 0 01-.46.061 2.16 2.16 0 01-.71-.116 1.718 1.718 0 01-.593-.346l.43-.514c.277.223.578.335.9.335a.457.457 0 00.236-.05.157.157 0 00.082-.142v-.008a.15.15 0 00-.02-.077.204.204 0 00-.073-.066.753.753 0 00-.143-.062 2.45 2.45 0 00-.233-.062 5.036 5.036 0 01-.413-.113 1.26 1.26 0 01-.331-.16.72.72 0 01-.222-.243.73.73 0 01-.082-.36v-.008a.863.863 0 01.074-.359.794.794 0 01.214-.283 1.007 1.007 0 01.34-.185 1.423 1.423 0 01.448-.066 2.006 2.006 0 01.025 0zm-9.358.025h.742l1.183 2.81h-.825l-.203-.499H8.623l-.198.498h-.81zm2.197.02h.814l.663 1.08.663-1.08h.814v2.79h-.766v-1.602l-.711 1.091h-.016l-.707-1.083v1.593h-.754zm3.469 0h2.235v.658h-1.473v.422h1.334v.61h-1.334v.442h1.493v.658h-2.255zm-5.3.897l-.315.793h.624zm-1.145 5.19h8.014l-4.09 1.348z
roblox	#000000	M18.926 23.998 0 18.892 5.075.002 24 5.108ZM15.348 10.09l-5.282-1.453-1.414 5.273 5.282 1.453z
playstation	#0070D1	M8.984 2.596v17.547l3.915 1.261V6.688c0-.69.304-1.151.794-.991.636.18.76.814.76 1.505v5.875c2.441 1.193 4.362-.002 4.362-3.152 0-3.237-1.126-4.675-4.438-5.827-1.307-.448-3.728-1.186-5.39-1.502zm4.656 16.241l6.296-2.275c.715-.258.826-.625.246-.818-.586-.192-1.637-.139-2.357.123l-4.205 1.5V14.98l.24-.085s1.201-.42 2.913-.615c1.696-.18 3.785.03 5.437.661 1.848.601 2.04 1.472 1.576 2.072-.465.6-1.622 1.036-1.622 1.036l-8.544 3.107V18.86zM1.807 18.6c-1.9-.545-2.214-1.668-1.352-2.32.801-.586 2.16-1.052 2.16-1.052l5.615-2.013v2.313L4.205 17c-.705.271-.825.632-.239.826.586.195 1.637.15 2.343-.12L8.247 17v2.074c-.12.03-.256.044-.39.073-1.939.331-3.996.196-6.038-.479z
apple	#000000	M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701
appletv	#000000	M20.57 17.735h-1.815l-3.34-9.203h1.633l2.02 5.987c.075.231.273.9.586 2.012l.297-.997.33-1.006 2.094-6.004H24zm-5.344-.066a5.76 5.76 0 0 1-1.55.207c-1.23 0-1.84-.693-1.84-2.087V9.646h-1.063V8.532h1.121V7.081l1.476-.602v2.062h1.707v1.113H13.38v5.805c0 .446.074.75.214.932.14.182.396.264.75.264.207 0 .495-.041.883-.115zm-7.29-5.343c.017 1.764 1.55 2.358 1.567 2.366-.017.042-.248.842-.808 1.658-.487.71-.99 1.418-1.79 1.435-.783.016-1.03-.462-1.93-.462-.89 0-1.17.445-1.913.478-.758.025-1.344-.775-1.838-1.484-.998-1.451-1.765-4.098-.734-5.88.51-.89 1.426-1.451 2.416-1.46.75-.016 1.468.512 1.93.512.461 0 1.327-.627 2.234-.536.38.016 1.452.157 2.136 1.154-.058.033-1.278.743-1.27 2.219M6.468 7.988c.404-.495.685-1.18.61-1.864-.585.025-1.294.388-1.723.883-.38.437-.71 1.138-.619 1.806.652.05 1.328-.338 1.732-.825Z
crunchyroll	#FF5E00	M2.909 13.436C2.914 7.61 7.642 2.893 13.468 2.898c5.576.005 10.137 4.339 10.51 9.819q.021-.351.022-.706C24.007 5.385 18.64.006 12.012 0S.007 5.36 0 11.988 5.36 23.994 11.988 24q.412 0 .815-.027c-5.526-.338-9.9-4.928-9.894-10.538Zm16.284.155a4.1 4.1 0 0 1-4.095-4.103 4.1 4.1 0 0 1 2.712-3.855 8.95 8.95 0 0 0-4.187-1.037 9.007 9.007 0 1 0 8.997 9.016q-.001-.847-.15-1.651a4.1 4.1 0 0 1-3.278 1.63Z
hbo	#000000	M7.042 16.896H4.414v-3.754H2.708v3.754H.01L0 7.22h2.708v3.6h1.706v-3.6h2.628zm12.043.046C21.795 16.94 24 14.689 24 11.978a4.89 4.89 0 0 0-4.915-4.92c-2.707-.002-4.09 1.991-4.432 2.795.003-1.207-1.187-2.632-2.58-2.634H7.59v9.674l4.181.001c1.686 0 2.886-1.46 2.888-2.713.385.788 1.72 2.762 4.427 2.76zm-7.665-3.936c.387 0 .692.382.692.817 0 .435-.305.817-.692.817h-1.33v-1.634zm.005-3.633c.387 0 .692.382.692.817 0 .436-.305.818-.692.818h-1.33V9.373zm1.77 2.607c.305-.039.813-.387.992-.61-.063.276-.068 1.074.006 1.35-.204-.314-.688-.701-.998-.74zm3.43 0a2.462 2.462 0 1 1 4.924 0 2.462 2.462 0 0 1-4.925 0zm2.462 1.936a1.936 1.936 0 1 0 0-3.872 1.936 1.936 0 0 0 0 3.872Z
max	#525252	M1.769 0A1.77 1.77 0 0 0 0 1.769V22.23A1.77 1.77 0 0 0 1.769 24H22.23A1.77 1.77 0 0 0 24 22.231V1.77A1.77 1.77 0 0 0 22.231 0zm12.485 3.28a4.301 4.301 0 0 1 4.3 4.302 4.301 4.301 0 0 1-1.993 3.63 6.085 6.085 0 0 1 1.054 3.422 6.085 6.085 0 0 1-6.085 6.085 6.085 6.085 0 0 1-6.085-6.085 6.085 6.085 0 0 1 4.66-5.916 4.301 4.301 0 0 1-.152-1.136 4.301 4.301 0 0 1 4.301-4.301zm0 1.849a2.453 2.453 0 0 0-2.453 2.453 2.453 2.453 0 0 0 2.453 2.453 2.453 2.453 0 0 0 2.453-2.453 2.453 2.453 0 0 0-2.453-2.453zm-2.724 5.268a4.237 4.237 0 0 0-4.237 4.237 4.237 4.237 0 0 0 4.237 4.237 4.237 4.237 0 0 0 4.237-4.237 4.237 4.237 0 0 0-4.237-4.237zm.032 2.54a1.781 1.781 0 1 1 0 3.562 1.781 1.781 0 0 1 0-3.562Z
paramountplus	#0064FF	M16.347 21.373c.057-.084.151-.314-.025-.74l-.53-1.428c-.073-.182.084-.293.19-.173 0 0 1.004 1.157 1.264 1.64l.495.822c.425.028 1.6.06 2.732.06a3.26 3.26 0 0 1-.316-.364c-1.93-2.392-3.154-3.724-3.166-3.737-.391-.426-.572-.508-.87-.643a4.82 4.82 0 0 1-.138-.065v.364c0 .047-.057.073-.086.022l-2.846-5.001a1.598 1.598 0 0 0-.508-.587l-.277-.194-1.354 3.123c.212 0 .354.216.27.409l-1.25 2.893h1.147c.443 0 .883.087 1.294.255l.302.125s-.913 1.878-.913 2.867c0 .181.028.362.075.534h2.104l-.096-.595s1.266.294 2.502.413M12 2.437c-6.627 0-12 5.373-12 12 0 2.669.873 5.133 2.346 7.126.503-.218.783-.542.983-.791l2.234-2.858a.467.467 0 0 1 .179-.138l.336-.146 3.674-4.659.534-.417 1.094-1.524a.482.482 0 0 1 .101-.102l.478-.347a.34.34 0 0 1 .398-.004l.578.407c.308.216.557.504.726.84l2.322 4.077c.051.09.09.129.182.174.454.227.732.268 1.33.913.277.304 1.495 1.666 3.203 3.784.236.318.538.588.963.783A11.948 11.948 0 0 0 24 14.437c0-6.627-5.373-12-12-12M3.236 15.1l-.778-.253-.48.662v-.818l-.778-.253.778-.253v-.818l.48.662.778-.253-.48.662Zm-.185 2.676-.252.778-.253-.778h-.818l.661-.481-.253-.777.663.48.66-.48-.252.777.662.481Zm.156-6.195.253.778-.661-.48-.663.48.253-.778-.66-.48h.817l.253-.778.252.777h.818Zm1.314-1.76L4.04 9.16l-.778.253.48-.661-.48-.663.778.254.48-.662v.818l.778.253-.777.252Zm2.045-2.862-.253.777-.252-.777h-.818l.662-.48-.253-.778.661.48.661-.48-.252.777.662.48Zm2.577-1.313-.48.661V5.49l-.779-.254.778-.253v-.817l.48.66.78-.253-.481.663.48.66zm3.265-.75.253.778-.661-.48-.662.48.252-.777-.66-.481h.818L12 3.637l.252.778h.818zm2.93.595v.816l-.481-.661-.777.252.48-.662-.48-.662.777.253.48-.66v.817l.779.252zm5.426 8.285.778.253.48-.662v.818l.778.253-.778.253v.818l-.48-.662-.778.253.48-.662zm-3.077-6.04-.253-.777h-.818l.662-.48-.253-.778.662.48.662-.48-.254.778.662.48h-.818zm1.792 2.086v-.818l-.777-.252.777-.253V7.68l.481.662.777-.254-.48.663.48.66-.777-.252zm1.469 1.278.253-.777.254.777h.816l-.66.481.252.778-.662-.48-.661.48.253-.778-.662-.48zm.506 6.676-.253.778-.253-.778h-.817l.662-.481-.253-.777.66.48.663-.48-.253.777.661.481zm-12.08-.615.76-1.588c.024-.048-.032-.108-.067-.067l-.664.668c-.313.329-.847 1.25-.95 1.421l-.808 1.335a.109.109 0 0 1 .1.162l-.739 1.238c-.18.309.145.523.189.452 1.157-1.868 1.832-1.719 1.832-1.719l.387-.897c.022-.047-.001-.1-.05-.12-.12-.05-.316-.27.01-.885z
dazn	#F8F8F5	M14.774 8.291l.772-2.596.79 2.596zm3.848 2.268l-2.025-6.128c-.045-.135-.097-.224-.154-.266-.059-.041-.152-.063-.28-.063h-1.12a.485.485 0 0 0-.284.068c-.06.045-.11.132-.149.261l-2.045 6.128c-.025.032-.038.096-.038.192 0 .149.09.223.27.223h.84c.076 0 .139-.003.187-.01a.207.207 0 0 0 .116-.048.326.326 0 0 0 .077-.116c.022-.051.046-.119.072-.202l.318-1.071h2.306l.327 1.051c.026.09.051.16.077.213a.395.395 0 0 0 .087.12c.031.028.07.047.114.053h.002c.045.006.103.01.173.01h.897c.18 0 .27-.074.27-.223a.59.59 0 0 0-.005-.09.878.878 0 0 0-.036-.108l.003.006zm-.994 2.467h-.646c-.168 0-.279.024-.333.072-.055.049-.082.147-.082.295v3.638l-1.91-3.647c-.076-.155-.152-.253-.226-.295-.074-.041-.204-.063-.39-.063h-.599c-.167 0-.278.025-.332.073-.055.048-.082.147-.082.294v6.138c0 .148.025.246.077.294.052.048.16.072.328.072h.656c.167 0 .278-.024.332-.072.055-.048.082-.146.082-.294v-3.648l1.91 3.657c.077.155.152.253.227.295.073.042.204.062.39.062h.598c.167 0 .278-.024.333-.072.054-.048.082-.146.082-.294v-6.138c0-.148-.028-.246-.082-.294-.055-.048-.166-.073-.333-.073zm3.203-.581l1.665 1.665v8.385H1.505V14.11l1.663-1.664a.63.63 0 0 0 0-.89L1.504 9.891V1.505h20.991v8.384l-1.665 1.666a.63.63 0 0 0 0 .89zM24 0H0v10.613L1.387 12 0 13.387V24h24V13.387L22.613 12 24 10.613zM10.67 18.469H7.96l2.855-4.014a.67.67 0 0 0 .087-.155.425.425 0 0 0 .019-.135v-.772c0-.148-.028-.246-.082-.294-.055-.048-.166-.073-.334-.073H6.382c-.149 0-.245.028-.29.082-.045.055-.068.169-.068.343v.58c0 .172.023.287.068.341.045.055.141.083.29.083h2.545L6.11 18.469a.438.438 0 0 0-.107.27v.792c0 .148.027.245.082.294.055.048.167.072.334.072h4.25c.148 0 .245-.027.29-.081.045-.055.068-.17.068-.344v-.579c0-.173-.023-.287-.068-.342-.045-.055-.142-.082-.29-.082zM9.408 8.233c0 .264-.017.484-.052.661-.036.177-.093.32-.174.43a.648.648 0 0 1-.318.231 1.523 1.523 0 0 1-.487.068h-.79v-4.17h.79c.366 0 .63.11.79.324.16.215.241.571.241 1.067v1.389zm1.38-2.789c-.225-.457-.533-.795-.921-1.013-.39-.219-.88-.328-1.47-.328H6.418c-.167 0-.278.024-.333.072-.054.049-.082.147-.082.294v6.138c0 .148.028.246.082.295.055.048.166.072.333.072h2.218c1.048 0 1.765-.447 2.15-1.342.09-.205.153-.413.188-.622a4.91 4.91 0 0 0 .054-.796V6.911c0-.367-.018-.656-.054-.868a2.2 2.2 0 0 0-.193-.612l.006.013z
bilibili	#00A1D6	M17.813 4.653h.854c1.51.054 2.769.578 3.773 1.574 1.004.995 1.524 2.249 1.56 3.76v7.36c-.036 1.51-.556 2.769-1.56 3.773s-2.262 1.524-3.773 1.56H5.333c-1.51-.036-2.769-.556-3.773-1.56S.036 18.858 0 17.347v-7.36c.036-1.511.556-2.765 1.56-3.76 1.004-.996 2.262-1.52 3.773-1.574h.774l-1.174-1.12a1.234 1.234 0 0 1-.373-.906c0-.356.124-.658.373-.907l.027-.027c.267-.249.573-.373.92-.373.347 0 .653.124.92.373L9.653 4.44c.071.071.134.142.187.213h4.267a.836.836 0 0 1 .16-.213l2.853-2.747c.267-.249.573-.373.92-.373.347 0 .662.151.929.4.267.249.391.551.391.907 0 .355-.124.657-.373.906zM5.333 7.24c-.746.018-1.373.276-1.88.773-.506.498-.769 1.13-.786 1.894v7.52c.017.764.28 1.395.786 1.893.507.498 1.134.756 1.88.773h13.334c.746-.017 1.373-.275 1.88-.773.506-.498.769-1.129.786-1.893v-7.52c-.017-.765-.28-1.396-.786-1.894-.507-.497-1.134-.755-1.88-.773zM8 11.107c.373 0 .684.124.933.373.25.249.383.569.4.96v1.173c-.017.391-.15.711-.4.96-.249.25-.56.374-.933.374s-.684-.125-.933-.374c-.25-.249-.383-.569-.4-.96V12.44c0-.373.129-.689.386-.947.258-.257.574-.386.947-.386zm8 0c.373 0 .684.124.933.373.25.249.383.569.4.96v1.173c-.017.391-.15.711-.4.96-.249.25-.56.374-.933.374s-.684-.125-.933-.374c-.25-.249-.383-.569-.4-.96V12.44c.017-.391.15-.711.4-.96.249-.249.56-.373.933-.373Z
claude	#D97757	m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z
googlegemini	#8E75B2	M11.04 19.32Q12 21.51 12 24q0-2.49.93-4.68.96-2.19 2.58-3.81t3.81-2.55Q21.51 12 24 12q-2.49 0-4.68-.93a12.3 12.3 0 0 1-3.81-2.58 12.3 12.3 0 0 1-2.58-3.81Q12 2.49 12 0q0 2.49-.96 4.68-.93 2.19-2.55 3.81a12.3 12.3 0 0 1-3.81 2.58Q2.49 12 0 12q2.49 0 4.68.96 2.19.93 3.81 2.55t2.55 3.81
perplexity	#1FB8CD	M22.3977 7.0896h-2.3106V.0676l-7.5094 6.3542V.1577h-1.1554v6.1966L4.4904 0v7.0896H1.6023v10.3976h2.8882V24l6.932-6.3591v6.2005h1.1554v-6.0469l6.9318 6.1807v-6.4879h2.8882V7.0896zm-3.4657-4.531v4.531h-5.355l5.355-4.531zm-13.2862.0676 4.8691 4.4634H5.6458V2.6262zM2.7576 16.332V8.245h7.8476l-6.1149 6.1147v1.9723H2.7576zm2.8882 5.0404v-3.8852h.0001v-2.6488l5.7763-5.7764v7.0111l-5.7764 5.2993zm12.7086.0248-5.7766-5.1509V9.0618l5.7766 5.7766v6.5588zm2.8882-5.0652h-1.733v-1.9723L13.3948 8.245h7.8478v8.087z
googlechrome	#4285F4	M12 0C8.21 0 4.831 1.757 2.632 4.501l3.953 6.848A5.454 5.454 0 0 1 12 6.545h10.691A12 12 0 0 0 12 0zM1.931 5.47A11.943 11.943 0 0 0 0 12c0 6.012 4.42 10.991 10.189 11.864l3.953-6.847a5.45 5.45 0 0 1-6.865-2.29zm13.342 2.166a5.446 5.446 0 0 1 1.45 7.09l.002.001h-.002l-5.344 9.257c.206.01.413.016.621.016 6.627 0 12-5.373 12-12 0-1.54-.29-3.011-.818-4.364zM12 16.364a4.364 4.364 0 1 1 0-8.728 4.364 4.364 0 0 1 0 8.728Z
googleplay	#414141	M22.018 13.298l-3.919 2.218-3.515-3.493 3.543-3.521 3.891 2.202a1.49 1.49 0 0 1 0 2.594zM1.337.924a1.486 1.486 0 0 0-.112.568v21.017c0 .217.045.419.124.6l11.155-11.087L1.337.924zm12.207 10.065l3.258-3.238L3.45.195a1.466 1.466 0 0 0-.946-.179l11.04 10.973zm0 2.067l-11 10.933c.298.036.612-.016.906-.183l13.324-7.54-3.23-3.21z
googlemaps	#4285F4	M19.527 4.799c1.212 2.608.937 5.678-.405 8.173-1.101 2.047-2.744 3.74-4.098 5.614-.619.858-1.244 1.75-1.669 2.727-.141.325-.263.658-.383.992-.121.333-.224.673-.34 1.008-.109.314-.236.684-.627.687h-.007c-.466-.001-.579-.53-.695-.887-.284-.874-.581-1.713-1.019-2.525-.51-.944-1.145-1.817-1.79-2.671L19.527 4.799zM8.545 7.705l-3.959 4.707c.724 1.54 1.821 2.863 2.871 4.18.247.31.494.622.737.936l4.984-5.925-.029.01c-1.741.601-3.691-.291-4.392-1.987a3.377 3.377 0 0 1-.209-.716c-.063-.437-.077-.761-.004-1.198l.001-.007zM5.492 3.149l-.003.004c-1.947 2.466-2.281 5.88-1.117 8.77l4.785-5.689-.058-.05-3.607-3.035zM14.661.436l-3.838 4.563a.295.295 0 0 1 .027-.01c1.6-.551 3.403.15 4.22 1.626.176.319.323.683.377 1.045.068.446.085.773.012 1.22l-.003.016 3.836-4.561A8.382 8.382 0 0 0 14.67.439l-.009-.003zM9.466 5.868L14.162.285l-.047-.012A8.31 8.31 0 0 0 11.986 0a8.439 8.439 0 0 0-6.169 2.766l-.016.018 3.665 3.084z
gmail	#EA4335	M24 5.457v13.909c0 .904-.732 1.636-1.636 1.636h-3.819V11.73L12 16.64l-6.545-4.91v9.273H1.636A1.636 1.636 0 0 1 0 19.366V5.457c0-2.023 2.309-3.178 3.927-1.964L5.455 4.64 12 9.548l6.545-4.91 1.528-1.145C21.69 2.28 24 3.434 24 5.457z
github	#181717	M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12
wikipedia	#000000	M12.09 13.119c-.936 1.932-2.217 4.548-2.853 5.728-.616 1.074-1.127.931-1.532.029-1.406-3.321-4.293-9.144-5.651-12.409-.251-.601-.441-.987-.619-1.139-.181-.15-.554-.24-1.122-.271C.103 5.033 0 4.982 0 4.898v-.455l.052-.045c.924-.005 5.401 0 5.401 0l.051.045v.434c0 .119-.075.176-.225.176l-.564.031c-.485.029-.727.164-.727.436 0 .135.053.33.166.601 1.082 2.646 4.818 10.521 4.818 10.521l.136.046 2.411-4.81-.482-1.067-1.658-3.264s-.318-.654-.428-.872c-.728-1.443-.712-1.518-1.447-1.617-.207-.023-.313-.05-.313-.149v-.468l.06-.045h4.292l.113.037v.451c0 .105-.076.15-.227.15l-.308.047c-.792.061-.661.381-.136 1.422l1.582 3.252 1.758-3.504c.293-.64.233-.801.111-.947-.07-.084-.305-.22-.812-.24l-.201-.021c-.052 0-.098-.015-.145-.051-.045-.031-.067-.076-.067-.129v-.427l.061-.045c1.247-.008 4.043 0 4.043 0l.059.045v.436c0 .121-.059.178-.193.178-.646.03-.782.095-1.023.439-.12.186-.375.589-.646 1.039l-2.301 4.273-.065.135 2.792 5.712.17.048 4.396-10.438c.154-.422.129-.722-.064-.895-.197-.172-.346-.273-.857-.295l-.42-.016c-.061 0-.105-.014-.152-.045-.043-.029-.072-.075-.072-.119v-.436l.059-.045h4.961l.041.045v.437c0 .119-.074.18-.209.18-.648.03-1.127.18-1.443.421-.314.255-.557.616-.736 1.067 0 0-4.043 9.258-5.426 12.339-.525 1.007-1.053.917-1.503-.031-.571-1.171-1.773-3.786-2.646-5.71l.053-.036z
cloudflare	#F38020	M16.5088 16.8447c.1475-.5068.0908-.9707-.1553-1.3154-.2246-.3164-.6045-.499-1.0615-.5205l-8.6592-.1123a.1559.1559 0 0 1-.1333-.0713c-.0283-.042-.0351-.0986-.021-.1553.0278-.084.1123-.1484.2036-.1562l8.7359-.1123c1.0351-.0489 2.1601-.8868 2.5537-1.9136l.499-1.3013c.0215-.0561.0293-.1128.0147-.168-.5625-2.5463-2.835-4.4453-5.5499-4.4453-2.5039 0-4.6284 1.6177-5.3876 3.8614-.4927-.3658-1.1187-.5625-1.794-.499-1.2026.119-2.1665 1.083-2.2861 2.2856-.0283.31-.0069.6128.0635.894C1.5683 13.171 0 14.7754 0 16.752c0 .1748.0142.3515.0352.5273.0141.083.0844.1475.1689.1475h15.9814c.0909 0 .1758-.0645.2032-.1553l.12-.4268zm2.7568-5.5634c-.0771 0-.1611 0-.2383.0112-.0566 0-.1054.0415-.127.0976l-.3378 1.1744c-.1475.5068-.0918.9707.1543 1.3164.2256.3164.6055.498 1.0625.5195l1.8437.1133c.0557 0 .1055.0263.1329.0703.0283.043.0351.1074.0214.1562-.0283.084-.1132.1485-.204.1553l-1.921.1123c-1.041.0488-2.1582.8867-2.5527 1.914l-.1406.3585c-.0283.0713.0215.1416.0986.1416h6.5977c.0771 0 .1474-.0489.169-.126.1122-.4082.1757-.837.1757-1.2803 0-2.6025-2.125-4.727-4.7344-4.727
paypal	#002991	M15.607 4.653H8.941L6.645 19.251H1.82L4.862 0h7.995c3.754 0 6.375 2.294 6.473 5.513-.648-.478-2.105-.86-3.722-.86m6.57 5.546c0 3.41-3.01 6.853-6.958 6.853h-2.493L11.595 24H6.74l1.845-11.538h3.592c4.208 0 7.346-3.634 7.153-6.949a5.24 5.24 0 0 1 2.848 4.686M9.653 5.546h6.408c.907 0 1.942.222 2.363.541-.195 2.741-2.655 5.483-6.441 5.483H8.714Z
speedtest	#141526	M11.628 16.186l-2.047-2.14 6.791-5.953 1.21 1.302zm8.837 6.047c2.14-2.14 3.535-5.117 3.535-8.466 0-6.604-5.395-12-12-12s-12 5.396-12 12c0 3.35 1.302 6.326 3.535 8.466l1.674-1.675c-1.767-1.767-2.79-4.093-2.79-6.79A9.568 9.568 0 0 1 12 4.185a9.568 9.568 0 0 1 9.581 9.581c0 2.605-1.116 5.024-2.79 6.791Z
linkedin	#0A66C2	M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z
primevideo	#00A8E1	M0 9.508c0-.043.01-.073.028-.09.018-.017.047-.025.086-.025h.329c.07 0 .112.034.127.101l.032.119c.091-.088.202-.159.33-.21a1.04 1.04 0 0 1 .396-.079c.294 0 .528.109.7.326.171.217.257.51.257.88 0 .254-.042.475-.127.665-.086.19-.201.335-.347.437a.85.85 0 0 1-.502.154c-.125 0-.243-.02-.355-.06a.857.857 0 0 1-.288-.164v1.003c0 .043-.008.073-.025.09-.017.016-.046.025-.09.025H.115c-.04 0-.068-.009-.086-.025-.019-.017-.028-.047-.028-.09zm1.113.32a.868.868 0 0 0-.447.124v1.206a.834.834 0 0 0 .447.124c.17 0 .296-.058.376-.174.081-.117.121-.3.121-.55 0-.254-.04-.439-.118-.555-.08-.116-.206-.174-.379-.174zm2.248-.087c.121-.134.236-.23.344-.286a.733.733 0 0 1 .345-.085h.063c.043 0 .073.009.092.025.018.017.027.047.027.09v.385c0 .04-.008.068-.025.087-.017.018-.046.027-.089.027a.923.923 0 0 1-.082-.004 1.369 1.369 0 0 0-.383.025c-.1.02-.186.045-.256.076v1.54c0 .04-.008.069-.025.087-.016.018-.046.028-.089.028h-.437c-.04 0-.069-.01-.087-.028-.018-.018-.028-.047-.028-.087V9.508c0-.043.01-.073.028-.09.018-.017.047-.025.087-.025h.328c.07 0 .112.034.128.1zm1.526-.71a.396.396 0 0 1-.278-.096.338.338 0 0 1-.105-.262c0-.11.035-.197.105-.26a.395.395 0 0 1 .278-.097c.116 0 .208.032.278.096.07.064.105.151.105.261a.34.34 0 0 1-.105.262.396.396 0 0 1-.278.096zm-.333.477c0-.043.01-.073.027-.09.019-.017.048-.025.087-.025h.438c.043 0 .072.008.089.025s.025.047.025.09v2.113c0 .04-.008.069-.025.087-.017.018-.046.028-.09.028h-.437c-.04 0-.068-.01-.087-.028-.018-.018-.027-.047-.027-.087zm1.837.11c.161-.107.306-.183.435-.227.13-.045.263-.067.4-.067.273 0 .466.098.579.294.155-.104.3-.18.438-.225.137-.046.278-.069.424-.069.213 0 .377.06.495.179.117.12.175.286.175.5v1.618c0 .04-.008.069-.025.087-.017.019-.046.027-.089.027h-.438c-.04 0-.068-.008-.086-.027-.018-.018-.028-.047-.028-.087V10.15c0-.208-.092-.312-.278-.312-.164 0-.33.04-.497.119v1.664c0 .04-.008.069-.025.087-.017.019-.046.027-.09.027h-.437c-.04 0-.068-.008-.086-.027-.019-.018-.028-.047-.028-.087V10.15c0-.208-.093-.312-.278-.312-.17 0-.337.04-.502.123v1.66c0 .04-.008.069-.025.087-.017.019-.046.027-.089.027h-.438c-.039 0-.068-.008-.086-.027-.018-.018-.027-.047-.027-.087V9.508c0-.043.009-.073.027-.09.018-.017.047-.025.086-.025h.329c.07 0 .112.034.128.101zm4.387 1.16a1.81 1.81 0 0 1-.451-.05c.018.204.08.35.185.44.105.088.263.132.476.132.085 0 .168-.005.249-.016a3.08 3.08 0 0 0 .362-.078.143.143 0 0 1 .023-.002c.052 0 .078.035.078.105v.211c0 .049-.007.083-.02.103a.169.169 0 0 1-.08.053 1.953 1.953 0 0 1-.708.128c-.377 0-.666-.103-.868-.312-.203-.207-.304-.505-.304-.893 0-.398.104-.71.31-.935.207-.227.494-.34.862-.34.283 0 .504.069.664.206a.69.69 0 0 1 .24.55c0 .23-.087.403-.258.52-.172.119-.425.177-.76.177zm.064-.99c-.292 0-.46.18-.506.54.122.025.257.037.406.037.155 0 .267-.024.337-.071.07-.047.105-.12.105-.218 0-.193-.114-.289-.342-.289zm2.948 1.946a.21.21 0 0 1-.075-.011.119.119 0 0 1-.05-.037.274.274 0 0 1-.038-.071l-.777-2.04a1.863 1.863 0 0 1-.023-.063.162.162 0 0 1-.009-.05c0-.047.03-.07.091-.07h.454c.049 0 .084.01.107.028.023.018.04.049.052.092l.468 1.622.477-1.622a.175.175 0 0 1 .052-.092c.023-.018.058-.027.107-.027h.44c.061 0 .091.022.091.068a.16.16 0 0 1-.009.05l-.022.065-.777 2.039a.274.274 0 0 1-.039.07.122.122 0 0 1-.047.038.207.207 0 0 1-.078.01zm2.02-2.703a.393.393 0 0 1-.277-.097.338.338 0 0 1-.105-.26c0-.11.035-.198.105-.262a.393.393 0 0 1 .277-.096c.115 0 .207.032.277.096.07.064.104.151.104.261 0 .11-.034.197-.104.261a.393.393 0 0 1-.277.097zm-.218 2.703c-.04 0-.068-.01-.086-.028-.019-.018-.028-.047-.028-.087V9.507c0-.043.01-.072.028-.09.018-.016.047-.024.086-.024h.436c.042 0 .072.008.089.025.016.017.024.046.024.09v2.111c0 .04-.008.07-.024.087-.017.019-.047.028-.09.028zm1.948.05a.869.869 0 0 1-.513-.153.97.97 0 0 1-.334-.426 1.6 1.6 0 0 1-.116-.63c0-.38.09-.682.268-.91a.856.856 0 0 1 .709-.341.98.98 0 0 1 .622.206V8.458c0-.043.01-.073.027-.09.018-.016.047-.025.087-.025h.436c.042 0 .071.009.088.025.017.017.025.047.025.09v3.161c0 .04-.008.07-.025.087-.017.019-.046.028-.088.028h-.364a.135.135 0 0 1-.084-.023.137.137 0 0 1-.043-.078l-.027-.105a.958.958 0 0 1-.668.256zm.218-.504a.762.762 0 0 0 .418-.128v-1.21a.872.872 0 0 0-.45-.114c-.16 0-.28.06-.358.18-.08.121-.118.304-.118.548 0 .245.041.426.124.546.084.119.212.178.384.178zm2.588-.51c-.169 0-.315-.016-.44-.05.018.201.078.345.18.432.103.087.257.13.465.13.083 0 .164-.005.242-.016a2.997 2.997 0 0 0 .354-.076.135.135 0 0 1 .022-.002c.05 0 .075.035.075.103v.207c0 .048-.007.082-.02.101a.165.165 0 0 1-.077.052 1.895 1.895 0 0 1-.69.126c-.367 0-.65-.102-.846-.306-.197-.204-.296-.496-.296-.876 0-.39.1-.695.302-.917.202-.222.482-.333.84-.333.276 0 .492.068.647.203a.678.678 0 0 1 .234.539c0 .225-.084.395-.251.51-.168.115-.415.173-.74.173zm.063-.97c-.285 0-.45.176-.494.53.119.024.25.036.396.036.15 0 .26-.024.329-.07.068-.046.102-.117.102-.213 0-.19-.111-.284-.333-.284zm2.442 2.003c-.36 0-.642-.11-.845-.328-.203-.218-.304-.523-.304-.914 0-.388.101-.691.304-.91.203-.218.485-.327.845-.327s.642.109.845.327c.203.219.304.522.304.91 0 .39-.101.696-.304.914-.203.218-.485.328-.845.328zm0-.514c.318 0 .477-.242.477-.728 0-.483-.16-.724-.477-.724-.318 0-.477.241-.477.724 0 .486.16.728.477.728zm-6.844 1.886c.405-.306.944-.408 1.39-.408.418 0 .756.09.828.185.15.2-.039 1.584-.775 2.244-.112.102-.22.047-.17-.087.166-.442.536-1.436.36-1.677-.175-.242-1.158-.115-1.6-.058-.068.008-.107-.02-.112-.061v-.023c.004-.036.03-.078.079-.115zm-10.184-.172a.105.105 0 0 1 .106-.091c.027 0 .057.009.089.028a11.778 11.778 0 0 0 6.194 1.772c1.52 0 3.19-.34 4.726-1.043.232-.105.426.164.2.346-1.371 1.09-3.359 1.67-5.07 1.67-2.397 0-4.557-.956-6.191-2.547a.173.173 0 0 1-.054-.097Z
openai	#74AA9C	M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z
amazon	#FF9900	M.045 18.02c.072-.116.187-.124.348-.022 3.636 2.11 7.594 3.166 11.87 3.166 2.852 0 5.668-.533 8.447-1.595l.315-.14c.138-.06.234-.1.293-.13.226-.088.39-.046.525.13.12.174.09.336-.12.48-.256.19-.6.41-1.006.654-1.244.743-2.64 1.316-4.185 1.726a17.617 17.617 0 01-10.951-.577 17.88 17.88 0 01-5.43-3.35c-.1-.074-.151-.15-.151-.22 0-.047.021-.09.051-.13zm6.565-6.218c0-1.005.247-1.863.743-2.577.495-.71 1.17-1.25 2.04-1.615.796-.335 1.756-.575 2.912-.72.39-.046 1.033-.103 1.92-.174v-.37c0-.93-.105-1.558-.3-1.875-.302-.43-.78-.65-1.44-.65h-.182c-.48.046-.896.196-1.246.46-.35.27-.575.63-.675 1.096-.06.3-.206.465-.435.51l-2.52-.315c-.248-.06-.372-.18-.372-.39 0-.046.007-.09.022-.15.247-1.29.855-2.25 1.82-2.88.976-.616 2.1-.975 3.39-1.05h.54c1.65 0 2.957.434 3.888 1.29.135.15.27.3.405.48.12.165.224.314.283.45.075.134.15.33.195.57.06.254.105.42.135.51.03.104.062.3.076.615.01.313.02.493.02.553v5.28c0 .376.06.72.165 1.036.105.313.21.54.315.674l.51.674c.09.136.136.256.136.36 0 .12-.06.226-.18.314-1.2 1.05-1.86 1.62-1.963 1.71-.165.135-.375.15-.63.045a6.062 6.062 0 01-.526-.496l-.31-.347a9.391 9.391 0 01-.317-.42l-.3-.435c-.81.886-1.603 1.44-2.4 1.665-.494.15-1.093.227-1.83.227-1.11 0-2.04-.343-2.76-1.034-.72-.69-1.08-1.665-1.08-2.94l-.05-.076zm3.753-.438c0 .566.14 1.02.425 1.364.285.34.675.512 1.155.512.045 0 .106-.007.195-.02.09-.016.134-.023.166-.023.614-.16 1.08-.553 1.424-1.178.165-.28.285-.58.36-.91.09-.32.12-.59.135-.8.015-.195.015-.54.015-1.005v-.54c-.84 0-1.484.06-1.92.18-1.275.36-1.92 1.17-1.92 2.43l-.035-.02zm9.162 7.027c.03-.06.075-.11.132-.17.362-.243.714-.41 1.05-.5a8.094 8.094 0 011.612-.24c.14-.012.28 0 .41.03.65.06 1.05.168 1.172.33.063.09.099.228.099.39v.15c0 .51-.149 1.11-.424 1.8-.278.69-.664 1.248-1.156 1.68-.073.06-.14.09-.197.09-.03 0-.06 0-.09-.012-.09-.044-.107-.12-.064-.24.54-1.26.806-2.143.806-2.64 0-.15-.03-.27-.087-.344-.145-.166-.55-.257-1.224-.257-.243 0-.533.016-.87.046-.363.045-.7.09-1 .135-.09 0-.148-.014-.18-.044-.03-.03-.036-.047-.02-.077 0-.017.006-.03.02-.063v-.06z
nintendo	#E60012	m4.447 12.546-1.202-1.942h-.864v2.793h.864v-1.942l1.202 1.942h.856v-2.793H4.44l.007 1.942Zm6.828-1.001v-.279h-.451v-.376h-.841v.376h-.458v.279h.458v1.852h.841v-1.852h.451Zm-5.491 1.844h.834v-1.852h-.834v1.852Zm0-2.213h.841v-.572h-.841v.572Zm14.663.233c-.676 0-1.224.467-1.224 1.039 0 .572.548 1.039 1.224 1.039.676 0 1.225-.467 1.225-1.039 0-.572-.549-1.039-1.225-1.039Zm.338 1.431c0 .293-.173.414-.338.414-.165 0-.346-.121-.346-.414v-.783c0-.294.173-.414.346-.414.165 0 .338.12.338.414v.783Zm-2.659-1.212a1.093 1.093 0 0 0-.473-.166c-.601-.053-1.067.482-1.067.971 0 .648.496.881.571.919.285.128.646.135.961-.068v.105h.827v-2.785h-.827c.008 0 .008.595.008 1.024Zm.008.828v.331c0 .286-.196.361-.331.361s-.331-.075-.331-.361v-.662c0-.287.196-.362.331-.362.128 0 .33.075.33.362v.331h.001Zm-9.556-1.001a1.02 1.02 0 0 0-.668.278v-.196h-.834v1.852h.834V12.17c0-.158.172-.339.398-.339.225 0 .383.181.383.339v1.219h.834v-1.008c0-.731-.631-.942-.947-.926Zm6.798 0a1.01 1.01 0 0 0-.668.278v-.196h-.834v1.852h.834V12.17c0-.158.173-.339.398-.339.225 0 .383.181.383.339v1.219h.834v-1.008c0-.731-.631-.942-.947-.926Zm-1.75 1.016c0-.572-.556-1.054-1.232-1.054-.683 0-1.232.467-1.232 1.039 0 .572.549 1.039 1.232 1.039.564 0 1.044-.324 1.187-.76h-.834v.112c0 .339-.225.414-.345.414-.128 0-.353-.075-.353-.413v-.385l1.577.008Zm-1.517-.655a.346.346 0 0 1 .293-.166c.112 0 .225.053.293.166.052.09.052.203.052.361h-.698c0-.158.007-.263.06-.361Zm9.893-.866c0-.09-.068-.135-.203-.135h-.188v.474h.113v-.196h.06l.09.196h.128l-.105-.211c.067-.022.105-.068.105-.128Zm-.218.068h-.06v-.136h.052c.068 0 .105.023.105.068 0 .053-.029.068-.097.068Zm.007-.392a.433.433 0 0 0-.428.43c0 .233.196.429.429.429a.429.429 0 0 0 0-.859h-.001Zm0 .776a.35.35 0 0 1-.345-.346.35.35 0 0 1 .346-.347.35.35 0 0 1 .345.347.35.35 0 0 1-.345.346h-.001Zm-.938-2.364H3.132C1.254 9.03 0 10.386 0 12.004s1.254 2.959 3.14 2.959h17.72c1.886 0 3.14-1.34 3.14-2.959-.007-1.618-1.269-2.966-3.147-2.966Zm-.008 5.202H3.14c-1.495.008-2.404-1.001-2.404-2.236 0-1.235.917-2.228 2.404-2.236h17.705c1.487 0 2.404 1.001 2.404 2.236 0 1.235-.909 2.236-2.404 2.236Z
digitalocean	#0080FF	M12.04 0C5.408-.02.005 5.37.005 11.992h4.638c0-4.923 4.882-8.731 10.064-6.855a6.95 6.95 0 014.147 4.148c1.889 5.177-1.924 10.055-6.84 10.064v-4.61H7.391v4.623h4.61V24c7.86 0 13.967-7.588 11.397-15.83-1.115-3.59-3.985-6.446-7.575-7.575A12.8 12.8 0 0012.039 0zM7.39 19.362H3.828v3.564H7.39zm-3.563 0v-2.978H.85v2.978z
patreon	#000000	M22.957 7.21c-.004-3.064-2.391-5.576-5.191-6.482-3.478-1.125-8.064-.962-11.384.604C2.357 3.231 1.093 7.391 1.046 11.54c-.039 3.411.302 12.396 5.369 12.46 3.765.047 4.326-4.804 6.068-7.141 1.24-1.662 2.836-2.132 4.801-2.618 3.376-.836 5.678-3.501 5.673-7.031Z
swagger	#85EA2D	M12 0C5.383 0 0 5.383 0 12s5.383 12 12 12c6.616 0 12-5.383 12-12S18.616 0 12 0zm0 1.144c5.995 0 10.856 4.86 10.856 10.856 0 5.995-4.86 10.856-10.856 10.856-5.996 0-10.856-4.86-10.856-10.856C1.144 6.004 6.004 1.144 12 1.144zM8.37 5.868a6.707 6.707 0 0 0-.423.005c-.983.056-1.573.517-1.735 1.472-.115.665-.096 1.348-.143 2.017-.013.35-.05.697-.115 1.038-.134.609-.397.798-1.016.83a2.65 2.65 0 0 0-.244.042v1.463c1.126.055 1.278.452 1.37 1.629.033.429-.013.858.015 1.287.018.406.073.808.156 1.2.259 1.075 1.307 1.435 2.575 1.218v-1.283c-.203 0-.383.005-.558 0-.43-.013-.591-.12-.632-.535-.056-.535-.042-1.08-.075-1.62-.064-1.001-.175-1.988-1.153-2.625.503-.37.868-.812.983-1.398.083-.41.134-.821.166-1.237.028-.415-.023-.84.014-1.25.06-.665.102-.937.9-.91.12 0 .235-.017.369-.027v-1.31c-.16 0-.31-.004-.454-.006zm7.593.009a4.247 4.247 0 0 0-.813.06v1.274c.245 0 .434 0 .623.005.328.004.577.13.61.494.032.332.031.669.064 1.006.065.669.101 1.347.217 2.007.102.544.475.95.941 1.283-.817.549-1.057 1.333-1.098 2.215-.023.604-.037 1.213-.069 1.822-.028.554-.222.734-.78.748-.157.004-.31.018-.484.028v1.305c.327 0 .627.019.927 0 .932-.055 1.495-.507 1.68-1.412.078-.498.124-1 .138-1.504.032-.461.028-.927.074-1.384.069-.715.397-1.01 1.112-1.057a.972.972 0 0 0 .199-.046v-1.463c-.12-.014-.204-.027-.291-.032-.536-.023-.804-.203-.937-.71a5.146 5.146 0 0 1-.152-.993c-.037-.618-.033-1.241-.074-1.86-.08-1.192-.794-1.753-1.887-1.786zm-6.89 5.28a.844.844 0 0 0-.083 1.684h.055a.83.83 0 0 0 .877-.78v-.046a.845.845 0 0 0-.83-.858zm2.911 0a.808.808 0 0 0-.834.78c0 .027 0 .05.004.078 0 .503.342.826.859.826.507 0 .826-.332.826-.853-.005-.503-.342-.836-.855-.831zm2.963 0a.861.861 0 0 0-.876.835c0 .47.378.849.849.849h.009c.425.074.853-.337.881-.83.023-.457-.392-.854-.863-.854z
snyk	#4C4A73	M17.097 13.344c.143-.37.06-2.117-.222-4.675l-.004-.04.904-2.431v-.05c0-1.06-1.374-3.9-2.186-5.41L15.192 0l-.84 5.854-.503.829-.125-.042c-.351-.118-1.042-.316-1.728-.316-.65 0-1.294.171-1.72.315l-.125.042-.504-.827L8.807 0l-.396.737c-.812 1.51-2.186 4.35-2.186 5.411v.05l.904 2.432-.004.039c-.283 2.558-.366 4.305-.222 4.674.13.332.642 1.041 1.072 1.605l-.619 5.724.617.442.576-5.329c.012.414.064 1.277.275 2.068l-.389 3.592L12 24l4.279-3.067.375-.268-.62-5.73c.428-.561.934-1.262 1.063-1.591zM15.59 2.298c.694 1.408 1.421 3.08 1.471 3.779l-.388 1.045c-.935-1.31-1.228-3.441-1.253-3.636zm-1.124 7.8c.84 0 .212.712.138.792h-1.587c.144-.18.69-.792 1.45-.792zm-.452 1.468a.178.178 0 0 1-.175.153.292.292 0 1 0 .441-.31h.504v.024a.662.662 0 0 1-1.325 0v-.025h.511l-.008.007c.039.038.06.093.052.15zM12.39 19.29c.097.064.2.115.306.156-.168.19-.399.287-.697.287-.299 0-.53-.097-.697-.288.107-.04.21-.092.306-.156a.573.573 0 0 0 .391.114c.103 0 .255 0 .391-.113zm-2.62-7.724a.178.178 0 0 1-.174.153.292.292 0 1 0 .441-.31h.504v.024a.662.662 0 0 1-1.326 0v-.025h.511l-.008.007c.039.038.06.093.052.15zm-.374-.676c-.074-.08-.702-.792.138-.792.759 0 1.305.612 1.45.792zM6.948 6.077c.05-.699.778-2.37 1.471-3.78l.185 1.29c-.07.48-.393 2.37-1.257 3.56zM9.473 18.09c-.373-1.02-.377-2.446-.377-2.507v-.097l-.06-.076c-.551-.683-1.477-1.9-1.616-2.257l-.005-.014c-.124-.43.1-2.997.268-4.513l.008-.066-.187-.502.07-.075c.476-.497.88-1.213 1.203-2.126L9 5.223l.118.82.807 1.326.22-.094c.009-.004.934-.4 1.851-.4H12v.44h-.004c-.812 0-1.669.36-1.677.363l-.571.246-.797-1.308c-.27.62-.585 1.137-.94 1.543l.129.347-.019.169c-.24 2.156-.348 4.044-.285 4.332.086.2.523.812 1 1.437l.748-.218 1.17-1.334.184 3.458c-.011.015-.28.393-.28.609 0 .235.344.541.685.786.005-.01.007-.02.013-.03.12-.212.275-.251.346-.087.04.092.028.369.028.369l.005.002v.328c-.013.027-.302.674-1.014.674-.275 0-.948-.089-1.248-.911zm2.536 2.409c-.527 0-1.297-.257-1.374-.952.029.001.057.003.086.003.06 0 .119-.003.177-.01.235.455.665.6 1.102.6.436 0 .865-.146 1.1-.6.059.007.119.01.18.01.029 0 .057-.002.085-.003-.076.695-.835.952-1.356.952zm2.956-5.09l-.061.077v.097c0 .06-.004 1.487-.377 2.507-.3.822-.973.91-1.248.91-.71 0-1.002-.658-1.014-.686V18l.005-.004s-.012-.276.028-.368c.07-.164.226-.126.346.088.006.009.009.02.013.03.34-.246.686-.552.686-.787 0-.216-.269-.593-.28-.61l.183-3.457 1.17 1.334 1.2.35c-.23.304-.463.6-.651.834zm-8.472-1.907c-.22-.563-.022-2.916.187-4.817l-.895-2.409v-.128c0-.312.095-.734.246-1.207-1.177.253-1.808.49-1.808.49v12.996l2.67 1.914.577-5.332c-.538-.718-.868-1.226-.977-1.507zm3.853-7.346c.446-.136 1.042-.27 1.65-.27.61 0 1.21.135 1.658.27l.276-.453.184-1.288s-1.288-.068-2.103-.068c-.759 0-1.467.026-2.125.07l.184 1.286zm7.623-1.217c.151.474.247.896.247 1.21v.127l-.895 2.409c.208 1.901.406 4.253.186 4.818-.109.279-.435.782-.968 1.493l.578 5.337 2.66-1.906V5.432s-.632-.24-1.808-.493Z
mongodb	#47A248	M17.193 9.555c-1.264-5.58-4.252-7.414-4.573-8.115-.28-.394-.53-.954-.735-1.44-.036.495-.055.685-.523 1.184-.723.566-4.438 3.682-4.74 10.02-.282 5.912 4.27 9.435 4.888 9.884l.07.05A73.49 73.49 0 0111.91 24h.481c.114-1.032.284-2.056.51-3.07.417-.296.604-.463.85-.693a11.342 11.342 0 003.639-8.464c.01-.814-.103-1.662-.197-2.218zm-5.336 8.195s0-8.291.275-8.29c.213 0 .49 10.695.49 10.695-.381-.045-.765-1.76-.765-2.405z
autodesk	#000000	m.129 20.202 14.7-9.136h7.625c.235 0 .445.188.445.445 0 .21-.092.305-.21.375l-7.222 4.323c-.47.283-.633.845-.633 1.265l-.008 2.725H24V4.362a.561.561 0 0 0-.585-.562h-8.752L0 12.893V20.2h.129z
redis	#FF4438	M22.71 13.145c-1.66 2.092-3.452 4.483-7.038 4.483-3.203 0-4.397-2.825-4.48-5.12.701 1.484 2.073 2.685 4.214 2.63 4.117-.133 6.94-3.852 6.94-7.239 0-4.05-3.022-6.972-8.268-6.972-3.752 0-8.4 1.428-11.455 3.685C2.59 6.937 3.885 9.958 4.35 9.626c2.648-1.904 4.748-3.13 6.784-3.744C8.12 9.244.886 17.05 0 18.425c.1 1.261 1.66 4.648 2.424 4.648.232 0 .431-.133.664-.365a100.49 100.49 0 0 0 5.54-6.765c.222 3.104 1.748 6.898 6.014 6.898 3.819 0 7.604-2.756 9.33-8.965.2-.764-.73-1.361-1.261-.73zm-4.349-5.013c0 1.959-1.926 2.922-3.685 2.922-.941 0-1.664-.247-2.235-.568 1.051-1.592 2.092-3.225 3.21-4.973 1.972.334 2.71 1.43 2.71 2.619z
scaleway	#4F0599	M16.605 11.11v5.72a1.77 1.77 0 01-1.54 1.69h-4a1.43 1.43 0 01-1.31-1.22 1.09 1.09 0 010-.18 1.37 1.37 0 011.37-1.36h1.74a1 1 0 001-1v-3.62a1.4 1.4 0 011.18-1.39h.17a1.37 1.37 0 011.39 1.36zm-6.46 1.74V9.26a1 1 0 011-1h1.85a1.37 1.37 0 001.37-1.37 1 1 0 000-.17 1.45 1.45 0 00-1.41-1.2h-3.96a1.81 1.81 0 00-1.58 1.66v5.7a1.37 1.37 0 001.37 1.37h.21a1.4 1.4 0 001.15-1.4zm12-4.29V20a4.53 4.53 0 01-4.15 4h-7.58a8.57 8.57 0 01-8.56-8.57V4.54A4.54 4.54 0 016.395 0h7.18a8.56 8.56 0 018.56 8.56zm-2.74 0a5.83 5.83 0 00-5.82-5.82h-7.19a1.79 1.79 0 00-1.8 1.8v10.89a5.83 5.83 0 005.82 5.8h7.44a1.79 1.79 0 001.54-1.48z
jetbrains	#000000	M2.345 23.997A2.347 2.347 0 0 1 0 21.652V10.988C0 9.665.535 8.37 1.473 7.433l5.965-5.961A5.01 5.01 0 0 1 10.989 0h10.666A2.347 2.347 0 0 1 24 2.345v10.664a5.056 5.056 0 0 1-1.473 3.554l-5.965 5.965A5.017 5.017 0 0 1 13.007 24v-.003H2.345Zm8.969-6.854H5.486v1.371h5.828v-1.371ZM3.963 6.514h13.523v13.519l4.257-4.257a3.936 3.936 0 0 0 1.146-2.767V2.345c0-.678-.552-1.234-1.234-1.234H10.989a3.897 3.897 0 0 0-2.767 1.145L3.963 6.514Zm-.192.192L2.256 8.22a3.944 3.944 0 0 0-1.145 2.768v10.664c0 .678.552 1.234 1.234 1.234h10.666a3.9 3.9 0 0 0 2.767-1.146l1.512-1.511H3.771V6.706Z
intel	#0071C5	M20.42 7.345v9.18h1.651v-9.18zM0 7.475v1.737h1.737V7.474zm9.78.352v6.053c0 .513.044.945.13 1.292.087.34.235.618.44.828.203.21.475.359.803.451.334.093.754.136 1.255.136h.216v-1.533c-.24 0-.445-.012-.593-.037a.672.672 0 0 1-.39-.173.693.693 0 0 1-.173-.377 4.002 4.002 0 0 1-.037-.606v-2.182h1.193v-1.416h-1.193V7.827zm-3.505 2.312c-.396 0-.76.08-1.082.241-.327.161-.6.384-.822.668l-.087.117v-.902H2.658v6.256h1.639v-3.214c.018-.588.16-1.02.433-1.299.29-.297.642-.445 1.044-.445.476 0 .841.149 1.082.433.235.284.359.686.359 1.2v3.324h1.663V12.97c.006-.89-.229-1.595-.686-2.09-.458-.495-1.1-.742-1.917-.742zm10.065.006a3.252 3.252 0 0 0-2.306.946c-.29.29-.525.637-.692 1.033a3.145 3.145 0 0 0-.254 1.273c0 .452.08.878.241 1.274.161.395.39.742.674 1.032.284.29.637.526 1.045.693.408.173.86.26 1.342.26 1.397 0 2.262-.637 2.782-1.23l-1.187-.904c-.248.297-.841.699-1.583.699-.464 0-.847-.105-1.138-.321a1.588 1.588 0 0 1-.593-.872l-.019-.056h4.915v-.587c0-.451-.08-.872-.235-1.267a3.393 3.393 0 0 0-.661-1.033 3.013 3.013 0 0 0-1.02-.692 3.345 3.345 0 0 0-1.311-.248zm-16.297.118v6.256h1.651v-6.256zm16.278 1.286c1.132 0 1.664.797 1.664 1.255l-3.32.006c0-.458.525-1.255 1.656-1.261zm7.073 3.814a.606.606 0 0 0-.606.606.606.606 0 0 0 .606.606.606.606 0 0 0 .606-.606.606.606 0 0 0-.606-.606zm-.008.105a.5.5 0 0 1 .002 0 .5.5 0 0 1 .5.501.5.5 0 0 1-.5.5.5.5 0 0 1-.5-.5.5.5 0 0 1 .498-.5zm-.233.155v.699h.13v-.285h.093l.173.285h.136l-.18-.297a.191.191 0 0 0 .118-.056c.03-.03.05-.074.05-.136 0-.068-.02-.117-.063-.154-.037-.038-.105-.056-.185-.056zm.13.099h.154c.019 0 .037.006.056.012a.064.064 0 0 1 .037.031c.013.013.012.031.012.056a.124.124 0 0 1-.012.055.164.164 0 0 1-.037.031c-.019.006-.037.013-.056.013h-.154Z
amd	#ED1C24	M18.324 9.137l1.559 1.56h2.556v2.557L24 14.814V9.137zM2 9.52l-2 4.96h1.309l.37-.982H3.9l.408.982h1.338L3.432 9.52zm4.209 0v4.955h1.238v-3.092l1.338 1.562h.188l1.338-1.556v3.091h1.238V9.52H10.47l-1.592 1.845L7.287 9.52zm6.283 0v4.96h2.057c1.979 0 2.88-1.046 2.88-2.472 0-1.36-.937-2.488-2.747-2.488zm1.237.91h.792c1.17 0 1.63.711 1.63 1.57 0 .728-.372 1.572-1.616 1.572h-.806zm-10.985.273l.791 1.932H2.008zm17.137.307l-1.604 1.603v2.25h2.246l1.604-1.607h-2.246z
linux	#FCC624	M12.504 0c-.155 0-.315.008-.48.021-4.226.333-3.105 4.807-3.17 6.298-.076 1.092-.3 1.953-1.05 3.02-.885 1.051-2.127 2.75-2.716 4.521-.278.832-.41 1.684-.287 2.489a.424.424 0 00-.11.135c-.26.268-.45.6-.663.839-.199.199-.485.267-.797.4-.313.136-.658.269-.864.68-.09.189-.136.394-.132.602 0 .199.027.4.055.536.058.399.116.728.04.97-.249.68-.28 1.145-.106 1.484.174.334.535.47.94.601.81.2 1.91.135 2.774.6.926.466 1.866.67 2.616.47.526-.116.97-.464 1.208-.946.587-.003 1.23-.269 2.26-.334.699-.058 1.574.267 2.577.2.025.134.063.198.114.333l.003.003c.391.778 1.113 1.132 1.884 1.071.771-.06 1.592-.536 2.257-1.306.631-.765 1.683-1.084 2.378-1.503.348-.199.629-.469.649-.853.023-.4-.2-.811-.714-1.376v-.097l-.003-.003c-.17-.2-.25-.535-.338-.926-.085-.401-.182-.786-.492-1.046h-.003c-.059-.054-.123-.067-.188-.135a.357.357 0 00-.19-.064c.431-1.278.264-2.55-.173-3.694-.533-1.41-1.465-2.638-2.175-3.483-.796-1.005-1.576-1.957-1.56-3.368.026-2.152.236-6.133-3.544-6.139zm.529 3.405h.013c.213 0 .396.062.584.198.19.135.33.332.438.533.105.259.158.459.166.724 0-.02.006-.04.006-.06v.105a.086.086 0 01-.004-.021l-.004-.024a1.807 1.807 0 01-.15.706.953.953 0 01-.213.335.71.71 0 00-.088-.042c-.104-.045-.198-.064-.284-.133a1.312 1.312 0 00-.22-.066c.05-.06.146-.133.183-.198.053-.128.082-.264.088-.402v-.02a1.21 1.21 0 00-.061-.4c-.045-.134-.101-.2-.183-.333-.084-.066-.167-.132-.267-.132h-.016c-.093 0-.176.03-.262.132a.8.8 0 00-.205.334 1.18 1.18 0 00-.09.4v.019c.002.089.008.179.02.267-.193-.067-.438-.135-.607-.202a1.635 1.635 0 01-.018-.2v-.02a1.772 1.772 0 01.15-.768c.082-.22.232-.406.43-.533a.985.985 0 01.594-.2zm-2.962.059h.036c.142 0 .27.048.399.135.146.129.264.288.344.465.09.199.14.4.153.667v.004c.007.134.006.2-.002.266v.08c-.03.007-.056.018-.083.024-.152.055-.274.135-.393.2.012-.09.013-.18.003-.267v-.015c-.012-.133-.04-.2-.082-.333a.613.613 0 00-.166-.267.248.248 0 00-.183-.064h-.021c-.071.006-.13.04-.186.132a.552.552 0 00-.12.27.944.944 0 00-.023.33v.015c.012.135.037.2.08.334.046.134.098.2.166.268.01.009.02.018.034.024-.07.057-.117.07-.176.136a.304.304 0 01-.131.068 2.62 2.62 0 01-.275-.402 1.772 1.772 0 01-.155-.667 1.759 1.759 0 01.08-.668 1.43 1.43 0 01.283-.535c.128-.133.26-.2.418-.2zm1.37 1.706c.332 0 .733.065 1.216.399.293.2.523.269 1.052.468h.003c.255.136.405.266.478.399v-.131a.571.571 0 01.016.47c-.123.31-.516.643-1.063.842v.002c-.268.135-.501.333-.775.465-.276.135-.588.292-1.012.267a1.139 1.139 0 01-.448-.067 3.566 3.566 0 01-.322-.198c-.195-.135-.363-.332-.612-.465v-.005h-.005c-.4-.246-.616-.512-.686-.71-.07-.268-.005-.47.193-.6.224-.135.38-.271.483-.336.104-.074.143-.102.176-.131h.002v-.003c.169-.202.436-.47.839-.601.139-.036.294-.065.466-.065zm2.8 2.142c.358 1.417 1.196 3.475 1.735 4.473.286.534.855 1.659 1.102 3.024.156-.005.33.018.513.064.646-1.671-.546-3.467-1.089-3.966-.22-.2-.232-.335-.123-.335.59.534 1.365 1.572 1.646 2.757.13.535.16 1.104.021 1.67.067.028.135.06.205.067 1.032.534 1.413.938 1.23 1.537v-.043c-.06-.003-.12 0-.18 0h-.016c.151-.467-.182-.825-1.065-1.224-.915-.4-1.646-.336-1.77.465-.008.043-.013.066-.018.135-.068.023-.139.053-.209.064-.43.268-.662.669-.793 1.187-.13.533-.17 1.156-.205 1.869v.003c-.02.334-.17.838-.319 1.35-1.5 1.072-3.58 1.538-5.348.334a2.645 2.645 0 00-.402-.533 1.45 1.45 0 00-.275-.333c.182 0 .338-.03.465-.067a.615.615 0 00.314-.334c.108-.267 0-.697-.345-1.163-.345-.467-.931-.995-1.788-1.521-.63-.4-.986-.87-1.15-1.396-.165-.534-.143-1.085-.015-1.645.245-1.07.873-2.11 1.274-2.763.107-.065.037.135-.408.974-.396.751-1.14 2.497-.122 3.854a8.123 8.123 0 01.647-2.876c.564-1.278 1.743-3.504 1.836-5.268.048.036.217.135.289.202.218.133.38.333.59.465.21.201.477.335.876.335.039.003.075.006.11.006.412 0 .73-.134.997-.268.29-.134.52-.334.74-.4h.005c.467-.135.835-.402 1.044-.7zm2.185 8.958c.037.6.343 1.245.882 1.377.588.134 1.434-.333 1.791-.765l.211-.01c.315-.007.577.01.847.268l.003.003c.208.199.305.53.391.876.085.4.154.78.409 1.066.486.527.645.906.636 1.14l.003-.007v.018l-.003-.012c-.015.262-.185.396-.498.595-.63.401-1.746.712-2.457 1.57-.618.737-1.37 1.14-2.036 1.191-.664.053-1.237-.2-1.574-.898l-.005-.003c-.21-.4-.12-1.025.056-1.69.176-.668.428-1.344.463-1.897.037-.714.076-1.335.195-1.814.12-.465.308-.797.641-.984l.045-.022zm-10.814.049h.01c.053 0 .105.005.157.014.376.055.706.333 1.023.752l.91 1.664.003.003c.243.533.754 1.064 1.189 1.637.434.598.77 1.131.729 1.57v.006c-.057.744-.48 1.148-1.125 1.294-.645.135-1.52.002-2.395-.464-.968-.536-2.118-.469-2.857-.602-.369-.066-.61-.2-.723-.4-.11-.2-.113-.602.123-1.23v-.004l.002-.003c.117-.334.03-.752-.027-1.118-.055-.401-.083-.71.043-.94.16-.334.396-.4.69-.533.294-.135.64-.202.915-.47h.002v-.002c.256-.268.445-.601.668-.838.19-.201.38-.336.663-.336zm7.159-9.074c-.435.201-.945.535-1.488.535-.542 0-.97-.267-1.28-.466-.154-.134-.28-.268-.373-.335-.164-.134-.144-.333-.074-.333.109.016.129.134.199.2.096.066.215.2.36.333.292.2.68.467 1.167.467.485 0 1.053-.267 1.398-.466.195-.135.445-.334.648-.467.156-.136.149-.267.279-.267.128.016.034.134-.147.332a8.097 8.097 0 01-.69.468zm-1.082-1.583V5.64c-.006-.02.013-.042.029-.05.074-.043.18-.027.26.004.063 0 .16.067.15.135-.006.049-.085.066-.135.066-.055 0-.092-.043-.141-.068-.052-.018-.146-.008-.163-.065zm-.551 0c-.02.058-.113.049-.166.066-.047.025-.086.068-.14.068-.05 0-.13-.02-.136-.068-.01-.066.088-.133.15-.133.08-.031.184-.047.259-.005.019.009.036.03.03.05v.02h.003z
sinaweibo	#E6162D	M10.098 20.323c-3.977.391-7.414-1.406-7.672-4.02-.259-2.609 2.759-5.047 6.74-5.441 3.979-.394 7.413 1.404 7.671 4.018.259 2.6-2.759 5.049-6.737 5.439l-.002.004zM9.05 17.219c-.384.616-1.208.884-1.829.602-.612-.279-.793-.991-.406-1.593.379-.595 1.176-.861 1.793-.601.622.263.82.972.442 1.592zm1.27-1.627c-.141.237-.449.353-.689.253-.236-.09-.313-.361-.177-.586.138-.227.436-.346.672-.24.239.09.315.36.18.601l.014-.028zm.176-2.719c-1.893-.493-4.033.45-4.857 2.118-.836 1.704-.026 3.591 1.886 4.21 1.983.64 4.318-.341 5.132-2.179.8-1.793-.201-3.642-2.161-4.149zm7.563-1.224c-.346-.105-.57-.18-.405-.615.375-.977.42-1.804 0-2.404-.781-1.112-2.915-1.053-5.364-.03 0 0-.766.331-.571-.271.376-1.217.315-2.224-.27-2.809-1.338-1.337-4.869.045-7.888 3.08C1.309 10.87 0 13.273 0 15.348c0 3.981 5.099 6.395 10.086 6.395 6.536 0 10.888-3.801 10.888-6.82 0-1.822-1.547-2.854-2.915-3.284v.01zm1.908-5.092c-.766-.856-1.908-1.187-2.96-.962-.436.09-.706.511-.616.932.09.42.511.691.932.602.511-.105 1.067.044 1.442.465.376.421.466.977.316 1.473-.136.406.089.856.51.992.405.119.857-.105.992-.512.33-1.021.12-2.178-.646-3.035l.03.045zm2.418-2.195c-1.576-1.757-3.905-2.419-6.054-1.968-.496.104-.812.587-.706 1.081.104.496.586.813 1.082.707 1.532-.331 3.185.15 4.296 1.383 1.112 1.246 1.429 2.943.947 4.416-.165.48.106 1.007.586 1.157.479.165.991-.104 1.157-.586.675-2.088.241-4.478-1.338-6.235l.03.045z
qq	#1EBAFC	M21.395 15.035a40 40 0 0 0-.803-2.264l-1.079-2.695c.001-.032.014-.562.014-.836C19.526 4.632 17.351 0 12 0S4.474 4.632 4.474 9.241c0 .274.013.804.014.836l-1.08 2.695a39 39 0 0 0-.802 2.264c-1.021 3.283-.69 4.643-.438 4.673.54.065 2.103-2.472 2.103-2.472 0 1.469.756 3.387 2.394 4.771-.612.188-1.363.479-1.845.835-.434.32-.379.646-.301.778.343.578 5.883.369 7.482.189 1.6.18 7.14.389 7.483-.189.078-.132.132-.458-.301-.778-.483-.356-1.233-.646-1.846-.836 1.637-1.384 2.393-3.302 2.393-4.771 0 0 1.563 2.537 2.103 2.472.251-.03.581-1.39-.438-4.673
graylog	#FF3633	M6.93 11.369a.84.84 0 01.75.45h.705l1.112-2.675a.483.483 0 01.3-.278c.235-.042.47.086.513.321l1.177 5.177 1.198-6.974a.41.41 0 01.32-.342.44.44 0 01.535.321l1.284 5.24.663-1.946a.449.449 0 01.17-.235c.193-.129.471-.086.6.107l.556.791c.021.193.021.385.021.578a8.3 8.3 0 01-.043.748c-.085-.021-.15-.085-.213-.15l-.557-.77-.855 2.589a.448.448 0 01-.556.278.393.393 0 01-.278-.3l-1.156-4.663-1.219 7.08a.449.449 0 01-.492.364c-.192-.021-.32-.17-.363-.363l-1.305-5.99-.706 1.69a.439.439 0 01-.406.278H7.679a.863.863 0 01-.748.428.88.88 0 01-.877-.877c.02-.47.406-.877.877-.877zM12 .396c6.973 0 12 5.369 12 11.615 0 6.353-4.77 11.593-12 11.593S0 18.364 0 12.011C-.02 5.765 5.005.396 12 .396zM4.064 12.01c0 4.256 3.658 8 7.915 8 4.256 0 7.914-3.744 7.914-8 0-4.6-3.658-8.043-7.914-8.043-4.236 0-7.915 3.444-7.915 8.043z
google	#4285F4	M12.48 10.92v3.28h7.84c-.24 1.84-.853 3.187-1.787 4.133-1.147 1.147-2.933 2.4-6.053 2.4-4.827 0-8.6-3.893-8.6-8.72s3.773-8.72 8.6-8.72c2.6 0 4.507 1.027 5.907 2.347l2.307-2.307C18.747 1.44 16.133 0 12.48 0 5.867 0 .307 5.387.307 12s5.56 12 12.173 12c3.573 0 6.267-1.173 8.373-3.36 2.16-2.16 2.84-5.213 2.84-7.667 0-.76-.053-1.467-.173-2.053H12.48z
LOGOEOF
}

# Сопоставление имени/домена сервиса слагу Simple Icons ("" -> без марки).
brand_slug_for() {
    local n
    n=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    n="${n%% (*}"
    n="${n%%/*}"
    n=$(printf '%s' "$n" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # Полные домены — до укорачивания: у части из них бренд не в первой метке.
    case "$n" in
        play.google.com)             echo googleplay; return ;;
        redirector.googlevideo.com|*.googlevideo.com) echo youtube; return ;;
        copilot.microsoft.com)       echo ""; return ;;
        # cloudflare.com у ipregion — это geo-эндпоинт speed.cloudflare.com,
        # такая же строка-источник, как ipinfo.io рядом. Марка там оставалась
        # единственной на всю группу GeoIP-баз и читалась как случайность.
        # У «Cloudflare CDN» — отдельная проверка сервиса — знак остаётся.
        cloudflare.com)              echo ""; return ;;
    esac

    # Служебные поддомены отбрасываем, иначе api.telegram.org читается как «api»,
    # а speed.cloudflare.com — как «speed».
    if [[ "$n" == *.* ]]; then
        n="${n#www.}"
        while [[ "$n" == *.*.* ]]; do
            case "${n%%.*}" in
                api|www|play|speed|cdn|app|apps|my|web|store|accounts|get|demo|rdap|db|redirector) n="${n#*.}" ;;
                *) break ;;
            esac
        done
        n="${n%%.*}"
    fi
    case "$n" in
        google|"google search captcha") echo google ;;
        youtube|"youtube premium"|"youtube cdn"|"youtube music"|youtubemusic) echo youtube ;;
        netflix|"netflix cdn") echo netflix ;;
        spotify|"spotify signup") echo spotify ;;
        chatgpt|openai) echo openai ;;
        twitch) echo twitch ;;
        reddit*) echo reddit ;;
        apple|"apple tv"|appletv) echo apple ;;
        steam) echo steam ;;
        tiktok) echo tiktok ;;
        cloudflare*) echo cloudflare ;;
        telegram) echo telegram ;;
        discord) echo discord ;;
        instagram) echo instagram ;;
        facebook) echo facebook ;;
        x|twitter) echo x ;;
        linkedin) echo linkedin ;;
        digitalocean) echo digitalocean ;;
        "google play"|googleplay) echo googleplay ;;
        patreon) echo patreon ;;
        swagger) echo swagger ;;
        snyk) echo snyk ;;
        mongodb) echo mongodb ;;
        autodesk) echo autodesk ;;
        redis) echo redis ;;
        amazonprimevideo|amazonpv|"amazon prime"|"amazon prime video"|"prime video"|amazon) echo primevideo ;;
        gmail) echo gmail ;;
        playstation) echo playstation ;;
        jetbrains) echo jetbrains ;;
        scaleway) echo scaleway ;;
        speedtest|ookla|"ookla speedtest") echo speedtest ;;
        intel) echo intel ;;
        amd) echo amd ;;
        github) echo github ;;
        graylog) echo graylog ;;
        gemini|"gemini supported"|"google gemini") echo googlegemini ;;
        *) echo "" ;;
    esac
}

# ============================================================
#  Парсеры вывода тестов -> .metrics / .services
#  .metrics:  label \t value \t colorkey(ok|bad|warn|pri|"")
#  .services: kind(chip|bar) \t name \t slug \t state(ok|bad|warn|na) \t value \t frac(0..1|-1)
# ============================================================

# Поля разделяем US (\x1f), а НЕ табом: таб — IFS-пробельный, и пустое поле
# (например, отсутствующий slug или slug у строк-шкал) при read «схлопывается»,
# сдвигая остальные поля. \x1f непробельный — пустые поля сохраняются.
mt_metric() { printf '%s\x1f%s\x1f%s\n' "$1" "$2" "${3:-}" >> "$MT_MFILE"; }
mt_service() { printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$1" "$2" "${3:-}" "${4:-na}" "${5:-}" "${6:--1}" >> "$MT_SFILE"; }

# Разбирает ячейку таблицы ipregion в «состояние<US>подпись».
# inv=1 переворачивает Yes/No: у «Google Search Captcha» ipregion считает
# хорошим ответ No (капчи нет) и красит его в цвет сервиса, а Yes — в красный.
# Все остальные Yes/No-проверки у него ровно наоборот, поэтому полярность
# приходится задавать снаружи, а не угадывать по значению.
ipregion_cell() {
    local v="$1" cons="$2" inv="${3:-0}" st val code
    case "$v" in
        -1|N/A|n/a|null|null*|"") st="na"; val="N/A" ;;
        Yes|yes) if [[ "$inv" == "1" ]]; then st="bad"; val="есть"; else st="ok"; val="да"; fi ;;
        No|no)   if [[ "$inv" == "1" ]]; then st="ok"; else st="bad"; fi; val="нет" ;;
        Denied|"Server error") st="bad"; val="$v" ;;
        Rate-limit|Rate-Limit) st="warn"; val="$v" ;;
        *)
            code="${v%% *}"   # ведущий код из "FR (CDG)"
            if [[ "$code" =~ ^[A-Z]{2}$ ]]; then
                if [[ -n "$cons" && "$code" != "$cons" ]]; then st="warn"; else st="ok"; fi
                val="$v"
            elif [[ "$code" =~ ^[A-Z]{3}$ ]]; then st="ok"; val="$v"
            else st="na"; val="$v"; fi
            ;;
    esac
    printf '%s\x1f%s' "$st" "$val"
}

parse_ipregion() {
    local txt="$1" rows cons4 cons6 asn nsvc ngeo match4 match6 has6 split
    # Хвост «Legend» отрезаем целиком. Там своя таблица — Code / Country / % IPv4, —
    # и по форме её строки неотличимы от сервисных: «DE  Germany  90%» проходило все
    # фильтры и приезжало на карточку сервисом «DE» со значением «Germany», а «Code
    # Country» — заголовком, притворившимся сервисом. Её же третья колонка включала
    # признак наличия IPv6, и на одностековом сервере подписи метрик получали суффикс
    # v4, которому не с чем было соседствовать.
    txt=$(printf '%s\n' "$txt" | sed -n '/^[[:space:]]*Legend[[:space:]]*$/q;p')
    # нормализуем разделители (табы/серии пробелов -> таб) и отсеиваем строки-спиннеры
    # ("Checking: ...") и прочий не-табличный мусор: имя сервиса короткое, без : / \
    # $1 ~ /^[A-Za-z0-9]/ — имя сервиса всегда начинается с буквы или цифры;
    # отсекает шапку самого multitest (">>> IP Region") и прочую отбивку,
    # которая иначе приезжала в таблицу отдельной строкой с N/A.
    rows=$(printf '%s\n' "$txt" | sed -E 's/\t/  /g; s/  +/\t/g' \
        | awk -F'\t' 'NF>=2 && $2!="" && $1!="Service" && $1 ~ /^[A-Za-z0-9]/ && length($1)<=30 && $1 !~ /[:\/\\]/ && tolower($1) !~ /checking|made with/' || true)

    # Третья колонка появляется, только если у сервера есть IPv6. Пустая или
    # сплошь N/A — значит стека нет, и всю v6-часть отчёта показывать незачем.
    has6=0
    printf '%s\n' "$rows" | awk -F'\t' 'NF>=3 && $3!="" && $3!="N/A" && $3!="-1" {f=1} END{exit !f}' && has6=1

    cons4=$(printf '%s\n' "$rows" | awk -F'\t' '$2 ~ /^[A-Z]{2}$/ {c[$2]++} END{m="";x=0;for(k in c)if(c[k]>x){x=c[k];m=k};print m}')
    cons6=$(printf '%s\n' "$rows" | awk -F'\t' '$3 ~ /^[A-Z]{2}$/ {c[$3]++} END{m="";x=0;for(k in c)if(c[k]>x){x=c[k];m=k};print m}')
    # cut -c резал байты и обрывал имя на полуслове без всякого знака, что оно
    # продолжается («AS218914 Datagio Syste»); vcut считает символы и ставит многоточие
    asn=$(printf '%s\n' "$txt" | grep -m1 -iE '^ASN:' | sed -E 's/^ASN:[[:space:]]*//I')
    [[ -n "$asn" ]] && asn=$(vcut "$asn" 32)
    # Считаем порознь: на карточке это и так два разных блока, а одно число на оба
    # («Сервисов 42») не отвечало ни на один вопрос, который к нему можно задать.
    nsvc=$(printf '%s\n' "$rows" | awk -F'\t' '$1 !~ /\./ {n++} END{print n+0}')
    ngeo=$(printf '%s\n' "$rows" | awk -F'\t' '$1 ~ /\./ {n++} END{print n+0}')
    match4=$(printf '%s\n' "$rows" | awk -F'\t' -v cc="$cons4" '$2~/^[A-Z]{2}$/{t++; if($2==cc)h++} END{if(t)printf "%d/%d",h+0,t}')
    match6=$(printf '%s\n' "$rows" | awk -F'\t' -v cc="$cons6" '$3~/^[A-Z]{2}$/{t++; if($3==cc)h++} END{if(t)printf "%d/%d",h+0,t}')
    # Сколько сервисов видят разные страны по v4 и по v6 — ради этого числа
    # двойной стек и проверяют: именно оно ловит утечку не туда.
    split=$(printf '%s\n' "$rows" | awk -F'\t' '$2~/^[A-Z]{2}/ && $3~/^[A-Z]{2}/ {
        split($2,a," "); split($3,b," "); if(a[1]!=b[1]) n++ } END{print n+0}')

    if [[ -n "$cons4" ]]; then
        # без второго стека «IPv4» в подписи не с чем соседствовать
        if [[ $has6 -eq 1 ]]; then mt_metric "Консенсус IPv4" "$cons4" "pri"
        else mt_metric "Консенсус" "$cons4" "pri"; fi
    fi
    [[ $has6 -eq 1 && -n "$cons6" ]] && mt_metric "Консенсус IPv6" "$cons6" "pri"
    [[ -n "$asn" ]] && mt_metric "ASN" "$asn" ""
    [[ "$nsvc" -gt 0 ]] && mt_metric "Сервисов" "$nsvc" ""
    [[ "$ngeo" -gt 0 ]] && mt_metric "GeoIP-баз" "$ngeo" ""
    if [[ $has6 -eq 1 ]]; then
        [[ -n "$match4" ]] && mt_metric "Совпадений v4" "$match4" "ok"
        [[ -n "$match6" ]] && mt_metric "Совпадений v6" "$match6" "ok"
        [[ "$split" -gt 0 ]] && mt_metric "v4≠v6" "$split" "bad"
    else
        [[ -n "$match4" ]] && mt_metric "Совпадений" "$match4" "ok"
    fi

    # Сначала сервисы, потом отбивка и GeoIP-базы. Различаем по точке в имени:
    # у ipregion потребительские сервисы названы словами (Netflix, Cloudflare CDN),
    # а базы — доменами (maxmind.com, ipinfo.io). У баз логотипов нет ни в одном
    # наборе иконок, и собранные в свою группу они читаются как раздел, а не как
    # строки, которым «забыли» марку.
    local pass
    for pass in services geo; do
    if [[ "$pass" == "geo" ]] && printf '%s\n' "$rows" | awk -F'\t' '$1 ~ /\./ {f=1} END{exit !f}'; then
        mt_service sep "GeoIP-базы" "" "" "" "-1"
    fi
    printf '%s\n' "$rows" | while IFS=$'\t' read -r name v4 v6 _; do
        [[ -z "$name" ]] && continue
        if [[ "$name" == *.* ]]; then [[ "$pass" == "geo" ]] || continue
        else [[ "$pass" == "services" ]] || continue; fi
        local st val st6 val6 inv=0
        # единственная проверка с обратной полярностью: капчи нет — это хорошо
        [[ "$name" == *"Search Captcha"* ]] && inv=1
        IFS=$'\x1f' read -r st val <<< "$(ipregion_cell "$v4" "$cons4" "$inv")"
        if [[ $has6 -eq 1 ]]; then
            IFS=$'\x1f' read -r st6 val6 <<< "$(ipregion_cell "$v6" "$cons6" "$inv")"
            # «N/A по v6» — обычное дело (у сервиса просто нет AAAA), это не
            # повод шуметь. А вот разные ответы по стекам показываем оба.
            if [[ "$st6" != "na" && "$val6" != "$val" ]]; then
                val="$val · $val6"
                if [[ "$st" == "bad" || "$st6" == "bad" ]]; then st="bad"
                else st="warn"; fi
            fi
        fi
        mt_service chip "$name" "$(brand_slug_for "$name")" "$st" "$val" "-1"
    done
    done
}

parse_censorcheck() {
    local txt="$1" avail blocked
    avail=$(printf '%s\n' "$txt" | grep -ciE 'Available|\bOK\b' || true)
    blocked=$(printf '%s\n' "$txt" | grep -ciE 'Blocked|Denied|timeout|connection reset' || true)
    [[ "$avail" -gt 0 ]] && mt_metric "Доступно" "$avail" "ok"
    [[ "$blocked" -gt 0 ]] && mt_metric "Заблокировано" "$blocked" "bad"
    printf '%s\n' "$txt" | grep -oiE '^[a-z0-9.-]+\.[a-z]{2,}.*' | while read -r line; do
        local dom rest st val
        dom=$(printf '%s' "$line" | grep -oE '^[a-z0-9.-]+\.[a-z]{2,}')
        [[ -z "$dom" ]] && continue
        rest=$(printf '%s' "$line" | sed -E "s#^$dom##")
        if printf '%s' "$rest" | grep -qiE 'Available|\bOK\b'; then st="ok"; val="доступен"
        elif printf '%s' "$rest" | grep -qiE 'Redirect'; then st="warn"; val="редирект"
        elif printf '%s' "$rest" | grep -qiE 'Blocked|Denied|timeout|reset|BLOCKED'; then st="bad"; val="блок"
        else st="na"; val="N/A"; fi
        mt_service chip "$dom" "$(brand_slug_for "$dom")" "$st" "$val" "-1"
    done
}

parse_iperf3() {
    local txt="$1" maxd minp cnt
    # строки вида "City   942.0 Mbps   610.0 Mbps   12 ms"
    local data; data=$(printf '%s\n' "$txt" | grep -E 'Mbps' | sed -E 's/\t/  /g' || true)
    maxd=$(printf '%s\n' "$data" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*Mbps' | grep -oE '[0-9]+(\.[0-9]+)?' | sort -gr | head -1)
    # запас: формат iperf3 Mbits/Gbits
    if [[ -z "$maxd" ]]; then
        maxd=$(printf '%s\n' "$txt" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*[MG]bits/sec' \
            | awk '{v=$1; if($0~/Gbit/)v*=1000; if(v>m)m=v} END{if(m)printf "%.0f", m}')
    fi
    minp=$(printf '%s\n' "$data" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*ms' | grep -oE '[0-9]+(\.[0-9]+)?' | sort -g | head -1)
    cnt=$(printf '%s\n' "$data" | grep -cE '[0-9]+(\.[0-9]+)?[[:space:]]*Mbps' || true)
    [[ -n "$maxd" ]] && mt_metric "Макс ↓" "${maxd} Mbps" "ok"
    [[ -n "$minp" ]] && mt_metric "Мин ping" "${minp} ms" "pri"
    [[ -n "$cnt" && "$cnt" -gt 0 ]] && mt_metric "Серверов" "$cnt" ""
    [[ -z "$maxd" ]] && return
    printf '%s\n' "$data" | while read -r line; do
        local city d u frac
        city=$(printf '%s' "$line" | sed -E 's/[[:space:]]{2,}.*//' | sed 's/[[:space:]]*$//')
        [[ -z "$city" ]] && continue
        printf '%s' "$line" | grep -qE '[0-9].*Mbps' || continue
        d=$(printf '%s' "$line" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*Mbps' | grep -oE '[0-9]+(\.[0-9]+)?' | sed -n '1p')
        u=$(printf '%s' "$line" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*Mbps' | grep -oE '[0-9]+(\.[0-9]+)?' | sed -n '2p')
        [[ -z "$d" ]] && continue
        frac=$(awk -v a="$d" -v b="$maxd" 'BEGIN{if(b>0)printf "%.3f", a/b; else print "0"}')
        mt_service bar "$city" "" "ok" "↓${d}${u:+ ↑$u}" "$frac"
    done
}

parse_yabs() {
    local txt="$1" cpu cores ram disk f4 f1 gs gm send
    cpu=$(printf '%s\n' "$txt" | grep -m1 -E '^Processor' | sed -E 's/^[^:]*:[[:space:]]*//' | cut -c1-26)
    cores=$(printf '%s\n' "$txt" | grep -m1 -E 'CPU cores' | grep -oE '[0-9]+' | head -1)
    ram=$(printf '%s\n' "$txt" | grep -m1 -E '^RAM' | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*[GM]iB' | head -1)
    disk=$(printf '%s\n' "$txt" | grep -m1 -E '^Disk' | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*[GT]iB' | head -1)
    # fio: две строки "Total" (4k|64k и 512k|1m), в каждой по два значения (лево|право)
    local _t1 _t2
    _t1=$(printf '%s\n' "$txt" | grep -E '^Total' | grep -E '[MG]B/s' | sed -n '1p')
    _t2=$(printf '%s\n' "$txt" | grep -E '^Total' | grep -E '[MG]B/s' | sed -n '2p')
    f4=$(printf '%s' "$_t1" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*[MG]B/s' | sed -n '1p')
    f1=$(printf '%s' "$_t2" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*[MG]B/s' | sed -n '2p')
    gs=$(printf '%s\n' "$txt" | awk '/Geekbench 6/{f=1} f&&/Single Core/{print $NF; exit}')
    gm=$(printf '%s\n' "$txt" | awk '/Geekbench 6/{f=1} f&&/Multi Core/{print $NF; exit}')
    if [[ -z "$gs" ]]; then gs=$(printf '%s\n' "$txt" | awk '/Geekbench 5/{f=1} f&&/Single Core/{print $NF; exit}'); gm=$(printf '%s\n' "$txt" | awk '/Geekbench 5/{f=1} f&&/Multi Core/{print $NF; exit}'); fi
    [[ -n "$cpu" ]] && mt_metric "CPU" "$cpu" ""
    [[ -n "$cores" ]] && mt_metric "Ядер" "$cores" ""
    [[ -n "$ram" ]] && mt_metric "RAM" "$ram" ""
    [[ -n "$disk" ]] && mt_metric "Диск" "$disk" ""
    [[ -n "$f4" ]] && mt_metric "fio 4k" "$f4" "pri"
    [[ -n "$f1" ]] && mt_metric "fio 1m" "$f1" "pri"
    [[ -n "$gs" ]] && mt_metric "GB6 single" "$gs" "ok"
    [[ -n "$gm" ]] && mt_metric "GB6 multi" "$gm" "ok"
    # iperf3 локации (recv для шкалы)
    local loc; loc=$(printf '%s\n' "$txt" | awk '/iperf3 Network Speed Tests/{f=1;next} /Geekbench|YABS completed/{f=0} f' | grep -E '\|' | grep -viE 'Provider|----' || true)
    local maxr; maxr=$(printf '%s\n' "$loc" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*[MG]bits/sec' | awk '{v=$1; if($0~/Gbit/)v*=1000; if(v>m)m=v} END{print m+0}')
    printf '%s\n' "$loc" | while IFS='|' read -r prov location send recv ping; do
        local name r rn frac
        name=$(printf '%s %s' "$prov" "$location" | sed -E 's/\(.*//; s/[[:space:]]+/ /g; s/^ //; s/ $//' | cut -c1-24)
        [[ -z "$(printf '%s' "$name" | tr -d ' ')" ]] && continue
        r=$(printf '%s' "$recv" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*[MG]bits/sec' | head -1)
        [[ -z "$r" ]] && continue
        rn=$(printf '%s' "$r" | grep -oE '[0-9]+(\.[0-9]+)?'); printf '%s' "$r" | grep -q Gbit && rn=$(awk -v v="$rn" 'BEGIN{print v*1000}')
        frac=$(awk -v a="$rn" -v b="$maxr" 'BEGIN{if(b>0)printf "%.3f", a/b; else print "0"}')
        mt_service bar "$name" "" "ok" "$(printf '%s' "$r" | sed 's/its\/sec//; s/[[:space:]]//g')" "$frac"
    done
}

parse_benchsh() {
    local txt="$1" cpu cores ram disk io org cc country
    cpu=$(printf '%s\n' "$txt" | grep -m1 -E 'CPU Model' | sed -E 's/^[^:]*:[[:space:]]*//' | cut -c1-26)
    cores=$(printf '%s\n' "$txt" | grep -m1 -E 'CPU Cores' | grep -oE '[0-9]+' | head -1)
    ram=$(printf '%s\n' "$txt" | grep -m1 -E 'Total RAM' | sed -E 's/^[^:]*:[[:space:]]*//' | awk '{print $1" "$2}')
    disk=$(printf '%s\n' "$txt" | grep -m1 -E 'Total Disk' | sed -E 's/^[^:]*:[[:space:]]*//' | awk '{print $1" "$2}')
    io=$(printf '%s\n' "$txt" | grep -m1 -iE 'I/O Speed\(average\)' | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*[MG]B/s' | head -1)
    org=$(printf '%s\n' "$txt" | grep -m1 -E 'Organization' | sed -E 's/^[^:]*:[[:space:]]*//' | cut -c1-24)
    country=$(printf '%s\n' "$txt" | grep -m1 -E '^[[:space:]]*Location' | sed -E 's#.*/[[:space:]]*##' | cut -c1-6)
    cc=$(printf '%s\n' "$txt" | grep -m1 -E 'TCP Congestion' | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '[:space:]')
    [[ -n "$cpu" ]] && mt_metric "CPU" "$cpu" ""
    [[ -n "$cores" ]] && mt_metric "Ядер" "$cores" ""
    [[ -n "$ram" ]] && mt_metric "RAM" "$ram" ""
    [[ -n "$disk" ]] && mt_metric "Диск" "$disk" ""
    [[ -n "$io" ]] && mt_metric "I/O сред." "$io" "pri"
    [[ -n "$cc" ]] && mt_metric "CC" "$cc" ""
    [[ -n "$org" ]] && mt_metric "Сеть" "$org" ""
    local nodes; nodes=$(printf '%s\n' "$txt" | grep -E ' Mbps' | grep -E ' ms' | sed -E 's/  +/\t/g' || true)
    local maxd; maxd=$(printf '%s\n' "$nodes" | awk -F'\t' '{print $3}' | grep -oE '[0-9]+(\.[0-9]+)?' | sort -gr | head -1)
    printf '%s\n' "$nodes" | while IFS=$'\t' read -r node up down lat _; do
        local nm d frac
        nm=$(printf '%s' "$node" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | cut -c1-24)
        [[ -z "$nm" ]] && continue
        d=$(printf '%s' "$down" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
        [[ -z "$d" ]] && continue
        frac=$(awk -v a="$d" -v b="$maxd" 'BEGIN{if(b>0)printf "%.3f", a/b; else print "0"}')
        mt_service bar "$nm" "" "ok" "↓${d}" "$frac"
    done
}

# Парсит секцию «Accessibility check for media and AI services» (транспонированная
# матрица Service:/Status:/Region:) и пишет строки-сервисы с логотипами.
# Скоупим на медиа-блок, иначе Region: подхватится из секции Risk Factors.
emit_media_services() {
    local txt="$1" mb
    mb=$(printf '%s\n' "$txt" | awk '/[Mm]edia and AI|Accessibility check/{f=1} f')
    [[ -z "$mb" ]] && return 1
    printf '%s\n' "$mb" | grep -qiE '^[[:space:]]*Service:' || return 1
    # Позиционное выравнивание: колонки берём из строки Service: и ими же режем
    # Status:/Region:. Устойчиво к пустым ячейкам (у заблокированных сервисов
    # нет региона) — простой split по индексу их бы сместил.
    printf '%s\n' "$mb" | awk '
      function trim(s){ gsub(/^[ \t\[]+|[ \t\]]+$/,"",s); return s }
      /^[[:space:]]*Service:/ && nsvc==0 {
        p=index($0,":"); n=0; inw=0;
        for(i=p+1;i<=length($0);i++){ c=substr($0,i,1);
          if(c!=" "){ if(!inw){ n++; cs[n]=i; inw=1 } } else { if(inw){ ce[n]=i-1; inw=0 } } }
        if(inw) ce[n]=length($0); nsvc=n;
        for(i=1;i<=nsvc;i++) nm[i]=trim(substr($0,cs[i],ce[i]-cs[i]+1));
      }
      /^[[:space:]]*Status:/ { for(i=1;i<=nsvc;i++){ e=(i<nsvc?cs[i+1]-1:length($0)); st[i]=(cs[i]<=length($0))?trim(substr($0,cs[i],e-cs[i]+1)):"" } }
      /^[[:space:]]*Region:/ { for(i=1;i<=nsvc;i++){ e=(i<nsvc?cs[i+1]-1:length($0)); rg[i]=(cs[i]<=length($0))?trim(substr($0,cs[i],e-cs[i]+1)):"" } }
      END { for(i=1;i<=nsvc;i++) if(nm[i]!="") printf "%s\x1f%s\x1f%s\n", nm[i], st[i], rg[i] }
    ' | while IFS=$'\x1f' read -r nm stt reg; do
        [[ -z "$nm" ]] && continue
        local state val
        # Частичный доступ разбираем ДО общих шаблонов, иначе его съедают они:
        # NoPrem. — это работающий YouTube без Premium, но начинается на No и
        # попадал в «блок». NF.Only — Netflix отдаёт только свои производства;
        # такой статус не совпадал ни с чем и уходил в «неизвестно», где от
        # него оставался один регион, как будто сервис доступен целиком.
        case "$stt" in
            NoPrem*|No.Prem*|NoPremium*) state="warn"; val="без Premium" ;;
            NF.Only*|NFOnly*|Only.NF*)   state="warn"; val="только оригиналы" ;;
            Yes*|Native*|Unlock*) state="ok"; [[ -z "$reg" || "$reg" == "-" ]] && val="да" || val="$reg" ;;
            Block*|No*|Failed*|Restricted*|Banned*) state="bad"; val="блок" ;;
            *) state="na"; [[ -z "$reg" || "$reg" == "-" ]] && val="?" || val="$reg" ;;
        esac
        mt_service chip "$nm" "$(brand_slug_for "$nm")" "$state" "$val" "-1"
    done
    return 0
}

# IP.Check.Place: акцент на медиа-разблокировке (с логотипами) + общий риск/DNSBL.
parse_ipcheck() {
    local txt="$1" risk media dnsbl port25 dbs
    risk=$(printf '%s\n' "$txt" | grep -m1 -iE 'Scamalytics' | grep -oiE 'VeryLow|Low|Medium|High|VeryHigh' | head -1)
    [[ -z "$risk" ]] && risk=$(printf '%s\n' "$txt" | grep -oiE 'VeryLow|Low|Medium|High|VeryHigh' | head -1)
    dbs=$(printf '%s\n' "$txt" | grep -oiE 'IP2Location|ipapi|ipregistry|IPQS|Scamalytics|ipdata|IPinfo|DB-?IP|AbuseIPDB' | sort -u | grep -c . || true)
    port25=$(printf '%s\n' "$txt" | grep -m1 -iE 'Port 25' | grep -oiE 'Blocked|Open|unreachable|закрыт|открыт' | head -1)
    dnsbl=$(printf '%s\n' "$txt" | grep -m1 -iE 'Blacklisted' | grep -oE 'Blacklisted[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | head -1)
    [[ -n "$risk" ]] && mt_metric "Риск" "$risk" "ok"
    [[ -n "$dbs" && "$dbs" -gt 0 ]] && mt_metric "Баз" "$dbs" ""
    [[ -n "$dnsbl" ]] && mt_metric "DNSBL" "$dnsbl" "$([[ "$dnsbl" == "0" ]] && echo ok || echo warn)"
    [[ -n "$port25" ]] && mt_metric "Port 25" "$port25" "warn"
    emit_media_services "$txt"
}

# Check.Place / IPQuality: акцент на типе IP (Usage/Company) и Risk Score по базам.
parse_ipquality() {
    local txt="$1" usage company geo
    # Тип IP: доминирующее значение в транспонированных строках Usage:/Company:
    usage=$(printf '%s\n' "$txt" | grep -m1 -iE '^[[:space:]]*Usage:' | sed -E 's/^[[:space:]]*Usage:[[:space:]]*//' \
        | sed -E 's/[[:space:]]{2,}/\n/g' | grep -vE '^[[:space:]]*$' | sort | uniq -c | sort -rn | head -1 | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]*//')
    company=$(printf '%s\n' "$txt" | grep -m1 -iE '^[[:space:]]*Company:' | sed -E 's/^[[:space:]]*Company:[[:space:]]*//' \
        | sed -E 's/[[:space:]]{2,}/\n/g' | grep -vE '^[[:space:]]*$' | sort | uniq -c | sort -rn | head -1 | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]*//')
    geo=$(printf '%s\n' "$txt" | grep -m1 -oE 'Geo-(consistent|discrepant)')
    [[ -n "$usage" ]] && mt_metric "Usage" "$usage" ""
    [[ -n "$company" ]] && mt_metric "Company" "$company" ""
    [[ -n "$geo" ]] && mt_metric "Гео" "${geo#Geo-}" "$([[ "$geo" == *consistent ]] && echo ok || echo warn)"
    # Risk Factors (секция 4): аноним-флаги, если хоть одна база отметила Yes
    local fac flagged=""
    for fac in Proxy VPN Tor; do
        printf '%s\n' "$txt" | grep -m1 -iE "^[[:space:]]*${fac}:" | grep -qiE '\bYes\b' && flagged="${flagged:+$flagged/}$fac"
    done
    if [[ -n "$flagged" ]]; then mt_metric "Аноним" "$flagged" "warn"; else
        printf '%s\n' "$txt" | grep -qiE '^[[:space:]]*(Proxy|VPN|Tor):' && mt_metric "Аноним" "нет" "ok"; fi
    # Port 25 / DNSBL (секция 6)
    local port25 dnsbl
    port25=$(printf '%s\n' "$txt" | grep -m1 -iE 'Port 25' | grep -oiE 'Available|Blocked|Open|unreachable')
    [[ -n "$port25" ]] && mt_metric "Port 25" "$([[ "$port25" =~ ^(Available|Open)$ ]] && echo открыт || echo закрыт)" "$([[ "$port25" =~ ^(Available|Open)$ ]] && echo ok || echo warn)"
    dnsbl=$(printf '%s\n' "$txt" | grep -m1 -iE 'Blacklisted' | grep -oE 'Blacklisted[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | head -1)
    [[ -n "$dnsbl" ]] && mt_metric "DNSBL" "$dnsbl" "$([[ "$dnsbl" == "0" ]] && echo ok || echo bad)"
    # Risk Score по базам -> строки-сервисы (значение «score · level», цвет по уровню)
    printf '%s\n' "$txt" | grep -E '^[[:space:]]*(IP2Location|Scamalytics|ipapi|AbuseIPDB|DB-?IP|IPQS):' | while read -r line; do
        local db rest score level st v
        db=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*([A-Za-z0-9-]+):.*/\1/')
        rest=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*[A-Za-z0-9-]+:[[:space:]]*//')  # после имени базы (в имени бывают цифры: IP2Location)
        score=$(printf '%s' "$rest" | grep -oE '[0-9]+(\.[0-9]+)?%?' | head -1)
        level=$(printf '%s' "$rest" | grep -oE 'VeryLow|VeryHigh|HighRisk|Elevated|Suspicious|Risky|Medium|High|Low' | tail -1)
        [[ -z "$level" && -z "$score" ]] && continue
        case "$level" in VeryLow|Low) st="ok";; Medium|Elevated) st="warn";; High|VeryHigh|HighRisk|Risky|Suspicious) st="bad";; *) st="na";; esac
        v="$level"; [[ -n "$score" && -n "$level" ]] && v="$score · $level"; [[ -z "$level" ]] && v="$score"
        mt_service chip "$db" "" "$st" "$v" "-1"
    done
    # --- разделитель + доступ к медиа/AI сервисам (с логотипами) ---
    if printf '%s\n' "$txt" | grep -qiE '^[[:space:]]*Service:'; then
        mt_service sep "Доступ к сервисам и AI" "" "" "" "-1"
        emit_media_services "$txt"
    fi
}

parse_sysbench() {
    local txt="$1" eps tev tt la l95
    eps=$(printf '%s\n' "$txt" | grep -m1 -iE 'events per second' | grep -oE '[0-9]+(\.[0-9]+)?' | tail -1)
    tev=$(printf '%s\n' "$txt" | grep -m1 -iE 'total events' | grep -oE '[0-9]+' | tail -1)
    tt=$(printf '%s\n' "$txt" | grep -m1 -iE 'total time' | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    la=$(printf '%s\n' "$txt" | grep -m1 -iE '^[[:space:]]*avg:' | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    l95=$(printf '%s\n' "$txt" | grep -m1 -iE '95th percentile' | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    [[ -n "$eps" ]] && mt_metric "events/s" "$eps" "ok"
    [[ -n "$tev" ]] && mt_metric "событий" "$tev" ""
    [[ -n "$tt" ]] && mt_metric "время" "${tt} s" ""
    [[ -n "$la" ]] && mt_metric "lat avg" "${la} ms" "pri"
    [[ -n "$l95" ]] && mt_metric "lat 95th" "${l95} ms" "pri"
}

# Диспетчер: читает лог, пишет .metrics/.services
parse_test_output() {
    local fn="$1" log="$2"
    MT_MFILE="$3"; MT_SFILE="$4"
    : > "$MT_MFILE"; : > "$MT_SFILE"
    [[ -f "$log" ]] || return 0
    local txt; txt=$(strip_ansi < "$log" | tr -d '\r')
    [[ -z "$txt" ]] && return 0
    case "$fn" in
        run_ip_region)                      parse_ipregion "$txt" ;;
        run_censorcheck_geoblock|run_censorcheck_dpi|run_censorcheck_tlab) parse_censorcheck "$txt" ;;
        run_iperf3_ru|run_iperf3_tlab)      parse_iperf3 "$txt" ;;
        run_yabs)                           parse_yabs "$txt" ;;
        run_bench_sh)                       parse_benchsh "$txt" ;;
        run_ip_check_place)                 parse_ipcheck "$txt" ;;
        run_ip_quality)                     parse_ipquality "$txt" ;;
        run_sysbench_cpu)                   parse_sysbench "$txt" ;;
    esac
}

# ============================================================
#  Рендер SVG-сводки («Server Scorecard»)
#
#  Оформление монохромное: один фон, одна поверхность карточки,
#  один волосяной контур, четыре ступени серого для текста.
#  Цвета нет вовсе — состояние несут слово и контраст:
#    норма    — приглушённый текст без плашки (не шумит);
#    внимание — текст в рамке;
#    ошибка   — инверсия (светлая плашка, тёмный текст): самое
#               заметное пятно на карточке достаётся тому
#               единственному, что требует реакции.
# ============================================================

sv() { SVG_BODY="${SVG_BODY}$1"$'\n'; }
sv_esc() { printf '%s' "$1" | xml_escape; }

# Длина строки В СИМВОЛАХ независимо от локали. В C/POSIX (а это типичная локаль
# для `wget|bash`) ${#s} считает БАЙТЫ, и кириллица меряется ×2 — отсюда «съезжал»
# весь текст. Убираем UTF-8 continuation-байты (0x80-0xBF) — остаётся по байту на символ.
vlen() { local c="${1//[$'\x80'-$'\xbf']/}"; echo "${#c}"; }

# Обрезка до N символов. По той же причине `cut -c` не годится: он режет байты
# и рвёт кириллическую букву пополам. Считаем ведущие байты вручную.
vcut() {
    local s="$1" n="$2" out="" i c cnt=0
    (( $(vlen "$s") <= n )) && { printf '%s' "$s"; return; }
    for (( i=0; i<${#s}; i++ )); do
        c="${s:$i:1}"
        [[ "$c" == [$'\x80'-$'\xbf'] ]] || cnt=$((cnt+1))
        (( cnt > n )) && break
        out+="$c"
    done
    printf '%s…' "${out%.}"
}

# Марка сервиса (Simple Icons) — монохромом и без плашки-подложки.
# Пути нет — не рисуем ничего: имя стоит рядом и говорит всё само.
sv_mark() {
    local x="$1" y="$2" sz="$3" slug="$4" col="${5:-$C_MARK}" d=""
    [[ -n "$slug" ]] && d="${LOGO_PATH[$slug]:-}"
    [[ -z "$d" ]] && return 0
    local scl; scl=$(awk "BEGIN{printf \"%.4f\", $sz/24}")
    sv "<g transform=\"translate($x,$y) scale($scl)\"><path d=\"$d\" fill=\"$col\"/></g>"
}

# --- ЭКСПЕРИМЕНТ: «стена марок» -----------------------------------------
# Сервисы, у которых есть фирменная марка, выкладываются плитками вместо
# строк: знак крупнее, состояние читается заливкой плитки, и глаз находит
# заблокированное одним движением. Остальные (GeoIP-базы, шкалы скорости)
# остаются строками. MT_BRAND_WALL=0 возвращает прежний вид целиком.
MT_BRAND_WALL="${MT_BRAND_WALL:-1}"
WALL_COLS=6

# Плитка бренда: x y w h slug name state value
sv_brand_tile() {
    local x="$1" y="$2" w="$3" h="$4" slug="$5" nm="$6" st="$7" val="$8"
    local fill="$C_SCH" stroke="" mark="$C_MARK" tx="$C_TXT" vx="$C_TXT2"
    case "$st" in
        bad)  fill="$C_INV"; mark="$C_INK"; tx="$C_INK"; vx="#4A4A4A" ;;
        warn) stroke=" stroke=\"$C_LINE2\" stroke-width=\"1\"" ;;
        na)   fill="none"; stroke=" stroke=\"$C_LINE\" stroke-width=\"1\""
              mark="$C_TXT3"; tx="$C_TXT3"; vx="$C_TXT3" ;;
    esac
    sv "<rect x=\"$x\" y=\"$y\" width=\"$w\" height=\"$h\" rx=\"2\" fill=\"$fill\"$stroke/>"
    sv_mark "$((x + w/2 - 13))" "$((y+15))" 26 "$slug" "$mark"
    sv "<text x=\"$((x+w/2))\" y=\"$((y+62))\" text-anchor=\"middle\" fill=\"$tx\" font-size=\"11\">$(sv_esc "$(vcut "$nm" 23)")</text>"
    sv "<text x=\"$((x+w/2))\" y=\"$((y+80))\" text-anchor=\"middle\" fill=\"$vx\" font-size=\"11.5\" font-weight=\"600\">$(sv_esc "$val")</text>"
}

# Выкладывает накопленный сегмент: сперва стена плиток, затем строки.
# Работает через RS_* — один и тот же код меряет высоту и рисует.
rs_flush() {
    local n=${#RS_WALL[@]} i col row bx TW TH=92
    local kind name slug stt val frac
    TW=$(( (CARDW - 2*IPAD - (WALL_COLS-1)*8) / WALL_COLS ))
    # Стена из одной-двух плиток — не стена, а сирота посреди списка
    # (так выглядел cloudflare.com среди GeoIP-баз). Меньше четырёх — строками.
    if (( n > 0 && n < 4 )); then
        local -a demoted=()
        for ((i=0; i<n; i++)); do
            IFS=$'\x1f' read -r slug name stt val <<< "${RS_WALL[$i]}"
            demoted+=( "chip"$'\x1f'"$name"$'\x1f'"$slug"$'\x1f'"$stt"$'\x1f'"$val"$'\x1f'"-1" )
        done
        RS_ROWS=( "${demoted[@]}" ${RS_ROWS[@]+"${RS_ROWS[@]}"} )
        RS_WALL=(); n=0
    fi
    if (( n > 0 )); then
        for ((i=0; i<n; i++)); do
            [[ "$RS_DRAW" == "1" ]] || break
            col=$(( i % WALL_COLS )); row=$(( i / WALL_COLS ))
            IFS=$'\x1f' read -r slug name stt val <<< "${RS_WALL[$i]}"
            sv_brand_tile $(( PAD+IPAD + col*(TW+8) )) $(( RS_CY + row*(TH+8) )) "$TW" "$TH" "$slug" "$name" "$stt" "$val"
        done
        RS_CY=$(( RS_CY + ((n + WALL_COLS - 1)/WALL_COLS)*(TH+8) ))
        (( ${#RS_ROWS[@]} > 0 )) && RS_CY=$(( RS_CY + 6 ))
    fi
    col=0
    for ((i=0; i<${#RS_ROWS[@]}; i++)); do
        IFS=$'\x1f' read -r kind name slug stt val frac <<< "${RS_ROWS[$i]}"
        (( col==0 )) && bx=$sx1 || bx=$sx2
        if [[ "$RS_DRAW" == "1" ]]; then
            if [[ "$kind" == "bar" ]]; then sv_row_bar "$bx" "$RS_CY" "$colw" "$name" "${frac:-0}" "$val"
            else sv_row_chip "$bx" "$RS_CY" "$colw" "$slug" "$name" "$stt" "$val"; fi
        fi
        if (( col==1 )); then RS_CY=$((RS_CY+32)); col=0; else col=1; fi
    done
    (( col==1 )) && RS_CY=$((RS_CY+32))
    RS_WALL=(); RS_ROWS=()
}

# Вердикт у правого края xr: xr y state text
sv_vchip() {
    local xr="$1" y="$2" st="$3" t="$4" w
    case "$st" in
        bad)
            w=$(( ($(vlen "$t")*72)/10 + 22 ))
            sv "<rect x=\"$((xr-w))\" y=\"$y\" width=\"$w\" height=\"20\" rx=\"2\" fill=\"$C_INV\"/>"
            sv "<text x=\"$((xr-w/2))\" y=\"$((y+14))\" text-anchor=\"middle\" fill=\"$C_INK\" font-size=\"11.5\" font-weight=\"600\">$(sv_esc "$t")</text>" ;;
        warn)
            w=$(( ($(vlen "$t")*72)/10 + 22 ))
            sv "<rect x=\"$((xr-w))\" y=\"$y\" width=\"$w\" height=\"20\" rx=\"2\" fill=\"none\" stroke=\"$C_LINE2\" stroke-width=\"1\"/>"
            sv "<text x=\"$((xr-w/2))\" y=\"$((y+14))\" text-anchor=\"middle\" fill=\"$C_TXT\" font-size=\"11.5\">$(sv_esc "$t")</text>" ;;
        ok)
            sv "<text x=\"$xr\" y=\"$((y+14))\" text-anchor=\"end\" fill=\"$C_TXT2\" font-size=\"12\">$(sv_esc "$t")</text>" ;;
        *)
            sv "<text x=\"$xr\" y=\"$((y+14))\" text-anchor=\"end\" fill=\"$C_TXT3\" font-size=\"12\">$(sv_esc "$t")</text>" ;;
    esac
}

# строка-сервис с вердиктом: x y colw slug name state value (высота строки 32)
sv_row_chip() {
    local x="$1" y="$2" cw="$3" slug="$4" nm="$5" st="$6" val="$7"
    sv_mark "$x" "$((y+7))" 16 "$slug"
    sv "<text x=\"$((x+26))\" y=\"$((y+20))\" fill=\"$C_TXT\" font-size=\"13.5\">$(sv_esc "$nm")</text>"
    sv_vchip $((x+cw)) $((y+6)) "$st" "$val"
}

# строка-сервис со шкалой: x y colw name frac value (высота строки 32).
# Длина полосы и есть данные — красить её нечем и незачем.
sv_row_bar() {
    local x="$1" y="$2" cw="$3" nm="$4" fr="$5" val="$6"
    sv "<text x=\"$x\" y=\"$((y+13))\" fill=\"$C_TXT\" font-size=\"13\">$(sv_esc "$nm")</text>"
    sv "<text x=\"$((x+cw))\" y=\"$((y+13))\" text-anchor=\"end\" fill=\"$C_TXT2\" font-size=\"12.5\">$(sv_esc "$val")</text>"
    local fw; fw=$(awk "BEGIN{w=$cw*$fr; if(w<2)w=2; if(w>$cw)w=$cw; print int(w)}")
    sv "<rect x=\"$x\" y=\"$((y+20))\" width=\"$cw\" height=\"4\" fill=\"$C_TRACK\"/>"
    sv "<rect x=\"$x\" y=\"$((y+20))\" width=\"$fw\" height=\"4\" fill=\"$C_MARK\"/>"
}

# Ширина половинок метрики-чипа: подпись 11px, значение 13px.
mc_lw() { echo $(( ($(vlen "$1")*67)/10 + 22 )); }
mc_vw() { echo $(( ($(vlen "$1")*76)/10 + 24 )); }
sv_chipw() { echo $(( $(mc_lw "$1") + $(mc_vw "$2") )); }

# метрика-чип: x y label value colorkey
sv_mchip() {
    local x="$1" y="$2" l="$3" v="$4" ck="$5"
    local lw vw cw; lw=$(mc_lw "$l"); vw=$(mc_vw "$v"); cw=$((lw+vw))
    local bg="$C_SCH" lc="$C_TXT2" vc="$C_TXT" dv="$C_LINE2" so=""
    case "$ck" in
        bad)  bg="$C_INV"; lc="#4A4A4A"; vc="$C_INK"; dv="#B8B8B8" ;;
        warn) so=" stroke=\"$C_LINE2\" stroke-width=\"1\"" ;;
    esac
    sv "<rect x=\"$x\" y=\"$y\" width=\"$cw\" height=\"30\" rx=\"2\" fill=\"$bg\"$so/>"
    sv "<line x1=\"$((x+lw))\" y1=\"$((y+6))\" x2=\"$((x+lw))\" y2=\"$((y+24))\" stroke=\"$dv\" stroke-width=\"1\"/>"
    sv "<text x=\"$((x+lw/2))\" y=\"$((y+19))\" text-anchor=\"middle\" fill=\"$lc\" font-size=\"11\">$(sv_esc "$l")</text>"
    sv "<text x=\"$((x+lw+vw/2))\" y=\"$((y+19))\" text-anchor=\"middle\" fill=\"$vc\" font-size=\"13\" font-weight=\"600\">$(sv_esc "$v")</text>"
}

# Статус теста у правого края. «Выполнен» — ожидаемый исход, ему хватает
# приглушённой подписи; рамка и инверсия достаются тому, что пошло не так.
sv_status_chip() {
    local xr="$1" y="$2" st="$3" t w
    case "$st" in
        done) sv "<text x=\"$xr\" y=\"$((y+15))\" text-anchor=\"end\" fill=\"$C_TXT3\" font-size=\"12\">выполнен</text>"; return ;;
        skip) t="пропущен" ;;
        err)  t="ошибка" ;;
        *)    t="не запускался" ;;
    esac
    w=$(( ($(vlen "$t")*72)/10 + 24 ))
    if [[ "$st" == "err" ]]; then
        sv "<rect x=\"$((xr-w))\" y=\"$y\" width=\"$w\" height=\"22\" rx=\"2\" fill=\"$C_INV\"/>"
        sv "<text x=\"$((xr-w/2))\" y=\"$((y+15))\" text-anchor=\"middle\" fill=\"$C_INK\" font-size=\"12\" font-weight=\"600\">$t</text>"
    else
        sv "<rect x=\"$((xr-w))\" y=\"$y\" width=\"$w\" height=\"22\" rx=\"2\" fill=\"none\" stroke=\"$C_LINE2\" stroke-width=\"1\"/>"
        sv "<text x=\"$((xr-w/2))\" y=\"$((y+15))\" text-anchor=\"middle\" fill=\"$C_TXT2\" font-size=\"12\">$t</text>"
    fi
}

# Раскладка строк-сервисов в 2 колонки с поддержкой разделителей (kind=sep).
# Аргументы: sfile, sy(старт Y), draw(0|1). Возвращает итоговый Y (echo) —
# одна и та же логика для предпрохода (высота) и отрисовки.
render_services() {
    local sfile="$1" sy="$2" draw="$3"
    local kind name slug stt val frac
    RS_CY=$sy; RS_DRAW="$draw"; RS_WALL=(); RS_ROWS=()
    while IFS=$'\x1f' read -r kind name slug stt val frac; do
        [[ -z "$kind" ]] && continue
        if [[ "$kind" == "sep" ]]; then
            rs_flush          # sep режет сегменты: перенос марок через него сломал бы смысл
            if [[ "$draw" == "1" ]]; then
                RS_CY=$((RS_CY+16))
                sv "<line x1=\"$sx1\" y1=\"$RS_CY\" x2=\"$((PAD+CARDW-IPAD))\" y2=\"$RS_CY\" stroke=\"$C_LINE\" stroke-width=\"1\"/>"
                [[ -n "$name" ]] && sv "<text x=\"$sx1\" y=\"$((RS_CY+24))\" fill=\"$C_TXT2\" font-size=\"11\" letter-spacing=\"1\">$(sv_esc "$name")</text>"
                RS_CY=$((RS_CY+34))
            else
                RS_CY=$((RS_CY+50))
            fi
            continue
        fi
        if [[ "$MT_BRAND_WALL" == "1" && "$kind" == "chip" && -n "$slug" && -n "${LOGO_PATH[$slug]:-}" ]]; then
            RS_WALL+=( "$slug"$'\x1f'"$name"$'\x1f'"$stt"$'\x1f'"$val" )
        else
            RS_ROWS+=( "$kind"$'\x1f'"$name"$'\x1f'"$slug"$'\x1f'"$stt"$'\x1f'"$val"$'\x1f'"$frac" )
        fi
    done < "$sfile"
    rs_flush
    echo "$RS_CY"
}

# Палитра и геометрия карточки. Раньше это были local внутри build_summary_svg,
# и вложенные sv_* видели их по динамической области видимости. Страниц у сводки
# теперь несколько и рисуют их разные функции — общий набор вынесен в глобальные,
# иначе каждая страница тащила бы копию шкалы.
mt_style_init() {
    C_BG="#0A0A0A"; C_SC="#131313"; C_SCH="#202020"; C_TRACK="#2E2E2E"
    C_LINE="#262626"; C_LINE2="#3D3D3D"
    C_TXT="#F2F2F2"; C_TXT2="#9C9C9C"; C_TXT3="#757575"; C_FOOT="#545454"
    C_INV="#E6E6E6"; C_INK="#0A0A0A"; C_MARK="#C6C6C6"
    C_AD="#875FFF"
    W=1100; PAD=32; IPAD=28; CARDW=$((W-2*PAD))
    # колонки блока сервисов — их читают rs_flush/render_services
    colw=$(( (CARDW-2*IPAD-32)/2 ))
    sx1=$((PAD+IPAD))
    sx2=$((PAD+IPAD+(CARDW-2*IPAD-32)/2+32))
    load_logos
}

# Кто попал в прогон (по странице на тест), а кого не выбирали (сноска на обложке).
mt_album_plan() {
    MT_PAGE_IDX=(); MT_OFF_NAMES=()
    local idx fn
    for idx in "${!MT_CAT_FUNCS[@]}"; do
        fn="${MT_CAT_FUNCS[$idx]}"
        if [[ -n "${MT_STATUS[$fn]:-}" ]]; then
            MT_PAGE_IDX+=( "$idx" )
        else
            MT_OFF_NAMES+=( "${MT_CAT_NAMES[$idx]}" )
        fi
    done
}

# Счётчики прогона (только выбранные тесты) -> MT_DONE / MT_SKIP / MT_ERR / MT_TOT.
mt_run_counters() {
    MT_DONE=0; MT_SKIP=0; MT_ERR=0; MT_TOT=0
    local fn st
    for fn in "${MT_CAT_FUNCS[@]}"; do
        st="${MT_STATUS[$fn]:-}"; [[ -z "$st" ]] && continue
        MT_TOT=$((MT_TOT+1))
        case "$st" in
            выполнен) MT_DONE=$((MT_DONE+1)) ;;
            ошибка)   MT_ERR=$((MT_ERR+1)) ;;
            *)        MT_SKIP=$((MT_SKIP+1)) ;;
        esac
    done
    (( MT_TOT == 0 )) && MT_TOT=1
}

# Строка идентификации сервера: замаскированные адреса, гео, дата.
# Она нужна на КАЖДОЙ странице альбома: из альбома пересылают по одной картинке,
# и страница без неё уезжает в чужой чат как результат неизвестно чьего сервера.
mt_ident_line() {
    local ip4 ip6 ip
    ip4=$(mask_ip "$SYS_IP4"); ip6=$(mask_ip "$SYS_IP6")
    ip="$ip4${ip4:+${ip6:+ · }}$ip6"; [[ -n "$ip" ]] || ip="—"
    printf '%s · %s/%s · %s' "$ip" "$SYS_COUNTRY" "$SYS_CITY" "$(date '+%Y-%m-%d %H:%M')"
}

# Шапка обложки: логотип, подпись, идентификация и крупная дробь «выполнено».
# Возвращает Y под шапкой в MT_Y.
sv_head_full() {
    local Y="$1" xr=$((PAD+CARDW))
    sv "<text x=\"$PAD\" y=\"$((Y+28))\" fill=\"$C_TXT\" font-size=\"26\" font-weight=\"600\" letter-spacing=\"3\">MULTITEST</text>"
    sv "<text x=\"$PAD\" y=\"$((Y+52))\" fill=\"$C_TXT2\" font-size=\"13\">Сводка диагностики сервера · v${SCRIPT_VERSION}</text>"
    sv "<text x=\"$PAD\" y=\"$((Y+74))\" fill=\"$C_TXT3\" font-size=\"12.5\">$(sv_esc "$(mt_ident_line)")</text>"
    # главное число сводки — крупнее логотипа: это и есть результат прогона
    sv "<text x=\"$xr\" y=\"$((Y+38))\" text-anchor=\"end\" fill=\"$C_TXT\" font-size=\"40\" font-weight=\"700\">${MT_DONE}/${MT_TOT}</text>"
    sv "<text x=\"$xr\" y=\"$((Y+58))\" text-anchor=\"end\" fill=\"$C_TXT3\" font-size=\"10.5\" letter-spacing=\"1.4\">ВЫПОЛНЕНО</text>"
    local extra=""
    (( MT_SKIP > 0 )) && extra="пропущено: $MT_SKIP"
    (( MT_ERR  > 0 )) && extra="${extra:+$extra · }с ошибкой: $MT_ERR"
    [[ -n "$extra" ]] && sv "<text x=\"$xr\" y=\"$((Y+80))\" text-anchor=\"end\" fill=\"$C_TXT3\" font-size=\"12\">$extra</text>"
    MT_Y=$((Y+96))
}

# Шапка страницы теста: та же идентификация, но в одну полосу — на странице
# главное сама карточка, шапка тут только чтобы картинка не потеряла хозяина.
sv_head_slim() {
    local Y="$1" xr=$((PAD+CARDW))
    sv "<text x=\"$PAD\" y=\"$((Y+20))\" fill=\"$C_TXT\" font-size=\"17\" font-weight=\"600\" letter-spacing=\"2.4\">MULTITEST</text>"
    sv "<text x=\"$PAD\" y=\"$((Y+42))\" fill=\"$C_TXT3\" font-size=\"12\">$(sv_esc "$(mt_ident_line)")</text>"
    sv "<text x=\"$xr\" y=\"$((Y+22))\" text-anchor=\"end\" fill=\"$C_TXT\" font-size=\"20\" font-weight=\"700\">${MT_PAGE_I} / ${MT_PAGE_N}</text>"
    sv "<text x=\"$xr\" y=\"$((Y+42))\" text-anchor=\"end\" fill=\"$C_TXT3\" font-size=\"10.5\" letter-spacing=\"1.4\">СТРАНИЦА</text>"
    # линейки-разделителя нет: под шапкой идёт плашка спонсора, и её рамка
    # отбивает колонтитул сама — по той же причине, что и на обложке
    MT_Y=$((Y+66))
}

# Марка спонсора: x y высота. Ширина считается по пропорции контура.
sv_ad_logo() {
    local x="$1" y="$2" h="$3"
    local scl; scl=$(awk "BEGIN{printf \"%.5f\", $h/$AD_LOGO_H}")
    sv "<g transform=\"translate($x,$y) scale($scl)\"><path d=\"$AD_LOGO_PATH\" fill=\"$C_TXT\" fill-rule=\"evenodd\"/></g>"
}

# Баннер спонсора (встаёт на место линейки-разделителя шапки: рамка блока сама
# отбивает колонтитул от карточек, вторая линия рядом шумит). Слева внутри
# плашки — марка: она заняла место прежней вертикальной полоски-акцента,
# которая была ровно тем же «здесь начинается блок», только без имени.
sv_banner() {
    local Y="$1" ADH=42 LH=28
    sv "<rect x=\"$PAD\" y=\"$Y\" width=\"$CARDW\" height=\"$ADH\" rx=\"6\" fill=\"$C_SC\" stroke=\"$C_AD\" stroke-width=\"2\"/>"
    sv_ad_logo $((PAD+13)) $((Y+(ADH-LH)/2)) "$LH"
    sv "<text x=\"$((PAD+CARDW/2))\" y=\"$((Y+27))\" text-anchor=\"middle\" fill=\"$C_TXT\" font-size=\"14\" font-weight=\"700\" letter-spacing=\"1.5\">$(sv_esc "$AD_TEXT")</text>"
    MT_Y=$((Y+ADH+26))
}

# Карточка «Сервер» (label|value; подписи сразу заглавными — локале-прочно).
sv_card_server() {
    local Y="$1"
    local ip4_disp ip6_disp
    ip4_disp=$(mask_ip "$SYS_IP4"); ip6_disp=$(mask_ip "$SYS_IP6")
    local -a SF=( "CPU|$SYS_CPU · $SYS_CORES ядер" "RAM|$SYS_RAM" "ДИСК|$SYS_DISK" \
        "ОС|$SYS_OS" "ЯДРО|$SYS_KERNEL" "VIRT|$SYS_VIRT" "IPv4|${ip4_disp:-—}" )
    [[ -n "$ip6_disp" ]] && SF+=( "IPv6|$ip6_disp" )
    SF+=( "ГЕО|$SYS_COUNTRY / $SYS_CITY" "ASN|$SYS_ASN" "BBR / QDISC|$SYS_CC / $SYS_QDISC" \
        "UPTIME|$SYS_UPTIME" "LOAD AVG|$SYS_LOAD" )
    local SR=$(( (${#SF[@]}+1)/2 )) SH
    SH=$(( 66 + SR*30 + 14 ))
    sv "<rect x=\"$PAD\" y=\"$Y\" width=\"$CARDW\" height=\"$SH\" rx=\"6\" fill=\"$C_SC\" stroke=\"$C_LINE\" stroke-width=\"1\"/>"
    sv "<text x=\"$((PAD+IPAD))\" y=\"$((Y+34))\" fill=\"$C_TXT\" font-size=\"19\" font-weight=\"700\">Сервер</text>"
    sv "<line x1=\"$((PAD+IPAD))\" y1=\"$((Y+52))\" x2=\"$((PAD+CARDW-IPAD))\" y2=\"$((Y+52))\" stroke=\"$C_LINE\" stroke-width=\"1\"/>"
    local c1=$((PAD+IPAD)) c2=$((PAD+IPAD+(CARDW-2*IPAD)/2)) ry=$((Y+66)) i lbl val cx
    for i in "${!SF[@]}"; do
        lbl="${SF[$i]%%|*}"; val="${SF[$i]#*|}"
        if ((i%2==0)); then cx=$c1; else cx=$c2; fi
        sv "<text x=\"$cx\" y=\"$((ry+20))\" fill=\"$C_TXT2\" font-size=\"11\" letter-spacing=\"0.7\">$(sv_esc "$lbl")</text>"
        sv "<text x=\"$((cx+104))\" y=\"$((ry+20))\" fill=\"$C_TXT\" font-size=\"14\">$(sv_esc "$(vcut "$val" 46)")</text>"
        ((i%2==1)) && ry=$((ry+30))
    done
    MT_Y=$((Y+SH+30))
}

# Оглавление альбома: тест — его страница — его статус. Только на обложке и
# только в альбоме: в одной длинной картинке карточки идут следом, и список
# перед ними дублировал бы сам себя.
sv_card_toc() {
    local Y="$1" n=${#MT_PAGE_IDX[@]}
    (( n > 0 )) || { MT_Y=$Y; return 0; }
    local SR=$(( (n+1)/2 )) SH
    SH=$(( 66 + SR*30 + 14 ))
    sv "<rect x=\"$PAD\" y=\"$Y\" width=\"$CARDW\" height=\"$SH\" rx=\"6\" fill=\"$C_SC\" stroke=\"$C_LINE\" stroke-width=\"1\"/>"
    sv "<text x=\"$((PAD+IPAD))\" y=\"$((Y+34))\" fill=\"$C_TXT\" font-size=\"19\" font-weight=\"700\">Тесты</text>"
    sv "<text x=\"$((PAD+CARDW-IPAD))\" y=\"$((Y+33))\" text-anchor=\"end\" fill=\"$C_TXT3\" font-size=\"12\">страниц в альбоме: ${MT_PAGE_N}</text>"
    sv "<line x1=\"$((PAD+IPAD))\" y1=\"$((Y+52))\" x2=\"$((PAD+CARDW-IPAD))\" y2=\"$((Y+52))\" stroke=\"$C_LINE\" stroke-width=\"1\"/>"
    local tw=$(( (CARDW-2*IPAD)/2 )) ry=$((Y+66)) i idx fn st sstate cx
    for i in "${!MT_PAGE_IDX[@]}"; do
        idx="${MT_PAGE_IDX[$i]}"; fn="${MT_CAT_FUNCS[$idx]}"; st="${MT_STATUS[$fn]:-}"
        case "$st" in выполнен) sstate="done";; ошибка) sstate="err";; *) sstate="skip";; esac
        if ((i%2==0)); then cx=$((PAD+IPAD)); else cx=$((PAD+IPAD+tw)); fi
        sv "<text x=\"$cx\" y=\"$((ry+20))\" fill=\"$C_TXT3\" font-size=\"12\">$(printf '%02d' $((i+2)))</text>"
        sv "<text x=\"$((cx+30))\" y=\"$((ry+20))\" fill=\"$C_TXT\" font-size=\"13.5\">$(sv_esc "$(vcut "${MT_CAT_NAMES[$idx]}" 26)")</text>"
        sv_status_chip $((cx+tw-16)) $((ry+2)) "$sstate"
        ((i%2==1)) && ry=$((ry+30))
    done
    MT_Y=$((Y+SH+30))
}

# Сноска «не запускались»: пустая карточка на каждый невыбранный тест — трата места.
sv_offnames() {
    local Y="$1" n=${#MT_OFF_NAMES[@]}
    (( n > 0 )) || { MT_Y=$Y; return 0; }
    Y=$((Y+10))
    sv "<line x1=\"$PAD\" y1=\"$Y\" x2=\"$((PAD+CARDW))\" y2=\"$Y\" stroke=\"$C_LINE\" stroke-width=\"1\"/>"
    sv "<text x=\"$PAD\" y=\"$((Y+24))\" fill=\"$C_TXT3\" font-size=\"11\" letter-spacing=\"1.2\">НЕ ЗАПУСКАЛИСЬ</text>"
    local oy=$((Y+50)) oi ox
    for oi in "${!MT_OFF_NAMES[@]}"; do
        ox=$PAD; ((oi%2==1)) && ox=$((PAD+CARDW/2))
        sv "<text x=\"$ox\" y=\"$oy\" fill=\"$C_TXT3\" font-size=\"13\">$(sv_esc "${MT_OFF_NAMES[$oi]}")</text>"
        ((oi%2==1)) && oy=$((oy+24))
    done
    (( n%2==1 )) && oy=$((oy+24))
    MT_Y=$((oy-4))
}

# Карточка одного теста. Высоту отдаёт в CARD_H, а не через echo: рисование
# внутри $(...) ушло бы в подоболочку вместе с накопленным SVG_BODY.
# draw=0 — только померить, draw=1 — померить и нарисовать.
sv_test_card() {
    local idx="$1" Y="$2" draw="$3"
    local fn="${MT_CAT_FUNCS[$idx]}" nm="${MT_CAT_NAMES[$idx]}"
    local st="${MT_STATUS[$fn]:-}" sstate
    case "$st" in выполнен) sstate="done";; ошибка) sstate="err";; *) sstate="skip";; esac
    local mfile="$SUMMARY_DIR/$fn.metrics" sfile="$SUMMARY_DIR/$fn.services"
    local kv rest l v ck w

    # метрики -> позиции чипов (предварительный проход)
    local -a ML=(); local nmet=0
    if [[ "$sstate" == "done" && -s "$mfile" ]]; then
        while IFS=$'\x1f' read -r l v ck; do [[ -z "$l" ]] && continue; ML+=( "$l|$v|$ck" ); done < "$mfile"
        nmet=${#ML[@]}
    fi
    local chip_rows=0 cx=$IPAD
    if [[ $nmet -gt 0 ]]; then chip_rows=1
        for kv in "${ML[@]}"; do
            l="${kv%%|*}"; rest="${kv#*|}"; v="${rest%%|*}"
            w=$(sv_chipw "$l" "$v")
            if (( cx > IPAD && cx + w > CARDW - IPAD )); then chip_rows=$((chip_rows+1)); cx=$IPAD; fi
            cx=$((cx + w + 8))
        done
    fi
    local nsvc=0
    [[ "$sstate" == "done" && -s "$sfile" ]] && nsvc=$(grep -c . "$sfile")

    # высота карточки (высоту блока сервисов меряем тем же кодом, что и рисуем)
    local H=78 chips_h=0 svc_h=0
    if [[ "$sstate" == "done" ]]; then
        [[ $chip_rows -gt 0 ]] && chips_h=$(( chip_rows*38 ))
        [[ $nsvc -gt 0 ]] && svc_h=$(render_services "$sfile" 0 0)
        # тест прошёл, но парсер ничего не выцепил — тогда карточка это только
        # заголовок: линейка под ним ничего бы не отделяла
        if (( chips_h==0 && svc_h==0 )); then H=58
        else H=$(( 66 + chips_h + (chips_h>0?6:0) + svc_h + 16 )); fi
    fi
    CARD_H=$H
    [[ "$draw" == "1" ]] || return 0

    sv "<rect x=\"$PAD\" y=\"$Y\" width=\"$CARDW\" height=\"$H\" rx=\"6\" fill=\"$C_SC\" stroke=\"$C_LINE\" stroke-width=\"1\"/>"
    sv "<text x=\"$((PAD+IPAD))\" y=\"$((Y+34))\" fill=\"$C_TXT\" font-size=\"19\" font-weight=\"700\">$(sv_esc "$nm")</text>"
    sv_status_chip $((PAD+CARDW-IPAD)) $((Y+19)) "$sstate"

    if [[ "$sstate" != "done" ]]; then
        local note="Пропущен пользователем во время прогона."
        [[ "$sstate" == "err" ]] && note="Тест завершился с ошибкой или без вывода."
        sv "<text x=\"$((PAD+IPAD))\" y=\"$((Y+58))\" fill=\"$C_TXT3\" font-size=\"13\">$note</text>"
        return 0
    fi

    (( chips_h>0 || svc_h>0 )) && sv "<line x1=\"$((PAD+IPAD))\" y1=\"$((Y+52))\" x2=\"$((PAD+CARDW-IPAD))\" y2=\"$((Y+52))\" stroke=\"$C_LINE\" stroke-width=\"1\"/>"

    # чипы метрик
    if [[ $nmet -gt 0 ]]; then
        cx=$IPAD; local cyy=$((Y+66)) row=0
        for kv in "${ML[@]}"; do
            l="${kv%%|*}"; rest="${kv#*|}"; v="${rest%%|*}"; ck="${rest#*|}"
            w=$(sv_chipw "$l" "$v")
            if (( cx > IPAD && cx + w > CARDW - IPAD )); then row=$((row+1)); cx=$IPAD; fi
            sv_mchip $((PAD+cx)) $((cyy+row*38)) "$l" "$v" "$ck"
            cx=$((cx + w + 8))
        done
    fi

    # строки сервисов (2 колонки + разделители)
    if [[ $nsvc -gt 0 ]]; then
        local sy=$(( Y + 66 + chips_h + (chips_h>0?6:0) ))
        render_services "$sfile" "$sy" 1 >/dev/null
    fi
    return 0
}

# Подвал страницы. Короткая страница (пропущенный тест — это заголовок и строчка
# пояснения) иначе выходила бы полоской: прижимаем подвал к низу и дотягиваем
# холст до MT_PAGE_MINH, чтобы в ленте альбома все картинки были одного порядка.
MT_PAGE_MINH="${MT_PAGE_MINH:-520}"

sv_footer_and_close() {
    local Y="$1" note="$2"
    # отдельным оператором: bash раскрывает все слова `local` до присваиваний,
    # и в `local Y="$1" footY=$((Y+34))` подвал считался бы от пустого Y
    local footY=$((Y+34)) SVGH
    (( footY + 14 < MT_PAGE_MINH )) && footY=$(( MT_PAGE_MINH - 14 ))
    sv "<text x=\"$PAD\" y=\"$footY\" fill=\"$C_FOOT\" font-size=\"12\">$(sv_esc "$note")</text>"
    SVGH=$((footY+24))
    MT_PAGE_H=$SVGH
    cat <<HEAD
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $W $SVGH" text-rendering="geometricPrecision" font-family="'IBM Plex Sans', Roboto, 'Noto Sans', 'DejaVu Sans', sans-serif">
<rect width="$W" height="$SVGH" fill="$C_BG"/>
HEAD
    printf '%s' "$SVG_BODY"
    echo "</svg>"
}

# --- Страницы альбома -------------------------------------------------------

# Обложка: шапка со счётом, баннер, характеристики сервера, оглавление альбома.
build_page_cover() {
    SVG_BODY=""
    local date_e; date_e=$(date '+%Y-%m-%d %H:%M')
    sv_head_full "$PAD"
    sv_banner "$MT_Y"
    sv_card_server "$MT_Y"
    sv_card_toc "$MT_Y"
    sv_offnames "$MT_Y"
    sv_footer_and_close "$MT_Y" "multitest v${SCRIPT_VERSION} · ${date_e} · обложка · страниц: ${MT_PAGE_N} · логотипы Simple Icons (CC0)"
}

# Страница одного теста: слим-шапка с идентификацией и его карточка целиком.
build_page_test() {
    local idx="$1"
    SVG_BODY=""
    local date_e; date_e=$(date '+%Y-%m-%d %H:%M')
    sv_head_slim "$PAD"
    sv_banner "$MT_Y"
    local top=$MT_Y
    # Сперва меряем карточку вхолостую. Короткая страница (пропущенный тест —
    # это заголовок и строчка пояснения) иначе прижимала бы всё к шапке, а нижняя
    # треть картинки оставалась бы пустой: в ленте альбома это читается как
    # «страница не догрузилась». Остаток высоты делим поровну — поля сверху и снизу.
    sv_test_card "$idx" 0 0
    local natural=$(( top + CARD_H + 58 ))
    (( natural < MT_PAGE_MINH )) && top=$(( top + (MT_PAGE_MINH - natural)/2 ))
    sv_test_card "$idx" "$top" 1
    sv_footer_and_close $((top+CARD_H)) "multitest v${SCRIPT_VERSION} · ${date_e} · страница ${MT_PAGE_I} из ${MT_PAGE_N}"
}

# Печатает SVG-карточку «Server Scorecard» одним полотном — запасной путь на
# случай, если альбом собрать или залить не вышло (MT_ALBUM=0 включает его руками).
build_summary_svg() {
    mt_style_init
    mt_album_plan
    mt_run_counters
    SVG_BODY=""
    local date_e; date_e=$(date '+%Y-%m-%d %H:%M')

    sv_head_full "$PAD"
    sv_banner "$MT_Y"
    sv_card_server "$MT_Y"

    local Y=$MT_Y i idx
    for i in "${!MT_PAGE_IDX[@]}"; do
        idx="${MT_PAGE_IDX[$i]}"
        sv_test_card "$idx" "$Y" 1
        Y=$((Y+CARD_H+14))
    done

    sv_offnames "$Y"
    # одностраничнику высота холста задаётся содержимым, а не полом страницы альбома
    local keep=$MT_PAGE_MINH; MT_PAGE_MINH=0
    sv_footer_and_close "$MT_Y" "multitest v${SCRIPT_VERSION} · ${date_e} · логотипы Simple Icons (CC0)"
    MT_PAGE_MINH=$keep
}

# Крутилка: команда уходит в фоновый процесс, её вывод — в лог, а в терминале
# держится одна живая строка со счётчиком секунд. Иначе шаги сборки картинки
# (apt, скачивание шрифта, рендер, аплоад) выглядят как зависший терминал.
# Без TTY — просто строка и тихое ожидание: под `| bash` рисовать нечего.
spin_run() {
    local msg="$1"; shift
    local log="${SUMMARY_DIR:-/tmp}/step.log" rc t0
    t0=$SECONDS

    if [[ ! -t 1 ]]; then
        echo -e "  ${msg}..."
        "$@" >"$log" 2>&1; rc=$?
        [[ $rc -eq 0 ]] && echo -e "  ${GREEN}готово${NC}" || echo -e "  ${RED}не вышло${NC}"
        return $rc
    fi

    "$@" >"$log" 2>&1 &
    local pid=$! i=0
    local -a fr; local gok='✔' gbad='✖'
    # Брайлевские точки и галочка требуют UTF-8; в C/POSIX-локали консоль
    # (особенно голая VGA на VPS) покажет вместо них мусор.
    if [[ "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" == *[Uu][Tt][Ff]* ]]; then
        fr=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
    else
        fr=( '-' '\' '|' '/' ); gok='+'; gbad='x'
    fi
    local n=${#fr[@]} delay=0.09
    sleep "$delay" 2>/dev/null || delay=1

    printf '\033[?25l'
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r\033[K  %b%s%b %s %b%d c%b' "$CYAN" "${fr[i%n]}" "$NC" "$msg" "$YELLOW" "$((SECONDS-t0))" "$NC"
        i=$((i+1)); sleep "$delay" 2>/dev/null || sleep 1
    done
    wait "$pid"; rc=$?
    printf '\r\033[K'
    printf '\033[?25h'

    if [[ $rc -eq 0 ]]; then
        echo -e "  ${GREEN}${gok}${NC} ${msg}"
    else
        echo -e "  ${RED}${gbad}${NC} ${msg}"
        [[ -s "$log" ]] && sed -e 's/^/      /' "$log" | tail -4
    fi
    return $rc
}

# --- шаги сборки сводки (каждый под своей крутилкой) ---
# Результаты передаём файлами: шаг уходит в фоновый процесс, и переменные,
# выставленные внутри него, до родителя не доживут.

step_render_deps() {
    ensure_rsvg; ensure_fonts
    # Успех шага — не «apt отработал», а «есть чем рендерить». Иначе строка
    # рапортовала бы «готово» там, где картинка уже обречена уехать как SVG.
    command -v rsvg-convert &>/dev/null || command -v convert &>/dev/null || command -v magick &>/dev/null
}

step_build_svg() {
    gather_system_facts
    build_summary_svg > "$SUMMARY_DIR/summary.svg"
    [[ -s "$SUMMARY_DIR/summary.svg" ]]
}

step_render_png() {
    local svg="$SUMMARY_DIR/summary.svg" png="$SUMMARY_DIR/summary.png"
    printf '%s' "$svg" > "$SUMMARY_DIR/out.path"
    if   command -v rsvg-convert &>/dev/null; then rsvg-convert -w 2200 -o "$png" "$svg" 2>/dev/null
    elif command -v convert      &>/dev/null; then convert -density 220 -background none "$svg" "$png" 2>/dev/null
    elif command -v magick       &>/dev/null; then magick  -density 220 -background none "$svg" "$png" 2>/dev/null
    fi
    [[ -s "$png" ]] || return 1
    printf '%s' "$png" > "$SUMMARY_DIR/out.path"
}

step_upload() {
    local url
    url=$(upload_report "$(cat "$SUMMARY_DIR/out.path")") || return 1
    [[ -n "$url" ]] || return 1
    printf '%s' "$url" > "$SUMMARY_DIR/url.txt"
}

# --- шаги альбома (страница на тест) ---------------------------------------

# Telegram ужимает отправленное «фото» до ~1280 px по длинной стороне (у новых
# клиентов и с галочкой HD — до 2560) и перекодирует в JPEG. Прежняя простыня
# 2200x6000 приезжала в чат с масштабом 0.2-0.4x, и 11-пиксельные подписи в
# плитках превращались в пару физических пикселей под JPEG-звоном. Страницу
# отдаём сразу в размере, который клиенту нечего пересчитывать.
MT_MAXSIDE="${MT_MAXSIDE:-2560}"
MT_PAGE_SCALE="${MT_PAGE_SCALE:-2}"
# Альбом у imgdb — 64 картинки; выше потолка собирать нечего, уходим в простыню.
MT_ALBUM="${MT_ALBUM:-1}"
MT_ALBUM_MAX=64

# Рендер одной страницы: <base>.svg -> <base>.png, путь дописывается в pages.list.
# Высоту берём из MT_PAGE_H, который выставил построитель страницы: разбирать
# её обратно из viewBox — лишний способ разойтись с тем, что нарисовано.
mt_render_page() {
    local base="$1"
    local svg="$base.svg" png="$base.png"
    local w=$(( W * MT_PAGE_SCALE )) h=$(( MT_PAGE_H * MT_PAGE_SCALE ))
    local -a geo
    if (( h > MT_MAXSIDE )); then geo=( -h "$MT_MAXSIDE" ); else geo=( -w "$w" ); fi
    if   command -v rsvg-convert &>/dev/null; then rsvg-convert "${geo[@]}" -o "$png" "$svg" 2>/dev/null
    elif command -v magick       &>/dev/null; then magick  -density 220 -background none "$svg" -resize "${w}x${MT_MAXSIDE}>" "$png" 2>/dev/null
    elif command -v convert      &>/dev/null; then convert -density 220 -background none "$svg" -resize "${w}x${MT_MAXSIDE}>" "$png" 2>/dev/null
    fi
    [[ -s "$png" ]] || return 1
    printf '%s\n' "$png" >> "$SUMMARY_DIR/pages.list"
}

step_build_pages() {
    # ниже идёт rm -rf по этому пути — пустой SUMMARY_DIR превратил бы его в /pages
    [[ -n "$SUMMARY_DIR" && -d "$SUMMARY_DIR" ]] || return 1
    gather_system_facts
    mt_style_init
    mt_album_plan
    mt_run_counters

    local dir="$SUMMARY_DIR/pages" i idx fn base
    rm -rf "$dir"; mkdir -p "$dir" 2>/dev/null || return 1
    : > "$SUMMARY_DIR/pages.list" || return 1

    MT_PAGE_N=$(( ${#MT_PAGE_IDX[@]} + 1 ))
    MT_PAGE_I=1
    build_page_cover > "$dir/01-cover.svg"
    [[ -s "$dir/01-cover.svg" ]] || return 1
    mt_render_page "$dir/01-cover" || return 1

    for i in "${!MT_PAGE_IDX[@]}"; do
        idx="${MT_PAGE_IDX[$i]}"; fn="${MT_CAT_FUNCS[$idx]}"
        MT_PAGE_I=$(( i + 2 ))
        base=$(printf '%s/%02d-%s' "$dir" "$MT_PAGE_I" "${fn#run_}")
        build_page_test "$idx" > "$base.svg"
        [[ -s "$base.svg" ]] || return 1
        mt_render_page "$base" || return 1
    done
    [[ -s "$SUMMARY_DIR/pages.list" ]]
}

step_upload_album() {
    local -a files=(); local f url
    while IFS= read -r f; do [[ -s "$f" ]] && files+=( "$f" ); done < "$SUMMARY_DIR/pages.list"
    (( ${#files[@]} > 0 )) || return 1
    url=$(up_imgdb_album "${files[@]}") || return 1
    [[ "$url" == https://* ]] || return 1
    printf '%s' "$url" > "$SUMMARY_DIR/url.txt"
}

# Русское склонение числительных: 1 день / 2 дня / 5 дней.
ru_plural() {
    local n=$1 one=$2 few=$3 many=$4
    if   (( n % 100 >= 11 && n % 100 <= 14 )); then printf '%s' "$many"
    elif (( n % 10 == 1 ));                    then printf '%s' "$one"
    elif (( n % 10 >= 2 && n % 10 <= 4 ));     then printf '%s' "$few"
    else                                            printf '%s' "$many"
    fi
}

# Срок жизни ссылки imgdb — по полю expires из ответа API, а не по нашему ttl.
imgdb_life() {
    local exp now left h d
    exp=$(cat "$SUMMARY_DIR/expires.txt" 2>/dev/null)
    [[ "$exp" == "null" ]] && { printf 'постоянная'; return; }
    [[ "$exp" =~ ^[0-9]+$ ]] || { printf 'временная'; return; }
    now=$(date +%s); left=$(( exp - now ))
    (( left <= 0 )) && { printf 'временная'; return; }
    if (( left < 172800 )); then
        h=$(( (left + 1799) / 3600 )); (( h < 1 )) && h=1
        printf '≈%d %s' "$h" "$(ru_plural "$h" час часа часов)"
    else
        d=$(( left / 86400 ))
        printf '≈%d %s' "$d" "$(ru_plural "$d" день дня дней)"
    fi
}

# Строит картинку-сводку, рендерит в PNG (2x) и заливает на хостинг.
# Альбом: обложка + по странице на тест, всё одним запросом на imgdb, в ответ
# одна ссылка. Возвращает 0, только если ссылка на руках — иначе вызывающий
# уходит на прежний путь с одной длинной картинкой.
render_album_summary() {
    mt_album_plan
    local n=$(( ${#MT_PAGE_IDX[@]} + 1 ))
    # прогона не было — альбому неоткуда взяться; выше потолка imgdb тоже нечего пробовать
    (( ${#MT_PAGE_IDX[@]} > 0 && n <= MT_ALBUM_MAX )) || return 1

    rm -f "$SUMMARY_DIR/pages.list"
    if ! spin_run "Собираю страницы альбома (${n})" step_build_pages; then
        echo -e "  ${YELLOW}Страницы не собрались — соберу одной картинкой.${NC}"
        return 1
    fi
    if ! spin_run "Загружаю альбом на imgdb" step_upload_album; then
        echo -e "  ${YELLOW}Альбом не загрузился — соберу одной картинкой.${NC}"
        return 1
    fi

    local url dir="$SUMMARY_DIR/pages" life
    url=$(cat "$SUMMARY_DIR/url.txt"); life=$(imgdb_life)
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}${GREEN}Альбом со сводкой:${NC} ${BOLD}${url}${NC}"
    echo -e "  ${CYAN}Страниц: ${BOLD}${n}${NC}${CYAN} — обложка и по одной на тест.${NC}"
    # про постоянную ссылку молчим: строка была нужна, только пока срок конечный
    [[ "$life" != "постоянная" ]] && echo -e "  ${YELLOW}Ссылка ${life} — потом альбом удалится с хостинга.${NC}"
    echo -e "  ${YELLOW}Оригиналы лежат тут:${NC} ${BOLD}${dir}${NC}"
    echo -e "    ${YELLOW}например: ${BOLD}scp -r root@<host>:${dir} .${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    return 0
}

render_and_upload_summary() {
    print_separator "Формирую сводку (изображение)"

    if [[ -z "$SUMMARY_DIR" || ! -d "$SUMMARY_DIR" ]]; then
        SUMMARY_DIR=$(mktemp -d 2>/dev/null) || {
            echo -e "${YELLOW}Не удалось создать каталог для сводки — пропускаю.${NC}"
            return 0
        }
    fi
    rm -f "$SUMMARY_DIR/url.txt" "$SUMMARY_DIR/out.path" "$SUMMARY_DIR/expires.txt"

    spin_run "Устанавливаю зависимости для картинки" step_render_deps

    [[ "$MT_ALBUM" == "1" ]] && render_album_summary && return 0
    # дальше — прежний путь: одна длинная картинка и перебор файлообменников

    if ! spin_run "Собираю карточку" step_build_svg; then
        echo -e "  ${YELLOW}Не удалось собрать карточку — сводки не будет.${NC}"
        return 0
    fi

    if ! spin_run "Рендерю PNG" step_render_png; then
        echo -e "  ${YELLOW}PNG не отрендерился — загружу SVG (откроется в браузере).${NC}"
    fi
    local out; out=$(cat "$SUMMARY_DIR/out.path" 2>/dev/null)
    [[ -n "$out" ]] || out="$SUMMARY_DIR/summary.svg"

    echo -e "  Локально: ${BOLD}${out}${NC}"

    if spin_run "Загружаю на хостинг" step_upload; then
        local url life="временная"
        url=$(cat "$SUMMARY_DIR/url.txt")
        case "$url" in
            *imgdb.io*)          life=$(imgdb_life) ;;
            *x0.at*)             life="≈100 дней" ;;
            *files.catbox.moe*)  life="постоянная" ;;
            *litter.catbox.moe*) life="до 72 часов" ;;
            *uguu.se*)           life="3 часа" ;;
            *tmpfiles.org*)      life="1 час" ;;
        esac
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${BOLD}${GREEN}Ссылка на сводку:${NC} ${BOLD}${url}${NC}"
        [[ "$life" != "постоянная" ]] && echo -e "  ${YELLOW}Ссылка ${life} — потом файл удалится с хостинга.${NC}"
        echo -e "  ${YELLOW}Чтобы переслать надёжно/навсегда — ОБЯЗАТЕЛЬНО скачайте сам файл:${NC}"
        echo -e "    ${BOLD}${out}${NC}"
        echo -e "    ${YELLOW}например: ${BOLD}scp root@<host>:${out} .${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "  ${YELLOW}Загрузка не удалась — файл сохранён локально: ${out}${NC}"
        echo -e "  ${YELLOW}Скопируйте: scp root@<host>:${out} .${NC}"
    fi
}

# ============================================================
#  Главное меню
# ============================================================

show_menu() {
    print_header
    echo -e "  ${CYAN}${BOLD}── Тесты ──${NC}"
    echo ""
    echo -e "  ${GREEN} 1)${NC}  IP Region"
    echo -e "  ${GREEN} 2)${NC}  Censorcheck — проверка геоблока"
    echo -e "  ${GREEN} 3)${NC}  Censorcheck — DPI (серверы РФ)"
    echo -e "  ${GREEN} 4)${NC}  Censorcheck — censorcheck.tlab.pw"
    echo -e "  ${GREEN} 5)${NC}  iPerf3 — тест до российских серверов"
    echo -e "  ${GREEN} 6)${NC}  iPerf3 — bench.tlab.pw (РФ)"
    echo -e "  ${GREEN} 7)${NC}  YABS — бенчмарк сервера"
    echo -e "  ${GREEN} 8)${NC}  IP Check Place — блокировки зарубежными сервисами"
    echo -e "  ${GREEN} 9)${NC}  bench.sh — параметры сервера и скорость"
    echo -e "  ${GREEN}10)${NC}  IPQuality"
    echo -e "  ${GREEN}11)${NC}  sysbench CPU — тест процессора"
    echo ""
    echo -e "  ${YELLOW}12)${NC}  ${BOLD}Мультитест — выбор и запуск тестов${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}── Утилиты ──${NC}"
    echo ""
    echo -e "  ${GREEN}13)${NC}  Утилиты (BBR, IPv6...)"
    echo ""
    echo -e "  ${RED} 0)${NC}  Выход"

    # Блок спонсора уходит ПОД строку ввода: печатаем его, затем поднимаем
    # курсор обратно относительным сдвигом. Сохранённая позиция (ESC[s/ESC[u)
    # тут не годится — если блок не влез и экран прокрутился, строка ввода
    # уедет вверх, а сохранённый номер строки останется прежним.
    if [[ -t 0 && -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
        MT_PROMO_BELOW=1
        stencloud_promo_lines
        printf '\n\n\n'                        # отбивка, строка ввода, отбивка
        printf '%s\n' "${STENCLOUD_PROMO[@]}"
        printf '\033[%dA' $(( ${#STENCLOUD_PROMO[@]} + 2 ))
    else
        MT_PROMO_BELOW=0
        print_stencloud_promo
    fi
    echo -ne "  ${BOLD}Выберите пункт [0-13]: ${NC}"
}

# ============================================================
#  Главный цикл
# ============================================================

# Позволяет подключить функции для тестов: MULTITEST_TEST=1 source multitest.sh
[[ "${MULTITEST_TEST:-0}" == "1" ]] && return 0 2>/dev/null

# Ctrl+C на приглашении меню убивает скрипт прямо в read, мимо строки с
# очисткой ниже: блок спонсора остаётся на экране, и шелл потом затирает его
# по одной строке на каждую свою новую. Поэтому на выходе по сигналу стираем
# сами. Курсор в этот момент стоит сразу за отзеркаленным ^C, так что хвост
# строки уезжает вместе с блоком.
mt_menu_sigint() {
    [[ "${MT_PROMO_BELOW:-0}" == "1" ]] && printf '\033[J'
    echo
    exit 130
}

while true; do
    # Ставим до отрисовки: сигнал может прийти и посреди печати блока.
    trap mt_menu_sigint INT
    show_menu
    read -r choice
    trap - INT
    # Блок спонсора висит ниже строки ввода — стираем его до низа экрана,
    # иначе вывод теста ляжет прямо поверх букв.
    [[ "${MT_PROMO_BELOW:-0}" == "1" ]] && printf '\033[J'

    case "$choice" in
        1)  run_ip_region; pause_prompt ;;
        2)  run_censorcheck_geoblock; pause_prompt ;;
        3)  run_censorcheck_dpi; pause_prompt ;;
        4)  run_censorcheck_tlab; pause_prompt ;;
        5)  run_iperf3_ru; pause_prompt ;;
        6)  run_iperf3_tlab; pause_prompt ;;
        7)  run_yabs; pause_prompt ;;
        8)  run_ip_check_place; pause_prompt ;;
        9)  run_bench_sh; pause_prompt ;;
        10) run_ip_quality; pause_prompt ;;
        11) run_sysbench_cpu; pause_prompt ;;
        12) run_all; pause_prompt ;;
        13) show_utilities_menu ;;
        0)  echo -e "${GREEN}До свидания!${NC}"; exit 0 ;;
        *)  echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"; pause_prompt ;;
    esac
done
