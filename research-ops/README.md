# research-ops — 솔로 연구자용 GitHub 에이전트 워크플로우 키트

> **원칙 한 줄: 상태는 라벨로, 증거는 스키마로, 게이트는 사전등록으로, 인프라는 제로로.**

연구 프로젝트를 GitHub Issues/Actions 위에서 오케스트레이터·gjc(실행자)·사람의 역할로 굴리는 **재사용 운영 키트**. 상태는 `state:*` 라벨 상태기계로, 증거는 `### EVIDENCE` 스키마로, HUMAN GATE는 사전등록된 기준으로 관리하고, 알림·검증·대시보드는 **제로 인프라(gh CLI · GitHub Actions · ntfy.sh · 클라이언트 대시보드)**로 자동화한다.

이 키트는 이미 배포되어 운영 중이다: 워크플로 2개는 CODE repo(`jiminc77/DGCC`)의 `.github/workflows/`에서, 라이브 대시보드는 MGMT repo(`jiminc77/research-dashboard`)의 GitHub Pages에서 돌아간다.

- 세부 규칙: `PROTOCOL.md`
- 세션 절차: `ORCHESTRATOR.md`
- 착수·단계전환·재개 프롬프트: **가이드 웹매뉴얼** (`guide/index.html` — 착수 위저드 + 단계 전환은 phase-transition 킥오프 이슈가 완성본 프롬프트를 자동 생성)

---

## 1. 구성 요소 지도

```
research-ops/
  README.md                     # 이 문서 — 키트 front page·퀵스타트
  PROTOCOL.md                   # ★ 정형화 계약: 라벨 상태기계·GATE/EVIDENCE 스키마·사전등록·guard/close
  ORCHESTRATOR.md               # 세션 실행 지시서 (6-STEP + STEP 0 self-check + 라벨 전이)
  SESSION_B.md                  # 세션 B(gjc 감독) 지시서 템플릿
  templates/
    issue_dev.md                # 자기완결형 dev 이슈 (AC·작업 체크리스트·EVIDENCE 참조)
    issue_gate.md               # GATE 이슈/댓글 템플릿 (hard/soft/VERDICT 예시)
    pro_phase_spec_prompt.md    # gpt-pro 자문: 다음 단계 명세(gjc 브리프) 초안 지시
    pro_gate_advisor_prompt.md  # gpt-pro 자문: HUMAN GATE 판정 분석 지시
  scripts/
    bootstrap_project.sh        # 라벨 + milestone 멱등 생성 (--labels-only)
    setup_phase.sh              # @goal 파싱 → dev 이슈 + 매핑표 자동 backfill
    status.sh                   # 한 방 상태 조회 (blocked/running/verify/진행률)
    make_pro_bundle.sh          # gpt-pro 자문용 컨텍스트 번들러 (phase-spec | gate → /tmp/pro_bundle.md)
  workflows/                    # → CODE repo .github/workflows/ 로 복사해 사용 (4종)
    gate-notify.yml             # ntfy 푸시·리마인더·soft default 자동 채택
    evidence-verify.yml         # EVIDENCE SHA 체크아웃·pytest 재검증
    phase-transition.yml        # 단계 완료 감지 → 다음 단계 세션 A 킥오프 이슈 자동 생성
    pr-verify.yml               # PR 검증 (리포트·@goal 명세·불변값·status 린트)
```

대시보드는 MGMT repo의 `dashboard/index.html`에 있고 GitHub Pages로 공개된다: **https://jiminc77.github.io/research-dashboard/dashboard/** (무인증 공개 API만 사용, 5분 자동 새로고침, staleness 배지).

---

## 2. 신규 프로젝트 퀵스타트

새 프로젝트는 아래 순서로 인프라를 세운 뒤 킥오프한다. 오케스트레이터에게는 아래 **PROMPT-NEW**를 그대로 붙여넣으면 이 순서를 자동으로 밟는다.

```bash
# 0) 전제: gh CLI 로그인
gh auth status

# 1) 라벨 + phase별 milestone 부트스트랩 (양 레포, 멱등)
bash research-ops/scripts/bootstrap_project.sh \
  jiminc77 research-dashboard <CODE_REPO> <PROJECT> \
  "P0:환경파일럿,P1:베이스라인,P2:제안기법,P3:평가"

# 2) CODE repo에 워크플로 2개 커밋 (research-ops/workflows/ → .github/workflows/)
cp research-ops/workflows/*.yml <CODE_REPO_LOCAL>/.github/workflows/ \
  && git -C <CODE_REPO_LOCAL> add -A \
  && git -C <CODE_REPO_LOCAL> commit -m "ci: research-ops gate/evidence workflows" \
  && git -C <CODE_REPO_LOCAL> push

# 3) ntfy 토픽 secret 등록 (기존 topic 재사용, URL 노출 주의)
gh secret set NTFY_TOPIC -R jiminc77/<CODE_REPO>

# 4) 대시보드 CONFIG에 프로젝트 추가 후 커밋 (dashboard/index.html CONFIG.projects)
#    → Pages는 이미 활성화되어 있다: https://jiminc77.github.io/research-dashboard/dashboard/

# 5) 킥오프: 오케스트레이터에게 PROMPT-NEW를 붙여넣는다 (아래)
#    STEP 0 self-check → 계획서 정형화(HUMAN 승인) → milestone → P0.md(사전등록) → setup_phase.sh → gjc 위임

# 상태 확인은 언제든
bash research-ops/scripts/status.sh jiminc77 <CODE_REPO> research-dashboard
```

