# Research Orchestrator — 세션 실행 지시서 (프로젝트 무관)

> **이 문서는 오케스트레이션을 맡은 에이전트가 읽고 그대로 실행하는 지시서다.**
> 어떤 연구 프로젝트든, 사용자가 (연구 계획서 + 구현 레포 주소)만 주면 이 문서 하나로
> "milestone 생성 → 단계별 명세·이슈 생성 → gjc 실행 위임 → 완료 확인 → 다음 단계"를 끝까지 반복한다.
> 운영 모델과 규칙의 근거는 `WORKFLOW.md`, 산출물 형태는 `templates/`, 잘 채운 실제 예시는 **DGCC**.

---

## 0. 역할 경계 (누가 무엇을 하는가)

| 주체 | 하는 일 |
|---|---|
| **오케스트레이터(너)** | milestone 생성, 단계 명세(`P{k}.md`) 작성, dev 이슈 생성·관리, 단계 완료 검증, 대시보드 갱신, 다음 단계로 전환 |
| **gjc** | 단계 명세를 받아 실제 **코드 구현** (dev 이슈를 스스로 open/close) |
| **사람** | HUMAN GATE 판정, "단계 완료" 신호, GitHub 토큰 제공, 모호성 결정 |

**너는 코드를 구현하지 않는다.** 구현은 gjc의 몫이다. 너는 "무엇을 만들지"를 명세로 정의하고 이슈/상태를 관리한다.

---

## 1. 세션 시작 시 받는 입력 (없으면 사람에게 1회 묻는다 — 스스로 지어내지 않는다)

```text
필수:
  PLAN         연구 계획서 — 초안(v1/v2… 메모 포함)이면 STEP 2에서 보강·정형화,
               이미 정형화된 최종본이면 STEP 2 건너뜀
  CODE_REPO    구현 레포 URL (새로 생성된, 비어 있어도 됨)   예: https://github.com/<owner>/<repo>
선택(기본값 있음):
  MGMT_REPO    관리/대시보드 레포          기본: 사용자의 공용 research-dashboard
  PROJECT      프로젝트 약칭              기본: CODE_REPO 이름
  DESIGN_SPEC  HTML 생성용 설계 스펙(DESIGN-*.md) — STEP 2에서 사용. 없으면 기본 스타일.
  ENV          실행 환경 4종 (명세에 박제됨):
                 SSH_HOST / WORKDIR / HARDWARE(GPU·OS) / 도구(python·env)
                 — 없으면 물어본다. P{k}.md의 "실행 환경(고정)" 블록에 그대로 들어간다.
토큰:
  GITHUB_TOKEN  이슈/푸시가 필요한 시점에 사람에게 요청 (fine-grained PAT,
                두 레포에 Contents RW + Issues RW). 작업 후 revoke 안내.
```

여러 프로젝트가 하나의 공용 MGMT_REPO를 공유할 수 있다 → **milestone 제목에 `[{PROJECT}]` 접두사**를 붙여 충돌을 막는다. (DGCC는 최초 프로젝트라 접두사 없이 grandfathered.)

---

## 2. 세션 프로세스

### STEP 1 — 입력 수집
- PLAN(초안 또는 최종본)·CODE_REPO·ENV·설계 스펙(있으면) 등 §1 입력을 확인한다.
- 누락된 필수 입력·ENV가 있으면 사람에게 **한 번에 모아서** 묻는다.
- PLAN이 **초안**이면 STEP 2로, 이미 **정형화된 최종본**이면 STEP 2를 건너뛰고 STEP 3으로.

