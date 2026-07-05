#!/usr/bin/env bash
# 단계 리포트 HTML 기계 검증 — templates/phase_report_guide.md 계약 준수 확인
# 사용: bash research-ops/scripts/lint_report.sh docs/reports/P1_report.html
set -uo pipefail
f="${1:?usage: lint_report.sh <report.html>}"
[ -f "$f" ] || { echo "FAIL: 파일 없음 — $f"; exit 1; }
fail=0
err(){ echo "FAIL: $1"; fail=1; }
grep -qi '<html[^>]*lang=' "$f" || err 'lang 속성 없음 (<html lang="ko">)'
grep -q '</html>' "$f" || err '</html> 종료 없음'
for id in summary goals gates constants risks artifacts; do
  grep -q "id=\"$id\"" "$f" || err "필수 섹션 id=\"$id\" 없음"
done
grep -Eq 'GO|NO-GO|PARTIAL' "$f" || err '최종 판정 배지(GO/NO-GO/PARTIAL) 없음'
BANNED='비전문가|비전공자|일반 ?독자|일반인|누구나 (이해|알)|쉽게 (말해|설명|풀어)|입문자|초보자|하시면 됩니다|이 리포트는 .{0,20}(위해|목적)'
if grep -nE "$BANNED" "$f"; then err '어투 계약 위반 — 위 라인의 청중 언급/안내체 제거 (내용만 서술)'; fi
if grep -nE '<script[^>]+src=' "$f"; then err '외부 스크립트 금지 (self-contained)'; fi
if [ "$fail" -eq 0 ]; then echo "OK: $f — 리포트 계약 통과"; else exit 1; fi
