#!/usr/bin/env bash
# 새 프로젝트의 전체 Milestone(P0..Pn)을 관리 레포에 일괄 생성 (ORCHESTRATOR STEP 2)
# 사용법:
#   1) CONFIG를 채운다
#   2) 이슈 본문 준비:  $BODYDIR/p0.md, p1.md, ... (templates/issue_milestone.md 형식)
#   3) GITHUB_TOKEN=... bash bootstrap_project.sh
# 토큰: fine-grained PAT, MGMT_REPO에 Issues RW (+ 문서 push 하려면 Contents RW).
set -euo pipefail
: "${GITHUB_TOKEN:?GITHUB_TOKEN 환경변수를 설정하세요}"

# ===== CONFIG =====
OWNER="{owner}"
MGMT_REPO="research-dashboard"          # 관리/대시보드 레포
PROJECT="{PROJECT}"                      # 프로젝트 약칭 (다중 프로젝트면 제목 접두사로 사용)
PREFIX=""                                # 다중 프로젝트: "[$PROJECT] " / 단일이면 ""
BODYDIR="$(cd "$(dirname "$0")" && pwd)/milestones_${PROJECT}"
# 단계 목록: "코드|제목" (계획서에서 추출). 순서 = P0..Pn
PHASES=(
  "P0|환경·파일럿"
  "P1|Baseline 구축"
  # ... 계획서의 단계만큼
)
# =====================================

API="https://api.github.com"
HDR=(-H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")

create_issue () { # $1=title $2=bodyfile -> number
  jq -n --arg t "$1" --rawfile b "$2" '{title:$t, body:$b}' \
    | curl -sf "${HDR[@]}" -X POST "$API/repos/$OWNER/$MGMT_REPO/issues" -d @- | jq -r '.number'
}

echo "== Milestone 일괄 생성 ($MGMT_REPO / $PROJECT) =="
for entry in "${PHASES[@]}"; do
  code="${entry%%|*}"; name="${entry#*|}"
  low=$(echo "$code" | tr '[:upper:]' '[:lower:]')
  body="$BODYDIR/${low}.md"
  [ -f "$body" ] || { echo "  !! 본문 없음: $body"; exit 1; }
  n=$(create_issue "${PREFIX}[Milestone] ${code} — ${name}" "$body")
  echo "  #$n <- ${PREFIX}[Milestone] ${code} — ${name}"
  sleep 1
done

echo "== 완료 =="
echo "다음: (1) 대시보드 README/plan 문서를 이 프로젝트로 초기화 (P0=Current)"
echo "      (2) Project 보드에 milestone 추가, P0을 Current로"
echo "      (3) ORCHESTRATOR STEP 3: P0.md 작성 + setup_phase.sh 로 dev 이슈 생성"
