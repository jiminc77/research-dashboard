#!/usr/bin/env bash
# research-ops — gpt-pro 자문용 컨텍스트 번들러
#
# 강한 추론 모델(gpt-pro 등)에 붙여넣을 단일 마크다운을 /tmp/pro_bundle.md 로 만든다.
# 편의 도구다(치명 인프라 아님). 공개 데이터만 git/curl로 모은다 — 인증 불필요.
# (origin 원격에 토큰이 박혀 있으면 그대로 활용, 없어도 공개 레포면 동작.)
#
# 사용법:
#   make_pro_bundle.sh phase-spec P<next>       [project=dgcc]   # 다음 단계 명세 초안용
#   make_pro_bundle.sh gate       <ISSUE_NUM>   [project=dgcc]   # HUMAN GATE 자문용
#
# 예:
#   bash research-ops/scripts/make_pro_bundle.sh phase-spec P2 dgcc
#   bash research-ops/scripts/make_pro_bundle.sh gate 42 dgcc
#
# 산출: /tmp/pro_bundle.md (경로를 stdout 마지막 줄에 출력). 이 파일을 열어 모델에 붙여넣는다.
# 규칙: 이 번들은 "참고 입력"이다. 정본은 세션 A의 규약 검증(파서·임계 불변·lint) + issue 코멘트로만 확정된다.
set -uo pipefail

MODE="${1:-}"
ARG="${2:-}"
PROJECT="${3:-dgcc}"
OUT="/tmp/pro_bundle.md"

[ -n "$MODE" ] && [ -n "$ARG" ] || {
  echo "usage: make_pro_bundle.sh <phase-spec P_next | gate ISSUE_NUM> [project=dgcc]" >&2; exit 2; }

# --- 리포 루트 탐색 (스크립트 위치 기준) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCS="$ROOT/projects/$PROJECT"
TPL="$ROOT/research-ops/templates"

# --- project.yml 에서 code_repo / owner 파악 (없으면 기본값) ---
YML="$DOCS/project.yml"
owner="jiminc77"; code_repo="DGCC"; mgmt_repo="research-dashboard"
if [ -f "$YML" ]; then
  v(){ grep -E "^$1:" "$YML" | head -1 | sed -E 's/^[^:]+:[[:space:]]*"?([^"#]*)"?.*/\1/' | tr -d '[:space:]'; }
  [ -n "$(v owner)" ]     && owner="$(v owner)"
  [ -n "$(v code_repo)" ] && code_repo="$(v code_repo)"
  [ -n "$(v mgmt_repo)" ] && mgmt_repo="$(v mgmt_repo)"
fi
RAW="https://raw.githubusercontent.com/$owner/$code_repo/main"
API="https://api.github.com"

# --- curl 헬퍼: origin 토큰이 있으면 인증 붙이고, 없으면 무인증 (레이트리밋 관대 처리) ---
TOKEN=""
if git -C "$ROOT" remote get-url origin >/dev/null 2>&1; then
  TOKEN="$(git -C "$ROOT" remote get-url origin 2>/dev/null | sed -nE 's|https://[^:]*:([^@]+)@.*|\1|p')"
fi
gh_get(){ # $1=url  → body to stdout (실패/레이트리밋이면 빈 출력 + stderr 경고)
  local url="$1" hdr=(-s -w '\n%{http_code}')
  [ -n "$TOKEN" ] && hdr+=(-H "Authorization: token $TOKEN")
  local resp code body
  resp="$(curl "${hdr[@]}" "$url" 2>/dev/null)"; code="${resp##*$'\n'}"; body="${resp%$'\n'*}"
  if [ "$code" = "200" ]; then printf '%s' "$body"; return 0; fi
  if [ "$code" = "403" ]; then echo "  (경고: GitHub API rate-limit/403 — $url 생략)" >&2; return 1; fi
  echo "  (경고: $url → HTTP $code, 생략)" >&2; return 1
}
raw_get(){ curl -fsSL "$1" 2>/dev/null || { echo "  (경고: raw 없음 — $1)" >&2; return 1; }; }

sec(){ printf '\n\n---\n\n## %s\n\n' "$1" >>"$OUT"; }
note(){ printf '%s\n' "$1" >>"$OUT"; }
emb(){ # $1=제목 $2=본문(파일경로 or -). 코드펜스로 감싼다.
  printf '\n> **%s**\n\n```\n' "$1" >>"$OUT"
  if [ "$2" = "-" ]; then cat >>"$OUT"; else cat "$2" >>"$OUT" 2>/dev/null || echo "(내용 없음)" >>"$OUT"; fi
  printf '\n```\n' >>"$OUT"
}

# --- 헤더 ---
: >"$OUT"
{
  echo "# gpt-pro 자문 번들 — project=$PROJECT · mode=$MODE · arg=$ARG"
  echo ""
  echo "생성: $(date -u +%Y-%m-%dT%H:%MZ) · code_repo=$owner/$code_repo · mgmt_repo=$owner/$mgmt_repo"
  echo ""
  echo "> **역할 프롬프트는 이 번들 맨 끝의 템플릿을 따른다.** 이 번들은 자문용 참고 입력이다."
  echo "> 정본(canonical)은 세션 A의 규약 검증(파서·임계 불변·lint) 후 **커밋/issue 코멘트로만** 확정된다."
} >>"$OUT"

