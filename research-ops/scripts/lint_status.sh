#!/usr/bin/env bash
# 대시보드 status.json 스키마 검증 — plan HTML 오버레이·대시보드가 읽는 계약
# 사용: bash research-ops/scripts/lint_status.sh <status.json>
#
# jq 검증:
#   .project              — 문자열
#   .phases               — object, 각 값의 .state ∈ {done,current,next,backlog,blocked}
#   .decisions            — array, 각 원소는 {issue, title, url} 보유
# 하나라도 위반 시 FAIL.
set -uo pipefail

F="${1:?usage: lint_status.sh <status.json>}"
[ -f "$F" ] || { echo "FAIL: 파일 없음 — $F"; exit 1; }
command -v jq >/dev/null || { echo "FAIL: jq 없음 (설치 필요)"; exit 1; }

# JSON 파싱 가능 여부
if ! jq -e . "$F" >/dev/null 2>&1; then
  echo "FAIL: JSON 파싱 실패 — $F"
  exit 1
fi

fail=0
err(){ echo "FAIL: $1"; fail=1; }

# .project 문자열
jq -e '(.project | type) == "string"' "$F" >/dev/null 2>&1 \
  || err ".project 가 문자열이 아님"

# .phases object
jq -e '(.phases | type) == "object"' "$F" >/dev/null 2>&1 \
  || err ".phases 가 object 가 아님"

# 모든 phase 값의 .state ∈ 허용 집합
if jq -e '(.phases | type) == "object"' "$F" >/dev/null 2>&1; then
  bad_states="$(jq -r '
    .phases
    | to_entries[]
    | select((.value.state // "") as $s
             | ([ "done","current","next","backlog","blocked" ] | index($s)) | not)
    | "\(.key)=\(.value.state // "<없음>")"
  ' "$F" 2>/dev/null || true)"
  if [ -n "$bad_states" ]; then
    err ".phases 값 중 .state 가 [done,current,next,backlog,blocked] 밖: $bad_states"
  fi
fi

# .decisions array of {issue,title,url}
jq -e '(.decisions | type) == "array"' "$F" >/dev/null 2>&1 \
  || err ".decisions 가 array 가 아님"

if jq -e '(.decisions | type) == "array"' "$F" >/dev/null 2>&1; then
  bad_dec="$(jq -r '
    .decisions
    | to_entries[]
    | select((.value | has("issue") and has("title") and has("url")) | not)
    | "index \(.key)"
  ' "$F" 2>/dev/null || true)"
  if [ -n "$bad_dec" ]; then
    err ".decisions 원소 중 {issue,title,url} 미보유: $bad_dec"
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: $F — status 스키마 통과"
  exit 0
else
  echo "RESULT: FAIL — status.json 스키마 위반"
  exit 1
fi
