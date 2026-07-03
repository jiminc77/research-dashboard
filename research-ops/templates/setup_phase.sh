#!/usr/bin/env bash
# 새 Phase의 GitHub 이슈 생성 스크립트 (재사용 템플릿)
# 사용법:
#   1) 아래 CONFIG를 이 Phase에 맞게 채운다
#   2) issue 본문 파일을 준비:  $BODYDIR/milestone.md,  $BODYDIR/m0.md, m1.md, ...
#   3) GITHUB_TOKEN=... bash setup_phase.sh
# 토큰: fine-grained PAT, 두 레포에 Contents RW + Issues RW.
set -euo pipefail
: "${GITHUB_TOKEN:?GITHUB_TOKEN 환경변수를 설정하세요}"

# ===== CONFIG (Phase마다 수정) =====
OWNER="jiminc77"
MGMT_REPO="research-dashboard"          # milestone 이슈가 들어갈 관리 레포
CODE_REPO="DGCC"                        # dev 이슈가 들어갈 코드 레포
PHASE="P1"                              # 예: P1
PHASE_TITLE="Black-box Baseline 구축"    # milestone 제목에 들어갈 이름
BODYDIR="$(cd "$(dirname "$0")" && pwd)/bodies_${PHASE}"   # 이슈 본문 파일 위치
# dev 이슈 제목 (M0..Mk 순서 — 반드시 @goal 순서와 일치)
DEV_TITLES=(
  "[${PHASE}-M0] {제목}"
  "[${PHASE}-M1] {제목}"
  # ... 필요한 만큼
)
# =====================================

API="https://api.github.com"
HDR=(-H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")

create_issue () { # $1=repo $2=title $3=bodyfile -> echo number
  jq -n --arg t "$2" --rawfile b "$3" '{title:$t, body:$b}' \
    | curl -sf "${HDR[@]}" -X POST "$API/repos/$OWNER/$1/issues" -d @- | jq -r '.number'
}

echo "== 코드 레포 dev 이슈 생성 ($CODE_REPO) =="
i=0
for title in "${DEV_TITLES[@]}"; do
  body="$BODYDIR/m${i}.md"
  [ -f "$body" ] || { echo "  !! 본문 없음: $body"; exit 1; }
  n=$(create_issue "$CODE_REPO" "$title" "$body")
  echo "  #$n <- $title"
  echo "    → P${PHASE#P}.md 매핑표에 M$i = #$n 기록"
  sleep 1; i=$((i+1))
done

echo "== 관리 레포 milestone 이슈 생성 ($MGMT_REPO) =="
m=$(create_issue "$MGMT_REPO" "[Milestone] ${PHASE} — ${PHASE_TITLE}" "$BODYDIR/milestone.md")
echo "  #$m <- [Milestone] ${PHASE} — ${PHASE_TITLE}"

echo "== 완료 =="
echo "다음: (1) P{n}.md의 Goal↔Issue 매핑표를 위 dev 번호로 갱신·push"
echo "      (2) 관리 레포 Project 보드에서 milestone #$m 을 Current로, 이전 단계는 Done"
echo "      (3) 코드 레포에서 gjc ralplan → ultragoal 실행"
