# Multitest

Интерактивный bash-скрипт для диагностики и тестирования Linux-серверов. Объединяет популярные инструменты проверки в одном меню.

## Быстрый старт

**Запуск без установки:**

```bash
bash <(curl -sL https://raw.githubusercontent.com/Mrzalupa-lolz/multitest/refs/heads/master/multitest.sh)
```

**Установка как команда `multitest`:**

```bash
curl -sL https://raw.githubusercontent.com/Mrzalupa-lolz/multitest/refs/heads/master/multitest.sh -o /usr/local/bin/multitest && chmod +x /usr/local/bin/multitest && echo "Установлено! Запуск: multitest"
```

После установки скрипт доступен из любого места:

```bash
multitest
```

## Меню

### Тесты

| # | Название | Описание |
|---|----------|----------|
| 1 | IP Region | Определение региона IP-адреса сервера |
| 2 | Censorcheck (геоблок) | Проверка геоблокировок |
| 3 | Censorcheck (DPI) | Проверка DPI для серверов в РФ |
| 4 | iPerf3 (РФ) | Тест скорости до российских iPerf3 серверов |
| 5 | YABS | Бенчмарк сервера (диск, сеть, CPU) |
| 6 | IP Check Place | Проверка IP на блокировки зарубежными сервисами |
| 7 | bench.sh | Параметры сервера и скорость к зарубежным провайдерам |
| 8 | IPQuality | Проверка качества IP-адреса |
| 9 | sysbench CPU | Тест процессора (1 поток) |
| 10 | **Мультитест** | Запуск всех тестов последовательно |

### Утилиты

| # | Название | Описание |
|---|----------|----------|
| 1 | BBR + Cake | Включение TCP BBR congestion control и Cake qdisc |
| 2 | Выключить IPv6 | Отключение IPv6 через sysctl |

## Зависимости

Скрипт автоматически установит недостающие пакеты:

- `curl`
- `wget`
- `sysbench`

Поддерживаемые пакетные менеджеры: `apt`, `dnf`, `yum`, `apk`, `pacman`.

## Требования

- Linux (Debian/Ubuntu, CentOS/RHEL, Fedora, Alpine, Arch)
- Права root (для установки пакетов и утилит)
- Bash 4+

## Используемые проекты

- [ipregion](https://ipregion.vrnt.xyz) — определение региона IP
- [censorcheck](https://github.com/vernette/censorcheck) — проверка цензуры и DPI
- [russian-iperf3-servers](https://github.com/itdoginfo/russian-iperf3-servers) — iPerf3 серверы в РФ
- [YABS](https://yabs.sh) — Yet Another Bench Script
- [IP.Check.Place](https://ip.check.place) — проверка блокировок IP
- [bench.sh](https://bench.sh) — бенчмарк сервера
- [Check.Place](https://check.place) — IPQuality
- [sysbench](https://github.com/akopytov/sysbench) — тест CPU
