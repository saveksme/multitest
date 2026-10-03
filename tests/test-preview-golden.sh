#!/usr/bin/env bash
# Страницы .preview/gen.sh побайтно совпадают с ревизией MT_GOLDEN_REF (по умолчанию HEAD):
# ловит регрессии рендера от рефакторинга до коммита. Дата приколочена.
. "$(dirname "$0")/lib.sh"
t_need git sha256sum
ref="${MT_GOLDEN_REF:-HEAD}"
git -C "$T_ROOT" cat-file -e "$ref:multitest.sh" 2>/dev/null || { echo "SKIP: нет ревизии $ref"; exit 77; }
mkdir -p "$T_W/base/.preview"
git -C "$T_ROOT" show "$ref:multitest.sh"    > "$T_W/base/multitest.sh"
git -C "$T_ROOT" show "$ref:.preview/gen.sh" > "$T_W/base/.preview/gen.sh"
date() { printf '2026-01-02 03:04\n'; }; export -f date
export LC_ALL=C.UTF-8
bash "$T_W/base/.preview/gen.sh" >/dev/null 2>&1
bash "$T_ROOT/.preview/gen.sh"   >/dev/null 2>&1
sums() { (cd "$1" && sha256sum ./*.svg | sort -k2); }
sums "$T_W/base/.preview/out" > "$T_W/base.sum"
sums "$T_ROOT/.preview/out"   > "$T_W/cur.sum"
check "страниц столько же"       '[ "$(wc -l < "$T_W/base.sum")" = "$(wc -l < "$T_W/cur.sum")" ] && [ -s "$T_W/cur.sum" ]'
check "страницы побайтно равны"  'diff -q "$T_W/base.sum" "$T_W/cur.sum" >/dev/null'
t_finish