### PROMPT-NEW (오케스트레이터 킥오프 — 복붙)

```
새 연구 프로젝트의 오케스트레이션을 맡긴다.
jiminc77/research-dashboard 의 research-ops/ORCHESTRATOR.md, research-ops/PROTOCOL.md, research-ops/templates/ 를 읽고 그대로 따른다. STEP 0 self-check부터 시작한다.

- 계획서 초안: {경로 또는 URL}
- 구현 레포: jiminc77/{CODE_REPO}
- 프로젝트명: {PROJECT}
- 실행 환경: SSH_HOST={..} / WORKDIR={..} / HARDWARE={..} / 도구={..}

인프라 미구축 상태면 먼저 수행:
1) bash research-ops/scripts/bootstrap_project.sh jiminc77 research-dashboard {CODE_REPO} {PROJECT} "P0:{이름},P1:{이름},..."
2) research-ops/workflows/*.yml 을 {CODE_REPO}/.github/workflows/ 에 커밋
3) gh secret set NTFY_TOPIC -R jiminc77/{CODE_REPO}   # 값: 기존 topic 재사용
4) dashboard/index.html 의 CONFIG.projects 에 {PROJECT} 항목 추가 후 커밋
이후 STEP 1→6: 계획서 보강·정형화(HUMAN 승인) → milestone → P0.md(사전등록 포함) → setup_phase.sh → gjc 위임.
```

---

## 3. 단계 시작·재개

단계 전환("P{k} 완료 → P{k+1}")은 CODE repo의 **phase-transition 워크플로**가 마지막 `phase:Pk` 이슈 close 시 **킥오프 이슈**(복붙용 세션 A 지시서 — 웹 pro 완성본 포함)를 자동 생성한다. 착수·재개 절차와 규약은 **가이드 웹매뉴얼**(`guide/index.html`)에 정리되어 있다. 그대로 붙여넣으면 오케스트레이터가 완료 검증(ORCHESTRATOR §4) → 이월 → 다음 단계 명세·이슈 생성, 또는 라벨 기반 상태 복원을 수행한다.

한 줄 요약: 상태는 **라벨로 보이고**, 게이트는 **폰으로 오고**(ntfy), 증거는 **CI로 검증되고**, 대시보드는 **살아있다**.

---

## 4. gpt-pro 자문 경로 (선택 — 초안 보조)

강한 추론 모델(gpt-pro 등)을 **자문**으로 끼워, 다음 단계 명세 초안이나 게이트 판정 분석을 받는 경로다. **참고일 뿐이며, 정본은 issue 코멘트/세션 A 검증으로만 확정된다.**

흐름은 **번들 → 붙여넣기 → 초안 회수** 3단계다.

```bash
# (A) 다음 단계 명세 초안용 번들
bash research-ops/scripts/make_pro_bundle.sh phase-spec P2 dgcc
#   → /tmp/pro_bundle.md : 계획서 + 이전 단계 리포트 + 현재 P{k}.md + STEP_LOG tail
#     + 승계 리스크 골격 + pro_phase_spec_prompt.md(요구 출력 형식)

# (B) HUMAN GATE 판정 자문용 번들
bash research-ops/scripts/make_pro_bundle.sh gate 42 dgcc
#   → /tmp/pro_bundle.md : 게이트 이슈 본문·코멘트(GATE REQUEST/EVIDENCE)
#     + 사전등록 기준 인용 자리 + pro_gate_advisor_prompt.md
```

1. **번들**: 위 스크립트가 공개 데이터(git/curl, 인증 불필요)만 모아 `/tmp/pro_bundle.md`를 만든다.
2. **붙여넣기**: 그 파일을 gpt-pro에 그대로 붙여넣는다. 번들 끝의 프롬프트 템플릿이 요구 출력 형식(gjc 브리프 / 게이트 분석표)을 지시한다.
3. **초안 회수**: 돌아온 결과는 **초안**이다. 세션 A가 규약 검증(파서가 `@goal`을 다 잡는가·임계 불변인가·lint)을 거쳐 커밋으로 정본화하고, 게이트 판정은 사람이 `### GATE VERDICT` 코멘트로만 확정한다.

