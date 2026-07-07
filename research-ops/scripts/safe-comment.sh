#!/usr/bin/env bash
# safe-comment.sh — 에이전트 측 코멘트 게시 래퍼 (defense-in-depth).
#
# 목적: 프롬프트 인젝션/오작동으로 에이전트가 실수로 (또는 악의적 입력에 의해)
#   ### GATE REQUEST / ### GATE VERDICT 마커를 담은 코멘트를 게시하는 것을 차단한다.
#   게이트 계약(PROTOCOL.md §2)에서 REQUEST/VERDICT는 특권 신호이므로, 에이전트가
#   임의 텍스트에 이 마커를 넣어 게이트 상태기계를 오도하지 못하게 한다.
#   (P2 스펙이 에이전트 코멘트 경로에서 본 래퍼 사용을 의무화할 예정.)
#
# 사용법:  safe-comment.sh <repo> <issue_no> <body-file-or-->
#   <body-file-or-->  파일 경로, 또는 '-' 이면 stdin에서 본문을 읽는다.
#
# 규칙:
#   - 본문의 ANY 라인이 `^[[:space:]]*###[[:space:]]+GATE[[:space:]]+(VERDICT|REQUEST)`
#     에 매치하면 거부 (exit 2, stderr 메시지). 인용/인라인이 아니라 라인 단위로 방어한다.
#   - 단, 환경변수 GATE_REQUEST_ALLOWED=1 이면 통과 — 에이전트가 "정당하게" 게이트
#     요청을 게시할 때만 명시적으로 이 플래그를 켠다 (VERDICT는 사람 전용이므로 이
#     플래그로도 열어주지 않는 것이 이상적이나, 정책 결정은 호출 측에 맡긴다).
#   - 통과 시 `gh issue comment -R <repo> <issue_no> --body-file <...>` 로 위임한다.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: safe-comment.sh <repo> <issue_no> <body-file-or-->" >&2
  exit 64
fi

REPO="$1"
ISSUE_NO="$2"
BODY_SRC="$3"

# 본문 로드 → 임시 파일 (stdin '-' 지원, gh --body-file 에 넘기기 위함).
tmp_body="$(mktemp)"
trap 'rm -f "$tmp_body"' EXIT
if [ "$BODY_SRC" = "-" ]; then
  cat > "$tmp_body"
else
  if [ ! -r "$BODY_SRC" ]; then
    echo "safe-comment: body file not readable: $BODY_SRC" >&2
    exit 66
  fi
  cat "$BODY_SRC" > "$tmp_body"
fi

# 방어: 어떤 라인이든 게이트 마커면 차단 (GATE_REQUEST_ALLOWED=1 로만 우회).
if [ "${GATE_REQUEST_ALLOWED:-0}" != "1" ]; then
  # CRLF 정규화 후 라인 단위 매치.
  if sed -e 's/\r$//' "$tmp_body" \
       | grep -qE '^[[:space:]]*###[[:space:]]+GATE[[:space:]]+(VERDICT|REQUEST)'; then
    echo "safe-comment: REFUSED — body contains a '### GATE VERDICT/REQUEST' marker." >&2
    echo "  Gate markers are privileged (PROTOCOL.md §2). If this is a legitimate gate" >&2
    echo "  REQUEST, re-run with GATE_REQUEST_ALLOWED=1. VERDICT is human-only." >&2
    exit 2
  fi
fi

exec gh issue comment -R "$REPO" "$ISSUE_NO" --body-file "$tmp_body"
