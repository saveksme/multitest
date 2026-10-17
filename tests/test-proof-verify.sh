#!/usr/bin/env bash
# multitest --verify: подпись записи Multitest — вшитым открытым ключом и openssl (ECDSA P-256).
. "$(dirname "$0")/lib.sh"
t_need openssl
MULTITEST_TEST=1 source "$T_ROOT/multitest.sh" ""
t_fake_curl
cd "$T_W" || exit 1

openssl ecparam -name prime256v1 -genkey -noout -out key.pem 2>/dev/null
PUB=$(openssl ec -in key.pem -pubout -outform DER 2>/dev/null | openssl base64 -A)
MT_PROOF_KEYS="t1 $PUB"
T=$'\t'
{
    printf 'multitest-proof 1\nid%s7K2Q9XWAPD3M\ncode%sMT-7K2Q-9XWA-PD3M\nkid%st1\n' "$T" "$T" "$T"
    printf 'start%s2026-10-14T17:46:40Z\nfinish%s2026-10-14T18:03:20Z\nlaunch%sbot\n' "$T" "$T" "$T"
    printf 'ip4%s185.10.*.*%sAS64496 Example Hosting B.V.%sNL%s2026-10\nip6%s-%s-%s-%s-\n' "$T" "$T" "$T" "$T" "$T" "$T" "$T" "$T"
    printf 'test%s2%sip_region%sok%s-%s2026-10-14T17:48:20Z%sNL · 26/30%sff\n' "$T" "$T" "$T" "$T" "$T" "$T" "$T"
} > rec.txt
openssl dgst -sha256 -sign key.pem -out sig.der rec.txt
signed() { cat rec.txt; printf 'signature%st1%s%s\n' "$T" "$T" "$(openssl base64 -A -in sig.der)"; }
signed > good.txt

mt_verify good.txt > out 2>&1; rc=$?
check "файл: подпись верна"                 '[ $rc = 0 ] && grep -qF "Подпись верна" out'
check "файл: код, адрес, тест — из записи"   'grep -qF "MT-7K2Q-9XWA-PD3M" out && grep -qF "185.10.*.* · AS64496 Example Hosting B.V. · NL" out && grep -qF "Тест ip_region: ok · NL · 26/30" out'
sed 's/26\/30/30\/30/' good.txt > bad.txt
mt_verify bad.txt > out 2>&1; rc=$?
check "правка цифры — НЕВЕРНА"               '[ $rc = 1 ] && grep -qF "НЕВЕРНА" out'
sed 's/$/\r/' good.txt > crlf.txt
check "CRLF из редактора — верна"            'mt_verify crlf.txt >/dev/null 2>&1'
MT_PROOF_KEYS="t2 $PUB" mt_verify good.txt > out 2>&1; rc=$?
check "незнакомый ключ — не верна"          '[ $rc = 1 ] && grep -qF "Незнакомый ключ t1" out'
MT_PROOF_KEYS="t1 $PUB 2026-01-01" mt_verify good.txt > out 2>&1; rc=$?
check "отозванный ключ — не верна"          '[ $rc = 1 ] && grep -qF "отозван" out'
MT_PROOF_KEYS="t1 $PUB 2027-01-01" mt_verify good.txt > out 2>&1; rc=$?
check "запись до отзыва — верна"            '[ $rc = 0 ]'
printf 'signature\tt1\tAAAA\n' > junk.txt
check "мусор — не верна"                     '! mt_verify junk.txt >/dev/null 2>&1'

# по коду: запись — у бота, без ключа сервера
t_respond 200 "$(signed)"
mt_verify mt-7k2q-9xwa-pd3m > out 2>&1; rc=$?
check "код: скачано и верно"                 '[ $rc = 0 ] && grep -qx "https://mtbot.sixseven.cam/v1/proof/7K2Q9XWAPD3M.txt" "$T_W/curl/argv.1"'
check "код: без ключа сервера"               '! grep -qF -- "-K" "$T_W/curl/argv.1" && [ ! -e "$T_W/curl/stdin.1" ]'
t_respond 404 "err not_found"
mt_verify MT-0000-0000-0000 > out 2>&1; rc=$?
check "код не найден"                        '[ $rc = 1 ] && grep -qF "не найдена" out'
mt_verify "MT-12" > out 2>&1; rc=$?
check "кривой код — подсказка"               '[ $rc = 2 ]'
t_finish
