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
    pro_orchestrator_prompt.md  # 세션 A(웹 pro) 계약 — 킥오프 이슈가 치환 완성본을 자동 내장
  scripts/
    bootstrap_project.sh        # 라벨 + milestone 멱등 생성 (--labels-only)
    setup_phase.sh              # @goal 파싱 → dev 이슈 + 매핑표 자동 backfill
    status.sh                   # 한 방 상태 조회 (blocked/running/verify/진행률)
    lint_report.sh · lint_spec.sh · check_immutables.sh · lint_status.sh   # pr-verify가 쓰는 4종 린터
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

## 4. 세션 A — 웹 pro (유일 경로)

세션 A는 **ChatGPT 웹의 pro 모델 세션**이다. GitHub 앱(create_branch / push_files / create_issue …)으로 두 레포를 직접 읽고 쓴다. 별도 스크립트·번들·API 호출 없음.

- **진입**: 단계 전환 시 자동 생성되는 킥오프 이슈의 **완성본 프롬프트**(`templates/pro_orchestrator_prompt.md` 치환본)를 그대로 복붙.
- **산출물 4종**: 이전 단계 리포트 HTML · status.json · 차기 P{k}.md · 차기 dev 이슈(라벨 `phase:P{k}`+`type:dev`+`state:ready`, 마일스톤 부착).
- **쓰기 규율**: default branch 직접 쓰기 금지 — `phase/P{k}-kickoff` branch → PR(MGMT·CODE 각 1개) → `pr-verify` green → **사람 merge**로 게시 확정 (PROTOCOL §7-B). 직접 push는 gjc(CODE, phase 실행 중)·유지보수 세션에만 잠정 허용, P1 종료 시 branch protection으로 고정.
- **게이트 자문**: 별도 도구 없이 같은 세션에 게이트 이슈 URL을 주고 분석을 요청. **판정(GATE VERDICT)은 사람이 issue 코멘트로만** 확정하고, 불변값 변경 제안은 `[Decision]` 이슈 경유.
- **경계**: 세션 A는 셸이 없다 — bash 커맨드(setup_phase.sh 등)는 전부 **사람 로컬 셸**의 수동 대안 경로다. dev 이슈 발행의 표준은 세션 A가 GitHub 앱으로 직접 생성하는 것.
