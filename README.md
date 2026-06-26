# Multitest

Интерактивный bash-скрипт для диагностики и тестирования Linux-серверов. Объединяет популярные инструменты проверки в одном меню.

## Быстрый старт

**Запуск без установки:**

```bash
bash <(curl -sL https://raw.githubusercontent.com/saveksme/multitest/master/multitest.sh)
```

**Установка как команда `multitest`:**

```bash
curl -sL https://raw.githubusercontent.com/saveksme/multitest/master/multitest.sh -o /usr/local/bin/multitest && chmod +x /usr/local/bin/multitest && echo "Установлено! Запуск: multitest"
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
| 4 | Censorcheck (tlab) | Проверка блокировок через censorcheck.tlab.pw |
| 5 | iPerf3 (РФ) | Тест скорости до российских iPerf3 серверов |
| 6 | iPerf3 (РФ, tlab) | iPerf3-тест до РФ провайдеров через bench.tlab.pw |
| 7 | YABS | Бенчмарк сервера (диск, сеть, CPU) |
| 8 | IP Check Place | Проверка IP на блокировки зарубежными сервисами |
| 9 | bench.sh | Параметры сервера и скорость к зарубежным провайдерам |
| 10 | IPQuality | Проверка качества IP-адреса |
| 11 | sysbench CPU | Тест процессора (1 поток) |
| 12 | **Мультитест** | Выбор и последовательный запуск тестов (Enter = все) |

### Мультитест и сводка-картинка

При выборе **Мультитеста** можно отметить, какие тесты запускать (номера через пробел/запятую,
диапазоны вида `4-7`, либо Enter — все). Во время прогона каждый тест стартует автоматически через
5 секунд; `Ctrl+C` пропускает текущий, `s` — пропуск, `q` — выход.

По завершении формируется **сводка-картинка** в стиле Material You (Material Design 3) и заливается
на файлообменник — в консоль выводится прямая ссылка. На карточке:

- шапка с хостом, IP, гео и «пончиком» прогресса (выполнено / пропущено / ошибки);
- блок характеристик сервера (CPU, RAM, диск, ОС, ядро, virt, ASN, BBR/qdisc, uptime, load);
- по карточке на каждый тест со **всеми** распознанными метриками (чипы) и построчным списком
  сервисов — рядом с каждым сервисом его **логотип** (Netflix, Spotify, YouTube, ChatGPT и т.д.;
  логотипы Simple Icons встроены в скрипт, для остальных — монограмма);
- невыбранные тесты показаны отдельной приглушённой карточкой «не запускался», пропущенные и
  упавшие — со своим статусом.

Рендер: `rsvg-convert` (или ImageMagick как запасной вариант) — устанавливается автоматически.

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
- [censorcheck.tlab.pw](https://censorcheck.tlab.pw) — проверка блокировок (tlab)
- [russian-iperf3-servers](https://github.com/itdoginfo/russian-iperf3-servers) — iPerf3 серверы в РФ
- [bench.tlab.pw](https://bench.tlab.pw) — альтернативные iPerf3 серверы в РФ
- [YABS](https://yabs.sh) — Yet Another Bench Script
- [IP.Check.Place](https://ip.check.place) — проверка блокировок IP
- [bench.sh](https://bench.sh) — бенчмарк сервера
- [Check.Place](https://check.place) — IPQuality
- [sysbench](https://github.com/akopytov/sysbench) — тест CPU
