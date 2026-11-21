#!/usr/bin/env bash
# Подпись релизов: скачанный скрипт исполняется как root (mt_agent_ok запускает его ради
# «проверки»), поэтому подпись обязана сходиться ДО запуска. Здесь — механизм (верная,
# подделанная, пустая, чужой ключ, нет openssl), путь загрузки и подпись самого релиза.
. "$(dirname "$0")/lib.sh"
export LC_ALL=C.UTF-8
t_need openssl
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
PINNED="$MT_RELEASE_KEY"

# Свой ключ для механизма — релизный приватный ключ в тестах не участвует
openssl ecparam -name prime256v1 -genkey -noout -out "$T_W/k.pem" 2>/dev/null
PUB=$(openssl pkey -in "$T_W/k.pem" -pubout -outform DER 2>/dev/null | base64 -w0)
printf '#!/bin/bash\necho agent-ok\n' > "$T_W/cand.sh"
openssl dgst -sha256 -sign "$T_W/k.pem" -out "$T_W/sig.der" "$T_W/cand.sh"
openssl base64 -A -in "$T_W/sig.der" -out "$T_W/sig.b64"
MT_RELEASE_KEY="$PUB"

check "подпись: верная принимается"         'mt_release_ok "$T_W/cand.sh" "$T_W/sig.b64"'
printf 'echo pwned\n' >> "$T_W/cand.sh"
check "подпись: правка файла отклонена"     '! mt_release_ok "$T_W/cand.sh" "$T_W/sig.b64"'
check "подпись: пустая отклонена"           ': > "$T_W/empty"; ! mt_release_ok "$T_W/cand.sh" "$T_W/empty"'
check "подпись: мусор отклонён"             'printf "not-a-der" > "$T_W/junk"; ! mt_release_ok "$T_W/cand.sh" "$T_W/junk"'
check "подпись: чужой ключ отклонён"        '( MT_RELEASE_KEY=AAAA; ! mt_release_ok "$T_W/cand.sh" "$T_W/sig.b64" )'
check "подпись: без openssl — отказ"        '( PATH=/nonexistent; ! mt_release_ok "$T_W/cand.sh" "$T_W/sig.b64" )'

# Загрузка из репозитория: скрипт и подпись — два запроса, подпись по точным байтам тела
t_fake_curl
REPO_URL="https://repo.test/multitest.sh"
d="$T_W/curl"
printf '#!/bin/bash\necho agent-ok\n' > "$d/resp.1.body"; printf '200' > "$d/resp.1.code"
openssl dgst -sha256 -sign "$T_W/k.pem" -out "$T_W/s2.der" "$d/resp.1.body"
openssl base64 -A -in "$T_W/s2.der" > "$d/resp.2.body"; printf '200' > "$d/resp.2.code"
got=$(mt_repo_download); rc=$?
check "загрузка: подписанный релиз принят"  '[ $rc = 0 ] && [ -s "$got" ] && cmp -s "$got" "$d/resp.1.body"'
check "загрузка: тянет и подпись"           'grep -qxF "https://repo.test/multitest.sh.sig" "$d/argv.2"'
check "загрузка: только https и без даунгрейда" 'grep -qxF -- "--proto-redir" "$d/argv.1" && grep -qxF -- "=https" "$d/argv.1"'
rm -f "$got"

# Подписи нет (второй запрос не удался) — обновление не проходит
printf '#!/bin/bash\necho agent-ok\n' > "$d/resp.3.body"; printf '200' > "$d/resp.3.code"
got=$(mt_repo_download); rc=$?
check "загрузка: без подписи отказ"         '[ $rc != 0 ] && [ -z "$got" ]'

# Подпись не от того ключа — отказ, даже если файл подписи на месте
printf '#!/bin/bash\necho agent-ok\n' > "$d/resp.5.body"; printf '200' > "$d/resp.5.code"
printf 'AAAA' > "$d/resp.6.body"; printf '200' > "$d/resp.6.code"
got=$(mt_repo_download); rc=$?
check "загрузка: чужая подпись отклонена"   '[ $rc != 0 ] && [ -z "$got" ]'

# Релиз в репозитории: подпись обязана сходиться с текущим скриптом и зашитым ключом.
# Упало — значит скрипт правили после подписи: bash sign-release.sh перед коммитом.
check "релиз: подпись лежит рядом"          '[ -s "$T_ROOT/multitest.sh.sig" ]'
check "релиз: подпись сходится со скриптом" '( MT_RELEASE_KEY="$PINNED"; mt_release_ok "$T_ROOT/multitest.sh" "$T_ROOT/multitest.sh.sig" )'
t_finish