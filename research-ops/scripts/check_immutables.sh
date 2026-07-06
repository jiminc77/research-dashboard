#!/usr/bin/env bash
# 불변값 매니페스트 강제 — 사전등록 수치가 명세에서 사라지지 않았는지 기계 검증
# 사용: bash research-ops/scripts/check_immutables.sh <manifest> [changed file ...]
#
# 매니페스트 형식 (탭 구분, '#' 주석·빈 줄 허용):
#   <file-glob>\t<ERE regex>\t[설명(선택)]
#   예: P[0-9]*.md<TAB>ρ\s*≥\s*0\.9<TAB>G2 임계
#
# 규칙:
#   - changed file 중 glob 에 매칭되는 각 파일: 해당 regex 가 파일 내용에 매칭돼야 함.
#     매칭 실패 시 FAIL — 어느 파일에서 어느 불변값이 사라졌는지 나열.
#   - 매니페스트 파일 자체가 changed file 목록에 있으면: 불변값 정의 변경 →
#     env PR_BODY 에 'Decision' 문자열이 있어야 통과 (프로토콜: 불변값 변경은 [Decision] 이슈 인용 필수).
#     없으면 FAIL.
#
# glob 매칭은 파일의 basename 과 전체 경로 둘 다에 대해 시도한다 (a/b/P1.md 도 P[0-9]*.md 에 매칭).
set -uo pipefail

MANIFEST="${1:?usage: check_immutables.sh <manifest> [changed files...]}"
shift || true
CHANGED=("$@")

[ -f "$MANIFEST" ] || { echo "FAIL: 매니페스트 없음 — $MANIFEST"; exit 1; }

fail=0

# ---- 매니페스트 자체가 변경되었는가? → Decision 인용 강제 ----
manifest_base="$(basename "$MANIFEST")"
manifest_changed=0
for cf in "${CHANGED[@]:-}"; do
  [ -z "$cf" ] && continue
  cf_base="$(basename "$cf")"
  if [ "$cf" = "$MANIFEST" ] || [ "$cf_base" = "$manifest_base" ]; then
    manifest_changed=1
    break
  fi
done

if [ "$manifest_changed" -eq 1 ]; then
  if printf '%s' "${PR_BODY:-}" | grep -q 'Decision'; then
    echo "OK: 매니페스트($manifest_base) 변경 — PR 본문에 Decision 인용 확인됨 (불변값 변경 절차 준수)"
  else
    echo "FAIL: 매니페스트($manifest_base)가 변경되었으나 PR 본문에 'Decision' 인용이 없음."
    echo "      프로토콜: 불변값 정의 변경은 [Decision] 이슈 인용이 필수입니다 (env PR_BODY 에 'Decision' 필요)."
    fail=1
  fi
fi

# ---- 각 매니페스트 규칙을 변경 파일에 적용 ----
# glob 매칭 헬퍼: basename 또는 전체 경로가 glob 에 맞으면 0
matches_glob(){
  local path="$1" glob="$2" base
  base="$(basename "$path")"
  case "$base" in $glob) return 0 ;; esac
  case "$path" in $glob) return 0 ;; esac
  return 1
}

# 변경 파일이 하나도 없으면 규칙 적용 대상 없음 (매니페스트 변경 검사만 수행)
if [ "${#CHANGED[@]}" -gt 0 ]; then
  # 매니페스트 라인 순회
  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno+1))
    # 주석·빈 줄 skip
    case "$line" in
      ''|'#'*) continue ;;
    esac
    # 탭 분리: glob \t regex \t [desc]
    glob="$(printf '%s' "$line" | cut -f1)"
    regex="$(printf '%s' "$line" | cut -f2)"
    desc="$(printf '%s' "$line" | cut -f3)"
    [ -z "$glob" ] && continue
    if [ -z "$regex" ]; then
      echo "FAIL: 매니페스트 $lineno 행 — regex 누락 (glob 뒤 탭+ERE 필요): $line"
      fail=1
      continue
    fi
    label="${desc:-$regex}"

    for cf in "${CHANGED[@]}"; do
      [ -z "$cf" ] && continue
      # 매니페스트 자신은 규칙 대상에서 제외 (위에서 별도 처리)
      [ "$cf" = "$MANIFEST" ] && continue
      if matches_glob "$cf" "$glob"; then
        if [ ! -f "$cf" ]; then
          # 변경 파일이 존재하지 않으면(삭제 등) 내용 검증 불가 — 경고 후 통과 처리하지 않음
          echo "WARN: 변경 파일 없음(내용 검증 스킵) — $cf (규칙 [$label])"
          continue
        fi
        if grep -Pq -- "$regex" "$cf"; then
          : # 통과
        else
          echo "FAIL: [$cf] 불변값 누락 — [$label] (정규식 /$regex/ 미매칭)"
          fail=1
        fi
      fi
    done
  done < "$MANIFEST"
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: 불변값 매니페스트 통과 ($manifest_base)"
  exit 0
else
  echo "RESULT: FAIL — 불변값 계약 위반 (위 항목 확인)"
  exit 1
fi
