#!/usr/bin/env bash
# Подпись релиза: рядом с multitest.sh кладётся multitest.sh.sig (base64 от ECDSA P-256 DER).
# Агент проверяет её зашитым открытым ключом ДО запуска скачанного кода, поэтому без подписи
# обновление не поедет вовсе — это и есть защита от подмены кода в репозитории.
#
#   MT_RELEASE_KEY_FILE=~/.ssh/multitest_release bash sign-release.sh
#
# Ключ создаётся один раз и сервера не касается:
#   openssl ecparam -name prime256v1 -genkey -noout -out ~/.ssh/multitest_release
#   chmod 600 ~/.ssh/multitest_release
# Открытую часть вшивают в MT_RELEASE_KEY внутри multitest.sh:
#   openssl pkey -in ~/.ssh/multitest_release -pubout -outform DER | base64 -w0
# Приватный ключ держите офлайн-копией: потеря — новый ключ и новый релиз, утечка — чужие
# подписи релизов. Подписывать нужно ПОСЛЕ последней правки скрипта и до коммита: подпись
# считается по байтам файла, любое изменение после неё делает подпись недействительной.
set -euo pipefail
cd "$(dirname "$0")"

key="${MT_RELEASE_KEY_FILE:?задайте MT_RELEASE_KEY_FILE=<приватный ключ EC P-256>}"
[[ -s "$key" ]] || { echo "Нет ключа: $key" >&2; exit 1; }
[[ -s multitest.sh ]] || { echo "Нет multitest.sh" >&2; exit 1; }
bash -n multitest.sh || { echo "multitest.sh не проходит bash -n — сначала почините синтаксис." >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
openssl dgst -sha256 -sign "$key" -out "$tmp/sig.der" multitest.sh
openssl base64 -A -in "$tmp/sig.der" -out multitest.sh.sig

# Проверяем тем же путём, каким это сделает агент: открытая часть из ключа, DER, sha256.
openssl pkey -in "$key" -pubout -outform DER 2>/dev/null | base64 -w0 > "$tmp/pub.b64"
openssl base64 -d -A -in "$tmp/pub.b64" > "$tmp/pub.der"
openssl pkey -pubin -inform DER -in "$tmp/pub.der" -out "$tmp/pub.pem" 2>/dev/null
openssl dgst -sha256 -verify "$tmp/pub.pem" -signature "$tmp/sig.der" multitest.sh >/dev/null

pinned=$(sed -nE 's/^MT_RELEASE_KEY="\$\{MT_RELEASE_KEY:-([^}]+)\}"$/\1/p' multitest.sh)
[[ "$pinned" == "$(cat "$tmp/pub.b64")" ]] \
    || { echo "ВНИМАНИЕ: ключ в MT_RELEASE_KEY не совпадает с этим приватным ключом." >&2; exit 1; }

printf 'Подписано: multitest.sh.sig · ключ совпадает с зашитым в скрипт\n'