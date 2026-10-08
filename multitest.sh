#!/bin/bash

# ============================================================
#  Multitest — интерактивный скрипт диагностики сервера
# ============================================================

SCRIPT_VERSION="3.0"
REPO_URL="https://raw.githubusercontent.com/saveksme/multitest/master/multitest.sh"

# Цвета. ANSI-C quoting: внутри уже настоящий ESC, а не текст «\033». Так его
# одинаково печатают и `echo -e`, и `printf '%s'` — без переинтерпретации, из-за
# которой недоверенный текст мог бы собрать escape-последовательность.
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# Состояние сводки мультитеста
SUMMARY_DIR=""             # /tmp/multitest-summary-<ts>
SUMMARY_TS=""
SCRIPT_CAPTURE="util"      # util | busybox
MT_UA="Mozilla/5.0 (X11; Linux x86_64) multitest/${SCRIPT_VERSION}"  # User-Agent для хостингов

# Спонсор: подпись в подвале каждой страницы сводки (см. pg_footer) и блок
# в главном меню (см. print_stencloud_promo).
AD_PROMO="BEDOLAGA"        # промокод
AD_DISCOUNT="−20%"         # скидка по нему
AD_BOT="@stencloudbot"     # куда идти за сервером

# Telegram-бот Multitest: ссылка на бота зашита, пользователь бота не указывает.
# Секретов в скрипте нет — ключ сервера создаётся на месте при привязке и живёт
# в $MT_STATE_DIR/agent.conf (0600). Переопределение через окружение — для стенда.
MT_BOT_USERNAME="${MT_BOT_USERNAME:-multitestus_bot}"
MT_BOT_API="${MT_BOT_API:-https://mtbot.sixseven.cam}"
MT_STATE_DIR="${MT_STATE_DIR:-/etc/multitest}"
MT_CONF="$MT_STATE_DIR/agent.conf"
MT_CURL="${MT_CURL:-curl}"         # тесты подменяют curl
MT_TTY="${MT_TTY:-/dev/tty}"       # вопросы привязки — только с клавиатуры
MT_SRV_ID=""; MT_SRV_TOKEN=""; MT_API=""; MT_BOT=""
MT_RESP=""; MT_RESP_V=""; MT_RESP_A=()
# Агент (запуск тестов из Telegram): служба systemd и её рабочий каталог. Лимиты —
# локальные, бот их не переопределит; править можно в agent.conf (MT_LIM_*).
MT_AGENT_DIR="${MT_AGENT_DIR:-/var/lib/multitest}"
MT_AGENT_UNIT="${MT_AGENT_UNIT:-/etc/systemd/system/multitest-agent.service}"
MT_SYSTEMD="${MT_SYSTEMD:-/run/systemd/system}"
MT_LIM_GAP=300; MT_LIM_DAY=12; MT_LIM_HEAVY=4     # раз в 5 мин, 12 в сутки, тяжёлых 4
MT_HEADLESS=0; MT_JOB_ID=""; MT_JOB_DIR=""; MT_TEST_NUM=""

# Марка спонсора для подписи: контур обведён с растрового логотипа
# (assets/brand/stencloud.png, там же лежит читаемая копия stencloud.svg) —
# держать её вектором обязательно, скрипт качают одним файлом, а PNG в base64
# весил бы больше всей таблицы Simple Icons. Контур начинается в нуле и
# занимает 340×172.3 единиц. В подвале сводки марка одноцветная, как
# stencloud-white.png в макете: слово STEN и облако, у которого чёрточка и
# точки вырезаны (evenodd) — сквозь них виден фон страницы.
AD_LOGO_STEN="M 33.6 0.4 C 22.4 1.3, 12.7 9, 9.1 19.8 C 8.1 22.7, 7.7 27.3, 8.1 31 C 8.5 35, 9.3 37.5, 11.1 40.7 C 14.7 47, 20.7 51.5, 28.3 53.5 C 30.9 54.2, 31.5 54.2, 48.1 54.4 L 65.2 54.6 66.5 55.4 C 68.1 56.5, 69.1 58.4, 69.1 60.5 C 69.1 62.6, 68.2 64, 66.4 65.2 L 64.9 66.1 50.1 66.2 C 33.5 66.3, 33.6 66.3, 31.6 64.1 C 31 63.4, 30.4 62.4, 30.3 61.7 C 30.2 61, 29.9 60.4, 29.7 60.3 C 29.3 60, 7.4 60.3, 7.1 60.6 C 6.8 60.9, 7.4 66.3, 8 68.6 C 9.1 72.6, 10.9 75.9, 14.1 79.3 C 17.6 83, 21.3 85.1, 27 86.7 L 30 87.6 49.1 87.6 C 66.9 87.6, 68.4 87.5, 70.6 87 C 83.6 83.7, 91.8 73.4, 91.8 60.2 C 91.8 49.9, 85.5 40.4, 75.5 35.5 C 74.4 35, 72 34.2, 70 33.7 L 66.4 32.9 50.8 32.8 C 36.1 32.7, 35 32.7, 34 32.1 C 32.6 31.4, 31.5 29.9, 31.2 28.4 C 30.8 25.9, 32.6 23.1, 35.2 22.4 C 36 22.2, 40.9 22.1, 49.4 22.2 L 62.4 22.2 63.7 23 C 65.2 23.9, 66 24.9, 66.2 26.4 L 66.4 27.5 78.2 27.6 L 90 27.7 89.8 24.9 L 89.6 22.1 102.8 22.1 L 116 22.1 116.1 54.8 L 116.2 87.6 127.8 87.6 L 139.4 87.7 139.4 77.2 C 139.4 71.5, 139.4 57.4, 139.4 46 C 139.4 34.7, 139.4 24.6, 139.5 23.7 L 139.7 22.1 153.2 22.1 L 166.7 22.1 166.7 11.1 L 166.6 0.2 128 0.2 L 89.4 0.2 89.4 10.8 C 89.4 16.7, 89.3 21.2, 89.2 20.9 C 89.1 20.6, 88.7 19.2, 88.2 17.8 C 87.1 14.2, 84.9 10.9, 81.5 7.7 C 79.2 5.5, 78.2 4.8, 75.2 3.3 C 71.2 1.4, 69.1 0.8, 65.2 0.4 C 61.7 0, 37.7 0, 33.6 0.4 M 172.2 0.4 C 172.1 0.6, 172.1 20.3, 172.1 44.2 L 172.2 87.6 207.5 87.6 L 242.8 87.6 242.9 76.8 L 243 65.9 219.6 65.9 L 196.3 65.9 196.3 60.2 L 196.3 54.4 219.1 54.4 L 241.9 54.3 241.9 44.2 C 242 38.6, 242 33.7, 241.9 33.4 L 241.7 32.7 219 32.7 L 196.3 32.7 196.3 27.4 L 196.3 22.1 219.5 22 L 242.8 21.9 242.8 11 L 242.8 0.2 207.6 0.1 C 179.5 0, 172.3 0.1, 172.2 0.4 M 249.9 0.4 C 249.9 0.6, 249.8 20.3, 249.9 44.2 L 249.9 87.6 261.3 87.6 L 272.7 87.6 272.8 63.6 L 273 39.7 275.3 43.1 C 276.6 45, 278.6 48, 279.8 49.8 C 280.9 51.6, 283.7 55.8, 285.8 59.1 C 288 62.4, 290.8 66.8, 292.1 68.7 C 293.4 70.7, 296.7 75.8, 299.5 80 L 304.5 87.7 317 87.6 L 329.6 87.6 329.6 43.9 L 329.6 0.2 318.2 0.2 L 306.9 0.2 306.7 23.6 L 306.6 47.1 302.5 40.9 C 298.8 35.3, 295.7 30.5, 291.4 23.9 C 290.6 22.6, 288.5 19.4, 286.7 16.6 C 282.8 10.7, 280.1 6.4, 277.7 2.7 L 275.9 0 263 0 C 253 0, 250 0.1, 249.9 0.4"
AD_LOGO_CLOUD="M 32 98.6 C 17.8 100.6, 6.3 110.1, 1.9 123.4 C 0.6 127.3, 0 131.4, 0 136.1 C 0 140.6, 0.3 143.3, 1.3 146.9 C 4.8 160.6, 16.5 170.3, 31.5 172 C 35.6 172.5, 38.2 172.4, 42.4 171.8 C 51.1 170.6, 59.2 166.2, 63.8 160.1 C 67.2 155.6, 69.3 150.2, 69.4 145.4 L 69.5 143.2 59.2 143.2 C 49.4 143.1, 48.8 143.1, 48.8 143.6 C 48.8 144, 48.5 145.1, 48.2 146.2 C 46.5 151, 41.4 153.7, 34.7 153.3 C 29 152.9, 24.7 150.1, 22.4 145.5 C 20.9 142.3, 20.5 140.6, 20.5 135.8 C 20.5 131.1, 20.9 129.3, 22.2 126.4 C 23.6 123.5, 24.9 121.9, 27.4 120.2 C 29.9 118.5, 32.4 117.6, 35.5 117.4 C 40 117, 44.4 118.5, 46.5 121.2 C 47.7 122.6, 48.8 125.5, 48.8 127 L 48.8 127.8 59.3 127.8 L 69.8 127.8 69.6 125.1 C 68.6 112.2, 59.8 102.2, 46.7 99.2 C 43.6 98.5, 35.3 98.2, 32 98.6 M 72.5 134.8 L 72.5 171.4 94.4 171.4 L 116.3 171.4 116.3 162.3 L 116.2 153.2 104.4 153.1 L 92.6 153 92.7 146.1 C 92.7 142.3, 92.8 130, 92.7 118.8 L 92.7 98.3 82.6 98.3 L 72.5 98.3 72.5 134.8 M 216.9 124.4 L 217 150.4 217.8 153.4 C 219.1 158.1, 220.8 161.1, 224.1 164.4 C 226.7 167, 227.3 167.5, 230.5 169 C 235.2 171.3, 238.2 172, 243.8 172.2 C 255.5 172.7, 265.2 168.4, 270.3 160.4 C 272.4 157.1, 273.4 154.7, 274.1 150.6 C 274.4 148.6, 274.8 105.2, 274.5 101 L 274.3 98.3 264.3 98.3 L 254.2 98.3 254.1 101.2 C 254 102.8, 253.9 113.8, 253.9 125.7 C 253.8 137.6, 253.7 147.6, 253.6 148.1 C 253.3 149.5, 252.2 151.2, 251.1 151.9 C 246.6 155.1, 240.2 153.8, 238.2 149.3 C 237.5 147.9, 237.5 147.5, 237.4 123.1 L 237.3 98.3 227.1 98.3 L 216.8 98.3 216.9 124.4 M 278.4 134.8 L 278.4 171.1 295 171 C 310.8 170.9, 311.7 170.9, 314.2 170.2 C 323.8 167.7, 329.5 164.2, 334.2 157.9 C 336.3 155, 337.5 152.7, 338.6 149.1 C 339.9 144.8, 340.1 142.3, 339.9 133.3 C 339.8 125.4, 339.7 124.7, 339 121.8 C 335.6 109.7, 326.9 101.9, 313.9 99.4 C 311.7 98.9, 308.3 98.8, 294.8 98.7 L 278.4 98.5 278.4 134.8 M 167 99.3 C 160.7 100.2, 155.1 103.1, 150.9 107.5 C 147.8 110.7, 145.9 113.7, 144.5 117.7 C 143.8 119.6, 143.3 120.1, 141.9 120.1 C 140 120.1, 135.6 121.3, 133.3 122.4 C 126 126.1, 121.4 131.7, 119.4 139.2 C 116.3 151.3, 121.7 163.5, 132.4 168.8 C 137.8 171.4, 135.5 171.2, 168.1 171.2 L 197.1 171.2 199.8 170.2 C 203.7 168.9, 205.7 167.6, 208.4 164.9 C 212.4 160.9, 214.5 156.2, 214.9 150.7 C 215.4 141, 210 132.4, 201.2 129.1 L 198.9 128.3 198.7 125.2 C 198.4 120.2, 197.1 116.2, 194.5 112.1 C 192.5 109, 191.2 107.6, 188.9 105.7 C 182.4 100.4, 174.6 98.1, 167 99.3 M 298.9 135 L 298.9 152.8 304.5 152.7 C 309.9 152.6, 310 152.6, 312.1 151.6 C 313.2 151, 314.9 149.9, 315.9 149 C 318.8 146.2, 319.8 142.6, 319.8 134.2 C 319.8 127.3, 318.9 123.9, 316.5 121.3 C 313.8 118.4, 310.1 117.3, 303.2 117.3 L 298.9 117.3 298.9 135 M 144.5 148.7 C 142.4 149.3, 141 151.9, 141.4 154.2 C 141.7 155.7, 143.2 157.3, 144.6 157.7 C 145.3 157.9, 149.9 158, 155.9 158 C 165.7 158, 166 158, 167.4 157.3 C 169.1 156.5, 169.9 155.1, 169.9 153.2 C 169.9 151.3, 169.1 149.9, 167.4 149.1 C 166 148.4, 165.8 148.4, 155.7 148.4 C 150.1 148.4, 145 148.6, 144.5 148.7 M 178.4 148.7 C 177.8 148.9, 177 149.5, 176.5 150.1 C 173.1 153.8, 177.2 159.5, 181.8 157.5 C 185.3 155.9, 185.4 150.9, 182 149.1 C 180.5 148.3, 179.9 148.3, 178.4 148.7 M 192.4 149 C 190 150.1, 189 153.1, 190.3 155.5 C 191.1 157.1, 193.3 158.2, 195.1 157.9 C 197.6 157.4, 199.4 154.8, 198.9 152.2 C 198.7 150.8, 197.1 149.1, 195.7 148.7 C 194.2 148.3, 193.8 148.3, 192.4 149"

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

# Шапка меню: слово MULTITEST шрифтом figlet small — тем же, что у блока
# спонсора. Первые 27 колонок — MULTI, дальше — TEST.
mapfile -t MT_LOGO_WORD <<'LOGOWORD'
 __  __ _   _ _  _____ ___ _____ ___ ___ _____
|  \/  | | | | ||_   _|_ _|_   _| __/ __|_   _|
| |\/| | |_| | |__| |  | |  | | | _|\__ \ | |
|_|  |_|\___/|____|_| |___| |_| |___|___/ |_|
LOGOWORD

# Шапка собирается в MT_LOGO под ширину терминала: большая надпись и под ней
# подпись, а если надпись не влезает — две строки текстом.
# Ширину сначала спрашиваем у stty — его stdin это клавиатура меню, а у tput
# внутри $(…) stdout — канал, и терминал он может не увидеть.
mt_logo_lines() {
    local cols w b='' r='' pink='' teal='' grey=''

    cols=$(stty size 2>/dev/null); cols=${cols##* }
    [[ $cols =~ ^[1-9][0-9]*$ ]] || cols=$(tput cols 2>/dev/null)
    [[ $cols =~ ^[1-9][0-9]*$ ]] || cols=80

    if [[ -t 1 && "${NO_COLOR:-}" == "" ]]; then
        r=$'\033[0m'; b=$'\033[1m'; grey=$'\033[38;5;245m'
        pink=$'\033[1;38;5;204m'; teal=$'\033[1;38;5;79m'
    fi

    # Надписи с отступом нужно 2 + 47 колонок, последнюю колонку терминала не занимаем.
    if (( cols < 50 )); then
        MT_LOGO=("  ${b}MULTI${r}${teal}TEST${r} ${pink}v${SCRIPT_VERSION}${r}"
                 "  Диагностика и тестирование сервера")
        return 0
    fi
    MT_LOGO=()
    for w in "${MT_LOGO_WORD[@]}"; do MT_LOGO+=("  ${b}${w:0:27}${r}${teal}${w:27}${r}"); done
    MT_LOGO+=(""
              "  ${pink}v${SCRIPT_VERSION}${r} ${grey}─${r} диагностика и тестирование сервера"
              "  ${grey}IP · DPI · iPerf3 · YABS · Telegram${r}")
}

print_header() {
    clear
    mt_logo_lines
    echo ""
    printf '%s\n' "${MT_LOGO[@]}"
    echo ""
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
        run_yabs|run_ip_check_place|run_ip_quality|run_ping_map)
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
    wget -qO- https://censorcheck.tlab.pw | bash
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
    wget -qO- https://bench.tlab.pw | bash
}

run_yabs() {
    print_separator "YABS — бенчмарк сервера"
    check_and_install curl
    curl -sL https://yabs.sh | bash -s -- -4
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
    wget -qO- https://bench.sh | bash
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

# Ping-карта: как сервер виден снаружи — пинг с узлов check-host.net (РФ + мир).
# Публичный API без аккаунтов/токенов: GET check-ping?host=<ip>&node=… → поллинг check-result/<id>.
run_ping_map() {
    print_separator "Ping-карта — check-host.net"
    check_and_install curl

    echo -e "  Задержка и потери пакетов до сервера с точек РФ и мира."
    echo -e "  Публичный API check-host.net — без аккаунтов и токенов."
    echo ""

    # Внешний IPv4 берём сами: в capture-подоболочке переменные скрипта не экспортируются.
    # Именно -4: без него curl на dual-stack идёт по IPv6, и узлы без IPv6 (РФ,
    # соседи) отвечали бы «нет ответа» вместо пинга до самого сервера.
    local ip
    ip=$(curl -s4 --max-time 6 https://ifconfig.me 2>/dev/null)
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || ip=$(curl -s4 --max-time 6 https://api.ipify.org 2>/dev/null)
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || ip=""
    if [[ -z "$ip" ]]; then
        echo -e "  ${RED}[CH] ОШИБКА: не удалось определить внешний IPv4-адрес сервера.${NC}"
        return 1
    fi
    echo -e "  Цель: ${BOLD}${ip}${NC}"
    echo ""

    # Узлы: 3 РФ + соседи + ЕС + мир. Мёртвые/переименованные узлы просто не придут
    # в ответе API — список самовосстанавливающийся.
    local -a ch_nodes=( ru1 ru2 ru3 kz1 tr1 de4 fi1 pl2 nl1 uk1 us5 us1 sg1 jp1 )
    local -A ch_city=( [ru1]="Москва" [ru2]="Москва" [ru3]="Санкт-Петербург"
                       [kz1]="Караганда" [tr1]="Стамбул" [de4]="Франкфурт"
                       [fi1]="Хельсинки" [pl2]="Варшава" [nl1]="Амстердам"
                       [uk1]="Лондон" [us5]="Нью-Йорк" [us1]="Лос-Анджелес"
                       [sg1]="Сингапур" [jp1]="Токио" )
    ch_region() {
        case "$1" in
            ru*)                       echo "Россия" ;;
            kz1|tr1)                   echo "Соседи" ;;
            de4|fi1|pl2|nl1|uk1)       echo "Европа" ;;
            *)                         echo "Мир" ;;
        esac
    }
    ch_agggroup() {
        # группа агрегатных чипов (kz/tr попадают только в таблицу)
        case "$1" in
            ru*)                       echo "Россия" ;;
            de4|fi1|pl2|nl1|uk1)       echo "Европа" ;;
            us*)                       echo "США" ;;
            sg1|jp1)                   echo "Азия" ;;
        esac
    }

    # --- Запуск ping-проверки со всех узлов ---
    local url="https://check-host.net/check-ping?host=${ip}" n
    for n in "${ch_nodes[@]}"; do url+="&node=${n}.node.check-host.net"; done
    local resp rid
    resp=$(curl -s --max-time 20 -H "Accept: application/json" "$url" 2>/dev/null)
    rid=$(printf '%s' "$resp" | sed -nE 's/.*"request_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)
    if [[ -z "$rid" ]]; then
        echo -e "  ${RED}[CH] ОШИБКА: API check-host.net недоступен или вернул неожиданный ответ.${NC}"
        return 1
    fi
    local report="https://check-host.net/check-report/${rid}"

    # --- Поллинг результатов: узел со значением null ещё не завершил проверку ---
    local res="" a nulls
    echo -ne "  Опрашиваем узлы check-host.net..."
    for a in $(seq 1 18); do
        sleep 5
        res=$(curl -s --max-time 15 -H "Accept: application/json" \
              "https://check-host.net/check-result/${rid}" 2>/dev/null)
        [[ -z "$res" ]] && continue
        nulls=$(printf '%s' "$res" | grep -oE '"[a-z]+[0-9]+\.node\.check-host\.net"[[:space:]]*:[[:space:]]*null' | wc -l)
        nulls=$((nulls))
        # все ответили; после 30 с не ждём 1-2 застрявших узлов — они станут «нет ответа»
        (( nulls == 0 )) && break
        (( a >= 6 && nulls <= 2 )) && break
        echo -ne "\r  Опрашиваем узлы check-host.net... попытка ${a}/18 "
    done
    echo ""
    if [[ -z "$res" ]]; then
        echo -e "  ${RED}[CH] ОШИБКА: результаты check-host.net не получены.${NC}"
        return 1
    fi

    # --- Разбор результатов по узлам (jq в проекте нет — sed/awk) ---
    # Формат: "<узел>": [[["OK",0.044,"ip"],…]] | [[null]] (ошибка узла) | null (не успел)
    local -A p_ok p_loss p_avg p_min p_max p_bad
    local slice times to cnt st
    for n in "${ch_nodes[@]}"; do
        # режем JSON по кавычкам-ключам, затем берём строки от ключа узла до следующего ключа узла
        slice=$(printf '%s' "$res" | sed 's/[[{,][[:space:]]*"/\n"/g' | awk -v k="\"${n}.node.check-host.net\":" '
            index($0, k)==1 { on=1; next }
            /^"[a-z]+[0-9]+\.node\.check-host\.net":/ { on=0 }
            on { print }')
        times=$(printf '%s' "$slice" | grep -oE '"OK"[[:space:]]*,[[:space:]]*[0-9]+(\.[0-9]+)?' | grep -oE '[0-9]+(\.[0-9]+)?$')
        to=$(printf '%s' "$slice" | grep -oE '"TIMEOUT"' | wc -l); to=$((to))
        if [[ -z "$times" && "$to" -eq 0 ]]; then
            p_bad[$n]=1
            continue
        fi
        cnt=$(printf '%s\n' "$times" | grep -c .); cnt=$((cnt))
        # API отдаёт времена в секундах — переводим в миллисекунды
        st=$(printf '%s\n' "$times" | awk '{ s+=$1; if(m==""||$1<m)m=$1; if($1>M)M=$1 } END { if(NR>0) printf "%.1f %.1f %.1f", m*1000, s/NR*1000, M*1000 }')
        read -r "p_min[$n]" "p_avg[$n]" "p_max[$n]" <<< "$st"
        p_ok[$n]=$cnt
        p_loss[$n]=$to
    done

    # --- Таблица по узлам (формат строк канонический — его читает parse_pingmap) ---
    echo ""
    echo -e "  ${BOLD}Как сервер виден с разных точек:${NC}"
    echo ""
    local region prev="" city loss_pct
    for n in "${ch_nodes[@]}"; do
        region=$(ch_region "$n")
        if [[ "$region" != "$prev" ]]; then
            [[ -n "$prev" ]] && echo ""
            echo -e "  ${CYAN}── ${region} ──${NC}"
            prev="$region"
        fi
        city="${ch_city[$n]:-$n}"
        if [[ -n "${p_bad[$n]:-}" ]]; then
            printf "  %-4s · %s · — · нет ответа\n" "$n" "$city"
        elif (( ${p_ok[$n]:-0} == 0 )); then
            printf "  %-4s · %s · 100%% · все пакеты потеряны\n" "$n" "$city"
        else
            loss_pct=$(( ${p_loss[$n]:-0} * 100 / (${p_ok[$n]:-0} + ${p_loss[$n]:-0}) ))
            printf "  %-4s · %s · %d%% · %s/%s/%s ms\n" "$n" "$city" "$loss_pct" \
                   "${p_min[$n]}" "${p_avg[$n]}" "${p_max[$n]}"
        fi
    done

    # --- Агрегаты ---
    local -A g_val
    local g
    for n in "${ch_nodes[@]}"; do
        [[ -n "${p_bad[$n]:-}" ]] && continue
        (( ${p_ok[$n]:-0} == 0 )) && continue
        g=$(ch_agggroup "$n")
        [[ -z "$g" ]] && continue
        g_val[$g]="${g_val[$g]:-} ${p_avg[$n]}"
    done
    echo ""
    echo -e "  ${BOLD}Сводка:${NC}"
    local gavg
    for g in "Россия" "Европа" "США" "Азия"; do
        [[ -z "${g_val[$g]:-}" ]] && continue
        gavg=$(awk -v s="${g_val[$g]}" 'BEGIN{ n=split(s,a," "); t=0; for(i=1;i<=n;i++) t+=a[i]; printf "%.1f", t/n }')
        printf "  Средняя (%s): %s ms\n" "$g" "$gavg"
    done

    # Худший узел и потери (узлы без ответа API не считаем потерями сервера)
    local wn="" wv=0 wdetail="" wd answered=0 n_loss_cnt=0 n_loss_names="" w
    for n in "${ch_nodes[@]}"; do
        [[ -n "${p_bad[$n]:-}" ]] && continue
        ((answered++))
        if (( ${p_ok[$n]:-0} == 0 )); then
            ((n_loss_cnt++)); n_loss_names="${n_loss_names:+$n_loss_names }${ch_city[$n]}"
            w=999999; wd="100% потерь"
        else
            if (( ${p_loss[$n]:-0} > 0 )); then
                ((n_loss_cnt++)); n_loss_names="${n_loss_names:+$n_loss_names }${ch_city[$n]}"
            fi
            w=${p_avg[$n]}; wd="${p_avg[$n]} ms"
        fi
        if awk -v a="$w" -v b="$wv" 'BEGIN{ exit !(a>b) }'; then wn="$n"; wv="$w"; wdetail="$wd"; fi
    done
    if (( answered == 0 )); then
        echo -e "  ${RED}[CH] ОШИБКА: ни один узел не вернул результат (проверьте доступность check-host.net).${NC}"
        return 1
    fi
    [[ -n "$wn" ]] && printf "  Худший узел: %s (%s) · %s\n" "${ch_city[$wn]:-$wn}" "$wn" "$wdetail"
    if (( n_loss_cnt == 0 )); then
        printf "  Узлы с потерями: 0/%d\n" "$answered"
    else
        printf "  Узлы с потерями: %d/%d (%s)\n" "$n_loss_cnt" "$answered" "$n_loss_names"
    fi
    printf "  Отчёт: %s\n" "$report"
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

# Каталог тестов: порядок = нумерация в главном меню и порядок страниц альбома.
# Это же белый список: capture_test и задания из Telegram запускают только эти
# функции. Оценки времени грубые, порядок величины — прикинуть цену выбора.
MT_CAT_FUNCS=( run_ip_region run_censorcheck_geoblock run_censorcheck_dpi \
               run_censorcheck_tlab run_iperf3_ru run_iperf3_tlab run_yabs \
               run_ip_check_place run_bench_sh run_ip_quality run_sysbench_cpu \
               run_ping_map )
MT_CAT_NAMES=( "IP Region" \
               "Censorcheck — проверка геоблока" \
               "Censorcheck — DPI (серверы РФ)" \
               "Censorcheck — censorcheck.tlab.pw" \
               "iPerf3 — тест до российских серверов" \
               "iPerf3 — bench.tlab.pw (РФ)" \
               "YABS — бенчмарк сервера" \
               "IP Check Place — блокировки зарубежных сервисов" \
               "bench.sh — параметры сервера и скорость" \
               "IPQuality" \
               "sysbench CPU — тест процессора" \
               "Ping-карта — check-host.net" )
MT_CAT_SECS=(  40 120 180 120 180 120 720 180 300 180 15 60 )

mt_is_test_fn() {
    local f
    for f in "${MT_CAT_FUNCS[@]}"; do [[ "$1" == "$f" ]] && return 0; done
    return 1
}

# Интерактивный выбор тестов: стрелки — навигация, пробел — отметить.
# Заполняет MT_SEL (1 на выбранный тест). Возврат 1 — пользователь отменил.
# Читает all_funcs/all_names/all_secs из вызывающей run_all (копии MT_CAT_*).
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

    # --- Полный каталог тестов — MT_CAT_* (см. выше) ---
    local all_funcs=( "${MT_CAT_FUNCS[@]}" )
    local all_names=( "${MT_CAT_NAMES[@]}" )
    local all_secs=( "${MT_CAT_SECS[@]}" )
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

    # Среди выбранного есть сетевые тесты — предлагаем BBR + Cake одним
    # вопросом до старта прогона, а не перед каждым из них.
    local _f
    for _f in "${test_funcs[@]}"; do
        [[ "$MT_BBR_SPEED_TESTS" == *" $_f "* ]] && { recommend_bbr_cake; break; }
    done

    mt_run_selected
    (( $? == 3 )) && echo -e "  ${YELLOW}Сейчас идёт другой прогон (в том числе из Telegram) — дождитесь окончания.${NC}"
    return 0
}

# Тесты по списку id через запятую (id — имя функции без run_) → test_funcs/test_names в
# порядке каталога, без повторов. Пустой, кривой или незнакомый ввод → 1 и пустые массивы:
# заданию из Telegram «по умолчанию все тесты» не годится.
mt_sel_from_spec() {
    local spec="$1" rest id k fn LC_ALL=C
    local -A want=()
    test_funcs=(); test_names=()
    [[ -n "$spec" && ",$spec," != *",,"* ]] || return 1
    # режем подстановками: без read и без раскрытия glob (строка приходит снаружи)
    rest="$spec,"
    while [[ -n "$rest" ]]; do
        id="${rest%%,*}"; rest="${rest#*,}"
        [[ "$id" =~ ^[a-z0-9_]+$ ]] && mt_is_test_fn "run_$id" || return 1
        want["run_$id"]=1
    done
    for k in "${!MT_CAT_FUNCS[@]}"; do
        fn="${MT_CAT_FUNCS[$k]}"
        [[ -n "${want[$fn]:-}" ]] || continue
        test_funcs+=( "$fn" ); test_names+=( "${MT_CAT_NAMES[$k]}" )
    done
    (( ${#test_funcs[@]} > 0 ))
}

# Безголовый режим (служба агента): ни одного вопроса, без цветов в журнале, BBR не
# трогаем. SHELL — для script -c: под systemd иначе /bin/sh (dash), а он теряет
# экспортированные функции bash, и тесты молча проходят без метрик.
mt_headless_init() {
    MT_HEADLESS=1; MT_BBR_PROMPTED=1
    RED=""; GREEN=""; YELLOW=""; CYAN=""; BOLD=""; NC=""
    export SHELL=/bin/bash
}

# Одна блокировка на ручной мультитест и задания из Telegram: два бенчмарка разом
# исказят друг друга и столкнутся на блокировке пакетного менеджера. fd 9 держим до
# конца прогона; flock нет — работаем без блокировки. 1 — занято.
mt_run_lock() {
    local f="${MT_LOCK_FILE:-}"
    if [[ -z "$f" ]]; then
        f=/run/multitest.lock
        [[ -d /run && -w /run ]] || f="${TMPDIR:-/tmp}/multitest.lock"
    fi
    command -v flock >/dev/null 2>&1 || return 0
    { exec 9>"$f"; } 2>/dev/null || return 0
    flock -n 9 || { exec 9>&-; return 1; }
}

mt_cat_index() {
    local k
    for k in "${!MT_CAT_FUNCS[@]}"; do [[ "${MT_CAT_FUNCS[$k]}" == "$1" ]] && { echo "$k"; return 0; }; done
    echo 0
}

# Событие задания из Telegram: start | progress | beat | failed (+ k=v). Ответ «cancel» —
# в боте нажали «Остановить»: кладём флаг, прогон увидит его перед следующим тестом.
mt_job_event() {
    [[ -n "${MT_JOB_ID:-}" ]] || return 0
    local tmp kv
    local -a f=( --data-urlencode "type=$1" )
    shift
    for kv in "$@"; do f+=( --data-urlencode "$kv" ); done
    tmp=$(mktemp) || return 0
    MT_API_MAXTIME=15 mt_api POST "/v1/agent/jobs/$MT_JOB_ID/event" "$tmp" "${f[@]}" >/dev/null 2>&1
    mt_resp "$tmp"
    rm -f "$tmp"
    [[ "$MT_RESP_V" == cancel && -n "${MT_JOB_DIR:-}" ]] && : > "$MT_JOB_DIR/cancel"
    return 0
}

mt_job_cancelled() { [[ -n "${MT_JOB_DIR:-}" && -e "$MT_JOB_DIR/cancel" ]]; }

# Прогон test_funcs (≥ 1): зависимости, статусы, каталог сводки, тесты по очереди,
# сводка. Общий для ручного мультитеста и заданий из Telegram. 0 — прогон был,
# 1 — нечего гонять или нет каталога, 3 — занято другим прогоном.
mt_run_selected() {
    local total=${#test_funcs[@]} i num k _f secs now killed stopped=0
    (( total > 0 )) || return 1
    mt_run_lock || return 3

    print_separator "МУЛЬТИТЕСТ — запуск (${total} тест(ов))"
    for k in "${!test_names[@]}"; do
        printf "    ${GREEN}%2d.${NC} %s\n" "$((k + 1))" "${test_names[$k]}"
    done
    echo ""
    if [[ "$MT_HEADLESS" != 1 ]]; then
        echo -e "  ${YELLOW}Ctrl+C${NC} во время теста — пропустить текущий"
        echo -e "  Тесты идут автоматически; нажмите любую клавишу, чтобы выбрать вручную."
        echo ""
    fi
    install_deps_for "${test_funcs[@]}"

    # Статусы для сводки (каталог MT_CAT_* — глобальный: в картинке показываем
    # и невыбранные тесты)
    declare -gA MT_STATUS=()
    for _f in "${test_funcs[@]}"; do MT_STATUS["$_f"]="пропущен"; done
    test_status=(); test_metric=(); test_log=()

    # Каталог для логов и сводки: mktemp, а не имя по секундам — два запуска в одну
    # секунду делили бы каталог, а предсказуемое имя в /tmp от root — плохая идея.
    SUMMARY_TS=$(date +%Y%m%d-%H%M%S)
    if ! SUMMARY_DIR=$(mktemp -d "${MT_SUMMARY_ROOT:-/tmp}/multitest-summary-${SUMMARY_TS}-XXXX" 2>/dev/null); then
        echo -e "  ${RED}Не удалось создать каталог для сводки.${NC}"
        exec 9>&-
        return 1
    fi
    detect_script_flavor

    for (( i = 0; i < total; i++ )); do
        num=$((i + 1))
        test_status[$i]="пропущен"; test_metric[$i]=""; test_log[$i]="$SUMMARY_DIR/test-${num}.log"
        if mt_job_cancelled; then
            echo -e "  ${YELLOW}Остановлено из Telegram — сводка из готовых тестов.${NC}"
            stopped=1
            break
        fi
        mt_job_event progress "i=$num" "n=$total" "t=${test_funcs[$i]#run_}"

        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${CYAN}[${num}/${total}]${NC} Следующий: ${BOLD}${test_names[$i]}${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # --- Автостарт через 5 c, любая клавиша → ручной выбор (не в безголовом) ---
        local action="" _key=""
        if [[ -t 0 && "$MT_HEADLESS" != 1 ]]; then
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
                exec 9>&-
                return 0
                ;;
        esac

        # Задание из Telegram: дедлайн теста для сторожа — ETA × 3, от 2 до 30 минут.
        if [[ -n "${MT_JOB_DIR:-}" ]]; then
            secs=$(( MT_CAT_SECS[$(mt_cat_index "${test_funcs[$i]}")] * 3 ))
            (( secs < 120 )) && secs=120
            (( secs > 1800 )) && secs=1800
            printf -v now '%(%s)T' -1
            printf '%s %s\n' "$num" "$(( now + secs ))" > "$MT_JOB_DIR/cur"
        fi

        # Запуск теста в подоболочке с захватом вывода, Ctrl+C убивает только тест.
        # В безголовом режиме вывод теста — только в лог: в журнале службы ему не место
        # (там полные IP).
        MT_TEST_NUM=$num
        MULTITEST_SKIPPED=0
        trap multitest_skip_handler INT
        if [[ "$MT_HEADLESS" == 1 ]]; then
            ( capture_test "${test_funcs[$i]}" "${test_log[$i]}" ) >/dev/null 2>&1
        else
            ( capture_test "${test_funcs[$i]}" "${test_log[$i]}" )
        fi
        trap - INT
        killed=""
        if [[ -n "${MT_JOB_DIR:-}" ]]; then
            rm -f "$MT_JOB_DIR/cur"
            [[ -f "$MT_JOB_DIR/killed.$num" ]] && killed=$(cat "$MT_JOB_DIR/killed.$num")
        fi

        if [[ "$killed" == timeout ]]; then
            echo -e "  ${YELLOW}Тест не уложился во время и остановлен.${NC}"
            test_status[$i]="ошибка"
        elif [[ -n "$killed" || $MULTITEST_SKIPPED -eq 1 ]]; then
            echo ""
            echo -e "  ${YELLOW}Тест пропущен.${NC}"
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
    (( stopped )) || echo -e "${GREEN}${BOLD}Все тесты завершены! (${total}/${total})${NC}"
    render_and_upload_summary
    exec 9>&-
    return 0
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

# Тесты, ради которых есть смысл предложить BBR + Cake: их результат — скорость
# TCP, на которой congestion control сказывается напрямую; остальным тестам он
# безразличен.
MT_BBR_SPEED_TESTS=" run_iperf3_ru run_iperf3_tlab run_yabs run_bench_sh "

MT_BBR_PROMPTED=0

# Перед сетевыми тестами (iPerf3, YABS, bench.sh) предлагаем включить BBR +
# Cake: без него одиночный TCP-поток на дальнем маршруте недобирает, и скорость
# в тестах выходит ниже реальной. Спрашиваем один раз за запуск скрипта — и на
# весь мультитест один вопрос, а не по одному перед каждым сетевым тестом;
# отказ и молчаливый пропуск (не-TTY, уже включено) запоминаются до конца сеанса.
recommend_bbr_cake() {
    [[ "$MT_BBR_PROMPTED" == "1" ]] && return 0
    MT_BBR_PROMPTED=1

    # Headless (задания Telegram-агента) — интерактивного собеседника нет.
    [[ "${MT_HEADLESS:-0}" == "1" ]] && return 0

    # Уже включено — в том числе из меню утилит: предлагать нечего.
    local cc qd
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    qd=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    [[ "$cc" == "bbr" && "$qd" == "cake" ]] && return 0

    # Отвечать некому (`wget -qO- … | bash`) — тихо идём дальше.
    [[ -t 0 ]] || return 0

    echo ""
    echo -e "  ${YELLOW}Для тестов скорости (iPerf3, YABS, bench.sh) рекомендуем включить${NC}"
    echo -e "  ${YELLOW}BBR + Cake: без него одиночный TCP-поток на дальнем маршруте недобирает.${NC}"
    echo -ne "  ${BOLD}Включить сейчас? [y/д — да · Enter — нет]: ${NC}"
    local answer
    read -r answer
    case "$answer" in
        y | Y | д | Д | yes | да | Yes)
            enable_bbr_cake
            ;;
        *)
            echo -e "  ${CYAN}Оставляем как есть — включить/выключить потом: Утилиты → 1.${NC}"
            ;;
    esac
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
        # Telegram-бот: привязать сервер, проверить связь, запуск тестов из
        # Telegram, отвязать — своё подменю (mt_tg_menu).
        local tg_max=2
        if mt_tg_configured; then
            tg_max=3
            if mt_conf_load 2>/dev/null; then
                echo -e "  ${GREEN}3)${NC}  Telegram-бот — ${BOLD}настроить${NC}       ${CYAN}сейчас: $(mt_tg_label)$(mt_agent_installed && echo ' · запуск из TG вкл')${NC}"
            else
                echo -e "  ${GREEN}3)${NC}  Telegram-бот — ${BOLD}привязать сервер${NC}  ${CYAN}сводки и тесты прямо в Telegram${NC}"
            fi
        fi

        echo ""
        echo -e "  ${RED}0)${NC}  Назад"
        echo ""
        echo -ne "  ${BOLD}Выберите пункт [0-${tg_max}]: ${NC}"
        read -r util_choice || return 0

        case "$util_choice" in
            1) if [[ $bbr_on -eq 1 ]]; then disable_bbr_cake; else enable_bbr_cake; fi; pause_prompt ;;
            2) if [[ $v6_on -eq 1 ]]; then disable_ipv6; else enable_ipv6; fi; pause_prompt ;;
            3) if (( tg_max == 3 )); then mt_tg_menu; else echo -e "${RED}Неверный выбор.${NC}"; pause_prompt; fi ;;
            0) return ;;
            *) echo -e "${RED}Неверный выбор.${NC}"; pause_prompt ;;
        esac
    done
}

