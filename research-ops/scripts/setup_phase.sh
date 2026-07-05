#!/usr/bin/env bash
# research-ops — Phase dev 이슈 자동 생성 + 매핑표 backfill (수동 backfill 제거)
#
# P{k}.md 의 `@goal: M<n> — <제목>` 블록을 파싱해서:
#   - 블록별 dev 이슈 생성  (제목 "[P{k}-M{n}] <goal 제목>", 본문 = 블록 내용 + PROTOCOL footer,
#                            라벨 state:ready,type:dev,phase:P{k} — 블록에 "HUMAN GATE" 있으면 type:gate 추가,
#                            해당 phase의 GitHub milestone 연결)
#   - 생성된 이슈 번호·URL 수집
#   - P{k}.md 끝의 "## Goal ↔ Issue Map" 표를 자동 생성/갱신
#   - git add/commit (기본), --push 로 push
#
# 사용법:
#   bash setup_phase.sh [--dry-run] [--push] PHASE PATH_TO_Pk.md
#   예: bash setup_phase.sh P1 ../DGCC/P1.md
#   OWNER/CODE_REPO 는 환경변수 또는 인자로. 기본 jiminc77/DGCC.
#
# 전제: gh CLI 인증. P{k}.md 는 git 저장소 안에 있어야 커밋됨.
set -euo pipefail

DRY_RUN=0
DO_PUSH=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --push)    DO_PUSH=1; shift ;;
    *) echo "알 수 없는 플래그: $1" >&2; exit 2 ;;
  esac
done

PHASE="${1:?PHASE 필요 (예: P1)}"
SPEC="${2:?P{k}.md 경로 필요}"
OWNER="${OWNER:-jiminc77}"
CODE_REPO="${CODE_REPO:-DGCC}"
CODE="$OWNER/$CODE_REPO"

[[ -f "$SPEC" ]] || { echo "STOP: 명세 파일 없음: $SPEC" >&2; exit 1; }
command -v gh >/dev/null || { echo "STOP: gh CLI 없음" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "STOP: gh 미인증" >&2; exit 1; }

