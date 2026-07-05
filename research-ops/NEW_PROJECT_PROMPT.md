# 오케스트레이션 프롬프트 — 착수 / 단계 전환 / 재개

오케스트레이터에게 그대로 붙여넣는 프롬프트 3종. `{ }` 부분만 채운다.
계약·절차의 정본은 `research-ops/PROTOCOL.md`·`research-ops/ORCHESTRATOR.md`이며, 이 프롬프트들은 그 계약 기준으로 세션을 시작·전환·재개시킨다.

- **PROMPT-NEW** — 새 연구 착수 (최초 1회)
- **PROMPT-PHASE** — 한 단계가 gjc로 끝난 뒤 다음 단계 전환 (매 단계 반복)
- **PROMPT-RESUME** — 중간에 끊겼다 다시 시작할 때

브라우저용 매뉴얼은 `research-ops/manual.html`.

---

## 1. PROMPT-NEW — 프로젝트 착수

새 연구를 시작할 때 최초 1회. 인프라(라벨·워크플로·secret·대시보드 CONFIG)가 없으면 오케스트레이터가 먼저 셋업하고, 이어서 STEP 1→6으로 계획서 정형화·milestone·P0 명세·gjc 위임까지 진행한다. `{CODE_REPO}`·`{PROJECT}`·계획서 경로·ENV 4종을 채운다.

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

## 2. PROMPT-PHASE — 단계 전환

한 단계가 gjc로 끝난 뒤 다음 단계를 맡길 때 매 단계 반복. 오케스트레이터가 이전 단계 종료를 검증하고(dev 이슈 close·HUMAN GATE VERDICT 존재), 다음 단계 명세(`P{k}.md`)를 사전등록 포함해 작성한 뒤 `setup_phase.sh`로 이슈를 생성하고 gjc에 위임한다.

### 일반형 (P{k}, {CODE_REPO} 치환)

아래 "P2 실전 예시"에서 `P2 → P{k}`, `P1 → P{k-1}`, `DGCC → {CODE_REPO}`, 경로/문서명은 프로젝트 것으로 치환해 쓴다.

```
{CODE_REPO} P{k} 단계의 오케스트레이션을 맡긴다.
jiminc77/research-dashboard 의 research-ops/ORCHESTRATOR.md 와 research-ops/PROTOCOL.md 를 읽고 그대로 따른다.

1) STEP 0 self-check
2) P{k-1} 종료 검증: phase:P{k-1} dev 이슈 전부 closed, HUMAN sign-off 이슈에 GATE VERDICT 존재. 미완이면 정지하고 나에게 보고.
3) P{k}.md 작성 (jiminc77/{CODE_REPO} 루트, 이전 P{k}.md 형식 계승):
   - 입력: 계획서의 P{k} 정의 + 사전 고정 임계 문서 (수치 변경 금지)
   - @goal: M0..Mj 각 블록 Exit 에 primary+guard 지표와 판정 기준을 사전등록
   - HUMAN GATE goal 은 class(hard|soft) 지정, soft 는 default+deadline 포함
   - "실행 환경(고정)" 블록은 이전 단계 승계
4) P{k}.md 요약을 나에게 보고하고 승인받은 뒤 push
5) bash research-ops/scripts/setup_phase.sh P{k} {로컬 경로}/P{k}.md   # 이슈·라벨·마일스톤 연결·번호 backfill 자동
6) gjc 위임 (PROTOCOL.md 준수 명시) → 완료 검증은 ORCHESTRATOR §4 체크리스트
```

### P2 실전 예시 (DGCC)

```
DGCC P2 단계의 오케스트레이션을 맡긴다.
jiminc77/research-dashboard 의 research-ops/ORCHESTRATOR.md 와 research-ops/PROTOCOL.md 를 읽고 그대로 따른다.

1) STEP 0 self-check
2) P1 종료 검증: phase:P1 dev 이슈 전부 closed, HUMAN sign-off 이슈에 GATE VERDICT 존재. 미완이면 정지하고 나에게 보고.
3) P2.md 작성 (jiminc77/DGCC 루트, P0.md/P1.md 형식 계승):
   - 입력: docs/research/DGCC_research_plan.md §10 의 P2 정의 + docs/reports/P2_probing_decision.md 의 사전 고정 임계 (수치 변경 금지)
   - @goal: M0..Mj 각 블록 Exit 에 primary+guard 지표와 판정 기준을 사전등록
   - HUMAN GATE goal 은 class(hard|soft) 지정, soft 는 default+deadline 포함
   - "실행 환경(고정)" 블록은 P1.md 승계
4) P2.md 요약을 나에게 보고하고 승인받은 뒤 push
5) bash research-ops/scripts/setup_phase.sh P2 {DGCC 로컬 경로}/P2.md   # 이슈·라벨·마일스톤 연결·번호 backfill 자동
6) gjc 위임 (PROTOCOL.md 준수 명시) → 완료 검증은 ORCHESTRATOR §4 체크리스트
```

> 짧게 가려면 이어가는 한 줄로도 된다: **"P{k} 완료. 상태 확인하고 P{k+1} 진행해줘."** 오케스트레이터가 완료 검증 → 이월 → 다음 단계 명세·이슈 생성을 밟는다.

---

## 3. PROMPT-RESUME — 세션 재개

중간에 끊겼다 다시 시작할 때. 오케스트레이터가 라벨 쿼리로 현재 상태를 복원하고, 사람을 기다리는 게이트가 있으면 요약 보고 후 VERDICT를 기다린다. 없으면 마지막 CHECKPOINT부터 이어간다. `{PROJECT}`·`{CODE_REPO}`를 채운다.

```
{PROJECT} 오케스트레이션을 재개한다.
research-ops/ORCHESTRATOR.md 와 PROTOCOL.md 를 읽은 뒤 상태를 복원한다:
- bash research-ops/scripts/status.sh jiminc77 {CODE_REPO} research-dashboard
- state:blocked-human 이 있으면: 해당 GATE REQUEST 를 요약해 나에게 보고하고 VERDICT 를 기다린다
- 없으면: MGMT [Milestone] 이슈의 마지막 [CHECKPOINT] 코멘트 기준으로 다음 STEP 을 이어간다
```

---

## 채우기 팁

- **PROMPT-NEW**: 계획서·CODE_REPO·ENV 4종이 필수. 계획서에 단계(P0..Pn)가 명확히 나뉘어 있어야 milestone·부트스트랩이 깔끔하다.
- **PROMPT-PHASE**: 이전 단계에서 넘길 확정값/리스크가 있으면 3)의 입력 줄에 문서 경로를 명시한다.
- **PROMPT-RESUME**: 임의로 진행시키지 않는다 — 상태 보고와 다음 할 일 제안을 먼저 받는다.