# ============================================================
#  Telegram-бот: ключ, запросы к API, конфиг
# ============================================================
# Протокол — docs/telegram-protocol.md. Ответы API — одна строка text/plain,
# разбор регулярками, без eval/source/jq.

mt_tg_configured() { [[ -n "$MT_BOT_API" && -n "$MT_BOT_USERNAME" ]]; }

# Ключ сервера: mtk_ + 64 hex из /dev/urandom. Префикс — чтобы сканеры секретов
# (gitleaks, GitHub) узнавали ключ, если он где-то утечёт.
mt_tok_new() {
    local h
    h=$(od -An -N32 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')
    [[ ${#h} -eq 64 ]] || return 1
    printf 'mtk_%s' "$h"
}

# Запрос к API бота: mt_api МЕТОД ПУТЬ ФАЙЛ_ОТВЕТА [аргументы curl…].
# stdout — HTTP-код (000 — нет связи), код возврата — код curl. Ключ уходит
# заголовком через конфиг curl из stdin (-K -): в argv и в ps его нет. Только
# https, без редиректов (-L) и без -k. На время вызова xtrace выключаем — иначе
# `bash -x` напечатал бы ключ.
mt_api() {
    local method="$1" path="$2" out="$3" xt=0 rc
    shift 3
    [[ $- == *x* ]] && { xt=1; set +x; }
    local base="${MT_API:-$MT_BOT_API}"
    local -a args=(-sS --proto =https --proto-redir =https --connect-timeout 10
                   --max-time "${MT_API_MAXTIME:-30}" -A "$MT_UA" -o "$out" -w '%{http_code}')
    [[ "$method" == GET ]] && args+=(-G)
    [[ "$method" == POST && $# -eq 0 ]] && args+=(--data '')
    if [[ -n "$MT_SRV_TOKEN" ]]; then
        # MT_API_HEADER — ещё один секретный заголовок (код привязки из бота): тоже через
        # stdin, не в argv. Значение проверено вызывающим — только [A-Za-z0-9_:- ].
        { printf 'header = "Authorization: Bearer %s"\n' "$MT_SRV_TOKEN"
          [[ -n "${MT_API_HEADER:-}" ]] && printf 'header = "%s"\n' "$MT_API_HEADER"; } \
            | "$MT_CURL" -K - "${args[@]}" "$@" "${base%/}$path"
    else
        "$MT_CURL" "${args[@]}" "$@" "${base%/}$path" </dev/null
    fi
    rc=$?
    (( xt )) && set -x
    return $rc
}

# Первая строка ответа (≤ 2048 байт) → MT_RESP; первый токен → MT_RESP_V,
# остальные → MT_RESP_A. 1 — ответ пустой.
mt_resp() {
    local line="" rest LC_ALL=C
    MT_RESP=""; MT_RESP_V=""; MT_RESP_A=()
    [[ -s "$1" ]] || return 1
    IFS= read -r line < <(head -c 2048 "$1") || [[ -n "$line" ]] || return 1
    MT_RESP="${line%$'\r'}"
    read -r MT_RESP_V rest <<< "$MT_RESP"
    read -ra MT_RESP_A <<< "$rest"
    [[ -n "$MT_RESP_V" ]]
}

# Текст от бэкенда перед выводом в терминал: без ESC и прочих управляющих, без C1
# в UTF-8 (CSI и компания). Иначе ответ сервера мог бы управлять терминалом.
mt_clean() {
    local s="$1" LC_ALL=C
    s=${s//$'\xc2'[$'\x80'-$'\x9f']/}
    s=${s//[$'\t\r\n\x1f']/}
    s=${s//[$MT_SUM_CTRL]/}
    printf '%s' "$s"
}

# Строки 2…61 ответа (QR и т. п.) — построчно через mt_clean.
mt_resp_body() {
    local l
    tail -n +2 "$1" 2>/dev/null | head -n 60 | while IFS= read -r l || [[ -n "$l" ]]; do
        mt_clean "$l"; echo
    done
}

# agent.conf — данные, а не код: построчно KEY=value по белому списку ключей,
# значения — по регуляркам, никакого source. 0 — прочитан, 1 — файла нет,
# 78 — испорчен (тогда ничего не трогаем и не удаляем).
mt_conf_load() {
    local line k v id="" tok="" api="" bot="" LC_ALL=C
    [[ -f "$MT_CONF" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=${line%$'\r'}
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]] || return 78
        k="${BASH_REMATCH[1]}"; v="${BASH_REMATCH[2]}"
        case "$k" in
            MT_SRV_ID)    [[ "$v" =~ ^[A-Za-z0-9]{8,32}$ ]] || return 78; id="$v" ;;
            MT_SRV_TOKEN) [[ "$v" =~ ^mtk_[0-9a-f]{64}$ ]] || return 78; tok="$v" ;;
            MT_API)       [[ "$v" =~ ^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?(/[A-Za-z0-9._~/-]*)?$ ]] || return 78; api="$v" ;;
            MT_BOT)       [[ "$v" =~ ^[A-Za-z0-9_]{5,32}$ ]] || return 78; bot="$v" ;;
            MT_LIM_GAP|MT_LIM_DAY|MT_LIM_HEAVY)
                          [[ "$v" =~ ^[0-9]{1,6}$ ]] || return 78; printf -v "$k" '%s' "$v" ;;
            *)            return 78 ;;
        esac
    done < "$MT_CONF"
    [[ -n "$id" && -n "$tok" && -n "$api" && -n "$bot" ]] || return 78
    MT_SRV_ID="$id"; MT_SRV_TOKEN="$tok"; MT_API="$api"; MT_BOT="$bot"
}

# Запись атомарно: временный файл в том же каталоге под umask 077, потом mv.
mt_conf_save() {
    local xt=0 rc
    [[ $- == *x* ]] && { xt=1; set +x; }
    (
        umask 077
        mkdir -p "$MT_STATE_DIR" && chmod 700 "$MT_STATE_DIR" || exit 1
        tmp=$(mktemp "$MT_STATE_DIR/.agent.conf.XXXXXX") || exit 1
        if printf 'MT_SRV_ID=%s\nMT_SRV_TOKEN=%s\nMT_API=%s\nMT_BOT=%s\n' \
                "$MT_SRV_ID" "$MT_SRV_TOKEN" "$MT_API" "$MT_BOT" > "$tmp" \
            && chmod 600 "$tmp" && mv -f "$tmp" "$MT_CONF"; then
            exit 0
        fi
        rm -f "$tmp"; exit 1
    )
    rc=$?
    (( xt )) && set -x
    return $rc
}

mt_conf_wipe() {
    rm -f "$MT_CONF"
    MT_SRV_ID=""; MT_SRV_TOKEN=""; MT_API=""; MT_BOT=""
}

# Регулярка в C-локали: в UTF-8 диапазоны вида [A-Za-z] ловят лишнее. BASH_REMATCH — глобальный.
mt_match() { local LC_ALL=C; [[ "$2" =~ $1 ]]; }

# Вопрос «да/нет» с клавиатуры: fd 8 открывает вызывающий (exec 8<"$MT_TTY"). Не stdin:
# при `curl … | bash` stdin — это сам скрипт. Да — y/д и полные слова, иначе — нет.
# Только `printf '%s'`: в тексте бывает имя подтвердившего из Telegram, а `echo -e`
# доинтерпретировал бы `\e`, `\c` и `\n` из него и отдал бы терминал бэкенду.
mt_tg_ask() {
    local a=""
    printf '%s' "$1"
    IFS= read -r a <&8 || { echo; return 1; }
    case "$a" in y|Y|yes|Yes|д|Д|да|Да) return 0 ;; *) return 1 ;; esac
}

mt_tg_label() {
    if mt_conf_load 2>/dev/null; then printf 'привязан к @%s' "$MT_BOT"; else printf 'не привязан'; fi
}

# Понятная строка вместо ответа бэкенда: тело ответа в терминал не печатаем.
mt_tg_say_fail() {   # <HTTP-код> <файл ответа>
    local code="$1"
    mt_resp "$2" 2>/dev/null
    if [[ "$code" == 000 || -z "$code" ]]; then
        echo -e "  ${YELLOW}Бот недоступен — проверьте сеть и попробуйте позже.${NC}"
    elif [[ "$MT_RESP_V" == retry ]]; then
        echo -e "  ${YELLOW}Слишком много попыток — повторите через несколько минут.${NC}"
    elif [[ "$MT_RESP_V" == closed ]]; then
        echo -e "  ${YELLOW}Бот сейчас закрыт владельцем — попробуйте позже.${NC}"
    else
        echo -e "  ${YELLOW}Бот ответил неожиданно (HTTP $(mt_clean "${code:0:3}")). Попробуйте позже.${NC}"
    fi
}

# Привязка сервера к боту (docs/telegram-protocol.md): ключ создаём здесь. Без кода —
# device flow: бот показывает три кода, а здесь человек видит, КТО подтвердил. С кодом
# mtp_… из команды «Добавить сервер» аккаунт известен сразу — ни ссылки, ни QR. В обоих
# случаях здесь спрашиваем «это ваш Telegram?» и пишем конфиг только после ok на
# pair/confirm. $1 — код из бота или пусто. 0 — привязан, 1 — нет.
mt_tg_pair() {
    local join="${1:-}" tmp code ttl match who="" approved=0 min re kv deadline q rc=1
    local -a form=()
    print_separator "Telegram-бот — привязка сервера"
    if ! mt_tg_configured; then
        echo -e "  ${YELLOW}Telegram-бот ещё не настроен в этой версии скрипта.${NC}"; return 1
    fi
    if [[ -n "$join" ]] && ! mt_match '^mtp_[A-Za-z0-9]{24}$' "$join"; then
        echo -e "  ${YELLOW}Это не код из бота. Скопируйте команду заново: в боте «Добавить сервер».${NC}"; return 1
    fi
    if ! ( exec 8<"$MT_TTY" ) 2>/dev/null; then
        echo -e "  ${YELLOW}Привязка — только из терминала: ответы нужны с клавиатуры.${NC}"; return 1
    fi
    if ! ( umask 077; mkdir -p "$MT_STATE_DIR" ) 2>/dev/null || [[ ! -w "$MT_STATE_DIR" ]]; then
        echo -e "  ${YELLOW}Нужны права root: ключ сервера хранится в ${MT_STATE_DIR}.${NC}"; return 1
    fi
    exec 8<"$MT_TTY"
    tmp=$(mktemp -d) || { exec 8<&-; return 1; }

    if mt_conf_load; then
        if ! mt_tg_ask "  Сервер уже привязан к @${MT_BOT}. Привязать заново? [y/д — да · Enter — нет]: "; then
            rm -rf "$tmp"; exec 8<&-; return 0
        fi
        # Служба агента — до bye: иначе она получила бы «revoked» и стёрла бы уже
        # новый ключ. Включить её снова предложим после привязки.
        mt_agent_installed && mt_agent_uninstall >/dev/null
        MT_API_MAXTIME=15 mt_api POST /v1/agent/bye "$tmp/r" >/dev/null 2>&1
        mt_conf_wipe
    fi

    if ! MT_SRV_TOKEN=$(mt_tok_new); then
        echo -e "  ${RED}Не удалось создать ключ: нет /dev/urandom.${NC}"; rm -rf "$tmp"; exec 8<&-; return 1
    fi
    MT_PAIR_ABORT=0
    trap 'MT_PAIR_ABORT=1' INT

    echo -e "  Определяю адрес и железо сервера..."
    gather_system_facts
    mt_cpu_split
    for kv in "ip4=$(mask_ip "$SYS_IP4")" "ip6=$(mask_ip "$SYS_IP6")" "country=$SYS_COUNTRY" \
              "city=$SYS_CITY" "asn=$SYS_ASN" "cpu=$CPU_NAME" "cores=$SYS_CORES" "ram=$SYS_RAM" \
              "disk=$SYS_DISK" "os=$SYS_OS" "virt=$SYS_VIRT" "v=$SCRIPT_VERSION" "p=1"; do
        form+=( --data-urlencode "${kv//[$'\r\n\t']/ }" )
    done
    deadline=$(( SECONDS + 3600 ))
    if [[ -n "$join" ]]; then
        # Код — заголовком через stdin curl (MT_API_HEADER), как и ключ: в argv его нет.
        code=$(MT_API_HEADER="X-Pair-Token: $join" MT_API_MAXTIME=30 mt_api POST /v1/pair/claim "$tmp/r" "${form[@]}")
        if (( MT_PAIR_ABORT == 0 )); then
            if [[ "$code" == 200 ]] && mt_resp "$tmp/r" && [[ "$MT_RESP_V" == approved ]]; then
                approved=1; who="${MT_RESP_A[0]:-}"
            elif mt_resp "$tmp/r" && [[ "$MT_RESP" == "err token" ]]; then
                echo -e "  ${YELLOW}Команда из бота устарела или уже использована.${NC}"
                echo -e "  ${YELLOW}Нажмите в боте «Добавить сервер» — там будет новая.${NC}"
            elif [[ "$MT_RESP" == "err limit" ]]; then
                echo -e "  ${YELLOW}В боте слишком много серверов или незавершённых привязок — отвяжите лишние.${NC}"
            else
                mt_tg_say_fail "$code" "$tmp/r"
            fi
        fi
    else
        code=$(MT_API_MAXTIME=30 mt_api POST /v1/pair/start "$tmp/r" "${form[@]}")
        re='^ok ([A-Za-z0-9]{22}) ([0-9]{1,4}) ([0-9]{2})( .*)?$'
        if (( MT_PAIR_ABORT == 0 )) && { [[ "$code" != 200 ]] || ! mt_resp "$tmp/r" || ! mt_match "$re" "$MT_RESP"; }; then
            mt_tg_say_fail "$code" "$tmp/r"
            MT_SRV_TOKEN=""; rm -rf "$tmp"; exec 8<&-; trap - INT; return 1
        fi
        if (( MT_PAIR_ABORT == 0 )); then
            code="${BASH_REMATCH[1]}"; ttl="${BASH_REMATCH[2]}"; match="${BASH_REMATCH[3]}"
            (( ttl < 60 )) && ttl=60
            (( ttl > 1800 )) && ttl=1800
            min=$(( (ttl + 59) / 60 ))
            echo ""
            echo -e "  ${BOLD}Откройте в Telegram:${NC} https://t.me/${MT_BOT_USERNAME}?start=p_${code}"
            if [[ "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" == *[Uu][Tt][Ff]* ]]; then
                echo ""
                mt_resp_body "$tmp/r" | sed 's/^/  /'
            fi
            echo ""
            echo -e "  ${BOLD}Код для бота: ${match}${NC}"
            echo -e "  ${CYAN}Ждём подтверждения в Telegram (до ${min} мин). Ctrl+C — отмена.${NC}"

            deadline=$(( SECONDS + ttl ))
            while (( SECONDS < deadline && MT_PAIR_ABORT == 0 )); do
                code=$(MT_API_MAXTIME=15 mt_api POST /v1/pair/poll "$tmp/r")
                (( MT_PAIR_ABORT )) && break
                if [[ "$code" == 200 ]] && mt_resp "$tmp/r"; then
                    case "$MT_RESP_V" in
                        approved) approved=1; who="${MT_RESP_A[0]:-}"; break ;;
                        denied)   echo -e "  ${YELLOW}Привязка отменена в Telegram.${NC}"; break ;;
                        expired)  echo -e "  ${YELLOW}Время вышло — запустите привязку заново.${NC}"; break ;;
                    esac
                fi
                sleep 2
            done
        fi
    fi

    if (( MT_PAIR_ABORT )); then
        echo ""
        echo -e "  ${YELLOW}Привязка прервана — ничего не сохранено.${NC}"
    elif (( approved )); then
        who=$(printf '%b' "${who//%/\\x}")
        who=$(mt_clean "$who")
        # Имя — недоверенный ввод бэкенда. mt_clean вырезает управляющие, но не «\»,
        # а он — единственное, чем из текста собирается escape-последовательность для
        # стоков с `echo -e` (\e, \c): вырезаем до показа имени.
        who=${who//\\/}
        who=$(vcut "$who" 64)
        # с кодом: чужая команда привязала бы этот сервер к чужому аккаунту — имя показываем
        if [[ -n "$join" ]]; then
            q="  Команда из Telegram-аккаунта ${BOLD}${who}${NC}. Привязать сервер к нему? [y/д — да · Enter — нет]: "
        else
            q="  Подтвердил Telegram: ${BOLD}${who}${NC}. Это вы? [y/д — да · Enter — нет]: "
        fi
        if mt_tg_ask "$q"; then
            code=$(MT_API_MAXTIME=30 mt_api POST /v1/pair/confirm "$tmp/r" --data-urlencode "answer=yes")
            if [[ "$code" == 200 ]] && mt_resp "$tmp/r" && mt_match '^ok ([A-Za-z0-9]{8,32})$' "$MT_RESP"; then
                MT_SRV_ID="${BASH_REMATCH[1]}"; MT_API="$MT_BOT_API"; MT_BOT="$MT_BOT_USERNAME"
                if mt_conf_save; then
                    echo -e "  ${GREEN}Сервер привязан. Сводки мультитеста будут приходить в Telegram.${NC}"
                    rc=0
                    mt_agent_offer "$who"
                else
                    echo -e "  ${RED}Не удалось сохранить ключ в ${MT_CONF}.${NC}"
                fi
            else
                mt_tg_say_fail "$code" "$tmp/r"
            fi
        else
            MT_API_MAXTIME=30 mt_api POST /v1/pair/confirm "$tmp/r" --data-urlencode "answer=no" >/dev/null 2>&1
            echo -e "  ${YELLOW}Отменено — на сервере ничего не сохранено.${NC}"
        fi
    elif (( SECONDS >= deadline )); then
        echo -e "  ${YELLOW}Время вышло — запустите привязку заново.${NC}"
    fi

    (( rc == 0 )) || { MT_SRV_TOKEN=""; MT_SRV_ID=""; MT_API=""; MT_BOT=""; }
    rm -rf "$tmp"; exec 8<&-; trap - INT
    return $rc
}

# Отвязка: bye (ошибки не мешают) и ключ долой. Без терминала — без вопроса.
mt_tg_unpair() {
    local tmp
    print_separator "Telegram-бот — отвязка сервера"
    if ! mt_conf_load; then echo -e "  Сервер не привязан."; return 0; fi
    if ( exec 8<"$MT_TTY" ) 2>/dev/null; then
        exec 8<"$MT_TTY"
        if ! mt_tg_ask "  Отвязать сервер от @${MT_BOT}? Сводки перестанут приходить. [y/д — да · Enter — нет]: "; then
            exec 8<&-; return 0
        fi
        exec 8<&-
    fi
    mt_agent_installed && mt_agent_uninstall >/dev/null
    if tmp=$(mktemp -d); then
        MT_API_MAXTIME=15 mt_api POST /v1/agent/bye "$tmp/r" >/dev/null 2>&1
        rm -rf "$tmp"
    fi
    mt_conf_wipe
    echo -e "  ${GREEN}Сервер отвязан, ключ удалён.${NC}"
}

# Статус и проверка связи — через hello. 0 — привязан и бот ответил, 1 — не привязан
# (или отвязан в боте — тогда ключ стираем), 2 — привязан, но бот недоступен.
mt_tg_status() {
    local tmp code t
    if ! mt_conf_load; then
        echo -e "  Сервер не привязан. Привязать: ${BOLD}multitest --pair${NC} или Утилиты → Telegram-бот."; return 1
    fi
    tmp=$(mktemp -d) || return 2
    t=$(IFS=,; printf '%s' "${MT_CAT_FUNCS[*]//run_/}")
    code=$(MT_API_MAXTIME=15 mt_api POST /v1/agent/hello "$tmp/r" --data-urlencode "v=$SCRIPT_VERSION" \
           --data-urlencode "p=1" --data-urlencode "t=$t")
    mt_resp "$tmp/r"
    rm -rf "$tmp"
    if [[ "$MT_RESP_V" == revoked ]]; then
        mt_conf_wipe
        echo -e "  ${YELLOW}Сервер отвязан в боте — ключ на сервере удалён.${NC}"; return 1
    fi
    if [[ "$code" == 200 && "$MT_RESP_V" == ok ]]; then
        echo -e "  ${GREEN}Привязан к @${MT_BOT} · связь с ботом есть.${NC}"
        if mt_agent_installed; then
            if systemctl is-active --quiet multitest-agent 2>/dev/null; then
                echo -e "  ${GREEN}Запуск из Telegram включён — служба multitest-agent работает.${NC}"
            else
                echo -e "  ${YELLOW}Запуск из Telegram включён, но служба не работает: journalctl -u multitest-agent.${NC}"
            fi
        else
            echo -e "  Запуск из Telegram выключен — включить: multitest → Утилиты → Telegram-бот."
        fi
        return 0
    fi
    echo -e "  ${YELLOW}Привязан к @${MT_BOT} · бот сейчас недоступен (HTTP $(mt_clean "${code:0:3}")).${NC}"
    return 2
}

# Подменю «Утилиты → Telegram-бот».
mt_tg_menu() {
    local c paired
    while true; do
        print_header
        echo -e "  ${CYAN}${BOLD}── Telegram-бот ──${NC}"
        echo ""
        echo -e "  Бот ${BOLD}@${MT_BOT_USERNAME}${NC} · сервер $(mt_tg_label)"
        echo -e "  Сводки мультитеста приходят в бота — с постом, который можно поправить и переслать."
        echo ""
        paired=0; mt_conf_load && paired=1
        if (( paired )); then
            echo -e "  ${GREEN}1)${NC}  Проверить связь"
            if mt_agent_installed; then
                echo -e "  ${GREEN}2)${NC}  Запуск тестов из Telegram — ${BOLD}выключить${NC}"
                echo -e "  ${GREEN}3)${NC}  Обновить агент (скрипт службы)"
            else
                echo -e "  ${GREEN}2)${NC}  Запуск тестов из Telegram — ${BOLD}включить${NC}"
            fi
            echo -e "  ${GREEN}4)${NC}  Привязать заново"
            echo -e "  ${RED}5)${NC}  Отвязать сервер"
        else
            echo -e "  ${GREEN}1)${NC}  Привязать сервер"
        fi
        echo ""
        echo -e "  ${RED}0)${NC}  Назад"
        echo ""
        echo -ne "  ${BOLD}Выберите пункт: ${NC}"
        read -r c || return 0
        case "$paired:$c" in
            1:1) mt_tg_status; pause_prompt ;;
            1:2) if mt_agent_installed; then mt_agent_uninstall; else mt_agent_install; fi; pause_prompt ;;
            1:3) mt_agent_installed && mt_agent_install; pause_prompt ;;
            1:4|0:1) mt_tg_pair; pause_prompt ;;
            1:5) mt_tg_unpair; pause_prompt ;;
            *:0) return ;;
        esac
    done
}

# ============================================================
#  Telegram-бот: агент — тесты по заданиям из бота
# ============================================================
# Служба multitest-agent ждёт задание у бота (long-poll ~25 с) и гоняет только тесты из
# каталога (MT_CAT_FUNCS). Бот не может обойти локальные лимиты и ничего не меняет в
# системе: BBR, IPv6 и прочее — только руками. Ключ стирается только по явному «revoked».

mt_systemd() { [[ -d "$MT_SYSTEMD" ]]; }
mt_agent_installed() { [[ -f "$MT_AGENT_UNIT" ]]; }
MT_HEAVY_RE=',(yabs|iperf3_ru|iperf3_tlab|bench_sh),'

# hello с флагом агента (1 — служба работает, 0 — выключена) и лимитами. stdout — код HTTP.
mt_agent_hello() {
    local tmp code t
    tmp=$(mktemp) || return 1
    t=$(IFS=,; printf '%s' "${MT_CAT_FUNCS[*]//run_/}")
    code=$(MT_API_MAXTIME=15 mt_api POST /v1/agent/hello "$tmp" --data-urlencode "v=$SCRIPT_VERSION" \
        --data-urlencode "p=1" --data-urlencode "t=$t" --data-urlencode "agent=$1" \
        --data-urlencode "lim=$MT_LIM_GAP,$MT_LIM_DAY,$MT_LIM_HEAVY")
    mt_resp "$tmp"
    rm -f "$tmp"
    printf '%s' "$code"
}

# Локальные лимиты: история запусков — в $MT_AGENT_DIR/agent.runs («время тяжёлый»).
# 0 и «0» — можно; 1 и сколько секунд ждать — нельзя.
mt_agent_limits() {
    local f="$MT_AGENT_DIR/agent.runs" now t h last=0 day=0 heavy=0 want=0
    printf -v now '%(%s)T' -1
    [[ ",$1," =~ $MT_HEAVY_RE ]] && want=1
    if [[ -f "$f" ]]; then
        while read -r t h; do
            [[ "$t" =~ ^[0-9]+$ ]] || continue
            (( t > now )) && t=$now                # часы ушли назад — не верим будущему
            (( t > last )) && last=$t
            if (( now - t < 86400 )); then
                day=$(( day + 1 ))
                [[ "$h" == 1 ]] && heavy=$(( heavy + 1 ))
            fi
        done < "$f"
    fi
    if (( last > 0 && now - last < MT_LIM_GAP )); then echo $(( MT_LIM_GAP - (now - last) )); return 1; fi
    if (( day >= MT_LIM_DAY )); then echo 3600; return 1; fi
    if (( want && heavy >= MT_LIM_HEAVY )); then echo 3600; return 1; fi
    echo 0
}

mt_agent_record() {
    local f="$MT_AGENT_DIR/agent.runs" now h=0
    printf -v now '%(%s)T' -1
    [[ ",$1," =~ $MT_HEAVY_RE ]] && h=1
    { tail -n 49 "$f" 2>/dev/null; printf '%s %s\n' "$now" "$h"; } > "$f.tmp" && mv -f "$f.tmp" "$f"
}

# Погасить текущий тест задания: всю группу процессов лидера сессии из script,
# TERM, через 10 с — KILL. Маркер killed.<номер> скажет прогону, что случилось.
mt_agent_kill_current() {   # <cancel|timeout>
    local num tdl pid
    [[ -f "$MT_JOB_DIR/cur" ]] || return 0
    read -r num tdl < "$MT_JOB_DIR/cur"
    [[ "$num" =~ ^[0-9]+$ ]] || return 0
    printf '%s' "$1" > "$MT_JOB_DIR/killed.$num"
    pid=$(cat "$MT_JOB_DIR/pid.$num" 2>/dev/null)
    [[ "$pid" =~ ^[0-9]+$ ]] || return 0
    kill -TERM -- "-$pid" 2>/dev/null
    sleep 10
    kill -KILL -- "-$pid" 2>/dev/null
    return 0
}

# Сторож задания (в фоне): beat раз в 15 с — ответ «cancel» гасит тест; дедлайн теста
# (ETA × 3) и всего прогона (60 мин) — тоже. Останавливается, когда прогон положит done.
mt_agent_watchdog() {   # <дедлайн прогона, epoch>
    local tmp now num tdl
    tmp=$(mktemp) || return 0
    while [[ ! -e "$MT_JOB_DIR/done" ]]; do
        sleep 15
        [[ -e "$MT_JOB_DIR/done" ]] && break
        MT_API_MAXTIME=15 mt_api POST "/v1/agent/jobs/$MT_JOB_ID/event" "$tmp" --data-urlencode "type=beat" >/dev/null 2>&1
        if mt_resp "$tmp" && [[ "$MT_RESP_V" == cancel ]]; then
            : > "$MT_JOB_DIR/cancel"
            mt_agent_kill_current cancel
            continue
        fi
        printf -v now '%(%s)T' -1
        if (( now > $1 )); then
            : > "$MT_JOB_DIR/cancel"
            mt_agent_kill_current timeout
        elif [[ -f "$MT_JOB_DIR/cur" ]]; then
            read -r num tdl < "$MT_JOB_DIR/cur"
            [[ "$tdl" =~ ^[0-9]+$ ]] && (( now > tdl )) && mt_agent_kill_current timeout
        fi
    done
    rm -f "$tmp"
}

# Одно задание: «job <id> <тесты через запятую> [k=v…]». Всё незнакомое — отказ.
MT_AGENT_SEEN=""
mt_agent_job() {
    local line="$1" jid spec lw rc deadline wpid d now
    local re='^job ([A-Za-z0-9_-]{16,32}) ([a-z0-9_,]{1,200})( [a-z]{1,16}=[A-Za-z0-9_.,:-]{0,64}){0,8}$'
    if ! mt_match "$re" "$line"; then
        echo "агент: непонятное задание — пропускаю"
        return 1
    fi
    jid="${BASH_REMATCH[1]}"; spec="${BASH_REMATCH[2]}"
    [[ " $MT_AGENT_SEEN " == *" $jid "* ]] && return 0          # это задание уже было
    MT_AGENT_SEEN="$(printf '%s\n' $MT_AGENT_SEEN | tail -n 19 | tr '\n' ' ')$jid"
    MT_JOB_ID="$jid"
    if ! mt_sel_from_spec "$spec"; then
        mt_job_event failed "reason=bad_tests"; MT_JOB_ID=""; return 1
    fi
    if ! lw=$(mt_agent_limits "$spec"); then
        echo "агент: лимит запусков — следующий через ${lw} c"
        mt_job_event failed "reason=local_limit" "wait=$lw"; MT_JOB_ID=""; return 1
    fi
    mkdir -p "$MT_AGENT_DIR/runs" 2>/dev/null
    if ! MT_JOB_DIR=$(mktemp -d "$MT_AGENT_DIR/runs/job-XXXXXX" 2>/dev/null); then
        mt_job_event failed "reason=no_dir"; MT_JOB_ID=""; MT_JOB_DIR=""; return 1
    fi
    echo "агент: задание $jid — тесты $spec"
    mt_job_event start "n=${#test_funcs[@]}"
    printf -v now '%(%s)T' -1
    deadline=$(( now + 3600 ))
    mt_agent_watchdog "$deadline" &
    wpid=$!
    MT_SUMMARY_ROOT="$MT_JOB_DIR" MT_IMGDB=0 mt_run_selected
    rc=$?
    : > "$MT_JOB_DIR/done"
    kill "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
    if (( rc == 3 )); then
        mt_job_event failed "reason=busy"
    elif (( rc == 0 )); then
        mt_agent_record "$spec"
        [[ -e "$SUMMARY_DIR/tg.ok" ]] || mt_job_event failed "reason=no_deliver"
    else
        mt_job_event failed "reason=no_dir"
    fi
    # в каталоге заданий держим последние три прогона
    for d in $(ls -1dt "$MT_AGENT_DIR"/runs/job-* 2>/dev/null | tail -n +4); do rm -rf "$d"; done
    MT_JOB_ID=""; MT_JOB_DIR=""
    return 0
}

