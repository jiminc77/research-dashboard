#!/usr/bin/env bash
# audit_actors.sh — 이슈 코멘트의 계정 계약 감사 (PROTOCOL §2 '계정 계약').
#
# 사용: audit_actors.sh <owner/repo> <issue_no> [human_login] [agent_login]
#   기본값: human=jiminc77, agent=jiminc77-agent (projects/<slug>/project.yml 의
#   human_login/agent_login 과 맞출 것).
#
# 하드 규칙 (위반 시 exit 1):
#   - 첫 줄 `### GATE VERDICT` 또는 구계약 `## HUMAN ...`  → author 는 human_login 이어야 함
#   - 첫 줄 `### GATE REQUEST`                              → author 는 agent_login 이어야 함
# 소프트 신호 (경고만): 에이전트 보고류 어휘(사실 보고/kickoff/ACK/EVIDENCE/PROGRESS/체크포인트)가
#   human_login 명의로 게시된 경우 — 에이전트가 사람 토큰으로 도는 징후.
# 마지막에 author 별 코멘트 분포를 출력한다 (전부 한 계정이면 그 자체가 신호).
#
# bash 3.2(macOS) 호환 — 연관 배열/GNU 전용 옵션 사용 금지.
set -euo pipefail

REPO="${1:?usage: audit_actors.sh <owner/repo> <issue_no> [human_login] [agent_login]}"
N="${2:?issue number}"
HUMAN="${3:-jiminc77}"
AGENT="${4:-jiminc77-agent}"

command -v gh >/dev/null || { echo "STOP: gh CLI 없음" >&2; exit 1; }
command -v jq >/dev/null || { echo "STOP: jq 없음" >&2; exit 1; }

AGENTISH='(사실 보고|착수 보고|kickoff|ACK —|EVIDENCE|PROGRESS|체크포인트|실측 갱신)'

tmp_authors="$(mktemp)"
trap 'rm -f "$tmp_authors"' EXIT

viol=0; soft=0; total=0
while IFS=$'\t' read -r author first; do
  total=$((total+1))
  printf '%s\n' "$author" >> "$tmp_authors"
  first="${first%$'\r'}"
  want=""
  case "$first" in
    "### GATE VERDICT"*|"## HUMAN"*) want="$HUMAN" ;;
    "### GATE REQUEST"*)             want="$AGENT" ;;
  esac
  if [ -n "$want" ] && [ "$author" != "$want" ]; then
    echo "VIOLATION: author=@$author (기대 @$want) — ${first:0:60}"
    viol=$((viol+1))
  fi
  if [ -z "$want" ] && [ "$author" = "$HUMAN" ] \
     && printf '%s' "$first" | grep -qE "$AGENTISH"; then
    echo "WARN(soft): 에이전트 보고류가 사람 계정 명의 — @$author: ${first:0:60}"
    soft=$((soft+1))
  fi
done < <(gh api "repos/$REPO/issues/$N/comments" --paginate \
           -q '.[] | [.user.login, ((.body // "") | split("\n")[0])] | @tsv')

echo "---"
echo "코멘트 $total 개 · author 분포:"
sort "$tmp_authors" | uniq -c | awk '{printf "  @%s: %s\n", $2, $1}'
echo "하드 위반 $viol 건 · 소프트 경고 $soft 건 (기대: human=@$HUMAN, agent=@$AGENT)"
[ "$viol" -eq 0 ]
