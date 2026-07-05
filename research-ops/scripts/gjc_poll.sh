#!/usr/bin/env bash
# research-ops — gjc 자동 기상 폴러 (워크스테이션 cron용, API 키 불필요)
#
# 동작: state:ready 이슈가 있고 · state:running 이슈가 없고 · gjc 프로세스가 없으면 → gjc 를 깨운다.
#
# 설치 (예: 5분마다):
#   crontab -e
#   */5 * * * * OWNER=jiminc77 CODE_REPO={CODE_REPO} WORKDIR=$HOME/work/{CODE_REPO} \
#     GJC_CMD='gjc ultragoal resume' bash $HOME/research-ops/scripts/gjc_poll.sh >> $HOME/gjc_poll.log 2>&1
#
#   GJC_CMD 는 각자 실행 방식대로 (예: 'gjc ralplan --auto', 'gjc ultragoal resume').
#   전제: 이 머신에 gh 로그인 되어 있음 (gjc가 쓰는 그 인증).
set -euo pipefail

OWNER="${OWNER:-}"
CODE_REPO="${CODE_REPO:-}"
WORKDIR="${WORKDIR:-.}"
GJC_CMD="${GJC_CMD:-}"
GJC_PATTERN="${GJC_PATTERN:-gjc}"   # 실행 중 감지용 pgrep 패턴

if [ -z "$OWNER" ] || [ -z "$CODE_REPO" ] || [ -z "$GJC_CMD" ]; then
  echo "필요: OWNER, CODE_REPO, GJC_CMD 환경변수"; exit 2
fi

# 중복 실행 방지
LOCK="/tmp/gjc_poll.${CODE_REPO}.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

command -v gh >/dev/null || { echo "gh CLI 없음"; exit 1; }
R="$OWNER/$CODE_REPO"

ready=$(gh issue list -R "$R" --label state:ready --state open --json number --jq length)
running=$(gh issue list -R "$R" --label state:running --state open --json number --jq length)
blocked=$(gh issue list -R "$R" --label state:blocked-human --state open --json number --jq length)
echo "$(date -u +%FT%TZ) ready=$ready running=$running blocked-human=$blocked"

[ "$ready" -eq 0 ] && exit 0                      # 할 일 없음
[ "$running" -gt 0 ] && exit 0                    # 이미 작업 중 (라벨 기준)
pgrep -f "$GJC_PATTERN" >/dev/null && exit 0      # gjc 프로세스 살아있음

cd "$WORKDIR"
git pull --ff-only || echo "경고: git pull 실패 — 그대로 진행"

echo "→ gjc 기상: $GJC_CMD (ready=$ready)"
exec bash -c "$GJC_CMD"