# Сервер отвязали в боте: ключ, служба и unit — прочь. Порядок важен: сначала конфиг,
# потом disable без --now (иначе systemd убьёт нас посреди уборки); выход 78 служба
# не перезапускает (RestartPreventExitStatus=78).
mt_agent_selfremove() {
    mt_conf_wipe
    if mt_systemd; then
        systemctl disable multitest-agent >/dev/null 2>&1
        rm -f "$MT_AGENT_UNIT"
        systemctl daemon-reload >/dev/null 2>&1
    fi
}

# --agent: главный цикл службы. 78 — работать нечем (нет ключа, конфиг испорчен, отвязан).
mt_agent_main() {
    local rc code tmp backoff=5 polls=0
    mt_conf_load; rc=$?
    if (( rc == 1 )); then echo "агент: сервер не привязан — выхожу"; return 78; fi
    if (( rc == 78 )); then echo "агент: $MT_CONF испорчен — ничего не трогаю"; return 78; fi
    mt_headless_init
    mkdir -p "$MT_AGENT_DIR/runs" "$MT_AGENT_DIR/work" 2>/dev/null
    cd "$MT_AGENT_DIR/work" 2>/dev/null || cd /tmp || return 1
    tmp=$(mktemp) || return 1
    echo "агент: запущен, бот @${MT_BOT}"
    mt_agent_hello 1 >/dev/null
    [[ "$MT_RESP_V" == revoked ]] && { echo "агент: сервер отвязан в боте — удаляю ключ и службу"; mt_agent_selfremove; return 78; }
    while :; do
        if [[ -n "${MT_AGENT_POLLS:-}" ]]; then        # для тестов: ограничить число опросов
            (( polls++ >= MT_AGENT_POLLS )) && break
        fi
        code=$(MT_API_MAXTIME=60 mt_api GET /v1/agent/poll "$tmp" --data-urlencode "wait=25")
        mt_resp "$tmp"
        case "$code:$MT_RESP_V" in
            200:job)     backoff=5; mt_agent_job "$MT_RESP" ;;
            200:idle)    backoff=5 ;;
            200:revoked) echo "агент: сервер отвязан в боте — удаляю ключ и службу"
                         rm -f "$tmp"; mt_agent_selfremove; return 78 ;;
            200:upgrade) echo "агент: бот просит обновить multitest (multitest → Утилиты → Telegram-бот → обновить агент)"; sleep 3600 ;;
            *)           echo "агент: бот недоступен (HTTP $(mt_clean "${code:0:3}")) — повтор через ${backoff} c"
                         sleep $(( backoff + RANDOM % 5 ))
                         backoff=$(( backoff * 2 )); (( backoff > 21600 )) && backoff=21600 ;;
        esac
    done
    rm -f "$tmp"
    return 0
}

# Включить запуск из Telegram: скрипт в /usr/local/bin (проверяем, что он умеет агента),
# unit systemd, enable --now. Без systemd пока не умеем — доставка сводок работает и так.
mt_agent_install() {
    local bin=/usr/local/bin/multitest tmp
    if ! mt_systemd; then
        echo -e "  ${YELLOW}Запуск из Telegram пока работает только с systemd — здесь его нет.${NC}"; return 1
    fi
    tmp=$(mktemp) || return 1
    if [[ -f "$0" && -r "$0" ]] && head -1 "$0" | grep -q '^#!/bin/bash'; then
        cp "$0" "$tmp"
    elif ! curl -fsSL --proto =https --max-time 60 "$REPO_URL" -o "$tmp" 2>/dev/null; then
        rm -f "$tmp"; echo -e "  ${RED}Не удалось скачать multitest для службы.${NC}"; return 1
    fi
    if ! head -1 "$tmp" | grep -q '^#!/bin/bash' || ! bash -n "$tmp" 2>/dev/null \
        || [[ "$(bash "$tmp" --agent-selftest 2>/dev/null)" != agent-ok ]]; then
        rm -f "$tmp"
        echo -e "  ${YELLOW}Эта версия multitest не умеет запуск из Telegram. Установите свежую:${NC}"
        echo -e "    curl -sL $REPO_URL -o $bin && chmod +x $bin && multitest"
        return 1
    fi
    if [[ ! "$tmp" -ef "$bin" ]] && ! { [[ -f "$0" ]] && [[ "$0" -ef "$bin" ]]; }; then
        install -m 755 "$tmp" "$bin" || { rm -f "$tmp"; return 1; }
    fi
    rm -f "$tmp"
    mkdir -p "$MT_AGENT_DIR/work" "$MT_AGENT_DIR/runs"
    cat > "$MT_AGENT_UNIT" <<EOF
[Unit]
Description=Multitest agent — тесты по заданиям из Telegram-бота
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$bin --agent
Restart=on-failure
RestartSec=15
RestartPreventExitStatus=78
# bench.sh и YABS пишут тестовые файлы в текущий каталог, а под systemd это /
WorkingDirectory=$MT_AGENT_DIR/work
# SHELL обязателен: иначе script -c идёт через /bin/sh (dash), и тесты теряют функции
Environment=SHELL=/bin/bash HOME=/root TERM=xterm-256color
StandardInput=null

[Install]
WantedBy=multi-user.target
EOF
    if systemctl daemon-reload >/dev/null 2>&1 && systemctl enable --now multitest-agent >/dev/null 2>&1; then
        echo -e "  ${GREEN}Запуск из Telegram включён: в боте у сервера появилась кнопка «Запустить тест».${NC}"
        return 0
    fi
    echo -e "  ${RED}systemd не запустил службу multitest-agent — см. journalctl -u multitest-agent.${NC}"
    return 1
}

mt_agent_uninstall() {
    if mt_systemd; then
        systemctl disable --now multitest-agent >/dev/null 2>&1
        rm -f "$MT_AGENT_UNIT"
        systemctl daemon-reload >/dev/null 2>&1
    fi
    mt_conf_load 2>/dev/null && mt_agent_hello 0 >/dev/null
    echo -e "  ${GREEN}Запуск из Telegram выключен.${NC}"
}

# Вопрос согласия: что агент может и чего не может. Только с клавиатуры (fd 8).
mt_agent_offer() {   # <кто подтвердил>
    mt_systemd || return 0
    echo ""
    echo -e "  ${BOLD}Запуск тестов прямо из Telegram${NC}"
    echo -e "  Служба multitest-agent будет спрашивать у бота задания и запускать ${BOLD}только${NC} тесты"
    echo -e "  Multitest. Настройки системы она не меняет (ставит лишь пакеты для тестов — как ручной"
    echo -e "  запуск). Лимиты: не чаще раза в $(( MT_LIM_GAP / 60 )) мин, до ${MT_LIM_DAY} прогонов в сутки, тяжёлых"
    echo -e "  (YABS, iPerf3, bench.sh) — до ${MT_LIM_HEAVY}. Выключить: multitest → Утилиты → Telegram-бот."
    if mt_tg_ask "  Разрешить запуск тестов из Telegram для ${BOLD}$1${NC}? [y/д — да · Enter — нет]: "; then
        mt_agent_install
    else
        echo -e "  ${CYAN}Хорошо — только сводки. Включить позже: multitest → Утилиты → Telegram-бот.${NC}"
    fi
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

    # Имя теста ниже попадает в строку команды для script -c: только из каталога,
    # иначе это инъекция (а с заданиями из Telegram имя приходит снаружи).
    mt_is_test_fn "$fn" || { echo "capture_test: неизвестный тест «$fn»" >&2; return 2; }

    export RED GREEN YELLOW CYAN BOLD NC SCRIPT_VERSION
    export -f print_separator check_and_install install_package detect_pkg_manager
    export -f "${MT_CAT_FUNCS[@]}"

    if [[ "$SCRIPT_CAPTURE" == "util" && -n "${MT_JOB_DIR:-}" && -n "${MT_TEST_NUM:-}" ]]; then
        # Задание из Telegram: script запускает тест лидером новой сессии — его pid и
        # есть группа процессов. По нему сторож гасит тест вместе с fio/iperf3/geekbench,
        # а не один script (дети иначе остались бы сиротами и исказили бы следующий прогон).
        COLUMNS=200 script -q -c "echo \$\$ > '$MT_JOB_DIR/pid.$MT_TEST_NUM'; stty cols 200 2>/dev/null; bash -c '$fn'" "$logfile"
    elif [[ "$SCRIPT_CAPTURE" == "util" ]]; then
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
#
# По умолчанию просим 72 часа, а не «бессрочно», и это не про место на диске.
# Всё, что дольше, imgdb пережимает: одна и та же страница приезжает обратно с
# 17 уникальными цветами вместо 825 (замерено — залил один файл с разными ttl
# и сравнил ответы). Монохромной карточке это было безразлично, но в подписи
# спонсора есть флаги, и на 17 цветах они выцветают в серое: слоты в палитре
# достаются цветам по числу пикселей, а флаг занимает доли процента страницы.
# На 72 часах палитру не трогают вовсе — 252 цвета, флаги и текст как были.
# Кому нужна вечная ссылка, ставит MT_IMGDB_TTL=0 и мирится с флагами.
MT_IMGDB_TTL="${MT_IMGDB_TTL:-259200}"

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

# Качает шрифт и оставляет файл, только если это действительно TrueType
# (магия 00 01 00 00): CDN на ошибке отдаёт HTML со статусом 200, а битый файл
# в fontconfig ломает подбор молча — в картинке просто поедут метрики.
mt_fetch_ttf() {
    local url="$1" dst="$2"
    if command -v curl &>/dev/null; then
        curl -fsSL --max-time 30 "$url" -o "$dst" 2>/dev/null
    else
        wget -qO "$dst" "$url" 2>/dev/null
    fi
    [[ -s "$dst" ]] && [[ "$(head -c4 "$dst" 2>/dev/null | od -An -tx1 | tr -d ' \n')" == "00010000" ]] && return 0
    rm -f "$dst"; return 1
}

# Каталог для шрифта: системный, если пускают, иначе пользовательский —
# fontconfig подхватит оба.
mt_font_dir() {
    local d="/usr/share/fonts/truetype/$1"
    mkdir -p "$d" 2>/dev/null && { printf '%s' "$d"; return 0; }
    d="$HOME/.local/share/fonts/$1"
    mkdir -p "$d" 2>/dev/null && printf '%s' "$d"
}

# Best-effort: ставит шрифт сводки — Onest, им набран макет 5b: полная кириллица
# и все начертания 400–900 (900 — цифры в фигурах, 800 — заголовки, 700 —
# пилюли). Адреса TTF спрашиваем у самого Google Fonts: статические файлы лежат
# по версионным путям с хэшем, зашить такой в скрипт — однажды получить 404.
# UA при этом не подменяем: браузерам API отдаёт woff2, а его fontconfig не
# понимает — «безымянному» клиенту вроде curl достаётся именно TTF. Запасной
# источник — npm-пакет @expo-google-fonts/onest на jsDelivr. Не вышло ни там,
# ни там — Roboto/Noto/DejaVu из пакетов, кириллица есть во всех трёх.
# librsvg игнорирует @font-face, поэтому шрифт обязан попасть в fontconfig.
# Никогда не фатальна.
ensure_fonts() {
    command -v fc-list &>/dev/null || install_package fontconfig >/dev/null 2>&1

    if (( $(fc-list 2>/dev/null | grep -ci 'onest') < 6 )); then
        echo -e "${YELLOW}Загружаю шрифт Onest для сводки...${NC}"
        local fdir css w u got=0
        local -a pkg=( [400]=400Regular [500]=500Medium [600]=600SemiBold [700]=700Bold [800]=800ExtraBold [900]=900Black )
        fdir=$(mt_font_dir onest)
        if [[ -n "$fdir" ]]; then
            css=$(curl -fsSL --max-time 20 'https://fonts.googleapis.com/css2?family=Onest:wght@400;500;600;700;800;900' 2>/dev/null)
            while read -r w u; do
                [[ -n "$u" ]] && mt_fetch_ttf "$u" "$fdir/Onest-$w.ttf" && got=$((got+1))
            done < <(printf '%s\n' "$css" | awk '/font-weight/ { w = $2; gsub(/;/, "", w) }
                /src: url/ && match($0, /https:[^)]+\.ttf/) { print w, substr($0, RSTART, RLENGTH) }')
            for w in 400 500 600 700 800 900; do
                [[ -s "$fdir/Onest-$w.ttf" ]] && continue
                mt_fetch_ttf "https://cdn.jsdelivr.net/npm/@expo-google-fonts/onest/${pkg[w]}/Onest_${pkg[w]}.ttf" \
                    "$fdir/Onest-$w.ttf" && got=$((got+1))
            done
        fi
        (( got > 0 )) || echo -e "${YELLOW}Onest недоступен — использую запасной шрифт.${NC}"
    fi

    # Запасные шрифты ставим только если Onest не встал и Roboto ещё нет.
    if ! fc-list 2>/dev/null | grep -qi 'onest' && ! fc-list 2>/dev/null | grep -qi 'roboto'; then
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
    # секундами — для сводки: там аптайм пишется по-русски (см. mt_uptime_ru)
    SYS_UP_S=$(awk '{printf "%d", $1}' /proc/uptime 2>/dev/null)
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
bing	#000000	M20.176 15.406a6.48 6.48 0 01-1.736 4.414c1.338-1.47.803-3.869-1.003-4.635-.862-.305-2.488-.85-3.367-1.158a1.834 1.834 0 01-.932-.818c-.381-.975-1.163-2.968-1.548-3.948-.095-.285-.31-.625-.265-.938.046-.598.724-1.003 1.276-.754l3.682 1.888c.621.292 1.305.692 1.796 1.172a6.486 6.486 0 012.097 4.777zm-1.44 1.888c-.264-1.194-1.135-1.744-2.216-2.028-1.527.902-4.853 2.878-6.952 4.13-1.103.68-2.13 1.35-2.919 1.242a2.866 2.866 0 01-2.77-2.325c-.012-.048-.008-.03-.001.01a6.4 6.4 0 00.947 2.653 6.498 6.498 0 005.486 3.022c1.908.062 3.536-1.153 5.099-2.096.292-.188.804-.496 1.332-.831l1.423-1.51c.553-.577.764-1.426.571-2.267zm-12.04 2.97c.422 0 .822-.1 1.173-.29.355-.215.964-.579 1.7-1.018L9.57 4.502c0-.99-.497-1.864-1.257-2.382-.08-.059-2.91-1.901-2.99-1.956-.605-.432-1.523.045-1.5.797v14.887l.417 2.36a2.488 2.488 0 002.455 2.056z
copilot	#000000	M23.922 16.997C23.061 18.492 18.063 22.02 12 22.02 5.937 22.02.939 18.492.078 16.997A.641.641 0 0 1 0 16.741v-2.869a.883.883 0 0 1 .053-.22c.372-.935 1.347-2.292 2.605-2.656.167-.429.414-1.055.644-1.517a10.098 10.098 0 0 1-.052-1.086c0-1.331.282-2.499 1.132-3.368.397-.406.89-.717 1.474-.952C7.255 2.937 9.248 1.98 11.978 1.98c2.731 0 4.767.957 6.166 2.093.584.235 1.077.546 1.474.952.85.869 1.132 2.037 1.132 3.368 0 .368-.014.733-.052 1.086.23.462.477 1.088.644 1.517 1.258.364 2.233 1.721 2.605 2.656a.841.841 0 0 1 .053.22v2.869a.641.641 0 0 1-.078.256Zm-11.75-5.992h-.344a4.359 4.359 0 0 1-.355.508c-.77.947-1.918 1.492-3.508 1.492-1.725 0-2.989-.359-3.782-1.259a2.137 2.137 0 0 1-.085-.104L4 11.746v6.585c1.435.779 4.514 2.179 8 2.179 3.486 0 6.565-1.4 8-2.179v-6.585l-.098-.104s-.033.045-.085.104c-.793.9-2.057 1.259-3.782 1.259-1.59 0-2.738-.545-3.508-1.492a4.359 4.359 0 0 1-.355-.508Zm2.328 3.25c.549 0 1 .451 1 1v2c0 .549-.451 1-1 1-.549 0-1-.451-1-1v-2c0-.549.451-1 1-1Zm-5 0c.549 0 1 .451 1 1v2c0 .549-.451 1-1 1-.549 0-1-.451-1-1v-2c0-.549.451-1 1-1Zm3.313-6.185c.136 1.057.403 1.913.878 2.497.442.544 1.134.938 2.344.938 1.573 0 2.292-.337 2.657-.751.384-.435.558-1.15.558-2.361 0-1.14-.243-1.847-.705-2.319-.477-.488-1.319-.862-2.824-1.025-1.487-.161-2.192.138-2.533.529-.269.307-.437.808-.438 1.578v.021c0 .265.021.562.063.893Zm-1.626 0c.042-.331.063-.628.063-.894v-.02c-.001-.77-.169-1.271-.438-1.578-.341-.391-1.046-.69-2.533-.529-1.505.163-2.347.537-2.824 1.025-.462.472-.705 1.179-.705 2.319 0 1.211.175 1.926.558 2.361.365.414 1.084.751 2.657.751 1.21 0 1.902-.394 2.344-.938.475-.584.742-1.44.878-2.497Z
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
        copilot.microsoft.com)       echo copilot; return ;;
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
        "youtube music"|youtubemusic) echo youtubemusic ;;
        youtube|"youtube premium"|"youtube cdn") echo youtube ;;
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
        microsoft|bing|"microsoft bing") echo bing ;;
        copilot) echo copilot ;;
        *) echo "" ;;
    esac
}

# ============================================================
#  Парсеры вывода тестов -> .metrics / .services
#  .metrics:  label \t value \t colorkey(ok|bad|warn|pri|"")
#  .services: kind \t name \t slug \t state(ok|bad|warn|na) \t value \t frac(0..1|-1) \t aux
#    chip — строка-сервис: value — ответ (код страны, да/нет, блок…);
#    bar  — скорость: value — приём, aux — отдача (Мбит/с, числом);
#    net  — сеть YABS: name — место, value — Мбит/с, aux — провайдер;
#    ping — узел пинга: slug — узел, value — avg ms, aux — «потери|группа»;
#    sep  — разделитель секций (name — заголовок).
# ============================================================

