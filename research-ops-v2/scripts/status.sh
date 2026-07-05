#!/usr/bin/env bash
# research-ops v2 — 한 방 상태 조회 (터미널)
# 라벨 상태기계를 색상으로 요약: blocked-human(경과+6h강조) / blocked-tech / running(4h stale) / verify /
#                                phase별 done·total / MGMT Current milestone.
#
# 사용법: bash status.sh [OWNER] [CODE_REPO] [MGMT_REPO]
#   인자 생략 시 환경변수 OWNER/CODE_REPO/MGMT_REPO, 그것도 없으면 기본값.
set -euo pipefail

OWNER="${1:-${OWNER:-jiminc77}}"
CODE_REPO="${2:-${CODE_REPO:-DGCC}}"
MGMT_REPO="${3:-${MGMT_REPO:-research-dashboard}}"
CODE="$OWNER/$CODE_REPO"
MGMT="$OWNER/$MGMT_REPO"

command -v gh >/dev/null || { echo "STOP: gh CLI 없음" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "STOP: gh 미인증" >&2; exit 1; }

# ---- 색상 (tput, 비대화형이면 무색) ----
if [[ -t 1 ]] && command -v tput >/dev/null && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  RED=$(tput setaf 1); GRN=$(tput setaf 2); YEL=$(tput setaf 3)
  BLU=$(tput setaf 4); MAG=$(tput setaf 5); DIM=$(tput dim); BOLD=$(tput bold); RST=$(tput sgr0)
else
  RED=""; GRN=""; YEL=""; BLU=""; MAG=""; DIM=""; BOLD=""; RST=""
fi

now=$(date -u +%s)
# ISO8601(UTC) → epoch (GNU date / BSD date 양쪽)
to_epoch() {
  local ts="$1"
  date -u -d "$ts" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo "$now"
}
hours_since() { # $1=iso -> 정수 시간
  local e; e=$(to_epoch "$1"); echo $(( (now - e) / 3600 ))
}

section() { echo; echo "${BOLD}$1${RST}"; }

# ---- 공통: 라벨별 이슈 나열 ----
# gh issue list --json 으로 number/title/updatedAt/url
list_label() { gh issue list -R "$CODE" --state open --label "$1" \
  --json number,title,updatedAt,url -q '.[] | [.number, .updatedAt, .url, .title] | @tsv' 2>/dev/null || true; }

echo "${BOLD}== research-ops status :: $CODE ==${RST}  ${DIM}($(date -u +%Y-%m-%dT%H:%MZ))${RST}"

# 🔴 blocked-human
section "🔴 blocked-human (HUMAN GATE 대기)"
found=0
while IFS=$'\t' read -r n upd url title; do
  [[ -z "$n" ]] && continue
  found=1; h=$(hours_since "$upd")
  if (( h >= 6 )); then
    printf "  ${RED}${BOLD}#%s  %sh 경과 ⚠️${RST}  %s\n     %s\n" "$n" "$h" "$title" "$url"
  else
    printf "  ${RED}#%s  %sh${RST}  %s\n     %s\n" "$n" "$h" "$title" "$url"
  fi
done < <(list_label "state:blocked-human")
[[ "$found" == 0 ]] && echo "  ${DIM}없음${RST}"

# 🟠 blocked-tech
section "🟠 blocked-tech (기술 블로커)"
found=0
while IFS=$'\t' read -r n upd url title; do
  [[ -z "$n" ]] && continue; found=1; h=$(hours_since "$upd")
  printf "  ${YEL}#%s  %sh${RST}  %s\n     %s\n" "$n" "$h" "$title" "$url"
done < <(list_label "state:blocked-tech")
[[ "$found" == 0 ]] && echo "  ${DIM}없음${RST}"

# 🔵 running (4h+ stale)
section "🔵 running (구현 중)"
found=0
while IFS=$'\t' read -r n upd url title; do
  [[ -z "$n" ]] && continue; found=1; h=$(hours_since "$upd")
  if (( h >= 4 )); then
    printf "  ${BLU}#%s${RST}  ${YEL}%sh — stale${RST}  %s\n" "$n" "$h" "$title"
  else
    printf "  ${BLU}#%s  %sh${RST}  %s\n" "$n" "$h" "$title"
  fi
done < <(list_label "state:running")
[[ "$found" == 0 ]] && echo "  ${DIM}없음${RST}"

# 🟣 verify
section "🟣 verify (CI 검증 대기)"
found=0
while IFS=$'\t' read -r n upd url title; do
  [[ -z "$n" ]] && continue; found=1; h=$(hours_since "$upd")
  printf "  ${MAG}#%s  %sh${RST}  %s\n" "$n" "$h" "$title"
done < <(list_label "state:verify")
[[ "$found" == 0 ]] && echo "  ${DIM}없음${RST}"

# phase별 done/total
section "📊 phase별 진행 (done / total)"
for p in 0 1 2 3 4 5 6 7; do
  total=$(gh issue list -R "$CODE" --state all --label "phase:P${p}" --json number -q 'length' 2>/dev/null || echo 0)
  [[ "$total" -eq 0 ]] && continue
  done=$(gh issue list -R "$CODE" --state all --label "phase:P${p},state:done" --json number -q 'length' 2>/dev/null || echo 0)
  # done 라벨이 없을 수 있으니 closed 도 보조 집계
  closed=$(gh issue list -R "$CODE" --state closed --label "phase:P${p}" --json number -q 'length' 2>/dev/null || echo 0)
  (( done < closed )) && done=$closed
  bar_n=$(( total>0 ? done*20/total : 0 ))
  bar=$(printf '%*s' "$bar_n" '' | tr ' ' '#')$(printf '%*s' $((20-bar_n)) '' | tr ' ' '.')
  if (( done == total )); then col="$GRN"; else col="$BLU"; fi
  printf "  P%s  ${col}[%s]${RST}  %s/%s\n" "$p" "$bar" "$done" "$total"
done

# MGMT Current milestone (type:milestone 이슈 중 제목/본문에 Current 표시 또는 열린 것)
section "🎯 MGMT Current"
gh issue list -R "$MGMT" --state open --label "type:milestone" \
  --json number,title -q '.[] | "  #\(.number)  \(.title)"' 2>/dev/null | head -5 \
  || echo "  ${DIM}(type:milestone 이슈 없음)${RST}"

echo
echo "${DIM}상세: gh issue view <num> -R $CODE  |  대시보드: dashboard/index.html${RST}"
