#!/usr/bin/env bash
# gjc 단계 brief(P{k}.md) 구조 검증 — @goal 블록 문법 계약 (setup_phase.sh 파서와 동일 규약)
# 사용: bash research-ops/scripts/lint_spec.sh <spec.md>
#
# HARD 실패 (exit 1) — @goal 구조 계약 위반:
#   - column-0 `@goal:` 블록이 하나도 없음
#   - title·body 모두 빈 `@goal:` 블록 (내용 없는 goal)
#   - 들여쓰기된 `@goal:` (줄 맨 앞 공백/탭 뒤 @goal — 파서 미포착 유령 goal) — 해당 줄 나열
#   - goal 제목 중복 (setup_phase.sh 매핑표가 깨짐)
# SOFT 경고 (출력만, hard 없으면 exit 0) — 규약 준수 권고:
#   - `### EVIDENCE` 규약 언급 없음 (P2+ EVIDENCE 스키마)
#   - 제목에 'HUMAN' 포함인데 'human_blocked' 언급 없음 (게이트 정지 규약)
#
# 판정 기준: @goal 구조 체크(파서 계약)는 절대 완화하지 않는다.
set -uo pipefail

SPEC="${1:?usage: lint_spec.sh <spec.md>}"
[ -f "$SPEC" ] || { echo "FAIL: 파일 없음 — $SPEC"; exit 1; }

hard=0
soft=0
herr(){ echo "HARD FAIL: $1"; hard=1; }
swarn(){ echo "WARN: $1"; soft=1; }

# ---- column-0 @goal: 블록 존재 여부 (setup_phase.sh 와 동일 앵커: ^@goal:) ----
goal_count="$(grep -cP '^@goal:' "$SPEC" || true)"
if [ "${goal_count:-0}" -eq 0 ]; then
  herr "column-0 '@goal:' 블록이 하나도 없음 (gjc 파서가 읽을 마일스톤 없음)"
fi

# ---- 들여쓰기된 @goal: (줄 맨 앞 공백/탭 뒤 @goal — 파서 미포착 유령 goal) ----
# 주의: 백틱 안 인라인 언급('이 문서의 `@goal:` ...')처럼 앞에 비공백이 오는 경우는 대상 아님.
indented="$(grep -nP '^[[:space:]]+@goal:' "$SPEC" || true)"
if [ -n "$indented" ]; then
  herr "들여쓰기된 '@goal:' 발견 (column-0 아님 — 파서가 못 잡음). 해당 줄:"
  printf '%s\n' "$indented" | sed 's/^/    /'
fi

# ---- 각 column-0 @goal 블록의 title/body 검사 (awk: setup_phase.sh 와 동일 블록 분리) ----
BLOCKS="$(mktemp)"
TITLES="$(mktemp)"
trap 'rm -f "$BLOCKS" "$TITLES"' EXIT

if [ "${goal_count:-0}" -gt 0 ]; then
  awk '
    function flush(){
      if (started){
        printf "TITLE\t%s\n", title
        printf "BODYLEN\t%d\n", bodylen
      }
    }
    /^@goal:/ {
      flush()
      started=1
      line=$0
      title=line
      sub(/^@goal:[[:space:]]*/, "", title)                 # "@goal:" 접두 제거
      sub(/^M[0-9]+[[:space:]]*[—-]+[[:space:]]*/, "", title) # 선택적 "M<n> —" 제거
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", title)         # 좌우 공백 정리
      bodylen=0
      next
    }
    started==1 {
      t=$0
      gsub(/[[:space:]]/, "", t)
      bodylen += length(t)
    }
    END { flush() }
  ' "$SPEC" > "$BLOCKS"

  idx=0
  cur_title=""
  while IFS=$'\t' read -r kind val; do
    case "$kind" in
      TITLE)
        idx=$((idx+1))
        cur_title="$val"
        printf '%s\n' "$cur_title" >> "$TITLES"
        ;;
      BODYLEN)
        tlen="$(printf '%s' "$cur_title" | tr -d '[:space:]' | wc -c | tr -d ' ')"
        if [ "$tlen" -eq 0 ] && [ "${val:-0}" -eq 0 ]; then
          herr "빈 @goal 블록 (#$idx): 제목·본문 모두 비어 있음"
        fi
        ;;
    esac
  done < "$BLOCKS"

  # ---- 제목 중복 ----
  dups="$(sed '/^$/d' "$TITLES" | sort | uniq -d || true)"
  if [ -n "$dups" ]; then
    herr "중복 goal 제목 (매핑표 충돌):"
    printf '%s\n' "$dups" | sed 's/^/    /'
  fi
fi

# ---- SOFT: EVIDENCE 규약 언급 ----
if ! grep -qi '### EVIDENCE' "$SPEC"; then
  swarn "'### EVIDENCE' 규약 언급 없음 (P2+ EVIDENCE 스키마 — primary+guard 증거 계약 권고)"
fi

# ---- SOFT: 제목에 HUMAN 있는데 human_blocked 언급 없음 ----
if grep -qP '^@goal:.*HUMAN' "$SPEC"; then
  if ! grep -qi 'human_blocked' "$SPEC"; then
    swarn "제목에 'HUMAN' goal 이 있으나 'human_blocked' 언급 없음 (게이트 정지 규약 미명시)"
  fi
fi

# ---- 판정 ----
if [ "$hard" -ne 0 ]; then
  echo "RESULT: FAIL — @goal 구조 계약 위반 (위 HARD FAIL 항목 수정 필요)"
  exit 1
fi
if [ "$soft" -ne 0 ]; then
  echo "OK(경고 있음): $SPEC — 구조 계약 통과, 위 WARN 규약 권고 확인"
else
  echo "OK: $SPEC — @goal 구조 계약 통과"
fi
exit 0