# ================= MODE: phase-spec =================
if [ "$MODE" = "phase-spec" ]; then
  PN="$ARG"                         # 예: P2
  K="${PN#P}"                        # 숫자
  PREV="P$(( K>0 ? K-1 : 0 ))"

  sec "연구 계획서 (사전등록 · 정본 배경)"
  PLAN_MD="$(ls "$DOCS"/research/*_research_plan.md 2>/dev/null | head -1)"
  if [ -n "$PLAN_MD" ]; then note "출처: \`projects/$PROJECT/research/$(basename "$PLAN_MD")\`"; emb "research_plan.md" "$PLAN_MD"
  else note "(계획서 md 없음 — projects/$PROJECT/research/ 확인)"; fi

  sec "이전 단계($PREV) 리포트 / 게이트 기록"
  PREV_MD="$(ls "$DOCS"/reports/${PREV}*.md 2>/dev/null | head -1)"
  if [ -n "$PREV_MD" ]; then note "출처: \`projects/$PROJECT/reports/$(basename "$PREV_MD")\`"; emb "${PREV} report/gate (md)" "$PREV_MD"
  else note "(${PREV} md 리포트 없음 — HTML 회고나 CODE 레포 outputs 확인)"; fi

  sec "CODE 레포 최신 단계 명세 ${PN}.md (raw)"
  note "raw: $RAW/${PN}.md"
  if SPEC="$(raw_get "$RAW/${PN}.md")"; then printf '%s' "$SPEC" | emb "${PN}.md (CODE repo)" -
  else note "(${PN}.md 아직 없음 — 이 초안이 그 첫 버전이 된다)"; fi

  sec "STEP_LOG.md tail 100 (raw)"
  if LOG="$(raw_get "$RAW/STEP_LOG.md")"; then printf '%s\n' "$LOG" | tail -100 | emb "STEP_LOG.md (tail 100)" -
  else note "(STEP_LOG.md raw 접근 불가)"; fi

  sec "승계 리스크 (inherited risks — 채워 넣을 것)"
  note "아래는 이전 단계 리포트의 '승계 리스크 & 미해결' 섹션에서 옮겨온다. 초안은 이 표를 근거로 리스크 완화를 명세에 반영해야 한다."
  note ""
  note "| # | 승계 리스크 | 출처($PREV) | $PN에서의 처리 |"
  note "|---|---|---|---|"
  note "| 1 | (리포트 risks 섹션에서 발췌) | | |"

  sec "요구 출력 형식 — 프롬프트 템플릿 (그대로 지시로 사용)"
  emb "pro_phase_spec_prompt.md" "$TPL/pro_phase_spec_prompt.md"

# ================= MODE: gate =================
elif [ "$MODE" = "gate" ]; then
  ISSUE="$ARG"

  sec "게이트 이슈 #$ISSUE (CODE 레포 — 제목/본문)"
  note "출처: $owner/$code_repo issue #$ISSUE"
  if J="$(gh_get "$API/repos/$owner/$code_repo/issues/$ISSUE")"; then
    printf '%s' "$J" > /tmp/_pro_issue.json
    python3 - /tmp/_pro_issue.json <<'PY' >>"$OUT" 2>/dev/null || echo "(이슈 파싱 실패)" >>"$OUT"
import sys, json
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(f"\n### #{d.get('number')} — {d.get('title','')}\n")
print("labels:", ", ".join(l["name"] for l in d.get("labels", [])), "· state:", d.get("state"))
print("\n" + (d.get("body") or "(본문 없음)"))
PY
  else note "(이슈 본문 접근 불가 — rate-limit 또는 비공개)"; fi

  sec "게이트 이슈 코멘트 (GATE REQUEST / EVIDENCE 등)"
  if C="$(gh_get "$API/repos/$owner/$code_repo/issues/$ISSUE/comments?per_page=100")"; then
    printf '%s' "$C" > /tmp/_pro_comments.json
    python3 - /tmp/_pro_comments.json <<'PY' >>"$OUT" 2>/dev/null || echo "(코멘트 파싱 실패)" >>"$OUT"
import sys, json
for c in json.load(open(sys.argv[1], encoding="utf-8")):
    print(f"\n--- @{c['user']['login']} · {c['created_at']} ---\n")
    print(c.get("body") or "")
PY
  else note "(코멘트 접근 불가)"; fi

  sec "사전등록 기준 — 해당 P{k}.md 의 Exit/전역 규칙 (raw)"
  note "게이트가 속한 단계의 P{k}.md 를 지정해 사전등록 임계·primary/guard·옵션 정의를 그대로 인용한다."
  note "CODE 레포 raw 예: $RAW/P{k}.md  (실제 파일명으로 curl 후 §전역 규칙·@goal Exit 발췌)"
  note ""
  note "> 참조 지표 파일: 이슈 본문/EVIDENCE가 가리키는 outputs/{metrics,reports} 경로를 여기에 나열하고, 필요한 수치는 $RAW/<path> 로 가져온다."

  sec "요구 출력 형식 — 프롬프트 템플릿 (그대로 지시로 사용)"
  emb "pro_gate_advisor_prompt.md" "$TPL/pro_gate_advisor_prompt.md"

else
  echo "unknown mode: $MODE (phase-spec | gate)" >&2; exit 2
fi

echo ""
echo "번들 완성 → $OUT"
echo "$OUT"