PNUM="${PHASE#P}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---- phase milestone number 조회 (제목이 "P{k} — ..." 로 시작) ----
MILE_NUM="$(gh api "repos/$CODE/milestones?state=all&per_page=100" \
  -q ".[] | select(.title|startswith(\"${PHASE} \") or startswith(\"${PHASE}—\")) | .number" 2>/dev/null | head -1 || true)"
if [[ -z "$MILE_NUM" ]]; then
  echo "  !! 경고: '${PHASE} —' milestone 없음 — milestone 연결 생략 (bootstrap_project.sh 먼저 권장)" >&2
fi

# ---- @goal 블록 파싱 (awk) : 각 M<n> 블록을 개별 파일로 분리 ----
# 블록 시작: 라인이 '@goal: M<n>' 으로 시작. 다음 @goal 또는 EOF 전까지가 본문.
awk -v dir="$WORKDIR" '
  /^@goal:[[:space:]]*M[0-9]+/ {
    if (n!="") close(f)
    # M 번호 추출
    match($0, /M[0-9]+/); mnum=substr($0,RSTART+1,RLENGTH-1)
    # 제목: "— " 뒤 (없으면 "@goal:" 뒤 전체)
    title=$0
    sub(/^@goal:[[:space:]]*M[0-9]+[[:space:]]*[—-]*[[:space:]]*/, "", title)
    n=mnum
    f=dir "/m" mnum ".body"
    t=dir "/m" mnum ".title"
    print title > t; close(t)
    print $0 > f
    next
  }
  n!="" { print >> f }
' "$SPEC"

shopt -s nullglob
BODIES=( "$WORKDIR"/m*.body )
if [[ ${#BODIES[@]} -eq 0 ]]; then
  echo "STOP: '$SPEC' 에서 @goal: M<n> 블록을 찾지 못함" >&2
  exit 1
fi

# 숫자순 정렬
IFS=$'\n' BODIES=( $(printf '%s\n' "${BODIES[@]}" | sort -t/ -k99 -V) ); unset IFS

declare -a MAP_M MAP_NUM MAP_URL
echo "== dev 이슈 생성: $CODE ($PHASE) =="
for body in "${BODIES[@]}"; do
  base="$(basename "$body" .body)"      # mN
  mnum="${base#m}"
  title_file="$WORKDIR/${base}.title"
  goal_title="$(cat "$title_file" 2>/dev/null || echo "M${mnum}")"
  [[ -z "$goal_title" ]] && goal_title="M${mnum}"
  issue_title="[${PHASE}-M${mnum}] ${goal_title}"

  # HUMAN GATE 포함 여부 → type:gate 추가
  labels="state:ready,type:dev,phase:${PHASE}"
  if grep -qi "HUMAN GATE" "$body"; then
    labels="${labels},type:gate"
  fi

  # 본문 = @goal 블록 + PROTOCOL footer
  body_file="$WORKDIR/${base}.full"
  {
    cat "$body"
    cat <<'FOOTER'

---
<!-- research-ops PROTOCOL footer -->
**PROTOCOL.md 준수**: 착수 시 `state:running`. 진행은 `### PROGRESS` 댓글 편집(≥4h).
게이트는 `### GATE REQUEST` + `state:blocked-human`. 완료는 `### EVIDENCE`(primary+guard) 후
CI VERIFIED ✅ 까지 대기 → close. guard 이상치면 primary PASS여도 `state:blocked-human`.
FOOTER
  } > "$body_file"

  # milestone 연결 인자
  mile_args=()
  [[ -n "$MILE_NUM" ]] && mile_args=(--milestone "$MILE_NUM")

  if [[ "$DRY_RUN" == 1 ]]; then
    echo "  [dry-run] gh issue create -R $CODE -t '$issue_title' -l '$labels' ${mile_args[*]:-} (본문 $(wc -l <"$body_file") 줄)"
    url="https://github.com/$CODE/issues/DRYRUN-M${mnum}"
    num="?"
  else
    # gh issue create 는 milestone 을 제목으로 받는다 → number 대신 제목 사용
    mtitle_args=()
    if [[ -n "$MILE_NUM" ]]; then
      mtitle="$(gh api "repos/$CODE/milestones/$MILE_NUM" -q '.title' 2>/dev/null || true)"
      [[ -n "$mtitle" ]] && mtitle_args=(--milestone "$mtitle")
    fi
    url="$(gh issue create -R "$CODE" \
            --title "$issue_title" \
            --body-file "$body_file" \
            --label "$labels" \
            "${mtitle_args[@]}" 2>/dev/null)" \
      || { echo "  !! 이슈 생성 실패: $issue_title" >&2; continue; }
    num="${url##*/}"
    echo "  ✓ #$num  $issue_title"
  fi
  MAP_M+=("M${mnum}"); MAP_NUM+=("$num"); MAP_URL+=("$url")
  sleep 1
done

# ---- P{k}.md 의 "## Goal ↔ Issue Map" 표 자동 생성/갱신 ----
MAP_BLOCK="$WORKDIR/map.md"
{
  echo "## Goal ↔ Issue Map"
  echo ""
  echo "> setup_phase.sh 자동 생성 ($(date -u +%Y-%m-%dT%H:%MZ))"
  echo ""
  echo "| Goal | Issue | URL |"
  echo "|---|---|---|"
  for i in "${!MAP_M[@]}"; do
    echo "| ${MAP_M[$i]} | #${MAP_NUM[$i]} | ${MAP_URL[$i]} |"
  done
} > "$MAP_BLOCK"

if [[ "$DRY_RUN" == 1 ]]; then
  echo "== [dry-run] 매핑표 미리보기 =="
  cat "$MAP_BLOCK"
else
  # 기존 "## Goal ↔ Issue Map" 섹션 제거 후 파일 끝에 재추가 (awk: 헤더부터 EOF 또는 다음 '## ' 전까지 삭제)
  TMP="$WORKDIR/spec.new"
  awk '
    BEGIN{skip=0}
    /^## Goal ↔ Issue Map[[:space:]]*$/ {skip=1; next}
    skip==1 && /^## / {skip=0}
    skip==0 {print}
  ' "$SPEC" > "$TMP"
  # 끝 공백 정리 후 매핑표 append
  printf '%s\n\n' "$(cat "$TMP")" > "$SPEC"
  cat "$MAP_BLOCK" >> "$SPEC"
  echo "  ✓ 매핑표 갱신: $SPEC"

  # ---- git commit (기본) ----
  REPO_ROOT="$(git -C "$(dirname "$SPEC")" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$REPO_ROOT" ]]; then
    ( cd "$REPO_ROOT"
      git add "$SPEC"
      if git diff --cached --quiet; then
        echo "  = 변경 없음, 커밋 생략"
      else
        git commit -m "${PHASE}: setup_phase — dev 이슈 매핑표 자동 갱신" >/dev/null
        echo "  ✓ commit: ${PHASE} 매핑표"
        if [[ "$DO_PUSH" == 1 ]]; then
          git push && echo "  ✓ push 완료" || echo "  !! push 실패" >&2
        else
          echo "  (push 하려면 --push)"
        fi
      fi
    )
  else
    echo "  !! git 저장소 아님 — 커밋 생략 ($SPEC)" >&2
  fi
fi

echo "== 완료 =="
echo "다음: 대시보드에서 $PHASE 진행 확인 (bash scripts/status.sh), gjc 실행 위임"
