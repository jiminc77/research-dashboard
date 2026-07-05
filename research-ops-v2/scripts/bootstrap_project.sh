#!/usr/bin/env bash
# research-ops v2 — 프로젝트 부트스트랩
# 라벨(양 레포) + CODE_REPO phase별 GitHub milestone 을 멱등 생성한다.
#
# 사용법:
#   bash bootstrap_project.sh [--labels-only] [--dry-run] \
#        OWNER MGMT_REPO CODE_REPO PROJECT "P0:환경파일럿,P1:베이스라인,P2:제안기법,..."
# 예:
#   bash bootstrap_project.sh jiminc77 research-dashboard DGCC DGCC "P0:환경파일럿,P1:베이스라인"
#   bash bootstrap_project.sh --labels-only jiminc77 research-dashboard DGCC DGCC "P0:...,P1:..."
#
# 전제: gh CLI 인증 (gh auth login). fine-grained PAT면 두 레포 Contents RW + Issues RW.
set -euo pipefail

LABELS_ONLY=0
DRY_RUN=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --labels-only) LABELS_ONLY=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    *) echo "알 수 없는 플래그: $1" >&2; exit 2 ;;
  esac
done

OWNER="${1:?OWNER 필요}"
MGMT_REPO="${2:?MGMT_REPO 필요}"
CODE_REPO="${3:?CODE_REPO 필요}"
PROJECT="${4:?PROJECT 필요}"
PHASES_CSV="${5:?PHASES 필요 (예: \"P0:환경파일럿,P1:베이스라인\")}"

MGMT="$OWNER/$MGMT_REPO"
CODE="$OWNER/$CODE_REPO"

command -v gh >/dev/null || { echo "STOP: gh CLI 없음" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "STOP: gh 미인증 — gh auth login" >&2; exit 1; }

run() { # dry-run 지원 래퍼
  if [[ "$DRY_RUN" == 1 ]]; then echo "  [dry-run] $*"; else "$@"; fi
}

# gh label create --force 는 존재 시 갱신(멱등). 실패해도 부트스트랩 계속.
mklabel() { # repo name color desc
  local repo="$1" name="$2" color="$3" desc="$4"
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "  [dry-run] gh label create '$name' -R $repo --color $color --description '$desc' --force"
  else
    gh label create "$name" -R "$repo" --color "$color" --description "$desc" --force \
      >/dev/null 2>&1 || echo "  !! 라벨 실패(무시): $repo $name" >&2
    echo "  ✓ $repo  $name"
  fi
}

# ---- 라벨 정의 (양 레포 공통) ----
create_all_labels() {
  local repo="$1"
  echo "== 라벨 생성: $repo =="
  # state 상태기계 (dev 이슈는 항상 정확히 1개)
  mklabel "$repo" "state:ready"          "cccccc" "착수 대기"
  mklabel "$repo" "state:running"        "1d76db" "gjc 구현 중"
  mklabel "$repo" "state:verify"         "8250df" "EVIDENCE 게시, CI 검증 대기"
  mklabel "$repo" "state:done"           "0e8a16" "CI VERIFIED 후 완료"
  mklabel "$repo" "state:blocked-human"  "d73a4a" "HUMAN GATE 대기"
  mklabel "$repo" "state:blocked-tech"   "d93f0b" "기술 블로커/3-strike/CI 실패"
  # type
  mklabel "$repo" "type:dev"       "0052cc" "개발 작업 이슈"
  mklabel "$repo" "type:gate"      "b60205" "HUMAN GATE 이슈"
  mklabel "$repo" "type:decision"  "5319e7" "방향 전환 기록(사후 기준 변경 포함)"
  mklabel "$repo" "type:milestone" "006b75" "단계 milestone 이슈"
  # phase P0..P7
  local p
  for p in 0 1 2 3 4 5 6 7; do
    mklabel "$repo" "phase:P${p}" "fbca04" "단계 P${p}"
  done
  # proj (공용 MGMT 구분)
  mklabel "$repo" "proj:${PROJECT}" "c5def5" "프로젝트 ${PROJECT}"
}

create_all_labels "$MGMT"
create_all_labels "$CODE"

# ---- GitHub 네이티브 milestone (CODE_REPO, phase별) ----
create_milestones() {
  echo "== CODE_REPO milestone 생성: $CODE =="
  # 기존 milestone 제목 목록 (멱등: 있으면 건너뜀)
  local existing
  existing="$(gh api "repos/$CODE/milestones?state=all&per_page=100" -q '.[].title' 2>/dev/null || true)"
  local IFS=','
  for entry in $PHASES_CSV; do
    local code="${entry%%:*}" name="${entry#*:}"
    local title="${code} — ${name}"
    if grep -Fxq "$title" <<<"$existing"; then
      echo "  = 이미 있음: $title"
      continue
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
      echo "  [dry-run] gh api repos/$CODE/milestones -f title='$title' -f state=open"
    else
      gh api "repos/$CODE/milestones" -f title="$title" -f state=open >/dev/null \
        && echo "  ✓ milestone: $title" \
        || echo "  !! milestone 실패(무시): $title" >&2
    fi
  done
}

if [[ "$LABELS_ONLY" == 1 ]]; then
  echo "== --labels-only: milestone 생성 생략 (비파괴) =="
else
  create_milestones
fi

# ---- next steps ----
cat <<EOF

== 완료 ==
다음 단계:
  1) CODE repo에 워크플로 커밋:
       cp workflows/*.yml <local>/.github/workflows/ && git add -A && git commit -m "ci: research-ops v2" && git push
  2) ntfy 토픽 구독(폰 앱) 후 secret 등록:
       gh secret set NTFY_TOPIC -R $CODE      # 값 = 추측 불가능한 토픽명 (URL 노출 주의)
  3) MGMT repo에 dashboard/index.html 커밋 → Settings > Pages 활성화
       (dashboard/index.html CONFIG.projects 에 이 프로젝트 추가)
  4) 명세 작성 후 phase별 dev 이슈:
       bash scripts/setup_phase.sh P0 <local>/P0.md
  5) 상태 조회:
       bash scripts/status.sh $OWNER $CODE_REPO $MGMT_REPO
EOF