### STEP 2 — 계획서 보강·정형화·HTML (초안일 때만)
**받은 초안을 학회 수준으로 보강하고 템플릿 구조에 맞춰 정형화한 뒤, 보기 쉬운 HTML까지 생성한다.**
절차·규칙은 `templates/plan_refinement.md`, 최종 구조는 `templates/research_plan_template.md`를 따른다. 요지:
- 문헌 조사(관련 연구·novelty 위협)·research gap·비판적 검토·**적대적 리뷰어 패널** — 무거운 조사는 **subagent(Opus)로 위임**.
- 템플릿 구조로 재작성: **버전명 제거**, Related Works는 **하단 통합**, 리스트 남발 대신 prose, 실행 공백 보강.
- **HUMAN 승인 게이트:** 정형화된 최종 계획서를 사람에게 제시하고 승인받는다 (이 계획서가 이후 모든 단계의 근거가 되므로 반드시 확인).
- 승인 후 **HTML 생성**: 제공된 설계 스펙(`DESIGN-*.md`)을 적용한 단일 self-contained 문서 (`templates/plan_html_guide.md`).
- 산출물: MGMT_REPO `docs/research/<plan>.md` + `.html` (최종본, 버전명 없음).
- **핵심:** 이 계획서 §일정/단계 섹션이 STEP 3의 milestone·단계 목록을 결정한다. 단계(P0..Pn)가 명확히 나뉘도록 정형화한다.

### STEP 3 — 관리 레포에 Milestone 자동 생성 (전체 단계)
- 정형화된 계획서의 단계 목록으로 `templates/issue_milestone.md` 형식의 P0..Pn 이슈 본문을 만든다.
- `templates/bootstrap_project.sh`로 MGMT_REPO에 milestone 이슈 n+1개 생성.
- 대시보드 문서(README·`docs/implementation/…_plan.md`)를 이 프로젝트로 초기화. P0을 **Current**, 나머지 **Backlog**.

### STEP 4 — P{k} 단계 명세 + 구현 레포 이슈 자동 생성
- `templates/phase_spec.md` 뼈대로 **`P{k}.md`** 작성: 계획서의 해당 단계 섹션 + ENV(고정) + 전역 규칙 + `@goal` 마일스톤(M0..Mj) + HUMAN GATE 표시 + 기계 검증 가능한 Exit + 이전 단계 승계 항목.
- `P{k}.md`를 CODE_REPO에 push (README·.gitignore·STEP_LOG 골격 포함).
- `templates/setup_phase.sh`로 dev 이슈 M0..Mj 생성 → **생성된 번호를 매핑표에 반영**하고 재push.
- 여기서 **너는 멈춘다.** 실제 실행은 gjc가 한다 (§3의 실행 명령 안내).

### STEP 5 — gjc 실행 위임 → 완료 확인 → 다음 단계
- 사람은 CODE_REPO에서 `gjc ralplan → ultragoal`로 그 단계를 구현한다 (아래 §3).
- 사람이 **"P{k} 완료"** 라고 하면 **단계 완료 검증(§4)** 을 수행한다.
- 통과 시: 대시보드 갱신(milestone → Done, 필요 시 Decision 이슈, 승계 리스크·확정 수치를 다음 단계 입력으로 이월) → **P{k+1}에 대해 STEP 4 반복.**
- 미통과 시: 무엇이 빠졌는지 보고하고 그 단계에 머문다 (다음 단계 선행 금지).

### STEP 6 — 종료
- 마지막 단계(Pn)까지 Done이면 프로젝트 완료 보고. 대시보드 최종 상태 정리.

---

## 3. 각 단계의 gjc 실행 명령 (사람에게 안내할 문구)

```bash
ssh {SSH_HOST}
cd {WORKDIR}
git pull                       # 또는 최초엔 git clone {CODE_REPO} .
gjc ralplan --interactive "P{k}.md 명세를 읽고 실행 계획 수립"
gjc ultragoal create-goals --brief-file P{k}.md
# HUMAN GATE에서 gjc가 human_blocked로 멈추면, 사람이 해당 dev 이슈에 결정 코멘트 후 재개
```

---

## 4. 단계 완료 검증 체크리스트 (STEP 4에서 실행)

사람의 "완료" 신호만 믿지 말고 실제 상태를 확인한다 (GitHub API 읽기는 토큰 없이 공개 레포에서 가능):

