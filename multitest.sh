#!/bin/bash

# ============================================================
#  Multitest — интерактивный скрипт диагностики сервера
# ============================================================

SCRIPT_VERSION="1.1"
REPO_URL="https://raw.githubusercontent.com/saveksme/multitest/master/multitest.sh"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================
#  Установка (--install)
# ============================================================

if [[ "$1" == "--install" ]]; then
    echo -e "${CYAN}Установка multitest...${NC}"
    INSTALL_PATH="/usr/local/bin/multitest"

    if command -v curl &>/dev/null; then
        curl -sL "$REPO_URL" -o "$INSTALL_PATH"
    elif command -v wget &>/dev/null; then
        wget -qO "$INSTALL_PATH" "$REPO_URL"
    else
        echo -e "${RED}Нужен curl или wget для установки.${NC}"
        exit 1
    fi

    chmod +x "$INSTALL_PATH"
    echo -e "${GREEN}Установлено в ${INSTALL_PATH}${NC}"
    echo -e "${GREEN}Теперь можно запускать командой: ${BOLD}multitest${NC}"
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
        apt)     apt-get update -qq && apt-get install -y -qq "$pkg" ;;
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

install_deps() {
    echo -e "${CYAN}Проверка зависимостей...${NC}"
    check_and_install curl
    check_and_install wget
    check_and_install sysbench
    echo -e "${GREEN}Все зависимости в порядке.${NC}"
    echo ""
}

# ============================================================
#  Функции тестов
# ============================================================

run_ip_region() {
    print_separator "IP Region"
    check_and_install wget
    bash <(wget -qO- https://ipregion.vrnt.xyz)
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

run_iperf3_ru() {
    print_separator "iPerf3 — тест до российских серверов"
    check_and_install wget
    bash <(wget -qO- https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh)
}

run_yabs() {
    print_separator "YABS — бенчмарк сервера"
    check_and_install curl
    curl -sL yabs.sh | bash -s -- -4
}

run_ip_check_place() {
    print_separator "IP Check Place — блокировки зарубежными сервисами"
    check_and_install curl
    bash <(curl -Ls IP.Check.Place) -l en
}

run_bench_sh() {
    print_separator "bench.sh — параметры сервера и скорость"
    check_and_install wget
    wget -qO- bench.sh | bash
}

run_ip_quality() {
    print_separator "IPQuality"
    check_and_install curl
    bash <(curl -Ls https://Check.Place) -EI
}

run_sysbench_cpu() {
    print_separator "sysbench CPU — тест процессора"
    check_and_install sysbench
    sysbench cpu run --threads=1
}

run_all() {
    print_separator "МУЛЬТИТЕСТ — запуск всех тестов"
    install_deps

    run_ip_region
    run_censorcheck_geoblock
    run_censorcheck_dpi
    run_iperf3_ru
    run_yabs
    run_ip_check_place
    run_bench_sh
    run_ip_quality
    run_sysbench_cpu

    echo ""
    echo -e "${GREEN}${BOLD}Все тесты завершены!${NC}"
}

# ============================================================
#  Утилиты
# ============================================================

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

    # Записываем параметры в sysctl
    cat > /etc/sysctl.d/99-bbr-cake.conf <<EOF
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl -p /etc/sysctl.d/99-bbr-cake.conf

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
    cat > /etc/sysctl.d/99-disable-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF

    sysctl -p /etc/sysctl.d/99-disable-ipv6.conf

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

show_utilities_menu() {
    while true; do
        print_header
        echo -e "  ${CYAN}${BOLD}── Утилиты ──${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC}  Включить BBR + Cake"
        echo -e "  ${GREEN}2)${NC}  Выключить IPv6"
        echo ""
        echo -e "  ${RED}0)${NC}  Назад"
        echo ""
        echo -ne "  ${BOLD}Выберите пункт [0-2]: ${NC}"
        read -r util_choice

        case "$util_choice" in
            1) enable_bbr_cake; pause_prompt ;;
            2) disable_ipv6; pause_prompt ;;
            0) return ;;
            *) echo -e "${RED}Неверный выбор.${NC}"; pause_prompt ;;
        esac
    done
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
    echo -e "  ${GREEN} 4)${NC}  iPerf3 — тест до российских серверов"
    echo -e "  ${GREEN} 5)${NC}  YABS — бенчмарк сервера"
    echo -e "  ${GREEN} 6)${NC}  IP Check Place — блокировки зарубежными сервисами"
    echo -e "  ${GREEN} 7)${NC}  bench.sh — параметры сервера и скорость"
    echo -e "  ${GREEN} 8)${NC}  IPQuality"
    echo -e "  ${GREEN} 9)${NC}  sysbench CPU — тест процессора"
    echo ""
    echo -e "  ${YELLOW}10)${NC}  ${BOLD}Мультитест — запуск всех тестов${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}── Утилиты ──${NC}"
    echo ""
    echo -e "  ${GREEN}11)${NC}  Утилиты (BBR, IPv6...)"
    echo ""
    echo -e "  ${RED} 0)${NC}  Выход"
    echo ""
    echo -ne "  ${BOLD}Выберите пункт [0-11]: ${NC}"
}

# ============================================================
#  Главный цикл
# ============================================================

while true; do
    show_menu
    read -r choice

    case "$choice" in
        1)  run_ip_region; pause_prompt ;;
        2)  run_censorcheck_geoblock; pause_prompt ;;
        3)  run_censorcheck_dpi; pause_prompt ;;
        4)  run_iperf3_ru; pause_prompt ;;
        5)  run_yabs; pause_prompt ;;
        6)  run_ip_check_place; pause_prompt ;;
        7)  run_bench_sh; pause_prompt ;;
        8)  run_ip_quality; pause_prompt ;;
        9)  run_sysbench_cpu; pause_prompt ;;
        10) run_all; pause_prompt ;;
        11) show_utilities_menu ;;
        0)  echo -e "${GREEN}До свидания!${NC}"; exit 0 ;;
        *)  echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"; pause_prompt ;;
    esac
done