# Поля разделяем US (\x1f), а НЕ табом: таб — IFS-пробельный, и пустое поле
# (например, отсутствующий slug или slug у строк-шкал) при read «схлопывается»,
# сдвигая остальные поля. \x1f непробельный — пустые поля сохраняются.
mt_metric() { printf '%s\x1f%s\x1f%s\n' "$1" "$2" "${3:-}" >> "$MT_MFILE"; }
mt_service() { printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$1" "$2" "${3:-}" "${4:-na}" "${5:-}" "${6:--1}" "${7:-}" >> "$MT_SFILE"; }

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
    # продолжается («AS64496 Example Hostin»); vcut считает символы и ставит многоточие
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
    # Строка на город: приём и отдача числами. Шкалу страница строит сама —
    # по максимуму обоих направлений, иначе отдача вылезала бы за край.
    printf '%s\n' "$data" | while read -r line; do
        local city d u
        city=$(printf '%s' "$line" | sed -E 's/[[:space:]]{2,}.*//' | sed 's/[[:space:]]*$//')
        [[ -z "$city" ]] && continue
        printf '%s' "$line" | grep -qE '[0-9].*Mbps' || continue
        d=$(printf '%s' "$line" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*Mbps' | grep -oE '[0-9]+(\.[0-9]+)?' | sed -n '1p')
        u=$(printf '%s' "$line" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*Mbps' | grep -oE '[0-9]+(\.[0-9]+)?' | sed -n '2p')
        [[ -z "$d" ]] && continue
        mt_service bar "$city" "" "ok" "$d" "-1" "$u"
    done
}

parse_yabs() {
    local txt="$1" cpu cores ram disk f4 f1 gs gm send
    cpu=$(printf '%s\n' "$txt" | grep -m1 -E '^Processor' | sed -E 's/^[^:]*:[[:space:]]*//')
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
    # iperf3 локации: место («London, UK» — без «(10G)»), провайдер и приём
    # (Recv) в Мбит/с. Страница рисует флаг по коду страны в конце места.
    local loc; loc=$(printf '%s\n' "$txt" | awk '/iperf3 Network Speed Tests/{f=1;next} /Geekbench|YABS completed/{f=0} f' | grep -E '\|' | grep -viE 'Provider|----' || true)
    printf '%s\n' "$loc" | while IFS='|' read -r prov location send recv ping; do
        local place r rn
        place=$(printf '%s' "$location" | sed -E 's/\(.*//; s/[[:space:]]+/ /g; s/^ //; s/ $//')
        prov=$(printf '%s' "$prov" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
        [[ -z "$place" ]] && continue
        r=$(printf '%s' "$recv" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*[MG]bits/sec' | head -1)
        [[ -z "$r" ]] && continue
        rn=$(printf '%s' "$r" | awk '{v=$1; if($0~/Gbit/)v*=1000; printf "%.0f", v}')
        mt_service net "$place" "" "ok" "$rn" "-1" "$prov"
    done
}

parse_benchsh() {
    local txt="$1" cpu cores ram disk io org cc country
    cpu=$(printf '%s\n' "$txt" | grep -m1 -E 'CPU Model' | sed -E 's/^[^:]*:[[:space:]]*//')
    cores=$(printf '%s\n' "$txt" | grep -m1 -E 'CPU Cores' | grep -oE '[0-9]+' | head -1)
    ram=$(printf '%s\n' "$txt" | grep -m1 -E 'Total RAM' | sed -E 's/^[^:]*:[[:space:]]*//' | awk '{print $1" "$2}')
    disk=$(printf '%s\n' "$txt" | grep -m1 -E 'Total Disk' | sed -E 's/^[^:]*:[[:space:]]*//' | awk '{print $1" "$2}')
    io=$(printf '%s\n' "$txt" | grep -m1 -iE 'I/O Speed\(average\)' | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*[MG]B/s' | head -1)
    org=$(printf '%s\n' "$txt" | grep -m1 -E 'Organization' | sed -E 's/^[^:]*:[[:space:]]*//')
    country=$(printf '%s\n' "$txt" | grep -m1 -E '^[[:space:]]*Location' | sed -E 's#.*/[[:space:]]*##' | cut -c1-6)
    cc=$(printf '%s\n' "$txt" | grep -m1 -E 'TCP Congestion' | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '[:space:]')
    [[ -n "$cpu" ]] && mt_metric "CPU" "$cpu" ""
    [[ -n "$cores" ]] && mt_metric "Ядер" "$cores" ""
    [[ -n "$ram" ]] && mt_metric "RAM" "$ram" ""
    [[ -n "$disk" ]] && mt_metric "Диск" "$disk" ""
    [[ -n "$io" ]] && mt_metric "I/O сред." "$io" "pri"
    [[ -n "$cc" ]] && mt_metric "CC" "$cc" ""
    [[ -n "$org" ]] && mt_metric "Сеть" "$org" ""
    # Узлы speedtest: колонки Upload / Download / Latency — приём и отдача числами
    local nodes; nodes=$(printf '%s\n' "$txt" | grep -E ' Mbps' | grep -E ' ms' | sed -E 's/  +/\t/g' || true)
    printf '%s\n' "$nodes" | while IFS=$'\t' read -r node up down lat _; do
        local nm d u
        nm=$(printf '%s' "$node" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [[ -z "$nm" ]] && continue
        d=$(printf '%s' "$down" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
        u=$(printf '%s' "$up" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
        [[ -z "$d" ]] && continue
        mt_service bar "$nm" "" "ok" "$d" "-1" "$u"
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
    # sysbench пишет «total number of events», старые версии — «total events»
    tev=$(printf '%s\n' "$txt" | grep -m1 -iE 'total (number of )?events' | grep -oE '[0-9]+' | tail -1)
    tt=$(printf '%s\n' "$txt" | grep -m1 -iE 'total time' | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    la=$(printf '%s\n' "$txt" | grep -m1 -iE '^[[:space:]]*avg:' | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    # последнее число строки: первое — это «95» из самого «95th percentile»
    l95=$(printf '%s\n' "$txt" | grep -m1 -iE '95th percentile' | grep -oE '[0-9]+(\.[0-9]+)?' | tail -1)
    [[ -n "$eps" ]] && mt_metric "events/s" "$eps" "ok"
    [[ -n "$tev" ]] && mt_metric "событий" "$tev" ""
    [[ -n "$tt" ]] && mt_metric "время" "${tt} s" ""
    [[ -n "$la" ]] && mt_metric "lat avg" "${la} ms" "pri"
    [[ -n "$l95" ]] && mt_metric "lat 95th" "${l95} ms" "pri"
}

# Ping-карта: карточка «только агрегаты» — средние по регионам, худший узел, потери.
parse_pingmap() {
    local txt="$1" v st
    if printf '%s\n' "$txt" | grep -q '\[CH\] ОШИБКА'; then
        mt_metric "API" "недоступен" "bad"
        return 0
    fi
    v=$(printf '%s\n' "$txt" | grep -m1 -oE 'Средняя \(Россия\): [0-9]+(\.[0-9]+)? ms' | grep -oE '[0-9]+(\.[0-9]+)?')
    [[ -n "$v" ]] && mt_metric "РФ avg" "${v} ms" "pri"
    local gl gg
    for gl in "Европа:ЕС avg" "США:США avg" "Азия:Азия avg"; do
        gg="${gl%%:*}"
        v=$(printf '%s\n' "$txt" | grep -m1 -oE "Средняя \\(${gg}\\): [0-9]+(\\.[0-9]+)? ms" | grep -oE '[0-9]+(\.[0-9]+)?')
        [[ -n "$v" ]] && mt_metric "${gl##*:}" "${v} ms" \
            "$(awk -v x="$v" 'BEGIN{ print (x+0<80)?"ok":(x+0<=200)?"warn":"bad" }')"
    done
    local worst
    worst=$(printf '%s\n' "$txt" | grep -m1 -oE 'Худший узел: .+$' | sed -E 's/^Худший узел: //; s/ \([a-z]+[0-9]+\)//')
    if [[ -n "$worst" ]]; then
        v=$(printf '%s' "$worst" | grep -oE '[0-9]+(\.[0-9]+)?' | tail -1)
        if printf '%s' "$worst" | grep -qE 'потер|ответа'; then st="bad"
        elif [[ -n "$v" ]] && awk -v a="$v" 'BEGIN{ exit !(a>150) }'; then st="warn"
        else st="ok"; fi
        mt_metric "Худший" "$worst" "$st"
    fi
    local ln names
    ln=$(printf '%s\n' "$txt" | grep -m1 -oE 'Узлы с потерями: [0-9]+/[0-9]+.*')
    if [[ -n "$ln" ]]; then
        v=$(printf '%s' "$ln" | sed -nE 's/^Узлы с потерями: ([0-9]+\/[0-9]+).*$/\1/p')
        names=$(printf '%s' "$ln" | sed -nE 's/^.* \(([^)]+)\)[[:space:]]*$/\1/p')
        [[ "${v%%/*}" == "0" ]] && st="ok" || st="bad"
        mt_metric "Потери" "${v}${names:+ ($names)}" "$st"
    fi
    # Строка на узел для страницы: группа (заголовок «── Россия ──»), узел,
    # город, потери и min/avg/max. Разбираем ту же таблицу, что видна в консоли.
    local node city loss rest grp avg
    while IFS=$'\x1f' read -r node city loss rest grp; do
        [[ -n "$node" ]] || continue
        if [[ "$rest" =~ ^([0-9.]+)/([0-9.]+)/([0-9.]+)\ ms ]]; then
            avg="${BASH_REMATCH[2]}"
            st=$(LC_ALL=C awk -v x="$avg" -v l="${loss%\%}" 'BEGIN{ print (l+0>0)?"bad":(x+0<80)?"ok":(x+0<=200)?"warn":"bad" }')
        elif [[ "$rest" == *"ответа"* ]]; then avg="—"; loss="нет ответа"; st="na"
        else avg="—"; loss="все пакеты потеряны"; st="bad"; fi
        mt_service ping "$city" "$node" "$st" "$avg" "-1" "$loss|$grp"
    done < <(printf '%s\n' "$txt" | awk -F' · ' '
        /──/ { g = $0; gsub(/^[[:space:]]*──[[:space:]]*|[[:space:]]*──[[:space:]]*$/, "", g); next }
        NF >= 4 && $1 ~ /^[[:space:]]*[a-z]+[0-9]+[[:space:]]*$/ {
            n = $1; gsub(/[[:space:]]/, "", n)
            printf "%s\x1f%s\x1f%s\x1f%s\x1f%s\n", n, $2, $3, $4, g }')
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
        run_ping_map)                       parse_pingmap "$txt" ;;
    esac
}

# ============================================================
#  Сводка-альбом: Material 3 Expressive, тёмная тема (концепт 5b)
#
#  Одна тональная схема M3 из оранжевого исходного цвета. Главную цифру
#  страницы держит фигура M3 Expressive («печенька» или «солнце»), данные
#  идут сегментированными списками, скорость — волнистыми шкалами.
#  Холст — 1280 логических px, как в макете; PNG рендерится ×2.
#
#  Горячие функции написаны без форков: ширина строки считается по
#  таблице ширин глифов Onest, экранирование — подстановками bash.
#  На Linux разница невелика, а под Git Bash каждый $(…) стоит десятки
#  миллисекунд — строк же на странице сотни.
#
#  Ассеты вшиты в скрипт: ширины глифов Onest (OFL), иконки Material
#  Symbols Rounded (Apache-2.0), круглые флаги circle-flags (MIT).
# ============================================================

declare -A MT_GW4=() MT_GW9=()     # ширины глифов Onest, 1/1000 em: начертания 400 и 900
declare -A MT_ICON=()              # Material Symbols Rounded: имя -> путь в 960-сетке
declare -A MT_FLAG=()              # круглые флаги: код -> содержимое в 512-сетке
declare -A MT_FLAG_USED=()         # флаги текущей страницы -> попадут в <defs>
declare -A MT_FLAG_MISS=()         # коды, за которыми уже ходили в сеть и не нашли
declare -A MT_CNAME=() MT_CACC=()  # страна по-русски: именительный и винительный
declare -A MT_SHAPE=()             # кэш контуров фигур: «тип:размер» -> путь
declare -A M=() MC=()              # метрики текущего теста: подпись -> значение / цвет
MT_U8=0
# Код страны в регулярках — явным перечнем букв: диапазон [A-Z] в части
# UTF-8-локалей glibc сравнивается по правилам сортировки и ловит строчные.
MT_CC_RE='[ABCDEFGHIJKLMNOPQRSTUVWXYZ][ABCDEFGHIJKLMNOPQRSTUVWXYZ]'

sv() { SVG_BODY+="$1"$'\n'; }

# Экранирование для SVG без форка -> XE. Замену берём в кавычки: в bash 5.2
# (patsub_replacement) голый & в замене означает «найденный текст».
xesc() {
    local s="$1" q="'"
    s=${s//&/"&amp;"}; s=${s//</"&lt;"}; s=${s//>/"&gt;"}; s=${s//\"/"&quot;"}; s=${s//"$q"/"&apos;"}
    XE="$s"
}


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

# a/b десятичной строкой -> FD: fdiv — 5 знаков (масштабы), fxd — 2 знака со знаком.
fdiv() { printf -v FD '%d.%05d' $(( $1 / $2 )) $(( ($1 % $2) * 100000 / $2 )); }
fxd() {
    local a=$1 b=$2 s=""; (( a < 0 )) && { s="-"; a=$(( -a )); }
    printf -v FD '%s%d.%02d' "$s" $(( a / b )) $(( (a % b) * 100 / b ))
}

# Строка -> массивы символов GC[] и их ширин GWD[] (1/1000 em) для начертания.
# Ширина между 400 и 900 интерполируется линейно: у Onest это расходится с
# настоящим начертанием меньше чем на 0.2 %. В UTF-8-локали ${s:i:1} отдаёт
# символ, в C-локали — байт, и многобайтные символы собираем сами.
mt_glyphs() {
    local s="$1" t=$(( ${2:-400} - 400 )) n=${#1} i c q="" a b
    GC=(); GWD=()
    if (( MT_U8 )); then
        for (( i=0; i<n; i++ )); do
            c="${s:i:1}"; a=${MT_GW4["_$c"]:-600}; b=${MT_GW9["_$c"]:-640}
            GC+=("$c"); GWD+=( $(( a + (b-a)*t/500 )) )
        done
    else
        for (( i=0; i<=n; i++ )); do
            c="${s:i:1}"
            if (( i < n )) && [[ -n "$q" && "$c" == [$'\x80'-$'\xbf'] ]]; then q+="$c"; continue; fi
            if [[ -n "$q" ]]; then
                a=${MT_GW4["_$q"]:-600}; b=${MT_GW9["_$q"]:-640}
                GC+=("$q"); GWD+=( $(( a + (b-a)*t/500 )) )
            fi
            q="$c"
        done
    fi
}

# Ширина строки в px -> TW: <текст> <кегль> [начертание] [трекинг, 1/1000 em]
tw() {
    mt_glyphs "$1" "${3:-400}"
    local x sum=0
    for x in "${GWD[@]}"; do sum=$((sum+x)); done
    TW=$(( (sum + ${4:-0} * ${#GWD[@]}) * $2 / 1000 ))
}

# Кегль, при котором строка влезает в ширину -> FS:
# <текст> <ширина> <кегль> <начертание> [трекинг] [минимальный кегль]
fitsz() {
    tw "$1" "$3" "$4" "${5:-0}"
    FS=$3
    (( TW > $2 )) && FS=$(( $3 * $2 / TW ))
    (( FS < ${6:-10} )) && FS=${6:-10}
    return 0
}

# Обрезка по ширине с многоточием -> EL: <текст> <ширина> <кегль> [начертание]
ellip() {
    local mw=$2 sz=$3 sum=0 i lim
    mt_glyphs "$1" "${4:-400}"
    for (( i=0; i<${#GWD[@]}; i++ )); do sum=$((sum+GWD[i])); done
    if (( sum * sz / 1000 <= mw )); then EL="$1"; return; fi
    local e4=${MT_GW4[_…]:-700} e9=${MT_GW9[_…]:-800}
    lim=$(( mw * 1000 / sz - (e4 + (e9 - e4) * (${4:-400} - 400) / 500) ))
    EL=""; sum=0
    for (( i=0; i<${#GWD[@]}; i++ )); do
        (( sum + GWD[i] > lim )) && break
        sum=$((sum+GWD[i])); EL+="${GC[i]}"
    done
    # хвост из пробелов и знаков препинания убираем; «·» — отдельно и целиком:
    # в C-локали он в скобочном классе распался бы на байты, а последний байт
    # «·» совпадает с последним байтом «з» — и буква рвалась бы пополам
    while :; do
        case "$EL" in
            *" "|*","|*".") EL="${EL%?}" ;;
            *"·")           EL="${EL%·}" ;;
            *)              break ;;
        esac
    done
    EL+="…"
}

# Перенос по словам -> WL[]: <текст> <ширина> <кегль> [начертание] [макс. строк]
wrap() {
    local mw=$2 sz=$3 wt="${4:-400}" mx="${5:-99}" w line="" cand
    local -a words=()
    WL=()
    read -r -a words <<< "$1"
    for w in "${words[@]}"; do
        cand="${line:+$line }$w"
        tw "$cand" "$sz" "$wt"
        if (( TW <= mw )) || [[ -z "$line" ]]; then line="$cand"
        else WL+=("$line"); line="$w"; fi
    done
    [[ -n "$line" ]] && WL+=("$line")
    local i
    for i in "${!WL[@]}"; do ellip "${WL[$i]}" "$mw" "$sz" "$wt"; WL[$i]="$EL"; done
    if (( ${#WL[@]} > mx )); then
        local rest="${WL[*]:mx-1}"
        WL=("${WL[@]:0:mx-1}")
        ellip "$rest" "$mw" "$sz" "$wt"; WL+=("$EL")
    fi
}

# Текст: <x> <y> <кегль> <начертание> <цвет> <текст> [start|middle|end] [трекинг, 1/1000 em]
t() {
    xesc "$6"
    local a="" l=""
    [[ "${7:-start}" != start ]] && a=" text-anchor=\"$7\""
    if [[ -n "${8:-}" && "${8:-0}" != 0 ]]; then fxd $(( $8 * $3 )) 1000; l=" letter-spacing=\"$FD\""; fi
    sv "<text x=\"$1\" y=\"$2\" font-size=\"$3\" font-weight=\"$4\" fill=\"$5\"$a$l>$XE</text>"
}

# Прямоугольник с радиусом на каждый угол, порядок как у border-radius:
# <x> <y> <w> <h> <tl> <tr> <br> <bl> <заливка> [доп. атрибуты]
rr() {
    local x=$1 y=$2 w=$3 h=$4 a=$5 b=$6 c=$7 d=$8 m
    m=$(( (w < h ? w : h) / 2 ))
    (( a > m )) && a=$m; (( b > m )) && b=$m; (( c > m )) && c=$m; (( d > m )) && d=$m
    sv "<path d=\"M$((x+a)) ${y}H$((x+w-b))A$b $b 0 0 1 $((x+w)) $((y+b))V$((y+h-c))A$c $c 0 0 1 $((x+w-c)) $((y+h))H$((x+d))A$d $d 0 0 1 $x $((y+h-d))V$((y+a))A$a $a 0 0 1 $((x+a)) ${y}Z\" fill=\"$9\"${10:+ ${10}}/>"
}

# Радиусы элемента сегментированного списка -> R[]: <номер> <всего> <большой> <малый>
segr() {
    if (( $2 == 1 )); then R=($3 $3 $3 $3)
    elif (( $1 == 0 )); then R=($3 $3 $4 $4)
    elif (( $1 == $2 - 1 )); then R=($4 $4 $3 $3)
    else R=($4 $4 $4 $4); fi
}

# Фигура M3 Expressive: <тип> <x> <y> <размер> <заливка>. Формулы — из макета:
# r = 50 − a + a·cos(n·t) в процентах стороны; cookie12 (12 волн, 3 %),
# cookie9 (9 волн, 5 %), sunny8 (8 волн, 5.5 %). Контур на размер считаем раз.
mt_shape() {
    local key="$1:$4" d n a p
    d="${MT_SHAPE[$key]:-}"
    if [[ -z "$d" ]]; then
        case "$1" in
            cookie9) n=9; a=5;   p=144 ;;
            sunny8)  n=8; a=5.5; p=160 ;;
            *)       n=12; a=3;  p=192 ;;
        esac
        # LC_ALL=C: в ru_RU mawk печатает «1,5», а запятая в пути SVG — разделитель чисел
        d=$(LC_ALL=C awk -v n=$n -v a=$a -v p=$p -v s="$4" 'BEGIN{ pi = atan2(0, -1)
            for (i = 0; i < p; i++) { t = i / p * 2 * pi; r = 50 - a + a * cos(n * t)
                printf "%s%.1f %.1f", (i ? "L" : "M"), (50 + r * sin(t)) * s / 100, (50 - r * cos(t)) * s / 100 }
            printf "Z" }')
        MT_SHAPE[$key]="$d"
    fi
    sv "<path transform=\"translate($2 $3)\" d=\"$d\" fill=\"$5\"/>"
}

# Иконка Material Symbols: <имя> <x> <y> <размер> <цвет>. Путь лежит в сетке
# 0…960 по x и −960…0 по y — отсюда сдвиг на размер вниз.
mt_icon() {
    local d="${MT_ICON[$1]:-}"
    [[ -n "$d" ]] || return 0
    fdiv "$4" 960
    sv "<path transform=\"translate($2 $(( $3 + $4 ))) scale($FD)\" d=\"$d\" fill=\"$5\"/>"
}

# Марка сервиса (Simple Icons, сетка 24): <slug> <x> <y> <размер> <цвет>
sv_mark() {
    [[ -n "$1" ]] || return 1
    local d="${LOGO_PATH[$1]:-}"
    [[ -n "$d" ]] || return 1
    fdiv "$4" 24
    sv "<path transform=\"translate($2 $3) scale($FD)\" d=\"$d\" fill=\"$5\"/>"
}

# Круглый флаг: <код> <x> <y> <диаметр>. Вшитый — через <use> (содержимое уйдёт
# в <defs> один раз на страницу), редкий — догружаем с jsDelivr, а без сети
# рисуем кружок с буквами кода, чтобы строка не теряла выравнивание.
mt_flag() {
    local cc="${1,,}" x=$2 y=$3 d=$4
    [[ "$cc" == "uk" ]] && cc="gb"
    if [[ "$cc" =~ ^[a-z]{2}$ ]] && { [[ -n "${MT_FLAG[$cc]:-}" ]] || mt_flag_fetch "$cc"; }; then
        MT_FLAG_USED[$cc]=1
        fdiv "$d" 512
        sv "<use href=\"#fl-$cc\" xlink:href=\"#fl-$cc\" transform=\"translate($x $y) scale($FD)\"/>"
        return 0
    fi
    local r=$(( d / 2 ))
    sv "<circle cx=\"$(( x + r ))\" cy=\"$(( y + r ))\" r=\"$r\" fill=\"$C_SECC\"/>"
    t $(( x + r )) $(( y + r + d * 14 / 100 )) $(( d * 40 / 100 )) 700 "$C_ONSECC" "${cc^^}" middle
}

# Флаг, которого нет среди вшитых: один запрос на код за прогон. Версия пакета
# прибита (тот же circle-flags, из которого взяты вшитые), а ответ проверяем:
# обёртка — <svg> с маской-кругом, внутри — только простые фигуры без ссылок.
# Всё, что вставляется в картинку как есть, не должно нести <image>, <text>
# или внешних href — иначе — монограмма.
mt_flag_fetch() {
    local cc="$1" svg inner chk
    [[ "${MT_FLAG_FETCH:-1}" == "1" && -z "${MT_FLAG_MISS[$cc]:-}" ]] || return 1
    MT_FLAG_MISS[$cc]=1
    command -v curl &>/dev/null || return 1
    svg=$(curl -fsSL --max-time 5 "https://cdn.jsdelivr.net/npm/circle-flags@2.8.3/flags/${cc}.svg" 2>/dev/null) || return 1
    [[ "$svg" == "<svg"*'<g mask="url(#a)">'*"</g></svg>"* ]] || return 1
    inner="${svg#*<g mask=\"url(#a)\">}"; inner="${inner%</g></svg>*}"
    [[ -n "$inner" ]] || return 1
    chk="${inner//<path /}"; chk="${chk//<circle /}"; chk="${chk//<rect /}"; chk="${chk//<ellipse /}"
    chk="${chk//<polygon /}"; chk="${chk//<g>/}"; chk="${chk//<g /}"; chk="${chk//<\/g>/}"
    [[ "$chk" == *"<"* || "$chk" == *"href"* || "$chk" == *"url("* ]] && return 1
    MT_FLAG[$cc]="$inner"
}

# Базовая линия по верху строки: верх + кегль·(lh/2 + 0.3325), lh в тысячных.
# 0.3325 = (ascender − descender)/2 − descender для Onest (970 / 305 из 1000).
blt() { BL=$(( $1 + $2 * ($3 + 665) / 2000 )); }

# Вшитые таблицы: ширины глифов Onest (символ, 400, 900), иконки Material
# Symbols Rounded (имя, путь), круглые флаги (код, содержимое 512-сетки),
# страны по-русски (код, именительный, винительный — если отличается).
# Флаги — частые страны хостинга и GeoIP; остальные догружает mt_flag_fetch.
mt_load_assets() {
    (( ${#MT_GW4[@]} )) && return 0
    local a b c
    while IFS=$'\t' read -r a b c; do [[ -n "$b" ]] && { MT_GW4["_$a"]=$b; MT_GW9["_$a"]=$c; }; done <<'MTGWEOF'
 	270	290
!	273	325
"	359	447
#	653	700
$	656	668
%	804	941
&	677	744
'	222	263
(	308	384
)	308	384
*	414	495
+	550	620
,	261	328
-	458	469
.	254	299
/	477	536
0	665	657
1	363	408
2	566	557
3	599	622
4	633	639
5	616	614
6	623	624
7	505	516
8	622	627
9	620	622
:	253	305
;	261	327
<	550	620
=	550	620
>	550	620
?	513	541
@	983	1001
A	670	739
B	655	691
C	704	721
D	720	737
E	610	629
F	599	607
G	720	740
H	727	753
I	261	315
J	558	602
K	625	704
L	574	607
M	856	928
N	741	783
O	761	781
P	630	669
Q	761	782
R	658	710
S	652	665
T	569	612
U	726	745
V	683	736
W	983	1018
X	593	719
Y	614	727
Z	597	631
[	321	374
\	477	536
]	321	375
^	550	620
_	463	432
`	559	643
a	555	576
b	604	637
c	553	568
d	604	639
e	573	576
f	366	396
g	604	639
h	591	614
i	219	272
j	254	277
k	520	585
l	219	272
m	819	874
n	591	614
o	595	601
p	604	637
q	604	639
r	373	406
s	509	515
t	370	364
u	576	591
v	536	572
w	843	883
x	515	590
y	597	629
z	518	505
{	389	413
|	261	298
}	389	413
~	550	620
А	670	739
Б	654	692
В	655	691
Г	571	591
Д	709	754
Е	610	629
Ж	860	1008
З	626	676
И	732	769
Й	732	769
К	625	705
Л	693	706
М	860	928
Н	727	753
О	761	781
П	730	744
Р	625	669
С	710	727
Т	569	612
У	614	669
Ф	837	892
Х	593	719
Ц	724	755
Ч	661	703
Ш	965	1015
Щ	982	1037
Ъ	731	765
Ы	841	939
Ь	633	681
Э	708	724
Ю	991	1029
Я	660	730
а	555	576
б	576	626
в	547	577
г	454	445
д	593	643
е	573	576
ж	761	838
з	514	543
и	596	622
й	596	622
к	519	605
л	560	585
м	699	748
н	568	603
о	595	601
п	571	600
р	600	633
с	553	568
т	465	524
у	549	584
ф	722	807
х	515	590
ц	584	628
ч	529	558
ш	787	866
щ	811	888
ъ	590	596
ы	679	789
ь	519	566
э	548	561
ю	785	839
я	534	597
Ё	610	629
ё	573	576
·	249	308
—	759	854
–	578	636
−	550	620
…	697	804
≈	550	620
№	1061	1108
×	550	620
°	370	432
«	476	622
»	476	622
’	261	317
↓	701	773
↑	701	773
→	701	773
€	679	754
₽	699	693
±	550	620
²	372	389
é	573	576
ü	576	591
ö	595	601
ä	555	576
ç	553	568
ş	509	515
ı	219	272
MTGWEOF
    while IFS=$'\t' read -r a b; do [[ -n "$b" ]] && MT_ICON[$a]="$b"; done <<'MTICONEOF'
public	M324-111.5Q251-143 197-197t-85.5-127Q80-397 80-480t31.5-156Q143-709 197-763t127-85.5Q397-880 480-880t156 31.5Q709-817 763-763t85.5 127Q880-563 880-480t-31.5 156Q817-251 763-197t-127 85.5Q563-80 480-80t-156-31.5ZM437-141v-82q-35 0-59-26t-24-61v-44L149-559q-5 20-7 39.5t-2 39.5q0 130 84.5 227T437-141Zm294-108q44-48 66.5-107.5T820-480q0-106-58-192.5T607-799v18q0 35-24 61t-59 26h-87v87q0 17-13.5 28T393-568h-83v88h258q17 0 28 13t11 30v127h43q29 0 51 17t30 44Z
block	M324-111.5Q251-143 197-197t-85.5-127Q80-397 80-480t31.5-156Q143-709 197-763t127-85.5Q397-880 480-880t156 31.5Q709-817 763-763t85.5 127Q880-563 880-480t-31.5 156Q817-251 763-197t-127 85.5Q563-80 480-80t-156-31.5ZM699-220q11-9 21.5-18.86Q731-248.73 740-260L260-740q-11.27 9-21.14 19.5Q229-710 220-699l479 479Z
policy	M470.5-84q-4.5-1-9.5-3-138-47-219.5-168.5T160-522v-196q0-19 11-34.5t28-22.5l260-97q11-4 21-4t21 4l260 97q17 7 28 22.5t11 34.5v196q0 64-18 125.5T731-279L604-402q13-17 19-38t6-42q0-63-43.5-106.5T480-632q-62 0-105.5 43.5T331-482q0 62 43.5 105T480-334q22 0 43-7t40-18l134 130q-42 52-88.5 86T499-87q-5 2-9.5 3t-9.5 1q-5 0-9.5-1ZM417-419.5Q391-445 391-482q0-38 26-64t63-26q37 0 63 26t26 64q0 37-26 62.5T480-394q-37 0-63-25.5Z
travel_explore	M80-480q0-83 31.5-156T197-763q54-54 127-85.5T480-880q137 0 241.5 80T863-595q4 13-2 24.5T842-556q-12 3-22-4.5T806-580q-22-74-74-131.5T607-799v18q0 35-24 61t-59 26h-87v87q0 17-13.5 28T393-568h-83v88h80q13 0 21.5 8.5T420-450v95h-67L149-559q-5 20-7 39.5t-2 39.5q0 128 82.5 223.5T431-144q12 2 19.5 11.5T458-111q0 13-9 21t-22 6q-148-20-247.5-131.5T80-480Zm749 351L716-241q-21 15-45.5 23t-50.5 8q-71 0-120.5-49.5T450-380q0-71 49.5-120.5T620-550q71 0 120.5 49.5T790-380q0 26-8.5 50.5T759-283l112 112q9 9 9.5 21t-8.5 21q-9 9-21.5 9t-21.5-9ZM698-302q32-32 32-78t-32-78q-32-32-78-32t-78 32q-32 32-32 78t32 78q32 32 78 32t78-32Z
swap_vert	M331.5-458.5Q323-467 323-480v-286L223-666q-9 9-21 9t-21-9q-9-9-9-21t9-21l151-151q5-5 10-7t11-2q6 0 11 2t10 7l151 151q9 9 9 21t-9 21q-9 9-21 9t-21-9L383-766v286q0 13-8.5 21.5T353-450q-13 0-21.5-8.5ZM596-94q-5-2-10-7L435-252q-9-9-9-21t9-21q9-9 21-9t21 9l100 100v-286q0-13 8.5-21.5T607-510q13 0 21.5 8.5T637-480v286l100-100q9-9 21-9t21 9q9 9 9 21t-9 21L628-101q-5 5-10 7t-11 2q-6 0-11-2Z
speed	M418-340q25 25 63 23.5t55-27.5l180-271q7-11-1.5-19.5T695-636L424-456q-26 18-28.5 54.5T418-340ZM192-160q-18 0-34-8.5T134-193q-26-48-40-100T80-399q0-83 31.5-156T197-682.5q54-54.5 126.5-86T478-800q83 0 156.5 31.5t128 86Q817-628 848.5-555T880-399q0 54-13 106.5T827-193q-9 16-25 24.5t-34 8.5H192Z
shield	M470.5-85q-4.5-1-9.5-3-139-47-220-168.5T160-523v-196q0-19 11-34.5t28-22.5l260-97q11-4 21-4t21 4l260 97q17 7 28 22.5t11 34.5v196q0 145-81 266.5T499-88q-5 2-9.5 3t-9.5 1q-5 0-9.5-1Z
verified_user	m439-442-79-79q-9-9-22-9t-22 9q-9 9-9 22t9 22l99 100q9 9 21 9t21-9l186-186q9-9 9-21.5t-9-20.5q-8-8-21-7.5t-21 8.5L439-442Zm31.5 357q-4.5-1-9.5-3-139-47-220-168.5T160-523v-196q0-19 11-34.5t28-22.5l260-97q11-4 21-4t21 4l260 97q17 7 28 22.5t11 34.5v196q0 145-81 266.5T499-88q-5 2-9.5 3t-9.5 1q-5 0-9.5-1Z
memory	M377-407v-145q0-12.75 8.63-21.38Q394.25-582 407-582h145q12.75 0 21.38 8.62Q582-564.75 582-552v145q0 12.75-8.62 21.37Q564.75-377 552-377H407q-12.75 0-21.37-8.63Q377-394.25 377-407Zm-17 257v-50H260q-24 0-42-18t-18-42v-100h-50q-12.75 0-21.37-8.68-8.63-8.67-8.63-21.5 0-12.82 8.63-21.32 8.62-8.5 21.37-8.5h50v-124h-50q-12.75 0-21.37-8.68-8.63-8.67-8.63-21.5 0-12.82 8.63-21.32 8.62-8.5 21.37-8.5h50v-100q0-24 18-42t42-18h100v-46q0-12.75 8.68-21.38 8.67-8.62 21.5-8.62 12.82 0 21.32 8.62 8.5 8.63 8.5 21.38v46h124v-46q0-12.75 8.68-21.38 8.67-8.62 21.5-8.62 12.82 0 21.32 8.62 8.5 8.63 8.5 21.38v46h100q24 0 42 18t18 42v100h46q12.75 0 21.38 8.68 8.62 8.67 8.62 21.5 0 12.82-8.62 21.32-8.63 8.5-21.38 8.5h-46v124h46q12.75 0 21.38 8.68 8.62 8.67 8.62 21.5 0 12.82-8.62 21.32-8.63 8.5-21.38 8.5h-46v100q0 24-18 42t-42 18H604v50q0 12.75-8.68 21.37-8.67 8.63-21.5 8.63-12.82 0-21.32-8.63-8.5-8.62-8.5-21.37v-50H420v50q0 12.75-8.68 21.37-8.67 8.63-21.5 8.63-12.82 0-21.32-8.63-8.5-8.62-8.5-21.37Zm344-110v-444H260v444h444Z
monitoring	M128.5-128.63Q120-137.25 120-150v-46q0-12.75 8.68-21.38 8.67-8.62 21.5-8.62 12.82 0 21.32 8.62 8.5 8.63 8.5 21.38v46q0 12.75-8.68 21.37-8.67 8.63-21.5 8.63-12.82 0-21.32-8.63Zm165 0Q285-137.25 285-150v-206q0-12.75 8.68-21.38 8.67-8.62 21.5-8.62 12.82 0 21.32 8.62 8.5 8.63 8.5 21.38v206q0 12.75-8.68 21.37-8.67 8.63-21.5 8.63-12.82 0-21.32-8.63Zm165 0Q450-137.25 450-150v-146q0-12.75 8.68-21.38 8.67-8.62 21.5-8.62 12.82 0 21.32 8.62 8.5 8.63 8.5 21.38v146q0 12.75-8.68 21.37-8.67 8.63-21.5 8.63-12.82 0-21.32-8.63Zm165 0Q615-137.25 615-150v-246q0-12.75 8.68-21.38 8.67-8.62 21.5-8.62 12.82 0 21.32 8.62 8.5 8.63 8.5 21.38v246q0 12.75-8.68 21.37-8.67 8.63-21.5 8.63-12.82 0-21.32-8.63Zm165 0Q780-137.25 780-150v-366q0-12.75 8.68-21.38 8.67-8.62 21.5-8.62 12.82 0 21.32 8.62 8.5 8.63 8.5 21.38v366q0 12.75-8.68 21.37-8.67 8.63-21.5 8.63-12.82 0-21.32-8.63ZM559.5-499q-11.5 0-22.46-4.7-10.97-4.69-20.04-13.3L400-634 172-407q-9.07 9-21.53 8.5-12.47-.5-21.34-9.5-8.13-9-8.63-21t8.5-21l229-227q9.07-8.87 20.04-12.93Q389-694 400-694t22.34 4.07Q433.68-685.87 442-677l118 118 229-229q9-9 21-9t20.87 9q8.13 9 8.63 21t-8.5 21L602-517q-8 9-19.5 13.5t-23 4.5Z
network_ping	M190-240q-13 0-21.5-8.5T160-270q0-13 8.5-21.5T190-300h254L105-639q-9-9-9-21t9-21q9-9 21-9t21 9l332 332 234-233q-6-11-9.5-23.5T700-630q0-38 26-64t64-26q38 0 64 26t26 64q0 38-26 64t-64 26q-8 0-14.5-1t-14.5-4L516-300h254q13 0 21.5 8.5T800-270q0 13-8.5 21.5T770-240H190Z
skip_next	M680-270v-420q0-13 8.5-21.5T710-720q13 0 21.5 8.5T740-690v420q0 13-8.5 21.5T710-240q-13 0-21.5-8.5T680-270Zm-460-27v-366q0-14 9-22t21-8q5 0 9 1.5t8 4.5l263 182q7 5 10 11.5t3 13.5q0 7-3 13.5T530-455L267-273q-4 3-8 4.5t-9 1.5q-12 0-21-8t-9-22Z
error	M503.5-289.48q9.5-9.48 9.5-23.5t-9.48-23.52q-9.48-9.5-23.5-9.5t-23.52 9.48q-9.5 9.48-9.5 23.5t9.48 23.52q9.48 9.5 23.5 9.5t23.52-9.48Zm1-152.15q8.5-8.62 8.5-21.37v-193q0-12.75-8.68-21.38-8.67-8.62-21.5-8.62-12.82 0-21.32 8.62-8.5 8.63-8.5 21.38v193q0 12.75 8.68 21.37 8.67 8.63 21.5 8.63 12.82 0 21.32-8.63ZM480.27-80q-82.74 0-155.5-31.5Q252-143 197.5-197.5t-86-127.34Q80-397.68 80-480.5t31.5-155.66Q143-709 197.5-763t127.34-85.5Q397.68-880 480.5-880t155.66 31.5Q709-817 763-763t85.5 127Q880-563 880-480.27q0 82.74-31.5 155.5Q817-252 763-197.68q-54 54.31-127 86Q563-80 480.27-80Z
dns	M286.88-717q-20.88 0-35.38 14.62-14.5 14.62-14.5 35.5 0 20.88 14.62 35.38 14.62 14.5 35.5 14.5 20.88 0 35.38-14.62 14.5-14.62 14.5-35.5 0-20.88-14.62-35.38-14.62-14.5-35.5-14.5Zm0 414q-20.88 0-35.38 14.62-14.5 14.62-14.5 35.5 0 20.88 14.62 35.38 14.62 14.5 35.5 14.5 20.88 0 35.38-14.62 14.5-14.62 14.5-35.5 0-20.88-14.62-35.38-14.62-14.5-35.5-14.5ZM154-839h651q16 0 25.5 9.5t9.5 25.81V-535q0 17.42-9.5 29.21T805-494H154q-15 0-24.5-11.79T120-535v-268.69q0-16.31 9.5-25.81T154-839Zm0 413h647q15 0 27 12.5t12 28.53V-121q0 20-12 30.5T801-80H159q-16 0-27.5-10.5T120-121v-263.97q0-16.03 9.5-28.53T154-426Z
arrow_downward	M450-274v-496q0-13 8.5-21.5T480-800q13 0 21.5 8.5T510-770v496l227-227q9-9 21-9t21 9q9 9 9 21t-9 21L501-181q-5 5-10 7t-11 2q-6 0-11-2t-10-7L181-459q-9-9-9-21t9-21q9-9 21-9t21 9l227 227Z
arrow_upward	M450-686 223-459q-9 9-21 9t-21-9q-9-9-9-21t9-21l278-278q5-5 10-7t11-2q6 0 11 2t10 7l278 278q9 9 9 21t-9 21q-9 9-21 9t-21-9L510-686v496q0 13-8.5 21.5T480-160q-13 0-21.5-8.5T450-190v-496Z
language	M323-111.5Q250-143 196-197t-85-127.5Q80-398 80-482t31-156.5Q142-711 196-765t127-84.5Q396-880 480-880t157 30.5Q710-819 764-765t85 126.5Q880-566 880-482t-31 157.5Q818-251 764-197t-127 85.5Q564-80 480-80t-157-31.5ZM480-138q35-36 58.5-82.5T577-331H384q14 60 37.5 108t58.5 85Zm-85-12q-25-38-43-82t-30-99H172q38 71 88 111.5T395-150Zm171-1q72-23 129.5-69T788-331H639q-13 54-30.5 98T566-151ZM152-391h159q-3-27-3.5-48.5T307-482q0-25 1-44.5t4-43.5H152q-7 24-9.5 43t-2.5 45q0 26 2.5 46.5T152-391Zm221 0h215q4-31 5-50.5t1-40.5q0-20-1-38.5t-5-49.5H373q-4 31-5 49.5t-1 38.5q0 21 1 40.5t5 50.5Zm275 0h160q7-24 9.5-44.5T820-482q0-26-2.5-45t-9.5-43H649q3 35 4 53.5t1 34.5q0 22-1.5 41.5T648-391Zm-10-239h150q-33-69-90.5-115T565-810q25 37 42.5 80T638-630Zm-254 0h194q-11-53-37-102.5T480-820q-32 27-54 71t-42 119Zm-212 0h151q11-54 28-96.5t43-82.5q-75 19-131 64t-91 115Z
check	m378-358 350-349q14-14 34-14t34 14q14 14 14 34t-14 34L412-256q-14 14-34 14t-34-14L164-436q-14-14-14-34t14-34q14-14 34-14t34 14l146 146Z
close	M480-414 282-216q-14 14-33 14t-33-14q-14-14-14-33t14-33l198-198-198-198q-14-14-14-33t14-33q14-14 33-14t33 14l198 198 198-198q14-14 33-14t33 14q14 14 14 33t-14 33L546-480l198 198q14 14 14 33t-14 33q-14 14-33 14t-33-14L480-414Z
database	M480-120q-151 0-255.5-46.5T120-280v-400q0-66 105.5-113T480-840q149 0 254.5 47T840-680v400q0 67-104.5 113.5T480-120Zm0-488q86 0 176.5-26.5T773-694q-27-32-117.5-59T480-780q-88 0-177 26t-117 60q28 35 116 60.5T480-608Zm-1 214q42 0 84-4.5t80.5-13.5q38.5-9 73.5-22t63-29v-155q-29 16-64 29t-74 22q-39 9-80 14t-83 5q-42 0-84-5t-80.5-14q-38.5-9-73-22T180-618v155q27 16 61 29t72.5 22q38.5 9 80.5 13.5t85 4.5Zm1 214q48 0 99-8.5t93.5-22.5q42.5-14 72-31t35.5-35v-125q-28 16-63 28.5T643.5-352q-38.5 9-80 13.5T479-334q-43 0-85-4.5T313.5-352q-38.5-9-72.5-21.5T180-402v126q5 17 34 34.5t72 31q43 13.5 94 22t100 8.5Z
MTICONEOF
    while IFS=$'\t' read -r a b; do [[ -n "$b" ]] && MT_FLAG[$a]="$b"; done <<'MTFLAGEOF'
nl	<path fill="#eee" d="m0 167 253.8-19.3L512 167v178l-254.9 32.3L0 345z"/><path fill="#a2001d" d="M0 0h512v167H0z"/><path fill="#0052b4" d="M0 345h512v167H0z"/>
de	<path fill="#ffda44" d="m0 345 256.7-25.5L512 345v167H0z"/><path fill="#d80027" d="m0 167 255-23 257 23v178H0z"/><path fill="#333" d="M0 0h512v167H0z"/>
fi	<path fill="#eee" d="M0 0h133.6l35.3 16.7L200.3 0H512v222.6l-22.6 31.7 22.6 35.1V512H200.3l-32-19.8-34.7 19.8H0V289.4l22.1-33.3L0 222.6z"/><path fill="#0052b4" d="M133.6 0v222.6H0v66.8h133.6V512h66.7V289.4H512v-66.8H200.3V0h-66.7z"/>
fr	<path fill="#eee" d="M167 0h178l25.9 252.3L345 512H167l-29.8-253.4z"/><path fill="#0052b4" d="M0 0h167v512H0z"/><path fill="#d80027" d="M345 0h167v512H345z"/>
gb	<path fill="#eee" d="m0 0 8 22-8 23v23l32 54-32 54v32l32 48-32 48v32l32 54-32 54v68l22-8 23 8h23l54-32 54 32h32l48-32 48 32h32l54-32 54 32h68l-8-22 8-23v-23l-32-54 32-54v-32l-32-48 32-48v-32l-32-54 32-54V0l-22 8-23-8h-23l-54 32-54-32h-32l-48 32-48-32h-32l-54 32L68 0H0z"/><path fill="#0052b4" d="M336 0v108L444 0Zm176 68L404 176h108zM0 176h108L0 68ZM68 0l108 108V0Zm108 512V404L68 512ZM0 444l108-108H0Zm512-108H404l108 108Zm-68 176L336 404v108z"/><path fill="#d80027" d="M0 0v45l131 131h45L0 0zm208 0v208H0v96h208v208h96V304h208v-96H304V0h-96zm259 0L336 131v45L512 0h-45zM176 336 0 512h45l131-131v-45zm160 0 176 176v-45L381 336h-45z"/>
ie	<path fill="#eee" d="M167 0h178l25.9 252.3L345 512H167l-29.8-253.4z"/><path fill="#6da544" d="M0 0h167v512H0z"/><path fill="#ff9811" d="M345 0h167v512H345z"/>
be	<path fill="#333" d="M0 0h167l38.2 252.6L167 512H0z"/><path fill="#d80027" d="M345 0h167v512H345l-36.7-256z"/><path fill="#ffda44" d="M167 0h178v512H167z"/>
lu	<path fill="#eee" d="m0 167 253.8-19.3L512 167v178l-254.9 32.3L0 345z"/><path fill="#d80027" d="M0 0h512v167H0z"/><path fill="#338af3" d="M0 345h512v167H0z"/>
at	<path fill="#d80027" d="M0 0h512v167l-23.2 89.7L512 345v167H0V345l29.4-89L0 167z"/><path fill="#eee" d="M0 167h512v178H0z"/>
ch	<path fill="#d80027" d="M0 0h512v512H0z"/><path fill="#eee" d="M389.6 211.5h-89v-89h-89.1v89h-89v89h89v89h89v-89h89z"/>
it	<path fill="#eee" d="M167 0h178l25.9 252.3L345 512H167l-29.8-253.4z"/><path fill="#6da544" d="M0 0h167v512H0z"/><path fill="#d80027" d="M345 0h167v512H345z"/>
es	<path fill="#ffda44" d="m0 128 256-32 256 32v256l-256 32L0 384Z"/><path fill="#eee" d="M196 168q-11 1-15 11l-5-1q-15 1-16 16c-1 15 7 16 16 16q11 0 15-11a16 16 0 0 0 17-4 16 16 0 0 0 17 4 16 16 0 1 0 10-20 16 16 0 0 0-27-5q-4-6-12-6m0 8q8 1 8 8 0 8-8 8-7 0-8-8 1-7 8-8m24 0q8 1 8 8 0 8-8 8-7 0-8-8 1-7 8-8m-44 10 4 1 4 8q-1 7-8 7-9 0-8-8 1-7 8-8m64 0q8 1 8 8 0 8-8 8-7 0-8-7l4-8zm-112 38v80h16v-80zm80 0v40c-26 0-48 14-48 32s22 32 48 32 48-14 48-32v-72zm64 0v80h16v-80z"/><path fill="#ff9811" d="M200 160h16v32h-16z"/><path fill="#d80027" d="M0 0v128h512V0zm208 184c-22 0-40 11-40 24l8 8h64l8-8c0-13-18-24-40-24m-72 8a8 8 0 0 0-8 8v8a8 8 0 1 0 16 0v-8a8 8 0 0 0-8-8m144 0a8 8 0 0 0-8 8v8a8 8 0 1 0 16 0v-8a8 8 0 0 0-8-8m-120 32v24h-38a4 4 0 0 0-4 4 4 4 0 0 0 4 4h38v40a24 24 0 0 0 24 24 24 24 0 0 0 24-24 24 24 0 0 0 24 24 24 24 0 0 0 24-24v-24h-48v-48zm72 8a10 10 0 0 0-10 10v12a10 10 0 1 0 20 0v-12a10 10 0 0 0-10-10m24 16v8h38a4 4 0 0 0 4-4 4 4 0 0 0-4-4zm-134 24a4 4 0 0 0-4 4 4 4 0 0 0 4 4h28a4 4 0 0 0 4-4 4 4 0 0 0-4-4zm144 0a4 4 0 0 0-4 4 4 4 0 0 0 4 4h28a4 4 0 0 0 4-4 4 4 0 0 0-4-4zM0 384v128h512V384z"/><path fill="#ffda44" d="M186 196a6 6 0 0 0-6 6 6 6 0 0 0 6 6 6 6 0 0 0 6-6 6 6 0 0 0-6-6m22 0a6 6 0 0 0-6 6 6 6 0 0 0 6 6 6 6 0 0 0 6-6 6 6 0 0 0-6-6m22 0a6 6 0 0 0-6 6 6 6 0 0 0 6 6 6 6 0 0 0 6-6 6 6 0 0 0-6-6"/><path fill="#ff9811" d="M128 208a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16zm144 0a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16zm-96 8v8h64v-8zm-8 16v8h8v16h-8v8h32v-8h-8v-16h8v-8zm-8 40v24q1 12 9 19v-43zm19 0v47h10v-47zm20 0v43q9-7 9-19v-24zm-71 32a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16zm144 0a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16z"/><path fill="#338af3" d="M208 256a16 16 0 0 0-16 16 16 16 0 0 0 16 16 16 16 0 0 0 16-16 16 16 0 0 0-16-16m-80 64a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16zm144 0a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16z"/>
pt	<path fill="#6da544" d="M0 512h167l37.9-260.3L167 0H0z"/><path fill="#d80027" d="M512 0H167v512h345z"/><circle cx="167" cy="256" r="89" fill="#ffda44"/><path fill="#d80027" d="M116.9 211.5V267a50 50 0 1 0 100.1 0v-55.6H117z"/><path fill="#eee" d="M167 283.8c-9.2 0-16.7-7.5-16.7-16.7V245h33.4v22c0 9.2-7.5 16.7-16.7 16.7z"/>
pl	<path fill="#d80027" d="m0 256 256.4-44.3L512 256v256H0z"/><path fill="#eee" d="M0 0h512v256H0z"/>
cz	<path fill="#eee" d="M0 0h512v256l-265 45.2z"/><path fill="#d80027" d="M210 256h302v256H0z"/><path fill="#0052b4" d="M0 0v512l256-256L0 0z"/>
sk	<path fill="#0052b4" d="m0 160 256-32 256 32v192l-256 32L0 352z"/><path fill="#eee" d="M0 0h512v160H0z"/><path fill="#d80027" d="M0 352h512v160H0z"/><path fill="#eee" d="M64 63v217c0 104 144 137 144 137s144-33 144-137V63z"/><path fill="#d80027" d="M96 95v185a83 78 0 0 0 9 34h206a83 77 0 0 0 9-34V95z"/><path fill="#eee" d="M288 224h-64v-32h32v-32h-32v-32h-32v32h-32v32h32v32h-64v32h64v32h32v-32h64z"/><path fill="#0052b4" d="M152 359a247 231 0 0 0 56 24c12-3 34-11 56-24a123 115 0 0 0 47-45 60 56 0 0 0-34-10l-14 2a60 56 0 0 0-110 0 60 56 0 0 0-14-2c-12 0-24 4-34 10a123 115 0 0 0 47 45z"/>
hu	<path fill="#eee" d="m0 167 253.8-19.3L512 167v178l-254.9 32.3L0 345z"/><path fill="#d80027" d="M0 0h512v167H0z"/><path fill="#6da544" d="M0 345h512v167H0z"/>
ro	<path fill="#ffda44" d="M167 0h178l25.9 252.3L345 512H167l-29.8-253.4z"/><path fill="#0052b4" d="M0 0h167v512H0z"/><path fill="#d80027" d="M345 0h167v512H345z"/>
bg	<path fill="#496e2d" d="m0 166.9 258-31.7 254 31.7v178l-251.4 41.3L0 344.9z"/><path fill="#eee" d="M0 0h512v166.9H0z"/><path fill="#d80027" d="M0 344.9h512V512H0z"/>
gr	<path fill="#0052b4" d="M0 0h99l29 32 28-32h356v57l-32 28 32 29v57l-32 28 32 29v57l-32 28 32 28v57l-32 29 32 28v57H0v-57l32-28-32-29v-56l32-29-32-28V171l32-29-32-28Z"/><path fill="#eee" d="M99 0v114H0v57h99v114H0v57h512v-57H156V171h100v-57H156V0Zm157 57v57h256V57Zm0 114v57h256v-57ZM0 398v57h512v-57z"/>
se	<path fill="#0052b4" d="M0 0h133.6l35.3 16.7L200.3 0H512v222.6l-22.6 31.7 22.6 35.1V512H200.3l-32-19.8-34.7 19.8H0V289.4l22.1-33.3L0 222.6z"/><path fill="#ffda44" d="M133.6 0v222.6H0v66.8h133.6V512h66.7V289.4H512v-66.8H200.3V0z"/>
no	<path fill="#d80027" d="M0 0h100.2l66.1 53.5L233.7 0H512v189.3L466.3 257l45.7 65.8V512H233.7l-68-50.7-65.5 50.7H0V322.8l51.4-68.5-51.4-65z"/><path fill="#eee" d="M100.2 0v189.3H0v33.4l24.6 33L0 289.5v33.4h100.2V512h33.4l30.6-26.3 36.1 26.3h33.4V322.8H512v-33.4l-24.6-33.7 24.6-33v-33.4H233.7V0h-33.4l-33.8 25.3L133.6 0z"/><path fill="#0052b4" d="M133.6 0v222.7H0v66.7h133.6V512h66.7V289.4H512v-66.7H200.3V0z"/>
dk	<path fill="#d80027" d="M0 0h133.6l32.7 20.3 34-20.3H512v222.6L491.4 256l20.6 33.4V512H200.3l-31.7-20.4-35 20.4H0V289.4l29.4-33L0 222.7z"/><path fill="#eee" d="M133.6 0v222.6H0v66.8h133.6V512h66.7V289.4H512v-66.8H200.3V0h-66.7z"/>
is	<path fill="#0052b4" d="M0 0h100.2l66.1 53.5L233.7 0H512v189.3L466.3 257l45.7 65.8V512H233.7l-68-50.7-65.5 50.7H0V322.8l51.4-68.5-51.4-65z"/><path fill="#eee" d="M100.2 0v189.3H0v33.4l24.6 33L0 289.5v33.4h100.2V512h33.4l30.6-26.3 36.1 26.3h33.4V322.8H512v-33.4l-24.6-33.7 24.6-33v-33.4H233.7V0h-33.4l-33.8 25.3L133.6 0z"/><path fill="#d80027" d="M133.6 0v222.7H0v66.7h133.6V512h66.7V289.4H512v-66.7H200.3V0z"/>
ee	<path fill="#333" d="m0 167 254.6-36.6L512 166.9v178l-254.6 36.4L0 344.9z"/><path fill="#0052b4" d="M0 0h512v166.9H0z"/><path fill="#eee" d="M0 344.9h512V512H0z"/>
lv	<path fill="#a2001d" d="M0 0h512v189.2l-38.5 70 38.5 63.6V512H0V322.8l39.4-63L0 189.1z"/><path fill="#eee" d="M0 189.2h512v133.6H0z"/>
lt	<path fill="#6da544" d="m0 167 253.8-19.3L512 167v178l-254.9 32.3L0 345z"/><path fill="#ffda44" d="M0 0h512v167H0z"/><path fill="#d80027" d="M0 345h512v167H0z"/>
md	<path fill="#0052b4" d="M0 0h144.7l36 254.6-36 257.4H0z"/><path fill="#d80027" d="M367.3 0H512v512H367.3l-29.7-257.3z"/><path fill="#ffda44" d="M144.7 0h222.6v512H144.7z"/><path fill="#ff9811" d="M345.1 201.4H284a27.8 27.8 0 1 0-55.6 0h-61.2a28.2 28.2 0 0 0 28.3 27.4h-1a27.4 27.4 0 0 0 27.5 27.4c0 13.4 9.6 24.5 22.3 27l-21.6 48.7a88.8 88.8 0 0 0 33.5 6.5 88.8 88.8 0 0 0 33.5-6.5L268.1 283a27.4 27.4 0 0 0 22.3-26.9 27.4 27.4 0 0 0 27.4-27.4h-.9a28.2 28.2 0 0 0 28.3-27.4z"/><path fill="#0052b4" d="M256.1 239.3 220 256v33.4l36.2 22.3 36.2-22.3V256z"/><path fill="#d80027" d="M220 222.6h72.3V256H220z"/>
ua	<path fill="#ffda44" d="m0 256 258-39.4L512 256v256H0z"/><path fill="#338af3" d="M0 0h512v256H0z"/>
by	<path fill="#eee" d="M0 0h155.8l35 254.6-35 257.4H0z"/><path fill="#a2001d" d="M155.8 0H512v345.1l-183 37.4-173.2-37.4z"/><path fill="#6da544" d="M155.8 345.1H512V512H155.8z"/><path fill="#a2001d" d="M50 .2 22.3 50l27.8 50.4L77.9 50zm55.8 0L78 50l27.7 50.4 28-50.4zM50 137.5l-27.7 49.6 27.8 50.5 27.7-50.5zm55.8 0L78 187.1l27.7 50.5 28-50.5zM50 274.7l-27.7 49.7 27.8 50.4 27.8-50.4zm55.8 0L78 324.4l27.7 50.4 28-50.4zM50 412l-27.7 49.6 27.8 50.5 27.7-50.5zm55.8 0L78 461.6l27.7 50.5 28-50.5z"/>
rs	<path fill="#0052b4" d="m0 167 253.8-19.3L512 167v178l-254.9 32.3L0 345z"/><path fill="#d80027" d="M0 0h512v167H0z"/><path fill="#eee" d="M0 345h512v167H0z"/><path fill="#d80027" d="M66.2 144.7v127.7c0 72.6 94.9 95 94.9 95s94.9-22.4 94.9-95V144.7z"/><path fill="#ffda44" d="M105.4 167h111.4v-44.6l-22.3 11.2-33.4-33.4-33.4 33.4-22.3-11.2zm128.3 123.2-72.3-72.4L89 290.2l23.7 23.6 48.7-48.7 48.7 48.7z"/><path fill="#eee" d="M233.7 222.6H200a22.1 22.1 0 0 0 3-11.1 22.3 22.3 0 0 0-42-10.5 22.3 22.3 0 0 0-41.9 10.5 22.1 22.1 0 0 0 3 11.1H89a23 23 0 0 0 23 22.3h-.7c0 12.3 10 22.2 22.3 22.2 0 11 7.8 20 18.1 21.9l-17.5 39.6a72.1 72.1 0 0 0 27.2 5.3 72.1 72.1 0 0 0 27.2-5.3L171.1 289c10.3-2 18.1-11 18.1-21.9 12.3 0 22.3-10 22.3-22.2h-.8a23 23 0 0 0 23-22.3z"/>
hr	<path fill="#eee" d="m0 167 253.8-19.3L512 167v178l-254.9 32.3L0 345z"/><path fill="#d80027" d="M0 0h512v167H0z"/><path fill="#0052b4" d="M0 345h512v167H0z"/><path fill="#338af3" d="M322.8 178h-44.5l7.4-55.7 29.7-22.2 29.6 22.2V167zm-133.6 0h44.5l-7.4-55.7-29.7-22.2-29.6 22.2V167z"/><path fill="#0052b4" d="M285.7 178h-59.4v-55.7l29.7-22.2 29.7 22.2z"/><path fill="#eee" d="M167 167v122.3a89 89 0 0 0 35.8 71.3l15.5-3.9 19.7 19.8a89.1 89.1 0 0 0 18 1.8 89 89 0 0 0 17.9-1.8l22.4-18.7 13 2.8a89 89 0 0 0 35.7-71.3V167z"/><path fill="#d80027" d="M167 167h35.6v35.5H167zm71.2 0h35.6v35.5h-35.6zm71.2 0H345v35.5h-35.6zm-106.8 35.5h35.6v35.6h-35.6zm71.2 0h35.6v35.6h-35.6zM167 238.1h35.6v35.6H167zm35.6 35.6h35.6v35.6h-35.6zm35.6-35.6h35.6v35.6h-35.6zm71.2 0H345v35.6h-35.6zm-35.6 35.6h35.6v35.6h-35.6zm-35.6 35.6h35.6V345h-35.6zm-35.6 0h-33.3c3 13.3 9 25.4 17.3 35.6h16zM309.4 345h16a88.8 88.8 0 0 0 17.3-35.6h-33.3zm-106.8 0v15.6a88.7 88.7 0 0 0 35.6 16V345zm71.2 0v31.6a88.7 88.7 0 0 0 35.6-16V345z"/>
si	<path fill="#0052b4" d="m0 167 253.8-19.3L512 167v178l-254.9 32.3L0 345z"/><path fill="#eee" d="M0 0h512v167H0z"/><path fill="#d80027" d="M0 345h512v167H0z"/><path fill="#0052b4" d="M222.7 167v-66.8H89V167l67 82.6z"/><path fill="#eee" d="M89 167v22.2c0 51.1 66.8 66.8 66.8 66.8s66.8-15.7 66.8-66.8V167l-22.3 22.2-44.5-33.4-44.5 33.4z"/>
cy	<path fill="#eee" d="M0 0h512v512H0z"/><path fill="#6da544" d="M400.7 222.6h-33.4a111.3 111.3 0 0 1-222.6 0h-33.4c0 66.2 44.5 122 105.2 139.2a37 37 0 0 0 3.9 40.5l36.3-29.2 36.4 29.2a37 37 0 0 0 3.7-40.8 144.8 144.8 0 0 0 103.9-138.9z"/><path fill="#ffda44" d="M167 211.5s0 55.6 55.6 55.6l11.1 11.2H256s11.1-33.4 33.4-33.4c0 0 0-22.3 22.3-22.3H345s-11-44.5 44.6-77.9l-22.3-11.1s-78 55.6-133.6 44.5v22.2h-22.2l-11.2-11-33.3 22.2z"/>
ru	<path fill="#0052b4" d="M512 170v172l-256 32L0 342V170l256-32z"/><path fill="#eee" d="M512 0v170H0V0Z"/><path fill="#d80027" d="M512 342v170H0V342Z"/>
kz	<path fill="#338af3" d="M0 0h512v512H0z"/><path fill="#ffda44" d="M400.7 258.8H111.3c0 20 17.4 36.2 37.4 36.2h-1.2c0 20 16.2 36.1 36.2 36.1 0 20 16.1 36.2 36.1 36.2h72.4c20 0 36.1-16.2 36.1-36.2 20 0 36.2-16.2 36.2-36.1h-1.2c20 0 37.4-16.2 37.4-36.2z"/><path fill="#338af3" d="M356.2 211.5a100.2 100.2 0 0 1-200.4 0"/><path fill="#ffda44" d="m332.5 211.5-31.3 14.7 16.7 30.3-34-6.5-4.3 34.3L256 259l-23.6 25.3L228 250l-34 6.5 16.6-30.3-31.2-14.7 31.2-14.7-16.6-30.3 34 6.5 4.3-34.3 23.6 25.2 23.6-25.2L284 173l34-6.5-16.6 30.3z"/>
uz	<path fill="#d80027" d="m0 178 254.2-22L512 178v22.3l-40.2 54.1 40.2 57.3V334l-254 23.4L0 334v-22.3l36.7-59.4-36.7-52z"/><path fill="#338af3" d="M0 0h512v178H0z"/><path fill="#eee" d="M0 200.3h512v111.4H0z"/><path fill="#6da544" d="M0 334h512v178H0z"/><path fill="#eee" d="M117.2 105.7a50 50 0 0 1 39.3-48.9 50.2 50.2 0 0 0-10.7-1.1 50 50 0 1 0 10.7 99c-22.5-5-39.3-25-39.3-49zm69 22.8 3.3 10.4h11l-9 6.5 3.5 10.4-9-6.4-8.7 6.4 3.4-10.4-9-6.5h11zm35 0 3.4 10.4h11l-9 6.5 3.4 10.4-8.8-6.4-9 6.4 3.5-10.4-9-6.5h11zm35 0 3.4 10.4h11l-9 6.5 3.5 10.4-9-6.4-8.8 6.4 3.4-10.4-9-6.5h11zm35 0 3.4 10.4h11l-9 6.5 3.5 10.4-9-6.4-8.8 6.4 3.4-10.4-9-6.5h11zm35 0 3.4 10.4h11l-9 6.5 3.5 10.4-9-6.4-8.8 6.4 3.4-10.4-8.8-6.5h11zm-105-36.4 3.4 10.4h11l-9 6.5 3.4 10.4-8.8-6.5-9 6.5 3.5-10.4-9-6.5h11zm35 0 3.4 10.4h11l-9 6.5 3.5 10.4-9-6.5-8.8 6.5 3.4-10.4-9-6.5h11zm35 0 3.4 10.4h11l-9 6.5 3.5 10.4-9-6.5-8.8 6.5 3.4-10.4-9-6.5h11zm35 0 3.4 10.4h11l-9 6.5 3.5 10.4-9-6.5-8.8 6.5 3.4-10.4-8.8-6.5h11zm-70-36.4 3.4 10.4h11l-9 6.4 3.6 10.5-9-6.5-8.8 6.5 3.4-10.5-9-6.4h11zm35 0 3.4 10.4h11l-9 6.4 3.6 10.5-9-6.5-8.8 6.5 3.4-10.5-9-6.4h11zm35 0 3.4 10.4h11l-9 6.4 3.6 10.5-9-6.5-8.8 6.5 3.4-10.5-8.8-6.4h11z"/>
kg	<path fill="#d80027" d="M0 0h512v512H0z"/><path fill="#ffda44" d="M381.2 256 330 280l27.3 49.6-55.6-10.6-7 56.1-38.7-41.3-38.7 41.3-7-56.1-55.6 10.6 27.3-49.5-51.2-24.1 51.2-24-27.3-49.6 55.6 10.6 7-56.1 38.7 41.3 38.7-41.3 7 56.1 55.6-10.6-27.3 49.5z"/><circle cx="256" cy="256" r="77.9" fill="#d80027"/><path fill="#ffda44" d="M217 256c-1.8 0-3.7.1-5.5.3a44.3 44.3 0 0 0 10.4 28.3 78 78 0 0 1 15-24.9A55.4 55.4 0 0 0 217 256zm24 42a44.4 44.4 0 0 0 30 0c-2.6-10-7.8-19-15-26-7.2 7-12.4 16-15 26zm53.6-64.3a44.5 44.5 0 0 0-77.2 0 77.4 77.4 0 0 1 38.6 10.5 77.4 77.4 0 0 1 38.6-10.5zm-19.6 26a78 78 0 0 1 15.1 25 44.3 44.3 0 0 0 10.4-28.4 55.8 55.8 0 0 0-5.5-.3 55.3 55.3 0 0 0-20 3.7z"/>
tr	<path fill="#d80027" d="M0 0h512v512H0z"/><path fill="#eee" d="M208 115a141 141 0 1 0 106 242q-25 13-54 13a114 114 0 1 1 54-215 141 141 0 0 0-106-40m142 67v56l-54 18 54 17v57l33-46 54 18-33-46 33-46-54 18z"/>
ge	<path fill="#eee" d="M0 0h224l32 32 32-32h224v224l-32 32 32 32v224H288l-32-32-32 32H0V288l32-32-32-32Z"/><path fill="#d80027" d="M224 0v224H0v64h224v224h64V288h224v-64H288V0h-64zm-96 96v32H96v32h32v32h32v-32h32v-32h-32V96h-32zm224 0v32h-32v32h32v32h32v-32h32v-32h-32V96h-32zM128 320v32H96v32h32v32h32v-32h32v-32h-32v-32h-32zm224 0v32h-32v32h32v32h32v-32h32v-32h-32v-32h-32z"/>
am	<path fill="#0052b4" d="m0 171 256-32 256 32v170l-256 32L0 341Z"/><path fill="#d80027" d="M0 0h512v171H0Z"/><path fill="#ff9811" d="M0 341h512v171H0Z"/>
az	<path fill="#d80027" d="m0 167 256-32 256 32v178l-256 32L0 345Z"/><path fill="#338af3" d="M0 0h512v167H0Z"/><path fill="#6da544" d="M0 345h512v167H0Z"/><path fill="#eee" d="M229 167a89 89 0 1 0 67 153 72 72 0 0 1-34 8 72 72 0 1 1 34-136 89 89 0 0 0-67-25m88 39-9 27-26-12 12 25-27 10 27 10-12 25 26-12 9 27 10-27 26 12-13-25 27-10-27-10 13-25-26 12z"/>
ae	<path fill="#a2001d" d="M0 0h167l52.3 252L167 512H0z"/><path fill="#eee" d="m167 167 170.8-44.6L512 167v178l-173.2 36.9L167 345z"/><path fill="#6da544" d="M167 0h345v167H167z"/><path fill="#333" d="M167 345h345v167H167z"/>
il	<path fill="#eee" d="M0 0h512v55.7l-25 32.7 25 34v267.2l-26 36 26 30.7V512H0v-55.7l24.8-34.1L0 389.6V122.4l27.2-33.2L0 55.7z"/><path fill="#0052b4" d="M0 55.7v66.7h512V55.7zm0 333.9v66.7h512v-66.7zm352.4-189.3H288l-32-55.6-32.1 55.6h-64.3l32.1 55.7-32 55.7h64.2l32.1 55.6 32.1-55.6h64.3L320.3 256l32-55.7zm-57 55.7-19.7 34.2h-39.4L216.5 256l19.8-34.2h39.4l19.8 34.2zM256 187.6l7.3 12.7h-14.6zm-59.2 34.2h14.7l-7.4 12.7zm0 68.4 7.3-12.7 7.4 12.7zm59.2 34.2-7.3-12.7h14.6zm59.2-34.2h-14.7l7.4-12.7zm-14.7-68.4h14.7l-7.3 12.7z"/>
in	<path fill="#eee" d="m0 160 256-32 256 32v192l-256 32L0 352z"/><path fill="#ff9811" d="M0 0h512v160H0Z"/><path fill="#6da544" d="M0 352h512v160H0Z"/><circle cx="256" cy="256" r="72" fill="#0052b4"/><circle cx="256" cy="256" r="48" fill="#eee"/><circle cx="256" cy="256" r="24" fill="#0052b4"/>
sg	<path fill="#d80027" d="M0 0h512v256l-256 32L0 256Z"/><path fill="#eee" d="M200 56a78 78 0 1 0 17 154 78 78 0 0 1 0-152q-8-2-17-2m56 5-5 17h-18l14 11-5 17 14-11 15 11-6-17 15-11h-18zm-43 34-6 17h-18l15 10-6 17 15-10 14 10-5-17 14-10h-18zm86 0-5 17h-18l14 10-5 17 14-10 15 10-6-17 15-10h-18zm-70 50-5 17h-18l14 10-5 17 14-10 15 10-6-17 15-10h-18zm54 0-6 17h-18l15 10-6 17 15-10 14 10-5-17 14-10h-18ZM0 256v256h512V256Z"/>
hk	<path fill="#d80027" d="M0 0h512v512H0z"/><path fill="#eee" d="M282.4 193.7c-5.8 24.2-16.1 19.6-21.2 40.7a55.7 55.7 0 0 1 26-108.3c-10.1 42.2.4 46-4.8 67.6zM205 211.6c21.2 13 13.6 21.4 32.1 32.8a55.7 55.7 0 0 1-94.9-58.2c37 22.7 43.8 13.8 62.8 25.4zm-7 79.3c19-16.2 24.7-6.4 41.2-20.4a55.7 55.7 0 0 1-84.7 72.2c33-28.2 26.6-37.4 43.6-51.8zm73.4 31c-9.6-23 1.5-25.3-6.8-45.3a55.7 55.7 0 0 1 42.6 102.8c-16.6-40-27.3-36.9-35.8-57.4zm52.2-60c-24.9 2-23.7-9.3-45.3-7.6a55.7 55.7 0 0 1 111-8.7c-43.3 3.4-43.6 14.5-65.7 16.3z"/>
jp	<path fill="#eee" d="M0 0h512v512H0z"/><circle cx="256" cy="256" r="111.3" fill="#d80027"/>
kr	<path fill="#eee" d="M0 0h512v512H0Z"/><path fill="#333" d="m350 335 24-24 16 16-24 23zm-39 39 24-24 15 16-23 24zm87 8 23-24 16 16-24 24zm-40 39 24-23 16 15-24 24Zm16-63 24-23 15 15-23 24zm-39 40 23-24 16 16-24 23zm63-221-63-63 15-15 64 63zm-63-15-24-24 16-16 23 24zm39 39-24-24 16-15 24 23zm8-87-24-23 16-16 24 24Zm39 40-23-24 15-16 24 24ZM91 358l63 63-16 16-63-63zm63 16 23 24-15 15-24-23zm-40-39 24 23-16 16-23-24zm24-24 63 63-16 16-63-63zm16-220-63 63-16-16 63-63zm23 23-63 63-15-16 63-63zm24 24-63 63-16-16 63-63z"/><path fill="#d80027" d="M319 319 193 193a89 89 0 1 1 126 126z"/><path fill="#0052b4" d="M319 319a89 89 0 1 1-126-126z"/><circle cx="224.5" cy="224.5" r="44.5" fill="#d80027"/><circle cx="287.5" cy="287.5" r="44.5" fill="#0052b4"/>
tw	<path fill="#d80027" d="M0 256 256 0h256v512H0z"/><path fill="#0052b4" d="M256 256V0H0v256z"/><path fill="#eee" d="m222.6 149.8-31.3 14.7 16.7 30.3-34-6.5-4.3 34.3-23.6-25.2-23.7 25.2-4.3-34.3-34 6.5 16.7-30.3-31.2-14.7 31.2-14.7-16.6-30.3 34 6.5 4.2-34.3 23.7 25.3L169.7 77l4.3 34.3 34-6.5-16.7 30.3z"/><circle cx="146.1" cy="149.8" r="47.7" fill="#0052b4"/><circle cx="146.1" cy="149.8" r="41.5" fill="#eee"/>
cn	<path fill="#d80027" d="M0 0h512v512H0z"/><path fill="#ffda44" d="m140.1 155.8 22.1 68h71.5l-57.8 42.1 22.1 68-57.9-42-57.9 42 22.2-68-57.9-42.1H118zm163.4 240.7-16.9-20.8-25 9.7 14.5-22.5-16.9-20.9 25.9 6.9 14.6-22.5 1.4 26.8 26 6.9-25.1 9.6zm33.6-61 8-25.6-21.9-15.5 26.8-.4 7.9-25.6 8.7 25.4 26.8-.3-21.5 16 8.6 25.4-21.9-15.5zm45.3-147.6L370.6 212l19.2 18.7-26.5-3.8-11.8 24-4.6-26.4-26.6-3.8 23.8-12.5-4.6-26.5 19.2 18.7zm-78.2-73-2 26.7 24.9 10.1-26.1 6.4-1.9 26.8-14.1-22.8-26.1 6.4 17.3-20.5-14.2-22.7 24.9 10.1z"/>
id	<path fill="#eee" d="m0 256 249.6-41.3L512 256v256H0z"/><path fill="#d80027" d="M0 0h512v256H0z"/>
vn	<path fill="#d80027" d="M0 0h512v512H0Z"/><path fill="#ffda44" d="m176 378 208-150H128l208 150-80-244Z"/>
th	<path fill="#d80027" d="M0 0h512v89l-79.2 163.7L512 423v89H0v-89l82.7-169.6L0 89z"/><path fill="#eee" d="M0 89h512v78l-42.6 91.2L512 345v78H0v-78l40-92.5L0 167z"/><path fill="#0052b4" d="M0 167h512v178H0z"/>
my	<path fill="#eee" d="M256 0h256v64l-32 32 32 32v64l-32 32 32 32v64l-32 32 32 32v64l-256 32L0 448v-64l32-32-32-32v-64z"/><path fill="#d80027" d="M224 64h288v64H224Zm0 128h288v64H256ZM0 320h512v64H0Zm0 128h512v64H0Z"/><path fill="#0052b4" d="M0 0h256v256H0Z"/><path fill="#ffda44" d="M142 78a78 78 0 1 0 58 134 63 63 0 0 1-30 7 63 63 0 1 1 30-119 78 78 0 0 0-58-22m46 33-11 24-26-6 12 23-21 17 26 5v26l20-16 20 16v-26l26-5-21-17 12-23-26 6z"/>
ph	<path fill="#0052b4" d="M0 0h512v256l-265 45.2z"/><path fill="#d80027" d="M210 256h302v256H0z"/><path fill="#eee" d="M0 0v512l256-256z"/><path fill="#ffda44" d="M175.3 256 144 241.3l16.7-30.3-34 6.5-4.3-34.3-23.6 25.2L75 183.2l-4.3 34.3-34-6.5 16.7 30.3L22.3 256l31.2 14.7L37 301l34-6.5 4.2 34.3 23.7-25.2 23.6 25.2 4.3-34.3 34 6.5-16.7-30.3zm-107-155.8 10.4 14.5 17-5.4-10.6 14.4 10.4 14.5-17-5.6L68 147l.2-17.9-17-5.6 17-5.4zm0 264.8 10.4 14.6 17-5.4-10.6 14.3 10.4 14.6-17-5.7L68 411.8l.2-17.9-17-5.6 17-5.4zm148.4-132.4L206.3 247l-17-5.4 10.5 14.4-10.4 14.6 17-5.7 10.6 14.4-.1-17.9 17-5.6-17.1-5.4z"/>
us	<path fill="#eee" d="M256 0h256v64l-32 32 32 32v64l-32 32 32 32v64l-32 32 32 32v64l-256 32L0 448v-64l32-32-32-32v-64z"/><path fill="#d80027" d="M224 64h288v64H224Zm0 128h288v64H256ZM0 320h512v64H0Zm0 128h512v64H0Z"/><path fill="#0052b4" d="M0 0h256v256H0Z"/><path fill="#eee" d="m187 243 57-41h-70l57 41-22-67zm-81 0 57-41H93l57 41-22-67zm-81 0 57-41H12l57 41-22-67zm162-81 57-41h-70l57 41-22-67zm-81 0 57-41H93l57 41-22-67zm-81 0 57-41H12l57 41-22-67Zm162-82 57-41h-70l57 41-22-67Zm-81 0 57-41H93l57 41-22-67zm-81 0 57-41H12l57 41-22-67Z"/>
ca	<path fill="#d80027" d="M0 0v512h144l112-64 112 64h144V0H368L256 64 144 0Z"/><path fill="#eee" d="M144 0h224v512H144Z"/><path fill="#d80027" d="m301 289 44-22-22-11v-22l-45 22 23-44h-23l-22-34-22 33h-23l23 45-45-22v22l-22 11 45 22-12 23h45v33h22v-33h45z"/>
br	<path fill="#6da544" d="M0 0h512v512H0z"/><path fill="#ffda44" d="M256 100.2 467.5 256 256 411.8 44.5 256z"/><path fill="#eee" d="M174.2 221a87 87 0 0 0-7.2 36.3l162 49.8a88.5 88.5 0 0 0 14.4-34c-40.6-65.3-119.7-80.3-169.1-52z"/><path fill="#0052b4" d="M255.7 167a89 89 0 0 0-41.9 10.6 89 89 0 0 0-39.6 43.4 181.7 181.7 0 0 1 169.1 52.2 89 89 0 0 0-9-59.4 89 89 0 0 0-78.6-46.8zM212 250.5a149 149 0 0 0-45 6.8 89 89 0 0 0 10.5 40.9 89 89 0 0 0 120.6 36.2 89 89 0 0 0 30.7-27.3A151 151 0 0 0 212 250.5z"/>
ar	<path fill="#338af3" d="M0 0h512v144.7L488 256l24 111.3V512H0V367.3L26 256 0 144.7z"/><path fill="#eee" d="M0 144.7h512v222.6H0z"/><path fill="#ffda44" d="m332.4 256-31.2 14.7 16.7 30.3-34-6.5-4.2 34.3-23.7-25.2-23.6 25.2-4.3-34.3-34 6.5 16.6-30.3-31.2-14.7 31.3-14.7L194 211l34 6.5 4.3-34.3 23.6 25.2 23.6-25.2 4.4 34.3 34-6.5-16.7 30.3z"/>
mx	<path fill="#eee" d="M144 0h223l33 256-33 256H144l-32-256z"/><path fill="#d80027" d="M368 0h144v512H368z"/><path fill="#751a46" d="M256 174c22 11 12 33 11 34l-2-4c-4-15-13-33-31-18v11q10 1 11 11-11 12-4 26l4 8-13 23 29-7 18 18v-11l11 11 23-11-35-21-2-13c22-2 34 4 51 29 9-83-45-86-64-86Z"/><path fill="#6da544" d="M209 183q-5 4-4 12 1 11 10 15c3 2 8 0 10 3 3 3-2 5-4 6q-8 5-9 14 3 10 12 15c2 2 7 4 5 7q-4 2-9-2-12-6-19-19c-2-3-1-10-7-10-7 2-4 10-2 14q8 14 21 23 9 8 20 3 10-6 4-17c-3-6-11-8-14-14-2-3 2-4 4-6q8-4 9-11-2-13-14-15-6 1-7-6c-1-3 3-7 0-11q-2-3-6-1"/><path fill="#496e2d" d="M0 0v512h144V0zm164 235a5 5 0 0 0-5 5 97 97 0 0 0 194 0 5 5 0 0 0-5-5 5 5 0 0 0-5 5 87 87 0 1 1-174 0 5 5 0 0 0-5-5m35 25-4 1q-3 4 1 8 23 21 54 24v17h12v-17q31-3 54-24 4-4 1-8-4-3-8 0a78 78 0 0 1-106 0z"/><path fill="#338af3" d="M256 316q-21 0-40-13l6-9c20 13 48 13 68 0l7 9q-18 13-41 13"/><rect width="34" height="22" x="239" y="299" fill="#ff9811" rx="11" ry="11"/><path fill="#ffda44" d="m234 186-12 11v11l18-9q4-3 1-7zm-62 79a10 10 0 0 0-10 10 10 10 0 0 0 10 10 10 10 0 0 0 10-10 10 10 0 0 0-10-10m169 0a10 10 0 0 0-10 10 10 10 0 0 0 10 10 10 10 0 0 0 10-10 10 10 0 0 0-10-10m-69 4-16 8v5l15-1 4-9zm-83 23a10 10 0 0 0-10 10 10 10 0 0 0 10 10 10 10 0 0 0 10-10 10 10 0 0 0-10-10m135 0a10 10 0 0 0-10 10 10 10 0 0 0 10 10 10 10 0 0 0 10-10 10 10 0 0 0-10-10m-108 21a10 10 0 0 0-10 10 10 10 0 0 0 10 10 10 10 0 0 0 10-10 10 10 0 0 0-10-10m81 0a10 10 0 0 0-10 10 10 10 0 0 0 10 10 10 10 0 0 0 10-10 10 10 0 0 0-10-10"/>
cl	<path fill="#d80027" d="m0 256 254.5-51.3L512 256v256H0z"/><path fill="#0052b4" d="M0 0h256l52.7 132.8L256 256H0z"/><path fill="#eee" d="M256 0h256v256H256zM152.4 89l16.6 51h53.6l-43.4 31.6 16.6 51-43.4-31.5-43.4 31.5 16.6-51L82.2 140h53.6z"/>
co	<path fill="#d80027" d="m0 384 255.8-29.7L512 384v128H0z"/><path fill="#0052b4" d="m0 256 259.5-31L512 256v128H0z"/><path fill="#ffda44" d="M0 0h512v256H0z"/>
au	<path fill="#0052b4" d="M0 0h512v512H0z"/><path fill="#eee" d="m154 300 14 30 32-8-14 30 25 20-32 7 1 33-26-21-26 21 1-33-33-7 26-20-14-30 32 8zm222-27h47l-38 27 15-44 14 44zm7-162 7 15 16-4-7 15 12 10-15 3v17l-13-11-13 11v-17l-15-3 12-10-7-15 16 4zm57 67 7 15 16-4-7 15 12 10-15 3v16l-13-10-13 11v-17l-15-3 12-10-7-15 16 4zm-122 22 7 15 16-4-7 15 12 10-15 3v16l-13-10-13 11v-17l-15-3 12-10-7-15 16 4zm65 156 7 15 16-4-7 15 12 10-15 3v17l-13-11-13 11v-17l-15-3 12-10-7-15 16 4zM0 0v32l32 32L0 96v160h32l32-32 32 32h32v-83l83 83h45l-8-16 8-15v-14l-83-83h83V96l-32-32 32-32V0H96L64 32 32 0Z"/><path fill="#d80027" d="M32 0v32H0v64h32v160h64V96h160V32H96V0Zm96 128 128 128v-31l-97-97z"/>
nz	<path fill="#0052b4" d="M256 0h256v512H0V256Z"/><path fill="#eee" d="M0 0v32l32 32L0 96v160h32l32-32 32 32h32v-83l83 83h45l-8-16 8-15v-14l-83-83h83V96l-32-32 32-32V0H96L64 32 32 0Zm382 92-11 35h-37l30 21-12 35 30-22 30 22-12-35 30-21h-37l-11-35Zm61 72-11 35h-37l30 21-11 35 29-21 30 21-12-35 30-21h-37Zm-123 10-11 35h-37l30 22-11 35 29-22 30 22-11-35 29-22h-36zm59 130-11 35h-37l30 21-11 35 29-21 30 21-11-35 29-21h-36z"/><path fill="#d80027" d="M32 0v32H0v64h32v160h64V96h160V32H96V0Zm96 128 128 128v-31l-97-97zm251 201-5 18h-19l15 10-6 18 15-11 15 11-5-18 14-10h-18Zm-59-129-5 17h-19l15 11-6 17 15-11 15 11-6-17 15-11h-18l-6-17zm123-11-6 18h-18l15 11-6 17 15-11 15 11-6-17 15-11h-18l-6-18zm-61-72-6 17h-18l15 11-6 17 15-10 15 10-6-17 15-11h-18z"/>
za	<path fill="#eee" d="m0 0 192 256L0 512h47l465-189v-34l-32-33 32-33v-34L47 0Z"/><path fill="#333" d="M0 142v228l140-114z"/><path fill="#ffda44" d="M192 256 0 95v47l114 114L0 370v47z"/><path fill="#6da544" d="M512 223H223L0 0v94l161 162L0 418v94l223-223h289z"/><path fill="#d80027" d="M512 0H47l189 189h276z"/><path fill="#0052b4" d="M512 512H47l189-189h276z"/>
sc	<path fill="#0052b4" d="M0 0v332l150.9-138.5L225.2 0z"/><path fill="#ffda44" d="M273.1 253.3 512 0H225.2L0 332v80.2z"/><path fill="#d80027" d="M512 0 0 412.2v50.4L277.9 390 512 256z"/><path fill="#eee" d="M0 462.6 512 256v133.5l-223.9 78.8L0 488.4z"/><path fill="#6da544" d="m512 389.5-512 99V512h512z"/>
pa	<path fill="#eee" d="M0 0h256l256 256v256H256L0 256z"/><path fill="#0052b4" d="M0 256v256h256V256z"/><path fill="#d80027" d="M256 0h256v256H256z"/><path fill="#0052b4" d="m152.4 89 16.6 51h53.6l-43.4 31.6 16.6 51-43.4-31.5-43.4 31.5 16.6-51L82.2 140h53.6z"/><path fill="#d80027" d="m359.6 289.4 16.6 51h53.6L386.4 372l16.6 51-43.4-31.5-43.4 31.6 16.6-51-43.4-31.6H343z"/>
MTFLAGEOF
    while IFS=$'\t' read -r a b c; do [[ -n "$b" ]] && { MT_CNAME[$a]="$b"; [[ -n "$c" ]] && MT_CACC[$a]="$c"; }; done <<'MTCNEOF'
NL	Нидерланды
DE	Германия	Германию
FI	Финляндия	Финляндию
FR	Франция	Францию
GB	Великобритания	Великобританию
IE	Ирландия	Ирландию
BE	Бельгия	Бельгию
LU	Люксембург
AT	Австрия	Австрию
CH	Швейцария	Швейцарию
IT	Италия	Италию
ES	Испания	Испанию
PT	Португалия	Португалию
PL	Польша	Польшу
CZ	Чехия	Чехию
SK	Словакия	Словакию
HU	Венгрия	Венгрию
RO	Румыния	Румынию
BG	Болгария	Болгарию
GR	Греция	Грецию
SE	Швеция	Швецию
NO	Норвегия	Норвегию
DK	Дания	Данию
IS	Исландия	Исландию
EE	Эстония	Эстонию
LV	Латвия	Латвию
LT	Литва	Литву
MD	Молдова	Молдову
UA	Украина	Украину
BY	Беларусь
RS	Сербия	Сербию
HR	Хорватия	Хорватию
SI	Словения	Словению
CY	Кипр
MT	Мальта	Мальту
AL	Албания	Албанию
BA	Босния и Герцеговина	Боснию и Герцеговину
MK	Северная Македония	Северную Македонию
ME	Черногория	Черногорию
XK	Косово
LI	Лихтенштейн
MC	Монако
AD	Андорра	Андорру
GI	Гибралтар
IM	Остров Мэн
RU	Россия	Россию
KZ	Казахстан
UZ	Узбекистан
KG	Киргизия	Киргизию
TJ	Таджикистан
TM	Туркменистан
MN	Монголия	Монголию
TR	Турция	Турцию
GE	Грузия	Грузию
AM	Армения	Армению
AZ	Азербайджан
AE	ОАЭ
IL	Израиль
SA	Саудовская Аравия	Саудовскую Аравию
QA	Катар
KW	Кувейт
BH	Бахрейн
OM	Оман
JO	Иордания	Иорданию
LB	Ливан
IR	Иран
IQ	Ирак
IN	Индия	Индию
PK	Пакистан
BD	Бангладеш
LK	Шри-Ланка	Шри-Ланку
NP	Непал
SG	Сингапур
HK	Гонконг
MO	Макао
JP	Япония	Японию
KR	Южная Корея	Южную Корею
TW	Тайвань
CN	Китай
ID	Индонезия	Индонезию
VN	Вьетнам
TH	Таиланд
MY	Малайзия	Малайзию
PH	Филиппины
KH	Камбоджа	Камбоджу
US	США
CA	Канада	Канаду
MX	Мексика	Мексику
BR	Бразилия	Бразилию
AR	Аргентина	Аргентину
CL	Чили
CO	Колумбия	Колумбию
PE	Перу
VE	Венесуэла	Венесуэлу
UY	Уругвай
EC	Эквадор
CR	Коста-Рика	Коста-Рику
PA	Панама	Панаму
BZ	Белиз
AU	Австралия	Австралию
NZ	Новая Зеландия	Новую Зеландию
ZA	ЮАР
EG	Египет
MA	Марокко
TN	Тунис
NG	Нигерия	Нигерию
KE	Кения	Кению
SC	Сейшелы
MU	Маврикий
VG	Британские Виргинские острова
KY	Каймановы острова
BM	Бермуды
CW	Кюрасао
MTCNEOF
}

# Палитра и геометрия. Тональная схема M3 (тёмная) из оранжевого исходного
# цвета — как в макете 5b. Красного (error) в макете нет, а «блок» без него не
# отличить от «да»: взят стандартный error container из M3.
mt_style_init() {
    C_BG="#0f0b09"; C_SURF="#231f1c"; C_ON="#e7e1de"; C_ON2="#d1c3bb"
    C_OUT="#9b8e85"; C_OUTV="#50443d"; C_TRACK="#383431"; C_DIV="#2b2522"; C_DIV2="#3a332f"
    C_PRI="#feb380"; C_ONPRI="#4d2300"; C_PRIC="#6d3500"; C_ONPRIC="#ffdac2"
    C_SEC="#dfc0ab"; C_SECC="#5a402f"; C_ONSECC="#fbdbc7"
    C_TER="#c4ce8a"; C_ONTER="#2f3300"
    C_ERR="#ffb4ab"; C_ERRC="#93000a"; C_ONERRC="#ffdad6"
    MT_FONT="Onest, Roboto, 'Noto Sans', 'DejaVu Sans', sans-serif"
    W=1280; PX=48; PY=40; CW=$(( W - 2*PX )); GAP=16
    local p=$'\xd0\x96'; MT_U8=0; (( ${#p} == 1 )) && MT_U8=1
    MT_DATE=$(date '+%Y-%m-%d %H:%M')
    load_logos; mt_load_assets
}

# --- Страница ----------------------------------------------------------------
# Блоки идут сверху вниз; PG_Y — низ последнего блока, каждый следующий сам
# отступает GAP. Высоту холста знаем только в конце, поэтому SVG собирается в
# SVG_BODY, а шапка печатается последней.

pg_begin() { SVG_BODY=""; MT_FLAG_USED=(); PG_Y=$PY; }

pg_end() {
    local H=$(( PG_Y + PY )) cc
    MT_PAGE_H=$H
    printf '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="%d" height="%d" viewBox="0 0 %d %d" font-family="%s" text-rendering="geometricPrecision">\n' "$W" "$H" "$W" "$H" "$MT_FONT"
    printf '<rect width="%d" height="%d" fill="%s"/>\n' "$W" "$H" "$C_BG"
    # Флаги — один раз на страницу; клип-круг применяется в их собственной
    # 512-сетке, так что любой масштаб в <use> его не сбивает.
    printf '<defs><clipPath id="fc"><circle cx="256" cy="256" r="256"/></clipPath>'
    for cc in "${!MT_FLAG_USED[@]}"; do printf '<g id="fl-%s" clip-path="url(#fc)">%s</g>' "$cc" "${MT_FLAG[$cc]}"; done
    printf '</defs>\n%s</svg>\n' "$SVG_BODY"
}

# Верхняя строка: «Multitest», подпись, пилюля справа (номер страницы).
pg_topbar() {
    local cy=$(( PG_Y + 22 )) x=$(( PX + 8 )) xr=$(( PX + CW - 8 )) pw sx
    t $x $(( cy + 8 )) 24 800 "$C_ON" "Multitest"
    tw "Multitest" 24 800; sx=$(( x + TW + 14 ))
    tw "$2" 20 700; pw=$(( TW + 40 ))
    rr $(( xr - pw )) $PG_Y $pw 44 22 22 22 22 "$C_SECC"
    t $(( xr - pw/2 )) $(( cy + 7 )) 20 700 "$C_ONSECC" "$2" middle
    ellip "$1" $(( xr - pw - 14 - sx )) 20
    t $sx $(( cy + 7 )) 20 400 "$C_ON2" "$EL"
    PG_Y=$(( PG_Y + 44 ))
}

# Заголовок страницы теста: 104 px, под ним описание до трёх строк.
pg_title() {
    local top=$(( PG_Y + GAP + 28 )) x=$(( PX + 8 )) fs i
    fitsz "$1" $(( CW - 16 )) 104 800 -30 56; fs=$FS
    blt $top $fs 950; t $x $BL $fs 800 "$C_ON" "$1" start -30
    top=$(( top + (fs * 95 + 50) / 100 + 12 ))
    wrap "$2" 860 26 400 3
    for i in "${!WL[@]}"; do blt $(( top + i * 364 / 10 )) 26 1400; t $x $BL 26 400 "$C_ON2" "${WL[$i]}"; done
    PG_Y=$(( top + (${#WL[@]} * 364 + 5) / 10 + 12 ))
}

# Заголовок секции: <заголовок> [счётчик] [примечание справа]
pg_section() {
    local top=$(( PG_Y + GAP )) x=$(( PX + 8 )) bl
    bl=$(( top + 24 + 35 ))
    t $x $bl 36 800 "$C_ON" "$1"
    tw "$1" 36 800
    local used=$(( x + TW + 14 ))
    if [[ -n "${2:-}" ]]; then t $used $bl 28 800 "$C_PRI" "$2"; tw "$2" 28 800; used=$(( used + TW )); fi
    if [[ -n "${3:-}" ]]; then
        used=$(( used + 40 ))
        ellip "$3" $(( PX + CW - 8 - used )) 20
        t $(( PX + CW - 8 )) $bl 20 400 "$C_ON2" "$EL" end
    fi
    PG_Y=$(( top + 24 + 46 + 4 ))
}

# Марка спонсора одним белым цветом, как stencloud-white.png в макете: слово
# STEN и облако с вырезанными чёрточкой и точками (evenodd) — сквозь них виден
# фон, отдельный слой начинки не нужен. <x> <y> <высота>
mt_stencloud() {
    fdiv $(( $3 * 10 )) 1723
    sv "<g transform=\"translate($1 $2) scale($FD)\" fill=\"#ffffff\" fill-opacity=\"0.92\"><path d=\"$AD_LOGO_STEN\" fill-rule=\"evenodd\"/><path d=\"$AD_LOGO_CLOUD\" fill-rule=\"evenodd\"/></g>"
}

# Подвал как в макете: «multitest vX» слева; справа «powered by» над маркой,
# разделитель, промокод и строка флаги · скидка · бот.
pg_footer() {
    local top=$(( PG_Y + GAP + 20 )) cy x1 xd x3 w1 w3 wd wb wrow ry rc fx
    sv "<rect x=\"$PX\" y=\"$top\" width=\"$CW\" height=\"1\" fill=\"$C_DIV\"/>"
    cy=$(( top + 1 + 22 + 24 ))
    t $(( PX + 8 )) $(( cy + 6 )) 17 400 "$C_OUT" "multitest v${SCRIPT_VERSION}"
    tw "powered by" 14; w1=$TW; (( w1 < 60 )) && w1=60
    tw "$AD_PROMO" 21 500 30; w3=$TW
    tw "$AD_DISCOUNT" 15 600; wd=$TW
    tw "· $AD_BOT" 14; wb=$TW
    wrow=$(( 16 + 6 + 16 + 6 + wd + 6 + wb )); (( wrow > w3 )) && w3=$wrow
    x3=$(( PX + CW - 8 - w3 )); xd=$(( x3 - 18 - 1 )); x1=$(( xd - 18 - w1 ))
    t $x1 $(( cy - 12 )) 14 400 "$C_OUT" "powered by"
    mt_stencloud $x1 $(( cy - 6 )) 30
    sv "<rect x=\"$xd\" y=\"$(( cy - 19 ))\" width=\"1\" height=\"38\" fill=\"$C_DIV2\"/>"
    t $x3 $(( cy - 4 )) 21 500 "$C_ON" "$AD_PROMO" start 30
    ry=$(( cy + 5 )); rc=$(( cy + 13 )); fx=$x3
    mt_flag nl $fx $ry 16; fx=$(( fx + 22 ))
    mt_flag ee $fx $ry 16; fx=$(( fx + 22 ))
    t $fx $(( rc + 5 )) 15 600 "$C_ON" "$AD_DISCOUNT"; fx=$(( fx + wd + 6 ))
    t $fx $(( rc + 5 )) 14 400 "$C_OUT" "· $AD_BOT"
    PG_Y=$(( top + 1 + 22 + 48 ))
}

# --- Пилюли значений -------------------------------------------------------

# Вид пилюли по состоянию и значению -> PK (вид), PT (текст), PCC (флаг), PI (иконка).
# cons — «своя» страна: совпадение с ней тихое, чужая страна — салатовая пилюля.
mt_pill_kind() {
    local st="$1" v="$2" cons="${3:-}" cc
    # «—» вместо страны сервера (ipinfo не ответил) — сравнивать не с чем
    [[ "$cons" =~ ^${MT_CC_RE}$ ]] || cons=""
    PT="$v"; PCC=""; PI=""
    if [[ "$v" == "да" ]]; then PK=yes; PI=check
    elif [[ "$v" == "нет" ]]; then PK=no; PI=close
    elif [[ "$v" =~ ^(${MT_CC_RE})([[:space:]]|$) ]]; then
        cc="${BASH_REMATCH[1]}"; PCC="$cc"
        # «FR (CDG)» — код точки присутствия CDN; скобки в пилюле лишние
        [[ "$v" =~ ^(${MT_CC_RE})\ \((.+)\)$ ]] && PT="${BASH_REMATCH[1]} · ${BASH_REMATCH[2]}"
        if [[ "$st" == "bad" ]]; then PK=bad
        elif [[ "$st" == "ok" && ( -z "$cons" || "$cc" == "$cons" ) ]]; then PK=plain
        else PK=diff; fi
    elif [[ "$st" == "na" || "$v" == "N/A" || "$v" == "?" || -z "$v" ]]; then PK=muted; [[ -z "$v" ]] && PT="—"
    elif [[ "$st" == "bad" ]]; then PK=bad; [[ "$v" == "блок" ]] && PI=block
    elif [[ "$st" == "warn" ]]; then PK=warn
    else PK=plain; fi
}

# Пилюля у правого края: <правый край> <центр y> <кегль 20|19> <вид> <текст> [флаг] [иконка] [макс. ширина текста]
# Отдаёт ширину в PW. Геометрия — из макета: 20 px — отступы 8/14/6, флаг 24;
# 19 px — 6/12/5, флаг 22. Длинный ответ режем, чтобы он не съел имя строки.
mt_pill() {
    local xr=$1 cy=$2 sz=$3 kind="$4" txt="$5" cc="${6:-}" ic="${7:-}" mx="${8:-0}"
    local lead=24 pl=8 pr=14 pv=6 bg="" fg="$C_ON2" stroke="" h x tx
    (( sz < 20 )) && { lead=22; pl=6; pr=12; pv=5; }
    case "$kind" in
        muted) fg="$C_OUT" ;;
        diff|warn) bg="$C_TER"; fg="$C_ONTER" ;;
        yes) bg="$C_PRIC"; fg="$C_ONPRIC" ;;
        no) stroke="$C_OUTV" ;;
        bad) bg="$C_ERRC"; fg="$C_ONERRC" ;;
    esac
    if (( mx > 0 )); then ellip "$txt" $mx $sz 700; txt="$EL"; fi
    tw "$txt" $sz 700
    PW=$(( pl + pr + TW )); [[ -n "$cc$ic" ]] && PW=$(( PW + lead + 8 ))
    h=$(( 2*pv + sz * 1275 / 1000 )); (( h < 2*pv + lead )) && h=$(( 2*pv + lead ))
    x=$(( xr - PW ))
    [[ -n "$bg" ]] && rr $x $(( cy - h/2 )) $PW $h $(( h/2 )) $(( h/2 )) $(( h/2 )) $(( h/2 )) "$bg"
    [[ -n "$stroke" ]] && sv "<rect x=\"$x.75\" y=\"$(( cy - h/2 )).75\" width=\"$(( PW - 2 )).5\" height=\"$(( h - 2 )).5\" rx=\"$(( h/2 - 1 ))\" fill=\"none\" stroke=\"$stroke\" stroke-width=\"1.5\"/>"
    tx=$(( x + pl ))
    if [[ -n "$cc" ]]; then mt_flag "$cc" $tx $(( cy - lead/2 )) $lead; tx=$(( tx + lead + 8 ))
    elif [[ -n "$ic" ]]; then mt_icon "$ic" $(( tx + 1 )) $(( cy - lead/2 + 1 )) $(( lead - 2 )) "$fg"; tx=$(( tx + lead + 8 )); fi
    t $tx $(( cy + sz * 133 / 400 )) $sz 700 "$fg" "$txt"
}

# Иконка строки списка: логотип сервиса, иначе запасная по типу строки —
# глобус у доменов, «база данных» у баз риска, буква в кружке у остальных.
# <slug> <имя> <x> <y> <размер> <logo|globe|db>
mt_rowicon() {
    sv_mark "$1" "$3" "$4" "$5" "$C_ON2" && return 0
    case "$6" in
        globe) mt_icon language "$3" "$4" "$5" "$C_ON2" ;;
        db)    mt_icon database "$3" "$4" "$5" "$C_ON2" ;;
        *)
            local r=$(( $5 / 2 )) ch
            mt_glyphs "$2"; ch="${GC[0]:-?}"
            sv "<circle cx=\"$(( $3 + r ))\" cy=\"$(( $4 + r ))\" r=\"$r\" fill=\"$C_TRACK\"/>"
            t $(( $3 + r )) $(( $4 + r + 5 )) 15 700 "$C_ON2" "${ch^^}" middle ;;
    esac
}

# --- Списки -------------------------------------------------------------------
# Строки берутся из глобальных LR_NAME / LR_SLUG / LR_ST / LR_VAL.

# Две колонки «иконка · имя · пилюля» (сервисы, сайты, базы риска). Половина
# строк — в левую колонку, у каждой колонки свои скругления сегментов.
# <своя страна> <запасная иконка>
mt_list2() {
    local n=${#LR_NAME[@]} cw=$(( (CW - 12) / 2 )) top=$(( PG_Y + GAP )) half col s e cnt j i cx y
    half=$(( (n + 1) / 2 ))
    for col in 0 1; do
        cx=$(( PX + col * (cw + 12) ))
        if (( col == 0 )); then s=0; e=$half; else s=$half; e=$n; fi
        cnt=$(( e - s ))
        for (( j=0; j<cnt; j++ )); do
            i=$(( s + j )); y=$(( top + j * 68 ))
            segr $j $cnt 28 8; rr $cx $y $cw 64 "${R[@]}" "$C_SURF"
            mt_rowicon "${LR_SLUG[i]}" "${LR_NAME[i]}" $(( cx + 22 )) $(( y + 19 )) 26 "$2"
            mt_pill_kind "${LR_ST[i]}" "${LR_VAL[i]}" "$1"
            mt_pill $(( cx + cw - 14 )) $(( y + 32 )) 20 "$PK" "$PT" "$PCC" "$PI" $(( cw * 45 / 100 ))
            ellip "${LR_NAME[i]}" $(( cw - 64 - 14 - PW - 16 )) 22
            t $(( cx + 64 )) $(( y + 39 )) 22 400 "$C_ON" "$EL"
        done
    done
    PG_Y=$(( top + half * 68 - 4 ))
}

# Четыре колонки «имя · пилюля» (GeoIP-базы): заполняем по столбцам, как в макете.
mt_list4() {
    local n=${#LR_NAME[@]} cw=$(( (CW - 36) / 4 )) top=$(( PG_Y + GAP )) per col s e cnt j i cx y
    per=$(( (n + 3) / 4 ))
    for col in 0 1 2 3; do
        cx=$(( PX + col * (cw + 12) )); s=$(( col * per )); e=$(( s + per )); (( e > n )) && e=$n
        cnt=$(( e - s )); (( cnt > 0 )) || continue
        for (( j=0; j<cnt; j++ )); do
            i=$(( s + j )); y=$(( top + j * 64 ))
            segr $j $cnt 28 8; rr $cx $y $cw 60 "${R[@]}" "$C_SURF"
            mt_pill_kind "${LR_ST[i]}" "${LR_VAL[i]}" "$1"
            mt_pill $(( cx + cw - 12 )) $(( y + 30 )) 19 "$PK" "$PT" "$PCC" "$PI" $(( cw * 45 / 100 ))
            ellip "${LR_NAME[i]}" $(( cw - 20 - 12 - PW - 10 )) 20
            t $(( cx + 20 )) $(( y + 37 )) 20 400 "$C_ON" "$EL"
        done
    done
    PG_Y=$(( top + per * 64 - 4 ))
}

# Сетка «подпись / значение [/ подстрочник]» (характеристики, показатели).
# Ячейки — из G_L / G_V / G_S; ширины колонок — веса G_FR (по умолчанию равные).
# Скругляем только внешние углы всей сетки, как у карточки «Сервер» в макете.
# <колонок> <кегль значения>
mt_grid() {
    local cols=$1 vs=$2 n=${#G_L[@]} top=$(( PG_Y + GAP )) rows r c i k x y h rh fr sum=0 lh part
    (( n > 0 )) || return 0
    (( cols > n )) && cols=$n
    rows=$(( (n + cols - 1) / cols )); lh=$(( vs * 125 / 100 ))
    local -a cx=() cw=() frs=()
    for (( c=0; c<cols; c++ )); do frs[c]=${G_FR[c]:-10}; sum=$(( sum + frs[c] )); done
    x=$PX
    for (( c=0; c<cols; c++ )); do
        cw[c]=$(( (CW - (cols - 1) * 4) * frs[c] / sum )); cx[c]=$x; x=$(( x + cw[c] + 4 ))
    done
    cw[cols-1]=$(( PX + CW - cx[cols-1] ))
    y=$top
    for (( r=0; r<rows; r++ )); do
        # высота ряда — по самой высокой ячейке: значение переносится до двух строк
        rh=0; local -a lines=() nl=()
        for (( c=0; c<cols; c++ )); do
            i=$(( r * cols + c )); (( i < n )) || break
            wrap "${G_V[i]:-—}" $(( cw[c] - 52 )) $vs 700 2; nl[c]=${#WL[@]}
            printf -v part '%s\x1e' "${WL[@]}"; lines[c]="$part"
            h=$(( 22 + 22 + 4 + nl[c] * lh + 22 )); [[ -n "${G_S[i]:-}" ]] && h=$(( h + 4 + 22 ))
            (( h > rh )) && rh=$h
        done
        for (( c=0; c<cols; c++ )); do
            i=$(( r * cols + c )); (( i < n )) || break
            local tl=8 tr=8 br=8 bl=8 lastc=$(( (r == rows - 1) ? (n - 1 - r * cols) : (cols - 1) ))
            (( r == 0 && c == 0 )) && tl=28
            (( r == 0 && c == cols - 1 )) && tr=28
            (( r == rows - 1 && c == 0 )) && bl=28
            (( r == rows - 1 && c == lastc )) && br=28
            rr ${cx[c]} $y ${cw[c]} $rh $tl $tr $br $bl "$C_SURF"
            t $(( cx[c] + 26 )) $(( y + 22 + 17 )) 18 400 "$C_ON2" "${G_L[i]}"
            local ln=0 ystart=$(( y + 22 + 22 + 4 )) rest="${lines[c]}"
            while [[ -n "$rest" ]]; do
                part="${rest%%$'\x1e'*}"; rest="${rest#*$'\x1e'}"
                blt $(( ystart + ln * lh )) $vs 1250; t $(( cx[c] + 26 )) $BL $vs 700 "$C_ON" "$part"
                ln=$(( ln + 1 ))
            done
            if [[ -n "${G_S[i]:-}" ]]; then
                ellip "${G_S[i]}" $(( cw[c] - 52 )) 18
                t $(( cx[c] + 26 )) $(( ystart + ln * lh + 4 + 17 )) 18 400 "$C_ON2" "$EL"
            fi
        done
        y=$(( y + rh + 4 ))
    done
    PG_Y=$(( y - 4 ))
    G_FR=()
}

# --- Волнистые шкалы ------------------------------------------------------------

# Волна M3 Expressive: <x> <центр y> <длина> <цвет>. Узор — из макета:
# «M0 10 Q8 3 16 10 T32 10», период 32, толщина 5, круглые концы. Концы
# поджимаем на 3 px, чтобы скругление не вылезало за начало шкалы, а хвост
# дорисовываем частью полуволны (подкривая той же квадратичной Безье).
mt_wave() {
    local x=$(( $1 + 3 )) cy=$2 xe=$(( $1 + $3 - 3 )) col="$4" d s=-1 rem
    (( xe <= x )) && xe=$(( x + 1 ))
    d="M$x $cy"
    while (( x + 16 <= xe )); do d+="q8 $(( s * 7 )) 16 0"; x=$(( x + 16 )); s=$(( -s )); done
    rem=$(( xe - x ))
    (( rem > 0 )) && d+="q$(( rem / 2 )) $(( s * 7 * rem / 16 )) $rem $(( s * 14 * rem * (16 - rem) / 256 ))"
    sv "<path d=\"$d\" fill=\"none\" stroke=\"$col\" stroke-width=\"5\" stroke-linecap=\"round\"/>"
}

# Шкала со «стоп-точкой» M3: волна на долю, дальше трек и точка на конце.
# <x> <центр y> <ширина> <доля в тысячных> <цвет волны и точки>
mt_bar() {
    local x=$1 cy=$2 w=$3 f=$4 col="$5" ww tx
    (( f < 0 )) && f=0; (( f > 1000 )) && f=1000
    ww=$(( w * f / 1000 ))
    tx=$(( x + ww + 8 ))
    (( tx < x + w - 6 )) && sv "<rect x=\"$tx\" y=\"$(( cy - 3 ))\" width=\"$(( x + w - tx ))\" height=\"6\" rx=\"3\" fill=\"$C_TRACK\"/>"
    (( ww >= 6 )) && mt_wave $x $cy $ww "$col"
    sv "<circle cx=\"$(( x + w - 4 ))\" cy=\"$cy\" r=\"4\" fill=\"$col\"/>"
}

# Число с точкой -> N10 (десятые доли, целое): «2065.4» -> 20654.
num10() {
    local v="${1//[^0-9.]/}" i f
    [[ -n "$v" ]] || { N10=0; return; }
    i="${v%%.*}"; f="${v#"$i"}"; f="${f#.}"; f="${f:0:1}"
    N10=$(( 10#${i:-0} * 10 + 10#${f:-0} ))
}

# «Круглый» потолок шкалы -> NICE: 2140 -> 2500, 941 -> 1000. <значение> <ряд…>
mt_nice() {
    local v=$1 s; shift
    for s in "$@"; do (( v <= s )) && { NICE=$s; return; }; done
    NICE=$v
}

# Мбит/с -> «1.93» «Гбит/с» или «436» «Мбит/с»: <Мбит/с·10> -> SPD_N, SPD_U
mt_speed() {
    local n=$1 g
    if (( n >= 10000 )); then g=$(( (n + 50) / 100 )); printf -v SPD_N '%d.%02d' $(( g / 100 )) $(( g % 100 )); SPD_U="Гбит/с"
    else SPD_N=$(( (n + 5) / 10 )); SPD_U="Мбит/с"; fi
}

# --- Hero ---------------------------------------------------------------------

# Есть ли в строке буквы с нижним выносным элементом. Кириллицу ищем
# подстрокой, а не скобочным классом: в C-локали [дру] — это набор байтов,
# и под него попала бы любая русская буква.
mt_has_desc() {
    local s="$1" c
    [[ "$s" == *[gjpqy]* ]] && return 0
    for c in д р у ф ц щ; do [[ "$s" == *"$c"* ]] && return 0; done
    return 1
}

# Hero с фигурой справа (iPerf3, sysbench, IPQuality …):
# <фигура> <надпись> <число> <единица> <строка под числом> <текст в фигуре> <подпись в фигуре> [заливка фигуры] [цвет текста фигуры] [иконка вместо текста]
hero_right() {
    local top=$(( PG_Y + GAP )) sz=280 lx=$(( PX + 52 )) lw h fs ub uw cx cy y0 c
    local shf="${8:-$C_PRI}" shc="${9:-$C_ONPRI}"
    lw=$(( CW - 52 - 40 - sz - 40 ))
    # главное число вместе с единицей должно уместиться в колонку
    tw "$4" 34 700; uw=$TW
    fitsz "$3" $(( lw - (uw > 0 ? uw + 14 : 0) )) 148 800 -40 56; fs=$FS
    h=$(( 26 + 14 + fs * 85 / 100 + 14 + 30 ))
    mt_has_desc "$3" && h=$(( h + fs * 15 / 100 ))
    [[ -z "$2" ]] && h=$(( h - 40 )); [[ -z "$5" ]] && h=$(( h - 44 ))
    c=$(( h > sz ? h : sz ))
    rr $PX $top $CW $(( c + 80 )) 56 56 56 56 "$C_SURF"
    y0=$(( top + 40 + (c - h) / 2 ))
    if [[ -n "$2" ]]; then ellip "$2" $lw 21; t $lx $(( y0 + 20 )) 21 400 "$C_ON2" "$EL"; y0=$(( y0 + 40 )); fi
    blt $y0 $fs 850
    xesc "$3"; local big="$XE"; fxd $(( -40 * fs )) 1000
    if [[ -n "$4" ]]; then xesc "$4"
        sv "<text x=\"$lx\" y=\"$BL\" fill=\"$C_ON\"><tspan font-size=\"$fs\" font-weight=\"800\" letter-spacing=\"$FD\">$big</tspan><tspan dx=\"14\" font-size=\"34\" font-weight=\"700\" fill=\"$C_ON2\">$XE</tspan></text>"
    else
        sv "<text x=\"$lx\" y=\"$BL\" fill=\"$C_ON\" font-size=\"$fs\" font-weight=\"800\" letter-spacing=\"$FD\">$big</text>"
    fi
    y0=$(( y0 + fs * 85 / 100 + 14 ))
    # у «Hosting» хвост «g» уходит ниже строки межстрочного 0.85 — даём ему место
    mt_has_desc "$3" && y0=$(( y0 + fs * 15 / 100 ))
    if [[ -n "$5" ]]; then ellip "$5" $lw 24 600; t $lx $(( y0 + 23 )) 24 600 "$C_ON" "$EL"; fi
    cx=$(( PX + CW - 40 - sz )); cy=$(( top + 40 + c / 2 ))
    mt_shape "$1" $cx $(( cy - sz / 2 )) $sz "$shf"
    if [[ -n "${10:-}" ]]; then
        mt_icon "${10}" $(( cx + sz / 2 - 60 )) $(( cy - 60 )) 120 "$shc"
    else
        fitsz "$6" $(( sz * 70 / 100 )) 104 900 -40 40; fs=$FS
        ellip "$7" $(( sz * 78 / 100 )) 21 700
        local th=$(( fs * 9 / 10 + 4 + 27 ))
        blt $(( cy - th / 2 )) $fs 900; t $(( cx + sz / 2 )) $BL $fs 900 "$shc" "$6" middle -40
        t $(( cx + sz / 2 )) $(( cy + th / 2 - 6 )) 21 700 "$shc" "$EL" middle
    fi
    PG_Y=$(( top + c + 80 ))
}

# Hero с «печенькой» слева (IP Region, Censorcheck):
# <текст в фигуре> <число> <«/ всего»> <заголовок> <пояснение> [подпись в фигуре]
hero_left() {
    local top=$(( PG_Y + GAP )) sz=340 rx rw h c fs i y0 sl
    rx=$(( PX + 36 + sz + 48 )); rw=$(( PX + CW - 48 - rx ))
    wrap "$5" $rw 21 400 4; sl=${#WL[@]}
    h=$(( 109 + 14 + 36 )); (( sl > 0 )) && h=$(( h + 14 + sl * 3045 / 100 ))
    c=$(( h > sz ? h : sz ))
    rr $PX $top $CW $(( c + 72 )) 56 56 56 56 "$C_SURF"
    local sx=$(( PX + 36 )) sy=$(( top + 36 + (c - sz) / 2 ))
    mt_shape cookie12 $sx $sy $sz "$C_PRI"
    if [[ -n "${6:-}" ]]; then
        # число с подписью, как «7/7 тестов» на обложке
        fitsz "$1" $(( sz * 70 / 100 )) 128 900 -40 48; fs=$FS
        local th=$(( fs * 9 / 10 + 4 + 28 ))
        blt $(( sy + sz / 2 - th / 2 )) $fs 900; t $(( sx + sz / 2 )) $BL $fs 900 "$C_ONPRI" "$1" middle -40
        ellip "$6" $(( sz * 70 / 100 )) 22 700
        t $(( sx + sz / 2 )) $(( sy + sz / 2 + th / 2 - 7 )) 22 700 "$C_ONPRI" "$EL" middle
    else
        fitsz "$1" $(( sz * 76 / 100 )) 150 900 -40 48; fs=$FS
        t $(( sx + sz / 2 )) $(( sy + sz / 2 + fs * 333 / 1000 )) $fs 900 "$C_ONPRI" "$1" middle -40
    fi
    y0=$(( top + 36 + (c - h) / 2 ))
    xesc "$2"; local big="$XE"; xesc "$3"; fxd $(( -30 * 128 )) 1000
    sv "<text x=\"$rx\" y=\"$(( y0 + 97 ))\" fill=\"$C_ON\"><tspan font-size=\"128\" font-weight=\"800\" letter-spacing=\"$FD\">$big</tspan><tspan dx=\"16\" font-size=\"40\" font-weight=\"700\" fill=\"$C_ON2\">$XE</tspan></text>"
    y0=$(( y0 + 109 + 14 ))
    ellip "$4" $rw 28 600; t $rx $(( y0 + 27 )) 28 600 "$C_ON" "$EL"
    y0=$(( y0 + 36 + 14 ))
    for i in "${!WL[@]}"; do blt $(( y0 + i * 3045 / 100 )) 21 1450; t $rx $BL 21 400 "$C_ON2" "${WL[$i]}"; done
    PG_Y=$(( top + c + 72 ))
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

# --- Мелочи без форков ------------------------------------------------------

# Склонение без подоболочки -> RP: <n> <один> <два> <пять>
rp() {
    [[ "${1:-}" =~ ^-?[0-9]+$ ]] || { RP="$4"; return 0; }
    local n=$(( 10#${1#-} ))
    if (( n % 100 >= 11 && n % 100 <= 14 )); then RP="$4"
    elif (( n % 10 == 1 )); then RP="$2"
    elif (( n % 10 >= 2 && n % 10 <= 4 )); then RP="$3"
    else RP="$4"; fi
}

# Страна по-русски -> CN_NOM (именительный), CN_ACC (винительный); нет в таблице — код.
mt_country() {
    local cc="${1^^}"; [[ "$cc" == "UK" ]] && cc="GB"
    CN_NOM="${MT_CNAME[$cc]:-$cc}"; CN_ACC="${MT_CACC[$cc]:-$CN_NOM}"
}

# «A и B», «A, B и C», «A, B и ещё N» -> JN
mt_join_names() {
    local n=$#
    if (( n == 1 )); then JN="$1"
    elif (( n == 2 )); then JN="$1 и $2"
    elif (( n == 3 )); then JN="$1, $2 и $3"
    else JN="$1, $2 и ещё $(( n - 2 ))"; fi
}

# Название процессора без шума -> CPUC: «Intel(R) Xeon(R) Gold 6248R CPU @ 3.00GHz»
# -> «Intel Xeon Gold 6248R», «… 16-Core Processor» -> «… 16-Core». Частота есть
# на обложке, а в ячейке сетки она переносила название на вторую строку.
mt_cpu_clean() {
    local c="$1"
    c="${c//(R)/}"; c="${c//(r)/}"; c="${c//(TM)/}"; c="${c//(tm)/}"; c="${c// Processor/}"; c="${c// CPU/}"
    c="${c%%@*}"
    while [[ "$c" == *"  "* ]]; do c="${c//  / }"; done
    c="${c#"${c%%[! ]*}"}"; CPUC="${c%"${c##*[! ]}"}"
}

# Процессор: «AMD Ryzen 9 9950X 16-Core Processor» -> CPU_NAME «AMD Ryzen 9 9950X»,
# CPU_SUB «16-Core · 2 ядра» — как в макете: модель отдельно, ядра подстрочником.
mt_cpu_split() {
    local c="$SYS_CPU" core="" ghz="" sub=""
    c="${c//(R)/}"; c="${c//(r)/}"; c="${c//(TM)/}"; c="${c//(tm)/}"
    if [[ "$c" =~ @[[:space:]]*([0-9.]+)[[:space:]]*GHz ]]; then ghz="${BASH_REMATCH[1]} GHz"; c="${c%%@*}"; fi
    if [[ "$c" =~ ([0-9]+)-Core ]]; then core="${BASH_REMATCH[1]}-Core"; c="${c/"${BASH_REMATCH[0]}"/}"; fi
    c="${c// Processor/}"; c="${c// CPU/}"
    while [[ "$c" == *"  "* ]]; do c="${c//  / }"; done
    c="${c#"${c%%[! ]*}"}"; c="${c%"${c##*[! ]}"}"
    CPU_NAME="${c:-${SYS_CPU:-—}}"
    rp "${SYS_CORES:-0}" ядро ядра ядер
    [[ "${SYS_CORES:-}" =~ ^[0-9]+$ ]] && sub="$SYS_CORES $RP"
    CPU_SUB="$core"; [[ -n "$ghz" ]] && CPU_SUB="${CPU_SUB:+$CPU_SUB · }$ghz"
    [[ -n "$sub" ]] && CPU_SUB="${CPU_SUB:+$CPU_SUB · }$sub"
}

# Аптайм по-русски -> UPT: «17 минут», «3 часа 5 минут», «2 дня 4 часа».
mt_uptime_ru() {
    local s="${SYS_UP_S:-}" d h m
    if [[ ! "$s" =~ ^[0-9]+$ ]]; then UPT="${SYS_UPTIME:-—}"; return; fi
    d=$(( s / 86400 )); h=$(( s % 86400 / 3600 )); m=$(( s % 3600 / 60 ))
    if (( d > 0 )); then rp $d день дня дней; UPT="$d $RP"; (( h > 0 )) && { rp $h час часа часов; UPT+=" $h $RP"; }
    elif (( h > 0 )); then rp $h час часа часов; UPT="$h $RP"; (( m > 0 )) && { rp $m минута минуты минут; UPT+=" $m $RP"; }
    else rp $m минута минуты минут; UPT="$m $RP"; fi
}

# --- Данные теста ------------------------------------------------------------

# Метрики -> M[подпись]=значение, MC[подпись]=цвет, порядок — ML[]
mt_read_metrics() {
    M=(); MC=(); ML=()
    local f="$SUMMARY_DIR/$1.metrics" l v c
    [[ -s "$f" ]] || return 0
    while IFS=$'\x1f' read -r l v c; do
        [[ -n "$l" ]] || continue
        M["$l"]="$v"; MC["$l"]="$c"; ML+=("$l")
    done < "$f"
}

# Строки -> RK RN RS RT RV RF RA (вид, имя, slug, состояние, значение, доля, доп. поле)
mt_read_rows() {
    RK=(); RN=(); RS=(); RT=(); RV=(); RF=(); RA=()
    local f="$SUMMARY_DIR/$1.services" k n s st v fr a
    [[ -s "$f" ]] || return 0
    while IFS=$'\x1f' read -r k n s st v fr a; do
        [[ -n "$k" ]] || continue
        RK+=("$k"); RN+=("$n"); RS+=("$s"); RT+=("$st"); RV+=("$v"); RF+=("$fr"); RA+=("$a")
    done < "$f"
}

# chip-строки секции <n> (0 — до первого разделителя) -> LR_NAME LR_SLUG LR_ST LR_VAL
mt_rows_section() {
    LR_NAME=(); LR_SLUG=(); LR_ST=(); LR_VAL=()
    local i sec=0
    for i in "${!RK[@]}"; do
        if [[ "${RK[i]}" == sep ]]; then sec=$(( sec + 1 )); continue; fi
        (( sec == $1 )) && [[ "${RK[i]}" == chip ]] || continue
        LR_NAME+=("${RN[i]}"); LR_SLUG+=("${RS[i]}"); LR_ST+=("${RT[i]}"); LR_VAL+=("${RV[i]}")
    done
}

# Счётчики по LR_ST -> CNT_ALL CNT_OK CNT_BAD CNT_WARN CNT_NA
mt_count_states() {
    CNT_ALL=${#LR_ST[@]}; CNT_OK=0; CNT_BAD=0; CNT_WARN=0; CNT_NA=0
    local s
    for s in "${LR_ST[@]}"; do
        case "$s" in ok) CNT_OK=$(( CNT_OK + 1 )) ;; bad) CNT_BAD=$(( CNT_BAD + 1 )) ;; warn) CNT_WARN=$(( CNT_WARN + 1 )) ;; *) CNT_NA=$(( CNT_NA + 1 )) ;; esac
    done
}

# Имена строк LR_* с заданным состоянием -> JN («A, B и ещё N»), пусто если нет
mt_names_with() {
    local -a a=(); local i
    for i in "${!LR_ST[@]}"; do [[ "${LR_ST[i]}" == "$1" ]] && a+=("${LR_NAME[i]}"); done
    JN=""; (( ${#a[@]} )) && mt_join_names "${a[@]}"
}

# Название, иконка, подпись для оглавления и описание страницы теста
mt_test_meta() {
    case "$1" in
        run_ip_region) T_NAME="IP Region"; T_ICON=public; T_WHAT="страна IP глазами сервисов"
            T_DESC="Какую страну видят популярные сервисы и GeoIP-базы по IP этого сервера." ;;
        run_censorcheck_geoblock) T_NAME="Censorcheck"; T_ICON=block; T_WHAT="проверка геоблока"
            T_DESC="Пускают ли зарубежные сайты, которые закрываются для России, на IP этого сервера." ;;
        run_censorcheck_dpi) T_NAME="Censorcheck DPI"; T_ICON=policy; T_WHAT="DPI-блокировки, серверы РФ"
            T_DESC="Режут ли DPI-фильтры соединения с сайтами — проверка для серверов в России." ;;
        run_censorcheck_tlab) T_NAME="Censorcheck tlab"; T_ICON=travel_explore; T_WHAT="блокировки по списку tlab.pw"
            T_DESC="Доступность популярных сайтов и сервисов с этого сервера по списку censorcheck.tlab.pw." ;;
        run_iperf3_ru) T_NAME="iPerf3"; T_ICON=swap_vert; T_WHAT="тест до российских серверов"
            T_DESC="Реальная скорость канала между этим сервером и серверами в России, в обе стороны." ;;
        run_iperf3_tlab) T_NAME="iPerf3 tlab"; T_ICON=swap_vert; T_WHAT="скорость до РФ через tlab.pw"
            T_DESC="Скорость канала до серверов российских провайдеров через bench.tlab.pw, в обе стороны." ;;
        run_yabs) T_NAME="YABS"; T_ICON=speed; T_WHAT="бенчмарк сервера"
            T_DESC="Бенчмарк сервера: скорость диска и сети до дата-центров в разных странах." ;;
        run_ip_check_place) T_NAME="IP Check Place"; T_ICON=shield; T_WHAT="блокировки зарубежными сервисами"
            T_DESC="Открываются ли стриминги и AI-сервисы с IP этого сервера и как его оценивают базы риска." ;;
        run_bench_sh) T_NAME="bench.sh"; T_ICON=monitoring; T_WHAT="параметры и скорость сети"
            T_DESC="Параметры сервера, скорость диска и сети до узлов в разных странах." ;;
        run_ip_quality) T_NAME="IPQuality"; T_ICON=verified_user; T_WHAT="репутация IP"
            T_DESC="Репутация IP: тип адреса, оценки риска в базах, чёрные списки и доступ к сервисам." ;;
        run_sysbench_cpu) T_NAME="sysbench CPU"; T_ICON=memory; T_WHAT="тест процессора"
            T_DESC="Однопоточный тест процессора: сколько событий в секунду выдаёт одно ядро." ;;
        run_ping_map) T_NAME="Ping-карта"; T_ICON=network_ping; T_WHAT="пинг с узлов РФ и мира"
            T_DESC="Задержка и потери пакетов до этого сервера с узлов check-host.net в России и мире." ;;
        *) T_NAME="$1"; T_ICON=dns; T_WHAT=""; T_DESC="" ;;
    esac
}

# Строки iPerf3 / bench.sh (вид bar: значение — приём, доп. поле — отдача)
# -> LR_NAME LR_DN LR_UP LR_CC и максимум IMX (как в логе) / IMX10 / IMX_CITY / IMX_DIR
mt_speed_rows() {
    LR_NAME=(); LR_DN=(); LR_UP=(); LR_CC=()
    IMX=""; IMX10=0; IMX_CITY=""; IMX_DIR=""
    local i nm cc
    for i in "${!RK[@]}"; do
        [[ "${RK[i]}" == bar && -n "${RV[i]}" ]] || continue
        nm="${RN[i]}"; cc=""
        [[ "$nm" =~ ,\ (${MT_CC_RE})$ ]] && cc="${BASH_REMATCH[1]}"
        LR_NAME+=("$nm"); LR_DN+=("${RV[i]}"); LR_UP+=("${RA[i]}"); LR_CC+=("$cc")
        num10 "${RV[i]}"; (( N10 > IMX10 )) && { IMX10=$N10; IMX="${RV[i]}"; IMX_CITY="$nm"; IMX_DIR="приём"; }
        if [[ -n "${RA[i]}" ]]; then
            num10 "${RA[i]}"; (( N10 > IMX10 )) && { IMX10=$N10; IMX="${RA[i]}"; IMX_CITY="$nm"; IMX_DIR="отдача"; }
        fi
    done
}

# Ключевая цифра теста для оглавления на обложке -> K (текст), KC (цвет)
mt_test_key() {
    local fn="$1" m
    KC="$C_ON"; K=""
    case "${MT_STATUS[$fn]:-}" in
        выполнен) ;;
        ошибка) K="ошибка"; KC="$C_ERR"; return ;;
        *) K="пропущен"; KC="$C_OUT"; return ;;
    esac
    mt_read_metrics "$fn"; mt_read_rows "$fn"
    case "$fn" in
        run_ip_region)
            K="${M[Консенсус]:-${M["Консенсус IPv4"]:-}}"; m="${M[Совпадений]:-${M["Совпадений v4"]:-}}"
            [[ -n "$m" ]] && K="${K:+$K · }$m" ;;
        run_censorcheck_*)
            mt_rows_section 0; mt_count_states
            if (( CNT_ALL )); then K="$CNT_OK доступно · $CNT_BAD блок"
            elif [[ -n "${M[Доступно]:-}${M[Заблокировано]:-}" ]]; then K="${M[Доступно]:-0} доступно · ${M[Заблокировано]:-0} блок"; fi ;;
        run_iperf3_*|run_bench_sh)
            mt_speed_rows
            if [[ "$fn" == run_bench_sh && -n "${M["I/O сред."]:-}" ]]; then K="I/O ${M["I/O сред."]}"
            elif [[ -n "$IMX" ]]; then K="до $IMX Мбит/с"; fi ;;
        run_yabs) [[ -n "${M["fio 4k"]:-}" ]] && K="fio 4k ${M["fio 4k"]}" ;;
        run_ip_check_place)
            mt_rows_section 0; mt_count_states
            K="${M[Риск]:+риск ${M[Риск]}}"; (( CNT_ALL )) && K="${K:+$K · }$CNT_BAD блок" ;;
        run_ip_quality)
            K="${M[Usage]:-${M[Company]:-}}"; [[ -n "${M[DNSBL]:-}" ]] && K="${K:+$K · }DNSBL ${M[DNSBL]}" ;;
        run_sysbench_cpu) [[ -n "${M["events/s"]:-}" ]] && K="${M["events/s"]} events/s" ;;
        run_ping_map)
            if [[ -n "${M[API]:-}" ]]; then K="API недоступен"; KC="$C_ERR"
            else [[ -n "${M["РФ avg"]:-}" ]] && K="РФ ${M["РФ avg"]}"
                 m="${M[Потери]:-}"; [[ -n "$m" ]] && K="${K:+$K · }потери ${m%% *}"; fi ;;
    esac
    [[ -n "$K" ]] || K="выполнен"
}

# --- summary.txt: данные для поста в Telegram ------------------------------------
# Формат v1 (docs/telegram-protocol.md): строка на запись, поля через \x1f — как в
# .metrics/.services. JSON в bash не строим: экранера нет, а jq стоит не везде.

# Управляющие символы перечислены поштучно: диапазоны в скобках зависят от
# collation glibc (см. MT_CC_RE) и в UTF-8-локали ловят лишнее.
MT_SUM_CTRL=$(printf '\001\002\003\004\005\006\007\010\013\014\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\177')

# Одна строка summary.txt: \x1f, перевод строки и таб в полях → пробел (на голом
# железе SYS_VIRT бывает "none\nunknown"), прочие управляющие — прочь, ≤ 200 символов.
mt_sum_put() {
    local IFS=$'\x1f' f
    local -a out=()
    for f in "$@"; do
        f=${f//[$'\x1f\r\n\t']/ }
        f=${f//[$MT_SUM_CTRL]/}
        (( ${#f} > 199 )) && f=$(vcut "$f" 199)
        out+=( "$f" )
    done
    printf '%s\n' "${out[*]}"
}

mt_sum_svc() {
    local i
    for i in "${!LR_NAME[@]}"; do mt_sum_put svc "$1" "${LR_NAME[$i]}" "${LR_ST[$i]}" "${LR_VAL[$i]}"; done
}

# Пишет summary.txt по уже разобранным .metrics/.services и SYS_*. Вызывать после
# gather_system_facts и mt_style_init (дата) — то есть внутри шага сборки страниц.
mt_write_summary() {
    local out="${1:-$SUMMARY_DIR/summary.txt}" idx fn id st has l dir
    mt_album_plan
    mt_cpu_split
    {
        mt_sum_put v 1
        mt_sum_put sys version "$SCRIPT_VERSION"
        mt_sum_put sys date "${MT_DATE:-$(date '+%Y-%m-%d %H:%M')}"
        mt_sum_put sys country "$SYS_COUNTRY"
        mt_sum_put sys city "$SYS_CITY"
        mt_sum_put sys asn "$SYS_ASN"
        mt_sum_put sys ip4 "$(mask_ip "$SYS_IP4")"
        mt_sum_put sys ip6 "$(mask_ip "$SYS_IP6")"
        mt_sum_put sys cpu "$CPU_NAME"
        mt_sum_put sys cores "$SYS_CORES"
        mt_sum_put sys ram "$SYS_RAM"
        mt_sum_put sys disk "$SYS_DISK"
        mt_sum_put sys os "$SYS_OS"
        mt_sum_put sys virt "$SYS_VIRT"
        mt_sum_put sys kernel "$SYS_KERNEL"
        mt_sum_put sys cc "$SYS_CC"
        mt_sum_put sys qdisc "$SYS_QDISC"
        mt_sum_put sys uptime_s "$SYS_UP_S"
        for idx in "${MT_PAGE_IDX[@]}"; do
            fn="${MT_CAT_FUNCS[$idx]}"; id="${fn#run_}"
            case "${MT_STATUS[$fn]:-}" in
                выполнен) st=ok ;;
                ошибка)   st=err ;;
                *)        st=skip ;;
            esac
            has=0
            [[ -s "$SUMMARY_DIR/$fn.metrics" || -s "$SUMMARY_DIR/$fn.services" ]] && has=1
            mt_test_key "$fn"
            mt_sum_put test "$id" "$st" "$K" "$has"
            mt_read_metrics "$fn"
            for l in "${ML[@]}"; do mt_sum_put metric "$id" "$l" "${M[$l]}"; done
            mt_read_rows "$fn"
            case "$fn" in
                run_iperf3_ru|run_iperf3_tlab|run_bench_sh)
                    mt_speed_rows
                    if [[ -n "$IMX" ]]; then
                        dir=down; [[ "$IMX_DIR" == "отдача" ]] && dir=up
                        mt_sum_put best "$id" "$IMX" "$IMX_CITY" "$dir"
                    fi ;;
                run_censorcheck_*|run_ip_check_place) mt_rows_section 0; mt_sum_svc "$id" ;;
                run_ip_quality) mt_rows_section 1; mt_sum_svc "$id" ;;
            esac
        done
    } > "$out"
}

# --- Обложка ----------------------------------------------------------------------

build_page_cover() {
    pg_begin
    pg_topbar "v${SCRIPT_VERSION} · сводка диагностики сервера" "обложка"
    cover_hero
    cover_server
    cover_tests
    cover_offnames
    pg_footer
    pg_end
}

# Дата, замаскированный адрес крупно, флаг и место, ASN; справа «печенька» со счётом.
cover_hero() {
    local top=$(( PG_Y + GAP + 12 )) sz=300 lx=$(( PX + 52 )) lw ip ip4 ip6 second="" fs h c y0 loc
    lw=$(( CW - 52 - 40 - sz - 40 ))
    ip4=$(mask_ip "$SYS_IP4"); ip6=$(mask_ip "$SYS_IP6")
    ip="${ip4:-$ip6}"; [[ -n "$ip" ]] || ip="—"
    [[ -n "$ip4" && -n "$ip6" ]] && second="IPv6 · $ip6"
    fitsz "$ip" $lw 112 800 -30 44; fs=$FS
    h=$(( 26 + 18 + fs * 9 / 10 + 18 + 44 + 18 + 28 )); [[ -n "$second" ]] && h=$(( h + 18 + 28 ))
    c=$(( h > sz ? h : sz ))
    rr $PX $top $CW $(( c + 80 )) 56 56 56 56 "$C_SURF"
    y0=$(( top + 40 + (c - h) / 2 ))
    t $lx $(( y0 + 20 )) 21 400 "$C_ON2" "$MT_DATE"
    y0=$(( y0 + 26 + 18 ))
    blt $y0 $fs 900; t $lx $BL $fs 800 "$C_ON" "$ip" start -30
    y0=$(( y0 + fs * 9 / 10 + 18 ))
    mt_flag "$SYS_COUNTRY" $lx $y0 44
    mt_country "$SYS_COUNTRY"; loc="$CN_NOM"
    [[ -n "$SYS_CITY" && "$SYS_CITY" != "—" ]] && loc="$SYS_CITY, $loc"
    ellip "$loc" $(( lw - 58 )) 30 700; t $(( lx + 58 )) $(( y0 + 32 )) 30 700 "$C_ON" "$EL"
    y0=$(( y0 + 44 + 18 ))
    ellip "$SYS_ASN" $lw 22; t $lx $(( y0 + 21 )) 22 400 "$C_ON2" "$EL"
    if [[ -n "$second" ]]; then y0=$(( y0 + 28 + 18 )); ellip "$second" $lw 22; t $lx $(( y0 + 21 )) 22 400 "$C_ON2" "$EL"; fi

    local sx=$(( PX + CW - 40 - sz )) sy=$(( top + 40 + (c - sz) / 2 )) score="${MT_DONE}/${MT_TOT}" cy th
    mt_shape cookie12 $sx $sy $sz "$C_PRI"
    fitsz "$score" $(( sz * 78 / 100 )) 112 900 -40 48; fs=$FS
    th=$(( fs * 9 / 10 + 4 + 28 )); cy=$(( sy + sz / 2 ))
    blt $(( cy - th / 2 )) $fs 900; t $(( sx + sz / 2 )) $BL $fs 900 "$C_ONPRI" "$score" middle -40
    rp $MT_TOT тест теста тестов
    t $(( sx + sz / 2 )) $(( cy + th / 2 - 7 )) 22 700 "$C_ONPRI" "$RP" middle
    PG_Y=$(( top + c + 80 ))
}

# «Сервер»: сетка 3×3 характеристик.
cover_server() {
    local dsz="${SYS_DISK%% · *}" dus=""
    [[ "$SYS_DISK" == *" · "* ]] && dus="занято ${SYS_DISK##* · }"
    mt_cpu_split; mt_uptime_ru
    pg_section "Сервер"
    G_L=( "Процессор" "Память" "Диск" "Система" "Виртуализация" "Ядро" "BBR / qdisc" "Uptime" "Load average" )
    G_V=( "$CPU_NAME" "$SYS_RAM" "$dsz" "$SYS_OS" "$SYS_VIRT" "$SYS_KERNEL" "$SYS_CC / $SYS_QDISC" "$UPT" "$SYS_LOAD" )
    G_S=( "$CPU_SUB" "" "$dus" "" "" "" "" "" "" )
    mt_grid 3 24
}

# «Тесты»: иконка в cookie-9, название, что проверяет, ключевая цифра.
cover_tests() {
    local n=${#MT_PAGE_IDX[@]} i idx fn nw=230 y kw
    (( n > 0 )) || return 0
    pg_section "Тесты" "${MT_DONE}/${MT_TOT}"
    for idx in "${MT_PAGE_IDX[@]}"; do mt_test_meta "${MT_CAT_FUNCS[$idx]}"; tw "$T_NAME" 25 700; (( TW > nw )) && nw=$TW; done
    (( nw > 300 )) && nw=300
    y=$(( PG_Y + GAP ))
    for i in "${!MT_PAGE_IDX[@]}"; do
        idx="${MT_PAGE_IDX[$i]}"; fn="${MT_CAT_FUNCS[$idx]}"
        mt_test_meta "$fn"; mt_test_key "$fn"
        segr $i $n 28 8; rr $PX $y $CW 88 "${R[@]}" "$C_SURF"
        mt_shape cookie9 $(( PX + 16 )) $(( y + 14 )) 60 "$C_PRIC"
        mt_icon "$T_ICON" $(( PX + 32 )) $(( y + 30 )) 28 "$C_ONPRIC"
        ellip "$T_NAME" $nw 25 700; t $(( PX + 96 )) $(( y + 52 )) 25 700 "$C_ON" "$EL"
        ellip "$K" 420 21 600; tw "$EL" 21 600; kw=$TW
        t $(( PX + CW - 28 )) $(( y + 51 )) 21 600 "$KC" "$EL" end
        ellip "$T_WHAT" $(( CW - 28 - kw - 20 - 96 - nw - 20 )) 20; t $(( PX + 96 + nw + 20 )) $(( y + 51 )) 20 400 "$C_ON2" "$EL"
        y=$(( y + 92 ))
    done
    PG_Y=$(( y - 4 ))
}

# «Не запускались»: контурные чипы с переносом по строкам.
cover_offnames() {
    (( ${#MT_OFF_NAMES[@]} )) || return 0
    local top=$(( PG_Y + GAP + 20 )) x=$(( PX + 8 )) cx cy w nm maxx=$(( PX + CW - 8 ))
    t $x $(( top + 20 )) 21 700 "$C_ON2" "Не запускались"
    cy=$(( top + 26 + 14 )); cx=$x
    for nm in "${MT_OFF_NAMES[@]}"; do
        ellip "$nm" $(( maxx - x - 43 )) 19; tw "$EL" 19; w=$(( TW + 43 ))
        if (( cx > x && cx + w > maxx )); then cx=$x; cy=$(( cy + 61 )); fi
        sv "<rect x=\"$cx.75\" y=\"$cy.75\" width=\"$(( w - 2 )).5\" height=\"49.5\" rx=\"24.75\" fill=\"none\" stroke=\"$C_OUTV\" stroke-width=\"1.5\"/>"
        t $(( cx + 22 )) $(( cy + 32 )) 19 400 "$C_ON2" "$EL"
        cx=$(( cx + w + 10 ))
    done
    PG_Y=$(( cy + 51 ))
}

# --- Страницы тестов ------------------------------------------------------------

build_page_test() {
    local idx="$1" fn="${MT_CAT_FUNCS[$1]}" st
    st="${MT_STATUS[$fn]:-}"
    mt_test_meta "$fn"
    pg_begin
    local pg; printf -v pg '%02d / %02d' "$MT_PAGE_I" "$MT_PAGE_N"
    pg_topbar "$(mt_ident_line)" "$pg"
    pg_title "$T_NAME" "$T_DESC"
    if [[ "$st" != "выполнен" ]]; then
        page_status "$st"
    else
        case "$fn" in
            run_ip_region)       page_ipregion ;;
            run_censorcheck_*)   page_censor "$fn" ;;
            run_iperf3_*)        page_iperf "$fn" ;;
            run_yabs)            page_yabs ;;
            run_ip_check_place)  page_ipcheck ;;
            run_ip_quality)      page_ipquality ;;
            run_bench_sh)        page_bench ;;
            run_sysbench_cpu)    page_sysbench ;;
            run_ping_map)        page_ping ;;
            *)                   mt_read_metrics "$fn"; mt_read_rows "$fn"; page_fallback ;;
        esac
    fi
    pg_footer
    pg_end
}

# Тест не дошёл до результата: приглушённая фигура с иконкой вместо цифры.
page_status() {
    if [[ "$1" == "ошибка" ]]; then
        hero_right cookie9 "статус" "Ошибка" "" "Тест завершился с ошибкой или ничего не вывел." "" "" "$C_ERRC" "$C_ONERRC" error
    else
        hero_right cookie9 "статус" "Пропущен" "" "Тест прервали во время прогона — данных нет." "" "" "$C_TRACK" "$C_ON2" skip_next
    fi
}

# Показатели сеткой: все метрики, кроме перечисленных. Пусто — ничего.
mt_metrics_grid() {
    local l skip=" $* " n
    G_L=(); G_V=(); G_S=()
    for l in "${ML[@]}"; do
        [[ "$skip" == *" $l "* ]] && continue
        G_L+=("$l"); G_V+=("${M[$l]}")
    done
    n=${#G_L[@]}; (( n )) || return 0
    pg_section "Показатели"
    if (( n <= 4 )); then mt_grid $n 24; elif (( n <= 6 )); then mt_grid 3 24; else mt_grid 4 24; fi
}

# Тест выполнен, но парсер не узнал вывод: метрики, если есть, иначе пояснение.
page_fallback() {
    if (( ${#ML[@]} )); then mt_metrics_grid; return; fi
    hero_right cookie9 "результат" "Выполнен" "" "В выводе не нашлось распознаваемых данных." "" "" "$C_PRIC" "$C_ONPRIC" check
}

# Расхождения IP Region: «Иначе: A и B — GB, C — IT. Без ответа: D, E.» -> SUMM
ipr_summary() {
    local cons="$1" i v cc nm s
    local -A grp=(); local -a order=() na=() parts=() names=()
    for i in "${!RK[@]}"; do
        [[ "${RK[i]}" == chip ]] || continue
        v="${RV[i]}"; nm="${RN[i]}"
        if [[ "$v" =~ ^(${MT_CC_RE})([[:space:]]|$) ]]; then
            cc="${BASH_REMATCH[1]}"; [[ "$cc" == "$cons" ]] && continue
            [[ -n "${grp[$cc]:-}" ]] || order+=("$cc")
            grp[$cc]+="$nm"$'\x1f'
        elif [[ "$v" == "N/A" ]]; then na+=("$nm"); fi
    done
    for cc in "${order[@]}"; do
        IFS=$'\x1f' read -r -a names <<< "${grp[$cc]}"
        mt_join_names "${names[@]}"; parts+=("$JN — $cc")
    done
    SUMM=""
    if (( ${#parts[@]} )); then printf -v s '%s, ' "${parts[@]}"; SUMM="Иначе: ${s%, }."; fi
    if (( ${#na[@]} )); then
        if (( ${#na[@]} > 4 )); then printf -v s '%s, ' "${na[@]:0:3}"; s="${s%, } и ещё $(( ${#na[@]} - 3 ))"
        else printf -v s '%s, ' "${na[@]}"; s="${s%, }"; fi
        SUMM="${SUMM:+$SUMM }Без ответа: $s."
    fi
    [[ -n "$SUMM" ]] || SUMM="Все источники сходятся."
}

page_ipregion() {
    local cons cons6 m big small extra=""
    mt_read_metrics run_ip_region; mt_read_rows run_ip_region
    cons="${M[Консенсус]:-${M["Консенсус IPv4"]:-}}"; cons6="${M["Консенсус IPv6"]:-}"
    m="${M[Совпадений]:-${M["Совпадений v4"]:-}}"
    if [[ -n "$cons" ]]; then
        if [[ "$m" == */* ]]; then big="${m%%/*}"; small="/ ${m#*/}"; else big="${m:-—}"; small=""; fi
        mt_country "$cons"; ipr_summary "$cons"
        [[ -n "$cons6" ]] && extra=" По IPv6: $cons6${M["Совпадений v6"]:+, совпало ${M["Совпадений v6"]}}."
        [[ -n "${M["v4≠v6"]:-}" ]] && extra+=" Разные страны по v4 и v6: ${M["v4≠v6"]}."
        hero_left "$cons" "$big" "$small" "источников называют $CN_ACC" "$SUMM$extra"
    else
        mt_metrics_grid
    fi
    mt_rows_section 0
    if (( ${#LR_NAME[@]} )); then pg_section "Сервисы" "${#LR_NAME[@]}" "какую страну показывает сервис"; mt_list2 "$cons" logo; fi
    mt_rows_section 1
    if (( ${#LR_NAME[@]} )); then pg_section "GeoIP-базы" "${#LR_NAME[@]}" "по ним сайты определяют страну посетителя"; mt_list4 "$cons"; fi
}

page_censor() {
    local fn="$1" head s="" ok all bad
    mt_read_metrics "$fn"; mt_read_rows "$fn"; mt_rows_section 0; mt_count_states
    if (( CNT_ALL )); then ok=$CNT_OK; all=$CNT_ALL; bad=$CNT_BAD
    elif [[ -n "${M[Доступно]:-}${M[Заблокировано]:-}" ]]; then
        ok=${M[Доступно]:-0}; bad=${M[Заблокировано]:-0}; all=$(( ok + bad ))
    else page_fallback; return; fi
    case "$fn" in
        run_censorcheck_geoblock) head="пускают IP этого сервера" ;;
        run_censorcheck_dpi)      head="проходят без DPI-блокировок" ;;
        *)                        head="открываются с этого сервера" ;;
    esac
    mt_names_with bad;  [[ -n "$JN" ]] && s="Блок: $JN."
    mt_names_with warn; [[ -n "$JN" ]] && s="${s:+$s }Редирект: $JN."
    mt_names_with na;   [[ -n "$JN" ]] && s="${s:+$s }Без ответа: $JN."
    [[ -n "$s" ]] || s="Блокировок нет — все сайты из списка открываются."
    rp $bad блок блока блоков
    hero_left "$bad" "$ok" "/ $all" "$head" "$s" "$RP"
    if (( CNT_ALL )); then pg_section "Сайты" "$CNT_ALL" "доступность с этого сервера"; mt_list2 "" globe; fi
}

page_iperf() {
    local fn="$1" n ping pnum sub
    mt_read_metrics "$fn"; mt_read_rows "$fn"; mt_speed_rows
    n=${#LR_NAME[@]}
    if (( n == 0 )); then page_fallback; return; fi
    rp $n сервер сервера серверов; sub="$n $RP в России"
    ping="${M["Мин ping"]:-}"; pnum="${ping%% *}"
    if [[ -n "$pnum" ]]; then
        hero_right sunny8 "максимум · $IMX_CITY, $IMX_DIR" "$IMX" "Мбит/с" "$sub" "$pnum" "ms · мин. ping"
    else
        hero_right sunny8 "максимум · $IMX_CITY, $IMX_DIR" "$IMX" "Мбит/с" "" "$n" "$RP"
    fi
    mt_nice $(( (IMX10 + 9) / 10 )) 100 250 500 1000 2500 5000 10000 25000 50000 100000
    pg_section "Города" "" "Мбит/с · шкала $NICE"
    mt_updown_rows
}

# Строки «город · ↓ волна · ↑ волна» из LR_NAME / LR_DN / LR_UP (+ флаг из LR_CC).
mt_updown_rows() {
    local n=${#LR_NAME[@]} i y=$(( PG_Y + GAP )) c1 c2 bx=$(( PX + 348 )) bw=690 vx=$(( PX + CW - 28 )) nx nwid nm flags=0
    for (( i=0; i<n; i++ )); do [[ -n "${LR_CC[i]:-}" ]] && flags=1; done
    for (( i=0; i<n; i++ )); do
        segr $i $n 28 8; rr $PX $y $CW 122 "${R[@]}" "$C_SURF"
        nx=$(( PX + 28 )); nwid=250; nm="${LR_NAME[i]}"
        # страну уже сказал флаг — «Paris, FR» сокращаем до «Paris»
        if [[ -n "${LR_CC[i]:-}" ]]; then mt_flag "${LR_CC[i]}" $nx $(( y + 39 )) 44; nm="${nm%, *}"
        elif (( flags )); then mt_icon language $(( nx + 4 )) $(( y + 43 )) 36 "$C_ON2"; fi
        (( flags )) && { nx=$(( nx + 60 )); nwid=190; }
        ellip "$nm" $nwid 26 700; t $nx $(( y + 70 )) 26 700 "$C_ON" "$EL"
        c1=$(( y + 38 )); c2=$(( y + 84 ))
        mt_icon arrow_downward $(( PX + 306 )) $(( c1 - 13 )) 26 "$C_PRI"
        num10 "${LR_DN[i]}"; mt_bar $bx $c1 $bw $(( N10 * 100 / NICE )) "$C_PRI"
        t $vx $(( c1 + 8 )) 24 700 "$C_ON" "${LR_DN[i]}" end
        if [[ -n "${LR_UP[i]:-}" ]]; then
            mt_icon arrow_upward $(( PX + 306 )) $(( c2 - 13 )) 26 "$C_SEC"
            num10 "${LR_UP[i]}"; mt_bar $bx $c2 $bw $(( N10 * 100 / NICE )) "$C_SEC"
            t $vx $(( c2 + 8 )) 24 700 "$C_ON2" "${LR_UP[i]}" end
        fi
        y=$(( y + 126 ))
    done
    PG_Y=$(( y - 4 ))
}

# Строки «флаг · место / подпись · волна · значение» (сеть YABS, узлы пинга).
# LR_NAME LR_SUB LR_CC LR_N10 (значение ×10 для шкалы) LR_VN LR_VU (число и единица)
mt_net_rows() {
    local n=${#LR_NAME[@]} i y=$(( PG_Y + GAP )) c bx=$(( PX + 334 )) bw=648 vx=$(( PX + CW - 28 )) vc
    for (( i=0; i<n; i++ )); do
        segr $i $n 28 8; rr $PX $y $CW 81 "${R[@]}" "$C_SURF"
        c=$(( y + 40 ))
        if [[ -n "${LR_CC[i]}" ]]; then mt_flag "${LR_CC[i]}" $(( PX + 20 )) $(( c - 22 )) 44
        else mt_icon language $(( PX + 24 )) $(( c - 18 )) 36 "$C_ON2"; fi
        ellip "${LR_NAME[i]}" 226 23 700; t $(( PX + 80 )) $(( c - 3 )) 23 700 "$C_ON" "$EL"
        ellip "${LR_SUB[i]}" 226 17; t $(( PX + 80 )) $(( c + 19 )) 17 400 "$C_ON2" "$EL"
        mt_bar $bx $c $bw $(( LR_N10[i] * 100 / NICE )) "$C_PRI"
        # число и единица — двумя текстами, а не tspan под text-anchor="end":
        # старые librsvg выравнивают такой текст по кускам, и они наезжают
        vc="$C_ON"; [[ "${LR_VN[i]}" == "—" ]] && vc="$C_OUT"
        local ux=$vx
        if [[ -n "${LR_VU[i]}" ]]; then
            tw "${LR_VU[i]}" 17; ux=$(( vx - TW ))
            t $ux $(( c + 10 )) 17 400 "$C_ON2" "${LR_VU[i]}"; ux=$(( ux - 8 ))
        fi
        t $ux $(( c + 10 )) 30 800 "$vc" "${LR_VN[i]}" end
        y=$(( y + 85 ))
    done
    PG_Y=$(( y - 4 ))
}

# Две карточки fio: 4K в «солнце», 1M в «печеньке».
yabs_fio() {
    local top=$(( PG_Y + GAP )) cw x i k=0 num unit fs cy tx tw2 j
    local -a vals=("$1" "$2") lbl=("fio 4K" "fio 1M") shp=(sunny8 cookie12)
    local -a dsc=("мелкие блоки: базы данных, система" "крупные блоки: большие файлы, бэкапы")
    [[ -n "$1" && -n "$2" ]] && cw=$(( (CW - 12) / 2 )) || cw=$CW
    x=$PX
    for i in 0 1; do
        [[ -n "${vals[i]}" ]] || continue
        rr $x $top $cw 286 56 56 56 56 "$C_SURF"
        mt_shape "${shp[i]}" $(( x + 28 )) $(( top + 28 )) 230 "$C_PRI"
        num="${vals[i]%% *}"; unit="${vals[i]#* }"; [[ "$unit" == "${vals[i]}" ]] && unit=""
        fitsz "$num" 160 64 900 -30 32; fs=$FS; cy=$(( top + 143 ))
        blt $(( cy - (fs * 95 / 100 + 26) / 2 )) $fs 950; t $(( x + 143 )) $BL $fs 900 "$C_ONPRI" "$num" middle -30
        t $(( x + 143 )) $(( cy + (fs * 95 / 100 + 26) / 2 - 6 )) 20 700 "$C_ONPRI" "$unit" middle
        tx=$(( x + 28 + 230 + 28 )); tw2=$(( cw - 28 - 230 - 28 - 36 ))
        wrap "${dsc[i]}" $tw2 21 400 3
        local th=$(( 38 + 8 + ${#WL[@]} * 294 / 10 )) ty
        ty=$(( cy - th / 2 ))
        t $tx $(( ty + 29 )) 30 800 "$C_ON" "${lbl[i]}"
        for j in "${!WL[@]}"; do blt $(( ty + 46 + j * 294 / 10 )) 21 1400; t $tx $BL 21 400 "$C_ON2" "${WL[$j]}"; done
        x=$(( x + cw + 12 ))
    done
    PG_Y=$(( top + 286 ))
}

# Подпись шкалы: 2500 -> «2.5 Гбит/с», 500 -> «500 Мбит/с»
mt_scale_label() {
    if (( $1 >= 1000 )); then
        if (( $1 % 1000 == 0 )); then SCL="$(( $1 / 1000 )) Гбит/с"; else SCL="$(( $1 / 1000 )).$(( $1 % 1000 / 100 )) Гбит/с"; fi
    else SCL="$1 Мбит/с"; fi
}

page_yabs() {
    local f4 f1 i loc cc mx=0
    mt_read_metrics run_yabs; mt_read_rows run_yabs
    f4="${M["fio 4k"]:-}"; f1="${M["fio 1m"]:-}"
    [[ -n "$f4$f1" ]] && yabs_fio "$f4" "$f1"
    G_L=(); G_V=(); G_S=(); G_FR=()
    [[ -n "${M[CPU]:-}" ]]  && { mt_cpu_clean "${M[CPU]}"; G_L+=("Процессор"); G_V+=("$CPUC"); G_FR+=(16); }
    [[ -n "${M[Ядер]:-}" ]] && { G_L+=("Ядер"); G_V+=("${M[Ядер]}"); G_FR+=(10); }
    [[ -n "${M[RAM]:-}" ]]  && { G_L+=("RAM"); G_V+=("${M[RAM]}"); G_FR+=(10); }
    [[ -n "${M[Диск]:-}" ]] && { G_L+=("Диск"); G_V+=("${M[Диск]}"); G_FR+=(10); }
    (( ${#G_L[@]} )) && { pg_section "Сервер"; mt_grid ${#G_L[@]} 23; }
    if [[ -n "${M["GB6 single"]:-}${M["GB6 multi"]:-}" ]]; then
        G_L=("Одно ядро" "Все ядра"); G_V=("${M["GB6 single"]:-—}" "${M["GB6 multi"]:-—}"); G_S=()
        pg_section "Geekbench 6"; mt_grid 2 23
    fi
    LR_NAME=(); LR_SUB=(); LR_CC=(); LR_N10=(); LR_VN=(); LR_VU=()
    for i in "${!RK[@]}"; do
        [[ "${RK[i]}" == net ]] || continue
        loc="${RN[i]}"; cc=""; [[ "$loc" =~ ,\ (${MT_CC_RE})$ ]] && cc="${BASH_REMATCH[1]}"
        num10 "${RV[i]}"; mt_speed $N10
        LR_NAME+=("$loc"); LR_SUB+=("${RA[i]}"); LR_CC+=("$cc"); LR_N10+=("$N10"); LR_VN+=("$SPD_N"); LR_VU+=("$SPD_U")
        (( N10 > mx )) && mx=$N10
    done
    if (( ${#LR_NAME[@]} )); then
        mt_nice $(( (mx + 9) / 10 )) 100 250 500 1000 2500 5000 10000 25000 50000 100000
        mt_scale_label $NICE
        pg_section "Сеть" "${#LR_NAME[@]}" "до дата-центров по миру · шкала $SCL"
        mt_net_rows
    fi
    (( ${#ML[@]} )) || [[ ${#LR_NAME[@]} -gt 0 ]] || page_fallback
}

page_bench() {
    local io n bn bu
    mt_read_metrics run_bench_sh; mt_read_rows run_bench_sh; mt_speed_rows
    io="${M["I/O сред."]:-}"; n=${#LR_NAME[@]}
    if [[ -n "$io" ]]; then
        if (( n )); then mt_speed $IMX10; bn="$SPD_N"; bu="$SPD_U · лучший"
        else bn="${M[Ядер]:-—}"; rp "${M[Ядер]:-0}" ядро ядра ядер; bu="$RP CPU"; fi
        local ion="${io%% *}" iou="${io#* }"
        [[ "$iou" == "$io" ]] && { ion="${io%%[!0-9.]*}"; iou="${io#"$ion"}"; }
        hero_right sunny8 "диск · I/O, среднее из трёх прогонов" "$ion" "$iou" "${M[Сеть]:-}" "$bn" "$bu"
    fi
    G_L=(); G_V=(); G_S=(); G_FR=()
    [[ -n "${M[CPU]:-}" ]]  && { mt_cpu_clean "${M[CPU]}"; G_L+=("Процессор"); G_V+=("$CPUC"); G_FR+=(16); }
    [[ -n "${M[Ядер]:-}" ]] && { G_L+=("Ядер"); G_V+=("${M[Ядер]}"); G_FR+=(10); }
    [[ -n "${M[RAM]:-}" ]]  && { G_L+=("RAM"); G_V+=("${M[RAM]}"); G_FR+=(10); }
    [[ -n "${M[Диск]:-}" ]] && { G_L+=("Диск"); G_V+=("${M[Диск]}"); G_FR+=(10); }
    (( ${#G_L[@]} )) && { pg_section "Сервер"; mt_grid ${#G_L[@]} 23; }
    if (( n )); then
        mt_nice $(( (IMX10 + 9) / 10 )) 100 250 500 1000 2500 5000 10000 25000 50000 100000
        pg_section "Сеть" "$n" "Мбит/с · шкала $NICE"
        mt_updown_rows
    fi
    [[ -n "$io" ]] || (( n )) || page_fallback
}

page_sysbench() {
    local eps la tt tev line="" l
    mt_read_metrics run_sysbench_cpu
    eps="${M["events/s"]:-}"; la="${M["lat avg"]:-}"; tt="${M[время]:-}"; tev="${M[событий]:-}"
    if [[ -z "$eps" ]]; then page_fallback; return; fi
    if [[ -n "$tev" ]]; then rp "$tev" событие события событий; line="$tev $RP"; fi
    [[ -n "$tt" ]] && line="${line:+$line за }$tt"
    if [[ -n "$la" ]]; then hero_right sunny8 "events/s · 1 поток" "$eps" "" "$line" "${la%% *}" "ms · задержка"
    else hero_right sunny8 "events/s · 1 поток" "$eps" "" "$line" "1" "поток"; fi
    G_L=(); G_V=(); G_S=()
    for l in событий время "lat avg" "lat 95th"; do
        [[ -n "${M[$l]:-}" ]] || continue
        case "$l" in событий) G_L+=("Событий") ;; время) G_L+=("Время") ;; "lat avg") G_L+=("Задержка, среднее") ;; *) G_L+=("Задержка, 95%") ;; esac
        G_V+=("${M[$l]}")
    done
    (( ${#G_L[@]} )) && { pg_section "Детали"; mt_grid ${#G_L[@]} 24; }
}

page_ipcheck() {
    local risk dnsbl
    mt_read_metrics run_ip_check_place; mt_read_rows run_ip_check_place; mt_rows_section 0; mt_count_states
    risk="${M[Риск]:-}"; dnsbl="${M[DNSBL]:-}"
    if (( CNT_ALL )); then
        if [[ -n "$risk" ]]; then hero_right sunny8 "стриминги и AI-сервисы" "$CNT_OK" "/ $CNT_ALL" "открываются с этого IP" "$risk" "уровень риска"
        else hero_right sunny8 "стриминги и AI-сервисы" "$CNT_OK" "/ $CNT_ALL" "открываются с этого IP" "${dnsbl:-—}" "в DNSBL"; fi
        pg_section "Сервисы" "$CNT_ALL" "регион, который видит сервис"
        mt_list2 "$SYS_COUNTRY" logo
        mt_metrics_grid "Риск"
    else
        page_fallback
    fi
}

page_ipquality() {
    local usage company geo dnsbl line=""
    mt_read_metrics run_ip_quality; mt_read_rows run_ip_quality
    usage="${M[Usage]:-}"; company="${M[Company]:-}"; geo="${M[Гео]:-}"; dnsbl="${M[DNSBL]:-}"
    if [[ -n "$usage$company" ]]; then
        [[ -n "$company" ]] && line="Company: $company"
        [[ -n "$geo" ]] && line="${line:+$line · }Гео: $geo"
        hero_right sunny8 "тип IP по базам" "${usage:-$company}" "" "$line" "${dnsbl:-—}" "в чёрных списках"
    fi
    mt_rows_section 0
    if (( ${#LR_NAME[@]} )); then pg_section "Оценка риска" "${#LR_NAME[@]}" "по базам репутации IP"; mt_list2 "" db; fi
    mt_rows_section 1
    if (( ${#LR_NAME[@]} )); then pg_section "Сервисы и AI" "${#LR_NAME[@]}" "регион, который видит сервис"; mt_list2 "$SYS_COUNTRY" logo; fi
    # то, что уже стоит в hero, сеткой не повторяем; hero нет — показываем всё
    if [[ -n "$usage$company" ]]; then mt_metrics_grid Usage Company Гео DNSBL; else mt_metrics_grid; fi
    [[ -n "$usage$company" ]] || (( ${#RK[@]} )) || (( ${#ML[@]} )) || page_fallback
}

page_ping() {
    local ru worst loss wn wc line g i cc n ms node mx=0 grp
    mt_read_metrics run_ping_map; mt_read_rows run_ping_map
    if [[ -n "${M[API]:-}" ]]; then
        hero_right cookie9 "check-host.net" "API недоступен" "" "Сервис проверки не ответил — узлы не опрошены." "" "" "$C_ERRC" "$C_ONERRC" error
        return
    fi
    ru="${M["РФ avg"]:-}"; worst="${M[Худший]:-}"; loss="${M[Потери]:-}"
    if [[ "$loss" == 0/* ]]; then rp "${loss#0/}" узел узла узлов; line="потерь нет · ${loss#0/} $RP"
    elif [[ -n "$loss" ]]; then line="потери: $loss"; fi
    # «Токио · 184.2 ms» -> число и город; «Токио · 100% потерь» -> «100%» и город
    if [[ "$worst" =~ ^(.*)\ ·\ ([0-9]+(\.[0-9]+)?)\ ms$ ]]; then wn="${BASH_REMATCH[2]}"; wc="ms · ${BASH_REMATCH[1]}"
    elif [[ "$worst" =~ ^(.*)\ ·\ ([0-9]+%) ]]; then wn="${BASH_REMATCH[2]}"; wc="потерь · ${BASH_REMATCH[1]}"
    else wn="—"; wc="${worst:-худший узел}"; fi
    if [[ -n "$ru" ]]; then hero_right sunny8 "средний пинг из России" "${ru%% *}" "ms" "$line" "$wn" "$wc"; fi
    for i in "${!RK[@]}"; do
        [[ "${RK[i]}" == ping ]] || continue
        num10 "${RV[i]}"; (( N10 > mx )) && mx=$N10
    done
    mt_nice $(( (mx + 9) / 10 )) 50 100 150 200 300 500 1000 2000
    local first=1
    for g in "Россия" "Соседи" "Европа" "Мир"; do
        LR_NAME=(); LR_SUB=(); LR_CC=(); LR_N10=(); LR_VN=(); LR_VU=()
        for i in "${!RK[@]}"; do
            [[ "${RK[i]}" == ping ]] || continue
            IFS='|' read -r ms grp _ <<< "${RA[i]}"
            [[ "$grp" == "$g" ]] || continue
            node="${RS[i]}"; cc="${node%%[0-9]*}"
            LR_NAME+=("${RN[i]}"); LR_CC+=("$cc")
            if [[ "${RV[i]}" == "—" || -z "${RV[i]}" ]]; then
                LR_SUB+=("$node · ${ms:-нет ответа}"); LR_N10+=(0); LR_VN+=("—"); LR_VU+=("")
            else
                num10 "${RV[i]}"; LR_N10+=("$N10"); LR_VN+=("${RV[i]}"); LR_VU+=("ms")
                if [[ "$ms" == "0%" || -z "$ms" ]]; then LR_SUB+=("$node · без потерь"); else LR_SUB+=("$node · потери $ms"); fi
            fi
        done
        n=${#LR_NAME[@]}; (( n )) || continue
        if (( first )); then pg_section "$g" "$n" "задержка, шкала $NICE ms"; first=0; else pg_section "$g" "$n"; fi
        mt_net_rows
    done
    [[ -n "$ru" ]] || (( first == 0 )) || page_fallback
}

# --- Одна длинная картинка (MT_ALBUM=0 или если альбом не собрался) ----------------
# Те же страницы стопкой: каждая — вложенный <svg> со своим смещением.
build_summary_svg() {
    mt_style_init; mt_album_plan; mt_run_counters
    local tmp="${SUMMARY_DIR:-/tmp}/.page.svg" body="" y=0 i idx page
    MT_PAGE_N=$(( ${#MT_PAGE_IDX[@]} + 1 )); MT_PAGE_I=1
    build_page_cover > "$tmp"; page=$(<"$tmp")
    body+="<svg y=\"$y\"${page#<svg}"$'\n'; y=$(( y + MT_PAGE_H ))
    for i in "${!MT_PAGE_IDX[@]}"; do
        idx="${MT_PAGE_IDX[$i]}"; MT_PAGE_I=$(( i + 2 ))
        build_page_test "$idx" > "$tmp"; page=$(<"$tmp")
        body+="<svg y=\"$y\"${page#<svg}"$'\n'; y=$(( y + MT_PAGE_H ))
    done
    rm -f "$tmp"
    MT_PAGE_H=$y
    printf '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="%d" height="%d" viewBox="0 0 %d %d">\n%s</svg>\n' "$W" "$y" "$W" "$y" "$body"
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

# Одна длинная картинка — это все страницы стопкой, 15–20 тысяч px в высоту.
# Рендерим её в масштабе 1:1: кегли в 5b крупные и читаются и так, а ×2 на
# такой высоте — сотни мегабайт памяти под буфер, которых у VPS на 512 МБ нет.
step_render_png() {
    local svg="$SUMMARY_DIR/summary.svg" png="$SUMMARY_DIR/summary.png"
    printf '%s' "$svg" > "$SUMMARY_DIR/out.path"
    if   command -v rsvg-convert &>/dev/null; then rsvg-convert -w 1280 -o "$png" "$svg" 2>/dev/null
    elif command -v convert      &>/dev/null; then convert -density 96 -background none "$svg" "$png" 2>/dev/null
    elif command -v magick       &>/dev/null; then magick  -density 96 -background none "$svg" "$png" 2>/dev/null
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
# imgdb — веб-ссылка на альбом; MT_IMGDB=0 — не заливать (сводка всё равно уйдёт в Telegram, если сервер привязан)
MT_IMGDB="${MT_IMGDB:-1}"

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
    # логический размер — для склейки страниц в альбом Telegram (mt_tg_pages)
    printf '%s\t%s\t%s\n' "$png" "$W" "$MT_PAGE_H" >> "$SUMMARY_DIR/pages.dim"
}

# --- Telegram: один альбом ---------------------------------------------------
# В альбоме Telegram — до 10 картинок: обложка и 9 страниц. Если тестов больше,
# соседние страницы склеиваются попарно — те пары, что теряют при склейке меньше
# всего: короткие — одна под другой, длинные — рядом. Склейки нужны только боту:
# imgdb и папка с оригиналами получают страницы как есть.
MT_TG_ALBUM=10

# Масштаб картинки <ширина>x<высота> (логических px) после рендера, ×1000 — в MT_SC.
# Так же считает mt_render_page: MT_PAGE_SCALE, но длинная сторона ≤ MT_MAXSIDE.
mt_tg_scale() {
    local x
    MT_SC=$(( MT_PAGE_SCALE * 1000 ))
    x=$(( MT_MAXSIDE * 1000 / $1 )); (( x < MT_SC )) && MT_SC=$x
    x=$(( MT_MAXSIDE * 1000 / $2 )); (( x < MT_SC )) && MT_SC=$x
    return 0
}

# План склейки: <ширина> <высоты страниц тестов…> → строки «i» (страница как есть)
# или «i j stack|side» (пара), i с 1. Жадно: пара с наибольшим масштабом после склейки.
mt_tg_plan() {
    local w="$1"; shift
    local -a h=( 0 "$@" ) used=() pair=()
    local n=$# need k i best bi m s hi
    need=$(( n - (MT_TG_ALBUM - 1) ))
    for (( k = 0; k < need; k++ )); do
        best=-1; bi=0
        for (( i = 1; i < n; i++ )); do
            [[ -n "${used[i]:-}${used[i+1]:-}" ]] && continue
            mt_tg_scale "$w" $(( h[i] + h[i+1] )); s=$MT_SC; m=stack
            hi=$(( h[i] > h[i+1] ? h[i] : h[i+1] ))
            mt_tg_scale $(( w * 2 )) "$hi"
            (( MT_SC > s )) && { s=$MT_SC; m=side; }
            (( s > best )) && { best=$s; bi=$i; pair[i]=$m; }
        done
        (( bi )) || break
        used[bi]=${pair[bi]}; used[bi+1]=-
    done
    for (( i = 1; i <= n; i++ )); do
        case "${used[i]:-}" in
            stack|side) echo "$i $(( i + 1 )) ${used[i]}"; i=$(( i + 1 )) ;;
            *) echo "$i" ;;
        esac
    done
}

# Склейка двух PNG: <out> <stack|side> <a> <высота a> <b> <высота b> <ширина>.
# rsvg-convert рисует SVG со ссылками на обе картинки (файлы в той же папке),
# иначе — ImageMagick -append/+append.
mt_join_pages() {
    local out="$1" mode="$2" a="$3" ha="$4" b="$5" hb="$6" w="$7"
    local wc hc x2=0 y2=0 wpx hpx bg="${C_BG:-#0f0b09}" app=-append im=convert
    if [[ "$mode" == side ]]; then wc=$(( w * 2 )); hc=$(( ha > hb ? ha : hb )); x2=$w; app=+append
    else wc=$w; hc=$(( ha + hb )); y2=$ha; fi
    wpx=$(( wc * MT_PAGE_SCALE )); hpx=$(( hc * MT_PAGE_SCALE ))
    if (( wpx > MT_MAXSIDE )); then hpx=$(( hpx * MT_MAXSIDE / wpx )); wpx=$MT_MAXSIDE; fi
    if (( hpx > MT_MAXSIDE )); then wpx=$(( wpx * MT_MAXSIDE / hpx )); hpx=$MT_MAXSIDE; fi
    rm -f "$out"
    if command -v rsvg-convert &>/dev/null; then
        printf '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="%s" height="%s" viewBox="0 0 %s %s">\n<rect width="%s" height="%s" fill="%s"/>\n<image x="0" y="0" width="%s" height="%s" xlink:href="%s"/>\n<image x="%s" y="%s" width="%s" height="%s" xlink:href="%s"/>\n</svg>\n' \
            "$wc" "$hc" "$wc" "$hc" "$wc" "$hc" "$bg" "$w" "$ha" "${a##*/}" "$x2" "$y2" "$w" "$hb" "${b##*/}" \
            > "${out%.png}.svg"
        rsvg-convert -w "$wpx" -o "$out" "${out%.png}.svg" 2>/dev/null
    elif command -v magick &>/dev/null || command -v convert &>/dev/null; then
        command -v magick &>/dev/null && im=magick
        "$im" \( "$a" -resize "$(( wpx * w / wc ))x" \) \( "$b" -resize "$(( wpx * w / wc ))x" \) \
            -background "$bg" -gravity north "$app" "$out" 2>/dev/null
    fi
    [[ -s "$out" ]]
}

# tg-pages.list — картинки для бота: обложка + не больше 9 страниц.
mt_tg_pages() {
    local dims="$SUMMARY_DIR/pages.dim" out="$SUMMARY_DIR/tg-pages.list"
    local -a files=() hs=()
    local f w h a b mode joined wd=0
    rm -f "$out"
    [[ -s "$dims" ]] || return 1
    # read на конце файла обнуляет переменные — ширину запоминаем внутри цикла
    while IFS=$'\t' read -r f w h; do files+=( "$f" ); hs+=( "$h" ); wd=$w; done < "$dims"
    printf '%s\n' "${files[0]}" > "$out"
    while read -r a b mode; do
        if [[ -z "$b" ]]; then printf '%s\n' "${files[a]}" >> "$out"; continue; fi
        joined=$(printf '%s/tg-%02d-%02d.png' "${files[a]%/*}" "$a" "$b")
        mt_join_pages "$joined" "$mode" "${files[a]}" "${hs[a]}" "${files[b]}" "${hs[b]}" "$wd" \
            || { rm -f "$out"; return 1; }
        printf '%s\n' "$joined" >> "$out"
    done < <(mt_tg_plan "$wd" "${hs[@]:1}")
}

step_build_pages() {
    # ниже идёт rm -rf по этому пути — пустой SUMMARY_DIR превратил бы его в /pages
    [[ -n "$SUMMARY_DIR" && -d "$SUMMARY_DIR" ]] || return 1
    gather_system_facts
    mt_style_init
    mt_album_plan
    mt_run_counters
    # Данные для Telegram — до рендера: ниже шаг выходит при первой же ошибке
    # страницы, а сводку боту отправим и без картинок.
    mt_write_summary || true

    local dir="$SUMMARY_DIR/pages" i idx fn base
    rm -rf "$dir"; mkdir -p "$dir" 2>/dev/null || return 1
    : > "$SUMMARY_DIR/pages.list" || return 1
    : > "$SUMMARY_DIR/pages.dim"; rm -f "$SUMMARY_DIR/tg-pages.list"

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
    # боту — одним альбомом; не склеилось — уйдут страницы как есть
    if mt_tg_enabled; then mt_tg_pages || true; fi
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

# --- Telegram: доставка сводки ------------------------------------------------

# Слать ли сводку в бота: сервер привязан и не выключено через MT_TG=0.
mt_tg_enabled() { [[ "${MT_TG:-1}" != 0 ]] && mt_conf_load 2>/dev/null; }

# summary.txt и страницы альбома (обложка первой) — одним multipart-запросом.
# Шаг идёт под spin_run (на терминале — в фоне), поэтому итог — маркером в
# SUMMARY_DIR: tg.ok (с run_id), tg.blocked, tg.revoked, tg.err (с причиной).
# Ключ идемпотентности в tg.key: повтор после таймаута не создаст второй пост.
# Ключ сервера стирает только явный «revoked»; голый 401 — нет.
step_tg_deliver() {
    local key f code try wait=5 reason="" list
    local -a parts=()
    mt_conf_load || return 1
    rm -f "$SUMMARY_DIR/tg.ok" "$SUMMARY_DIR/tg.blocked" "$SUMMARY_DIR/tg.revoked" "$SUMMARY_DIR/tg.err"
    [[ -s "$SUMMARY_DIR/summary.txt" ]] || { printf 'нет summary.txt' > "$SUMMARY_DIR/tg.err"; return 1; }
    key=$(cat "$SUMMARY_DIR/tg.key" 2>/dev/null)
    if ! mt_match '^run-[0-9a-f]{16}$' "$key"; then
        key="run-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
        printf '%s' "$key" > "$SUMMARY_DIR/tg.key"
    fi
    parts=( -F "summary=@$SUMMARY_DIR/summary.txt;type=text/plain" -F "key=$key" )
    # сводка по заданию из Telegram закрывает это задание в боте
    [[ -n "${MT_JOB_ID:-}" ]] && parts+=( -F "job_id=$MT_JOB_ID" )
    # страницы — склеенные под альбом Telegram (tg-pages.list), если они есть
    list="$SUMMARY_DIR/pages.list"
    [[ -s "$list" && -s "$SUMMARY_DIR/tg-pages.list" ]] && list="$SUMMARY_DIR/tg-pages.list"
    if [[ -s "$list" ]]; then
        while IFS= read -r f; do
            [[ -s "$f" ]] && parts+=( -F "page=@$f;type=image/png" )
        done < "$list"
    fi
    for try in 1 2 3; do
        code=$(MT_API_MAXTIME=180 mt_api POST /v1/agent/runs "$SUMMARY_DIR/tg.resp" "${parts[@]}")
        mt_resp "$SUMMARY_DIR/tg.resp"
        case "$code:$MT_RESP_V" in
            200:ok)      printf '%s' "${MT_RESP_A[0]:-}" > "$SUMMARY_DIR/tg.ok"; return 0 ;;
            200:revoked) mt_conf_wipe; : > "$SUMMARY_DIR/tg.revoked"; return 1 ;;
            200:blocked) : > "$SUMMARY_DIR/tg.blocked"; return 1 ;;
            200:closed)  reason="бот закрыт владельцем — сводка осталась на сервере"; break ;;
            *:retry)     wait="${MT_RESP_A[0]:-30}"; [[ "$wait" =~ ^[0-9]+$ ]] || wait=30
                         (( wait > 30 )) && wait=30; reason="бот попросил подождать" ;;
            200:pending) wait=5; reason="бот ещё обрабатывает" ;;
            000:*)       wait=5; reason="нет связи с ботом" ;;
            5??:*)       wait=5; reason="HTTP $code" ;;
            *)           reason="HTTP ${code:0:3}"; break ;;
        esac
        (( try < 3 )) && sleep "$wait"
    done
    printf '%s' "$(mt_clean "$reason")" > "$SUMMARY_DIR/tg.err"
    return 1
}

mt_tg_report() {
    if [[ -e "$SUMMARY_DIR/tg.ok" ]]; then
        echo -e "  ${GREEN}Сводка отправлена в Telegram${NC} (@${MT_BOT:-$MT_BOT_USERNAME})."
    elif [[ -e "$SUMMARY_DIR/tg.blocked" ]]; then
        echo -e "  ${YELLOW}Telegram: бот заблокирован — разблокируйте его, и сводки снова будут приходить.${NC}"
    elif [[ -e "$SUMMARY_DIR/tg.revoked" ]]; then
        echo -e "  ${YELLOW}Telegram: сервер отвязан в боте — ключ на сервере удалён.${NC}"
    elif [[ -e "$SUMMARY_DIR/tg.err" ]]; then
        echo -e "  ${YELLOW}Telegram: сводка не отправилась ($(cat "$SUMMARY_DIR/tg.err")).${NC}"
    fi
}

# Подсказка непривязанному серверу — одна строка, только на терминале.
mt_tg_hint() {
    [[ -t 1 && "${MT_TG:-1}" != 0 ]] && mt_tg_configured || return 0
    mt_conf_load 2>/dev/null && return 0
    echo -e "  ${CYAN}Сводку можно получать в Telegram — Утилиты → Telegram-бот (или multitest --pair).${NC}"
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
    local tg=0 dir="$SUMMARY_DIR/pages"
    if ! spin_run "Собираю страницы альбома (${n})" step_build_pages; then
        # недостроенный альбом в бот не шлём — только сводку, бот напишет пост текстом
        if mt_tg_enabled && [[ -s "$SUMMARY_DIR/summary.txt" ]]; then
            rm -f "$SUMMARY_DIR/pages.list"
            spin_run "Отправляю сводку в Telegram" step_tg_deliver
            mt_tg_report
        fi
        echo -e "  ${YELLOW}Страницы не собрались — соберу одной картинкой.${NC}"
        return 1
    fi
    if mt_tg_enabled; then
        spin_run "Отправляю сводку в Telegram" step_tg_deliver
        [[ -e "$SUMMARY_DIR/tg.ok" ]] && tg=1
    fi
    # imgdb выключен (MT_IMGDB=0) или не ответил, а в Telegram сводка ушла — этого
    # достаточно: длинную простыню ради хостинга не собираем.
    if [[ "$MT_IMGDB" != "1" ]] || ! spin_run "Загружаю альбом на imgdb" step_upload_album; then
        if (( tg )) || [[ "$MT_IMGDB" != "1" ]]; then
            echo ""
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            mt_tg_report
            echo -e "  ${YELLOW}Оригиналы лежат тут:${NC} ${BOLD}${dir}${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            return 0
        fi
        mt_tg_report
        echo -e "  ${YELLOW}Альбом не загрузился — соберу одной картинкой.${NC}"
        return 1
    fi

    local url life
    url=$(cat "$SUMMARY_DIR/url.txt"); life=$(imgdb_life)
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}${GREEN}Альбом со сводкой:${NC} ${BOLD}${url}${NC}"
    echo -e "  ${CYAN}Страниц: ${BOLD}${n}${NC}${CYAN} — обложка и по одной на тест.${NC}"
    # про постоянную ссылку молчим: строка была нужна, только пока срок конечный
    [[ "$life" != "постоянная" ]] && echo -e "  ${YELLOW}Ссылка ${life} — потом альбом удалится с хостинга.${NC}"
    mt_tg_report
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
    rm -f "$SUMMARY_DIR/url.txt" "$SUMMARY_DIR/out.path" "$SUMMARY_DIR/expires.txt" \
          "$SUMMARY_DIR/tg.ok" "$SUMMARY_DIR/tg.blocked" "$SUMMARY_DIR/tg.revoked" \
          "$SUMMARY_DIR/tg.err" "$SUMMARY_DIR/tg.key"

    spin_run "Устанавливаю зависимости для картинки" step_render_deps

    [[ "$MT_ALBUM" == "1" ]] && render_album_summary && { mt_tg_hint; return 0; }
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
    echo -e "  ${GREEN}12)${NC}  Ping-карта — check-host.net"
    echo ""
    echo -e "  ${YELLOW}13)${NC}  ${BOLD}Мультитест — выбор и запуск тестов${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}── Утилиты ──${NC}"
    echo ""
    if mt_tg_configured; then
        echo -e "  ${GREEN}14)${NC}  Утилиты — BBR, IPv6, Telegram-бот"
    else
        echo -e "  ${GREEN}14)${NC}  Утилиты — BBR, IPv6"
    fi
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
    echo -ne "  ${BOLD}Выберите пункт [0-14]: ${NC}"
}

# ============================================================
#  Главный цикл
# ============================================================

# Позволяет подключить функции для тестов: MULTITEST_TEST=1 source multitest.sh
[[ "${MULTITEST_TEST:-0}" == "1" ]] && return 0 2>/dev/null

mt_cli_help() {
    echo "Использование: multitest [параметр]"
    echo "  (без параметров)  интерактивное меню"
    echo "  --install         установить как команду multitest"
    echo "  --pair [код]      привязать сервер к Telegram-боту @${MT_BOT_USERNAME}"
    echo "                    (код mtp_… — из кнопки «Добавить сервер» в боте: без ссылки и QR)"
    echo "  --tg-status       привязан ли сервер и есть ли связь с ботом"
    echo "  --unpair          отвязать сервер и удалить ключ"
    echo "  --agent           служба запуска тестов из Telegram (её запускает systemd)"
    echo "  --help            эта справка"
}

# Флаги разбираем здесь, а не в начале файла: ниже этой строки определено уже всё.
# Каждый режим завершает процесс; незнакомый флаг в меню не проваливается.
mt_cli_dispatch() {
    case "${1:-}" in
        "") return 0 ;;
        -h|--help) mt_cli_help; exit 0 ;;
        --pair) mt_tg_pair "${2:-}"; exit $? ;;
        --unpair) mt_tg_unpair; exit $? ;;
        --tg-status) mt_tg_status; exit $? ;;
        --agent) mt_agent_main; exit $? ;;
        --agent-selftest) echo agent-ok; exit 0 ;;
        *) echo "Неизвестный параметр: $1" >&2; mt_cli_help >&2; exit 2 ;;
    esac
}
mt_cli_dispatch "$@"

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
    # Конец ввода (stdin закрыт, не терминал) — выходим, а не крутим меню вечно.
    read -r choice || { [[ "${MT_PROMO_BELOW:-0}" == "1" ]] && printf '\033[J'; echo; exit 0; }
    trap - INT
    # Блок спонсора висит ниже строки ввода — стираем его до низа экрана,
    # иначе вывод теста ляжет прямо поверх букв.
    [[ "${MT_PROMO_BELOW:-0}" == "1" ]] && printf '\033[J'

    case "$choice" in
        1)  run_ip_region; pause_prompt ;;
        2)  run_censorcheck_geoblock; pause_prompt ;;
        3)  run_censorcheck_dpi; pause_prompt ;;
        4)  run_censorcheck_tlab; pause_prompt ;;
        5)  recommend_bbr_cake; run_iperf3_ru; pause_prompt ;;
        6)  recommend_bbr_cake; run_iperf3_tlab; pause_prompt ;;
        7)  recommend_bbr_cake; run_yabs; pause_prompt ;;
        8)  run_ip_check_place; pause_prompt ;;
        9)  recommend_bbr_cake; run_bench_sh; pause_prompt ;;
        10) run_ip_quality; pause_prompt ;;
        11) run_sysbench_cpu; pause_prompt ;;
        12) run_ping_map; pause_prompt ;;
        13) run_all; pause_prompt ;;
        14) show_utilities_menu ;;
        0)  echo -e "${GREEN}До свидания!${NC}"; exit 0 ;;
        *)  echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"; pause_prompt ;;
    esac
done
