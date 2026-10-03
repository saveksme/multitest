#!/usr/bin/env bash
# Все тесты: bash tests/run.sh [подстрока имени]
cd "$(dirname "$0")/.." || exit 1
pass=0 fail=0 skip=0
for t in tests/test-*.sh; do
    [[ -n "${1:-}" && "$t" != *"$1"* ]] && continue
    out=$(bash "$t" 2>&1); rc=$?
    case $rc in
        0)  pass=$((pass+1)); echo "PASS  $t" ;;
        77) skip=$((skip+1)); echo "SKIP  $t — $(printf '%s\n' "$out" | grep -m1 '^SKIP')" ;;
        *)  fail=$((fail+1)); echo "FAIL  $t"; printf '%s\n' "$out" | sed 's/^/      /' ;;
    esac
done
echo; echo "пройдено: $pass · пропущено: $skip · упало: $fail"
(( fail == 0 ))