거버넌스 규칙(불변): **자문은 참고, 정본은 issue 코멘트/세션 A 검증.** 자문 초안이 사전등록 임계를 바꾸자고 하면 그건 게이트 통과가 아니라 `[Decision]` 이슈를 거쳐야 하는 기준 변경이다.

### 호출 경로 2가지

```text
경로 A (수동 · 구독 ChatGPT의 pro 사용):
  make_pro_bundle.sh → /tmp/pro_bundle.md → ChatGPT(pro 모델)에 붙여넣기 → 답을 가져와 사용

경로 B (프로그래매틱 — 세션 유지한 채 도구처럼 호출; 기본=구독 OAuth, 폴백=API):
  make_pro_bundle.sh phase-spec P2          # 또는: gate <issue#>
  bash research-ops/scripts/ask_pro.sh /tmp/pro_bundle.md
  → /tmp/pro_answer.md 로 답 수신.
  기본 backend=codex: ChatGPT 구독 OAuth (Codex CLI, gpt-5.5 @ xhigh reasoning) —
    구독 포함이라 추가 과금 없음. 1회 로그인: `codex login` (headless는 --device-auth
    또는 로컬 로그인 후 ~/.codex/auth.json 복사, chmod 600, 절대 커밋 금지).
  폴백 --backend api: OPENAI_API_KEY + o3-pro (per-token $20/$80 per 1M) — 최난도 콜 전용.
```

경로 C (웹 ChatGPT + codexpro — 대화형 레포 탐색 후 결과 복사):
  분석 머신에 레포 clone → `npm i -g codexpro` → 레포에서 `codexpro setup` →
  출력된 URL을 ChatGPT 앱(Developer Mode 커넥터)으로 등록 → 웹 ChatGPT가
  read/tree/search/git_diff 도구로 레포를 직접 탐색·분석 → 답을 복사해 사용.
  · 여러 레포: 워크스페이스 전환 도구(open_workspace)로 이동
  · 주의 1: pro(딥리즈닝) 서페이스는 커넥터 툴콜 미보장 — 그 경우 codexpro의
    pro-bundle(export)로 컨텍스트를 내보내 pro에 붙여넣는다 (= 경로 A와 동일 패턴)
  · 주의 2: GitHub 이슈/라벨은 파일이 아니라 codexpro가 못 읽음 —
    make_pro_bundle.sh gate 스냅샷 파일을 워크스페이스에 두고 조합
  · 보안: 터널 URL 토큰 비공개, CODEXPRO_BASH_MODE=full 사용 금지

경로 D (웹 pro + GitHub 쓰기 앱 + PR/CI — 세션 A 게시 경로):
  경로 A~C 가 "자문(초안 회수)"이라면, 경로 D 는 웹 pro 를 **세션 A 자체**로 세워
  회고→리포트/상태→차기 명세→이슈까지 **직접 게시**하는 경로다. 단, 쓰기는 자문이 아니라
  실게시이므로 **branch+PR 로만** 한다(main 직접 금지).
  · 앱: ChatGPT 웹 pro + GitHub 쓰기 앱(create_branch/push_files/create_issue …)
  · 계약: templates/pro_orchestrator_prompt.md (파라미터 {PROJECT}/{OWNER}/{MGMT_REPO}/{CODE_REPO}/{PHASE_DONE}/{PHASE_NEXT})
  · 규율: create_branch phase/P{k+1}-kickoff → push_files → PR(MGMT·CODE 각 1개).
    PR 본문에 evidence 링크 + 불변값 이월 확인. pr-verify(.github/workflows/pr-verify.yml,
    on: pull_request) 가 리포트·@goal 명세·불변값·status 를 기계 검증 → **green + 사람 merge** 로 게시 확정.
  · 킥오프: 단계 전환 이슈의 "세션 A 실행 옵션 (b) 웹 pro 경로"가 프롬프트 raw URL + 치환할 파라미터를 채워 안내.
  · 거버넌스 동일: 게이트 판정(GATE VERDICT)은 사람 전용, 불변값 변경은 [Decision] 이슈 경유.
    직접 push 는 gjc(CODE, phase 실행 중)·유지보수 세션에만 잠정 허용, P1 종료 시 branch protection
    (required check `pr-verify`)으로 고정 (PROTOCOL §7-B).

경로 B는 세션 A·Cowork·임의 쉘에서 "고지능이 필요한 순간"에 한 줄로 호출하는 자문 도구다.
비용 주의(o3-pro: 입력 $20/1M·출력 $80/1M) — 번들 크기를 확인 후 호출. 거버넌스 동일:
출력은 자문/초안이며, 정본은 issue 코멘트(사람)와 세션 A 규약 검증(파서·임계 불변·lint) 후 커밋뿐.
