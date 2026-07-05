# research-ops — 솔로 연구자용 GitHub 에이전트 워크플로우 키트

> **원칙 한 줄: 상태는 라벨로, 증거는 스키마로, 게이트는 사전등록으로, 인프라는 제로로.**

연구 프로젝트를 GitHub Issues/Actions 위에서 오케스트레이터·gjc(실행자)·사람의 역할로 굴리는 **재사용 운영 키트**. 상태는 `state:*` 라벨 상태기계로, 증거는 `### EVIDENCE` 스키마로, HUMAN GATE는 사전등록된 기준으로 관리하고, 알림·검증·대시보드는 **제로 인프라(gh CLI · GitHub Actions · ntfy.sh · 클라이언트 대시보드)**로 자동화한다.

이 키트는 이미 배포되어 운영 중이다: 워크플로 2개는 CODE repo(`jiminc77/DGCC`)의 `.github/workflows/`에서, 라이브 대시보드는 MGMT repo(`jiminc77/research-dashboard`)의 GitHub Pages에서 돌아간다.

- 세부 규칙: `PROTOCOL.md`
- 세션 절차: `ORCHESTRATOR.md`
- 프롬프트 3종(착수·단계전환·재개): `NEW_PROJECT_PROMPT.md` · `manual.html`

---

## 1. 구성 요소 지도

```
research-ops/
  README.md                     # 이 문서 — 키트 front page·퀵스타트
  PROTOCOL.md                   # ★ 정형화 계약: 라벨 상태기계·GATE/EVIDENCE 스키마·사전등록·guard/close
  ORCHESTRATOR.md               # 세션 실행 지시서 (6-STEP + STEP 0 self-check + 라벨 전이)
  NEW_PROJECT_PROMPT.md         # 사람이 복붙하는 프롬프트 3종 (착수 / 단계 전환 / 재개)
  WORKFLOW.md                   # 3층위 멘탈 모델·이슈 3종 규약 (운영 계약서)
  manual.html                   # 위 프롬프트·절차의 브라우저용 매뉴얼
  templates/
    issue_dev.md                # 자기완결형 dev 이슈 (AC·작업 체크리스트·EVIDENCE 참조)
    issue_gate.md               # GATE 이슈/댓글 템플릿 (hard/soft/VERDICT 예시)
  scripts/
    bootstrap_project.sh        # 라벨 + milestone 멱등 생성 (--labels-only)
    setup_phase.sh              # @goal 파싱 → dev 이슈 + 매핑표 자동 backfill
    status.sh                   # 한 방 상태 조회 (blocked/running/verify/진행률)
  workflows/                    # → CODE repo .github/workflows/ 로 복사해 사용
    gate-notify.yml             # ntfy 푸시·리마인더·soft default 자동 채택
    evidence-verify.yml         # EVIDENCE SHA 체크아웃·pytest 재검증
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

단계 전환("P{k} 완료, P{k+1} 진행")과 세션 재개 프롬프트는 **`NEW_PROJECT_PROMPT.md`**(착수 / 단계 전환 / 재개 3종)와 브라우저용 **`manual.html`**에 정리되어 있다. 그대로 붙여넣으면 오케스트레이터가 완료 검증(ORCHESTRATOR §4) → 이월 → 다음 단계 명세·이슈 생성, 또는 라벨 기반 상태 복원을 수행한다.

한 줄 요약: 상태는 **라벨로 보이고**, 게이트는 **폰으로 오고**(ntfy), 증거는 **CI로 검증되고**, 대시보드는 **살아있다**.