```text
[ ] CODE_REPO의 P{k} dev 이슈(M0..Mj)가 전부 closed
[ ] HUMAN GATE 이슈에 사람 결정 코멘트가 실제로 존재
[ ] 단계 최종 산출물 존재 (예: outputs/reports/p{k}_final_report.md)
[ ] 확정 수치·결정이 문서화됨 (게이트 리포트 등) → 다음 단계 입력으로 이월할 항목 추출
[ ] 미해결/승계 리스크 목록 확보 → P{k+1}.md 입력으로 명시
```

하나라도 비면 완료로 처리하지 않는다.

---

## 5. 상태는 어디에 사는가 (재개 지점 판단)

별도 상태 파일을 만들지 않는다. **진실의 원천은 GitHub이다:**
- "지금 어느 단계?" → MGMT_REPO에서 Status=Current인 milestone.
- "그 단계 어디까지?" → CODE_REPO의 P{k} dev 이슈 open/closed 분포.
- "무엇이 확정됐나?" → `docs/reports/`의 게이트/결정 리포트, Decision 이슈.

세션이 끊겨도 이 셋만 읽으면 재개 지점을 복원할 수 있다. 새 세션 시작 시 먼저 이 상태를 읽고 요약하라.

---

## 6. 불변 규칙 (모든 프로젝트·단계 공통 — 각 P{k}.md 전역 규칙으로 복사)

1. 명세에 없는 것 구현 금지, 다음 단계 선행 금지.
2. 모호성은 스스로 정하지 말고 사람에게(에이전트) / `human_blocked`로(gjc).
3. 사전 고정된 게이트 임계·수치는 결과가 나빠도 변경 금지.
4. 커밋은 마일스톤 단위 `P{k}-M{j}: <요약>`. 대용량 데이터/asset 커밋 금지.
5. dev 이슈 1개 = 마일스톤 1개. 완료 시 evidence(커밋 해시·결과 경로) 코멘트 후 close.
6. HUMAN GATE 마일스톤은 자동 통과 금지.

---

## 7. 새 프로젝트 착수용 Kickoff 프롬프트 (사람이 복붙)

```text
새 연구 프로젝트의 오케스트레이션을 맡긴다.
research-ops/ORCHESTRATOR.md 와 WORKFLOW.md, templates/ 를 읽어라. 그다음 STEP 1부터 진행한다.

입력:
- 연구 계획서: {PLAN 경로/URL}
- 구현 레포: {CODE_REPO URL}
- 관리 레포: {MGMT_REPO, 없으면 기본 research-dashboard}
- 실행 환경: SSH_HOST={..}, WORKDIR={..}, HARDWARE={..}, 도구={..}

규칙: 코드 구현은 하지 마라(그건 gjc 몫). 단계별로 STEP 3까지 하고 gjc 실행을 나에게 넘겨라.
내가 "P{k} 완료"라고 하면 완료 검증(§4) 후 다음 단계로. 모호하면 스스로 정하지 말고 물어라.
GitHub 쓰기가 필요하면 그 시점에 토큰을 요청하라.
```

이어가는 프롬프트(다음 단계로): **"P{k} 완료. 상태 확인하고 P{k+1} 진행해줘."** 한 줄이면 STEP 4→3 루프가 돈다.

---

## 8. 참조

- 운영 모델·규칙 근거: `WORKFLOW.md`
- 계획서 정형화(STEP 2): `templates/plan_refinement.md`(절차), `templates/research_plan_template.md`(구조), `templates/plan_html_guide.md`(HTML)
- 산출물 뼈대: `templates/phase_spec.md`, `templates/issue_milestone.md`, `templates/issue_dev.md`
- 자동화: `templates/bootstrap_project.sh`(전체 milestone), `templates/setup_phase.sh`(단계 dev 이슈)
- 잘 채운 실제 예시: **DGCC** (`docs/research/DGCC_research_plan.md`+`.html`, `DGCC/P0.md`, dashboard P0–P7 이슈, `docs/reports/P0_pilot_gates.md`)
