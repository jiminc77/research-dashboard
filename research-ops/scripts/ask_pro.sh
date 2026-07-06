#!/usr/bin/env bash
# ask_pro.sh — 고지능 자문 호출: 번들(md)을 pro급 모델에 보내고 답을 받는다.
# 두 백엔드:
#   codex (기본) : ChatGPT 구독 OAuth (Codex CLI) — 구독 포함, per-token 과금 없음.
#                  1회 로그인 필요: `codex login` (headless: `codex login --device-auth`
#                  또는 로컬 로그인 후 ~/.codex/auth.json 복사). 기본 gpt-5.5 @ xhigh.
#   api          : OpenAI API (OPENAI_API_KEY, 기본 o3-pro) — 최난도 콜 폴백. per-token 과금.
#
# 사용:
#   bash ask_pro.sh <bundle.md> [--backend codex|api] [--model M] [--out F] [--cd DIR]
# 예:
#   bash make_pro_bundle.sh gate 12 && bash ask_pro.sh /tmp/pro_bundle.md
#   bash ask_pro.sh /tmp/pro_bundle.md --backend api            # o3-pro 폴백
#
# 거버넌스: 출력은 자문/초안. 정본은 issue 코멘트(사람)와 세션 A 규약 검증 후 커밋뿐.
set -euo pipefail
BUNDLE="${1:?usage: ask_pro.sh <bundle.md> [--backend codex|api] [--model M] [--out F] [--cd DIR]}"; shift || true
BACKEND="" MODEL="" OUT="/tmp/pro_answer.md" CDDIR="$(pwd)"
while [ $# -gt 0 ]; do case "$1" in
  --backend) BACKEND="$2"; shift 2;; --model) MODEL="$2"; shift 2;;
  --out) OUT="$2"; shift 2;; --cd) CDDIR="$2"; shift 2;;
  *) echo "unknown arg: $1"; exit 2;; esac; done
[ -f "$BUNDLE" ] || { echo "FAIL: 번들 없음 — $BUNDLE"; exit 1; }
if [ -z "$BACKEND" ]; then
  if command -v codex >/dev/null && { [ -f "${CODEX_HOME:-$HOME/.codex}/auth.json" ] || codex login status >/dev/null 2>&1; }; then
    BACKEND=codex; else BACKEND=api; fi
fi
NB=$(wc -c < "$BUNDLE"); echo "bundle: $BUNDLE ($NB bytes) → backend: $BACKEND"
INSTR="아래 <stdin> 번들은 연구 레포 컨텍스트다. 도구 사용·파일 수정·셸 실행 금지 — 분석과 답변 서술만 하라. 번들 앞부분의 역할 프롬프트와 출력 형식을 따르라."

if [ "$BACKEND" = codex ]; then
  M="${MODEL:-${PRO_MODEL:-gpt-5.5}}"
  cat "$BUNDLE" | codex exec \
    --model "$M" -c model_reasoning_effort="xhigh" \
    --sandbox read-only --skip-git-repo-check --cd "$CDDIR" \
    -o "$OUT" "$INSTR" \
    && { echo "OK: $OUT (구독 · $M @ xhigh)"; exit 0; } \
    || { echo "FAIL: codex exec 실패 — 로그인(codex login) 또는 모델 게이팅 확인. --backend api 폴백 가능"; exit 1; }
fi

# --- api backend (Responses API, background 폴링) ---
: "${OPENAI_API_KEY:?OPENAI_API_KEY 필요 (api backend)}"
M="${MODEL:-${PRO_MODEL_API:-o3-pro}}"
REQ=$(jq -n --arg m "$M" --arg i "$INSTR" --rawfile b "$BUNDLE" \
  '{model:$m, background:true, reasoning:{effort:"high"}, input:[{role:"user",content:($i+"\n\n"+$b)}]}')
RESP=$(curl -sf https://api.openai.com/v1/responses -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" -d "$REQ") || { echo "FAIL: API 요청 실패"; exit 1; }
ID=$(echo "$RESP" | jq -r '.id // empty'); [ -n "$ID" ] || { echo "$RESP" | jq -r '.error.message // "unknown"'; exit 1; }
echo "response id: $ID — 폴링 (최대 30분)"
for i in $(seq 1 180); do sleep 10
  R=$(curl -sf https://api.openai.com/v1/responses/"$ID" -H "Authorization: Bearer $OPENAI_API_KEY")
  case "$(echo "$R" | jq -r .status)" in
    completed) echo "$R" | jq -r '[.output[]?|select(.type=="message")|.content[]?|select(.type=="output_text")|.text]|join("\n")' > "$OUT"
      echo "OK: $OUT — $(echo "$R" | jq -r '.usage | "in \(.input_tokens)t · out \(.output_tokens)t"') ($M, per-token 과금)"; exit 0;;
    failed|cancelled|expired) echo "FAIL: $(echo "$R" | jq -r '.error.message // .status')"; exit 1;;
  esac; [ $((i%6)) -eq 0 ] && echo "  ... $((i*10))s"; done
echo "FAIL: 타임아웃 — id=$ID"; exit 1
