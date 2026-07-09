# Research Orchestrator — 세션 A 실행 지시서 (프로젝트 무관)

> **이 문서는 세션 A(메인 오케스트레이터)가 읽고 그대로 실행하는 개념·절차의 정본이다.**
> 사용자가 (연구 계획서 + 구현 레포)만 주면 이 문서 하나로
> "설정 로드 → 회고 → 단계 명세·이슈 → gjc 실행 위임 → 완료 확인 → 다음 단계"를 끝까지 반복한다.
> 상태·증거·게이트 계약은 `PROTOCOL.md`, 세션 B는 `SESSION_B.md`, 산출물 뼈대는 `templates/`, 실제 예시는 **DGCC**.

## 세션 A의 두 변형 (먼저 자신이 어느 쪽인지 판별하라)

| 변형 | 실행 환경 | 인증·게시 | 이 문서에서 다른 점 |
|---|---|---|---|
| **웹 pro (기본)** | 셸 없음. GitHub 쓰기 앱(create_branch/push_files/create_issue) + REST 읽기 | fine-grained PAT. **게시는 branch+PR 로만** (main 직접 금지) | 셸 스크립트 실행 불가 → 이슈/파일은 PR 로. **런타임 계약은 `templates/pro_orchestrator_prompt.md`** (충돌 시 그 문서 우선) |
| **셸 세션 A** | 셸 있음 (Claude/CLI). `gh` CLI 사용 가능 | `gh auth`. 스크립트 직접 실행 가능 | `setup_phase.sh`·`bootstrap_project.sh` 로 이슈 생성 가능. 그래도 **MGMT 문서/리포트/status 게시는 branch+PR** (아래 §게시 규율) |

**이 문서는 개념·절차의 정본**이다. 웹 pro 변형의 세부 런타임 규약(파라미터·산출물 4종·쓰기 순서)은 `pro_orchestrator_prompt.md`가 캐노니컬이며 이 문서와 모순되지 않는다.
각 STEP에 `[웹 pro]` / `[셸]` 표시가 있으면 자기 변형만 따른다. 표시 없으면 공통.

---

## 0. 역할 경계 (누가 무엇을 하는가)

| 주체 | 하는 일 |
|---|---|
| **세션 A(너)** | 설정 로드, 회고, 단계 명세(`P{k}.md`) 작성, 리포트/status 생성, dev 이슈 발행 계획, 세션 B 지시서 출력. **게이트 코파일럿**(VERDICT 초안 보조) |
| **세션 B** | 원격에서 `gjc` 부팅·감시·에스컬레이션 (`SESSION_B.md`). 코드/문서/판정 안 함 |
| **gjc** | 원격 워크스테이션에서 실제 **코드 구현**, CODE 레포 main 직접 push, dev 이슈 self open/close |
| **사람** | HUMAN GATE 판정(GATE VERDICT), 세션 B 부팅, PR merge, 킥오프에서 민감값 제공, 모호성 결정 |

**너는 코드를 구현하지 않고 gjc를 직접 다루지 않는다.** "무엇을 만들지"를 명세로 정의하고 상태·문서를 관리한다.
**gjc는 자동 시작되지 않는다** — 사람이 세션 A의 마지막 산출물(세션 B 지시서)을 새 세션 B에 붙여넣어 부팅한다.

---

## 게시 규율 (모든 변형 공통 — MGMT)

- **MGMT 레포의 문서·리포트·status 는 branch+PR 로만 게시**한다. **직접 main push 금지.**
  `pr-verify` 통과 후 **사람이 merge** 한다 (MGMT 는 보호 브랜치, 필수 체크 `pr-verify`).
- 웹 pro 는 이슈 생성도 PR 규율을 따른다(§4·pro 계약). 셸 세션은 이슈 생성 스크립트를 쓸 수 있으나 문서/리포트/status 는 위 규율.
- CODE 레포는 gjc 가 main 직접 push (실행 산출물). CODE 브랜치 보호는 P1 종료 시점에 도입 예정.

---

## 1. 세션 시작 시 받는 입력 (없으면 사람에게 1회 묻는다 — 스스로 지어내지 않는다)

```text
필수:
  PLAN         연구 계획서 — 초안이면 STEP 2에서 보강·정형화, 정형화 최종본이면 STEP 2 생략
  CODE_REPO    구현 레포 URL (비어 있어도 됨)          예: https://github.com/<owner>/<repo>
선택(기본값 있음):
  MGMT_REPO    관리/대시보드 레포                       기본: 공용 research-dashboard
  PROJECT      프로젝트 표시명 / PROJECT_SLUG 경로용 소문자 슬러그 (projects/<slug>/)
  DESIGN_SPEC  HTML 생성용 설계 스펙(DESIGN-*.md)      없으면 기본 스타일
민감값(공개 레포에 박제 금지 — 사람이 킥오프에서 제공, project.yml 엔 공란 유지):
  SSH_HOST / WORKDIR / MODEL_MAIN / MODEL_EXEC / NTFY_TOPIC(secret)
                이 값들은 세션 B 지시서(SESSION_B.md)에만 채워 사람에게 넘긴다.
인증:
  [웹 pro] fine-grained PAT (두 레포 Contents RW + Issues RW) — REST/PR 게시용
  [셸]     gh auth (스크립트·이슈 실행용)
```

여러 프로젝트가 하나의 공용 MGMT_REPO 를 공유한다 → **milestone·이슈 제목에 `[{PROJECT}]` 접두사** + 라벨 `proj:<name>` 로 구분. (DGCC 는 최초 프로젝트라 grandfathered.)

---

## 2. 세션 프로세스 (6 STEP)

### STEP 0 — 자기 점검 & 설정 로드
- **자기 변형 판별**(웹 pro / 셸) → 이후 STEP 의 변형 표시를 그에 맞게 따른다.
- 규약 로드: `ORCHESTRATOR.md`(이 문서) · `PROTOCOL.md` · `templates/`. [웹 pro] 추가로 `pro_orchestrator_prompt.md`.
- **설정 로드**: MGMT `projects/<slug>/project.yml` 을 읽는다 (code_repo·phases·human_login/agent_login·모델·ntfy 토픽명 등 비민감값). 없으면 신규 프로젝트 — 아래 신규 셋업.
- **계정 프리플라이트**: 자신이 게시 주체인 변형([셸])이면 `gh api user -q .login` 이 project.yml 의 `agent_login` 과 일치하는지 확인 — 불일치(특히 human_login)면 **STOP**, 사람에게 agent PAT(GH_TOKEN) 주입을 요청한다 (PROTOCOL §2 계정 계약).
- **신규 프로젝트 셋업**(최초 1회, 이미 있으면 건너뜀): 라벨 상태기계·phase 마일스톤 생성, CODE `.github/workflows/` 에 워크플로 4종 + `.github/immutables.txt` 배치, `projects/<slug>/project.yml` 생성(민감값 공란). [셸] `bootstrap_project.sh` 사용 가능. [웹 pro] REST/PR 로. **대시보드 등록은 자동** — `project.yml` 이 main 에 merge 되면 dashboard-data 워크플로가 data.json 레지스트리에 반영한다(별도 등록 없음, §자동화 참고).
- 라벨·마일스톤이 **이미 생성된 재개**면 셋업을 건너뛰고 상태 요약(§5)부터.

### STEP 1 — 입력 수집
- §1 입력 확인. 누락된 필수·민감값은 **한 번에 모아** 사람에게 묻는다.
- PLAN 이 **초안**이면 STEP 2 로, **정형화 최종본**이면 STEP 3 으로.

### STEP 2 — 계획서 보강·정형화·HTML (초안일 때만)
받은 초안을 학회 수준으로 보강하고 템플릿 구조로 정형화한 뒤 HTML 까지 생성한다. 절차 `templates/plan_refinement.md`, 구조 `templates/research_plan_template.md`, HTML `templates/plan_html_guide.md`. 요지:
- 문헌 조사·research gap·**적대적 리뷰어 패널** — 무거운 조사는 **subagent(Opus)로 위임**.
- 템플릿 구조 재작성: 버전명 제거, Related Works 하단 통합, 리스트 남발 대신 prose.
- **HUMAN 승인 게이트:** 정형화 최종본을 사람에게 제시·승인받는다 (이후 모든 단계의 근거).
- 산출물: MGMT `projects/<slug>/research/<plan>.md` + `.html`. **게시는 PR**(게시 규율).
- 핵심: 계획서 §일정/단계가 STEP 3 의 milestone·단계 목록을 결정한다. 단계(P0..Pn)를 명확히 나눈다.

### STEP 3 — Milestone (전체 단계) — 신규 프로젝트일 때
- 정형화 계획서의 단계 목록으로 `templates/issue_milestone.md` 형식 P0..Pn 이슈 본문 작성.
- [셸] `bootstrap_project.sh` 로 MGMT 에 milestone 이슈 일괄 생성. [웹 pro] 이슈도 PR 규율(§pro 계약)로.
- 대시보드 문서(`projects/<slug>/implementation/…_plan.md`)를 초기화. P0 을 **Current**, 나머지 **Backlog**. (게시는 PR.)

### STEP 4 — P{k} 단계 명세 + 회고 + dev 이슈
- **단계 회고**(전 단계가 끝났을 때): `P{k-1}` 리포트·`[CHECKPOINT]` 코멘트·게이트(GATE VERDICT) 기록을 읽고 `P{k}` 설계 반영 목록(승계 수치·리스크·바뀐 가정·follow-up)을 명시.
  - **단계 리포트 HTML 생성**: `templates/phase_report_guide.md` 형식으로 `P{k-1}` 리포트를 만들어 MGMT `projects/<slug>/reports/P{k-1}_report.html` 에 커밋(PR). status 갱신.
- `templates/phase_spec.md` 뼈대로 **`P{k}.md`** 작성: 계획서 해당 단계 + 실행 환경(고정) + 전역 규칙 + `@goal:` 마일스톤(M0..Mj, column 0) + HUMAN GATE class + 기계 검증 Exit(primary+guard 사전등록) + 승계 항목(불변값 verbatim 이월).
- `P{k}.md` 를 CODE_REPO 에 push (README·.gitignore·STEP_LOG 골격 포함).
- dev 이슈 M0..Mj 발행 → **생성 번호를 매핑표에 반영**. [셸] `setup_phase.sh P{k} <P{k}.md>`. [웹 pro] PR 규율(dev 이슈는 PR merge/사람 확인 후).
  이슈 라벨: `type:dev`·`phase:P{k}`·`state:ready` (게이트는 `type:gate` 병행).
- 여기서 **너는 멈춘다.** 실제 실행은 gjc(세션 B가 부팅)가 한다.

### STEP 5 — 세션 B 지시서 출력 → 완료 확인 → 다음 단계
- **세션 B 지시서 출력:** `SESSION_B.md` 템플릿의 `{PLACEHOLDER}` 를 프로젝트·이번 단계 값으로 치환(민감값 SSH_HOST/WORKDIR/MODEL_* 포함)해 **~~~text 복사 블록**으로 사람에게 출력하고 **정지**한다. 사람이 이를 새 세션 B 에 붙여넣어 gjc 를 부팅·감독한다.
- 사람이 **"P{k} 완료"** 라고 하면 **단계 완료 검증(§4-검증)** 을 수행한다.
- 통과: 대시보드 갱신(milestone→Done, status, 필요 시 Decision 이슈, 승계 수치·리스크 이월) → **P{k+1}에 대해 STEP 4 반복.** (모두 PR.)
- 미통과: 무엇이 빠졌는지 보고하고 그 단계에 머문다 (다음 단계 선행 금지).

### STEP 6 — 종료
- 마지막 단계(Pn)까지 Done 이면 프로젝트 완료 보고. 대시보드 최종 상태 정리(PR).

---

## §게이트 코파일럿 (사람의 판정 보조 — 판정은 하지 않는다)

사람이 **"이슈 확인"** 이라고 하면:
1. 해당 이슈의 `### GATE REQUEST`(id·class·options·default·deadline·evidence·impact)를 읽고 상황을 요약.
2. 선택지별 근거·리스크·되돌림 가능성을 분석. `PROTOCOL.md` 의 hard/soft 규칙 상기(soft 는 deadline 경과 시 default 자동 채택).
3. `### GATE VERDICT` **초안**(choice·rationale·follow-ups)을 제시 — **게시·확정은 사람.** 너는 초안까지만.

---

## §단계 회고 & 단계 리포트 (STEP 4 진입 시)

- 입력: `P{k-1}` 의 `outputs/reports·metrics`, `[CHECKPOINT]`/`### PROGRESS` 코멘트, GATE VERDICT.
- 산출: `templates/phase_report_guide.md` 계약(단일 self-contained HTML, 섹션 id 고정 `summary·goals·gates·constants·risks·artifacts`, 최종 판정 배지 GO/NO-GO/PARTIAL, 사실 평서형·이모지 금지). 모든 수치에 근거(이슈·커밋 SHA·`outputs/` 경로) 링크.
- 위치: MGMT `projects/<slug>/reports/P{k-1}_report.html`. **PR 전 `scripts/lint_report.sh` 통과** (pr-verify 가 재검증).

---

## §단계 완료 검증 체크리스트 (STEP 5 에서)

사람의 "완료" 신호만 믿지 말고 실제 상태를 확인한다 (공개 레포는 토큰 없이 REST 읽기 가능):

```text
[ ] CODE_REPO 의 P{k} dev 이슈(M0..Mj)가 전부 closed (state:done)
[ ] HUMAN GATE 이슈에 사람 GATE VERDICT 코멘트가 실제로 존재
[ ] 단계 최종 산출물 존재 (예: outputs/reports/p{k}_final_report.md, projects/<slug>/reports/P{k}_report.html)
[ ] 확정 수치·결정이 문서화됨 → 다음 단계 입력으로 이월할 불변값 추출(verbatim)
[ ] 미해결/승계 리스크 목록 확보 → P{k+1}.md 입력으로 명시
```

하나라도 비면 완료로 처리하지 않는다.

---

## §상태는 어디에 사는가 (재개 지점 판단)

별도 상태 파일을 만들지 않는다. **진실의 원천은 GitHub 이다** (`PROTOCOL.md §7` 라벨 쿼리):
- "지금 어느 단계?" → MGMT `projects/<slug>/research/status.json` + Current milestone.
- "그 단계 어디까지?" → CODE_REPO 의 `state:*` 라벨 분포(`blocked-human`/`running`/`verify`/`done`).
- "무엇이 확정됐나?" → `projects/<slug>/reports/` 의 리포트, `[Decision]` 이슈.

세션이 끊겨도 이 셋만 읽으면 재개 지점을 복원한다. 새 세션 시작 시 먼저 상태를 읽고 요약하라.

---

## §자동화 (CODE 워크플로 4종 + MGMT + 데몬 — 각자 역할)

CODE 레포 `.github/workflows/` (4종):
- **pr-verify** — PR 의 명세·리포트를 재검증(lint_spec/lint_report·immutables 매니페스트 강제). MGMT 에도 이 워크플로만 존재(문서 PR 게이트).
- **phase-transition** — `phase:P{k}` open 이슈가 0이 되면 P{k+1} 세션 A 킥오프 이슈 자동 생성(+ntfy).
- **gate-notify (아웃바운드)** — GATE REQUEST 감지 시 `blocked-human` 자가치유, soft deadline 경과 시 default 자동 채택, ntfy 푸시.
- **evidence-verify** — `### EVIDENCE` 의 커밋 SHA 체크아웃·pytest 재실행 → VERIFIED/FAILED 로 state 확정.

데몬·기타:
- **gate-watcher (리턴 경로)** — 원격 워크스테이션 systemd 데몬. 사람이 GATE VERDICT 를 게시하면 살아있는 gjc tmux 세션에 "가서 읽어라" 신호를 넣는다(본문 주입 없음). 설치·경보는 `gate-watcher/`.
- **대시보드** — MGMT Actions **`dashboard-data.yml`** 이 `projects/*/project.yml` 을 스캔해 이슈 전량+리포트 목록을 `dashboard/data.json` 으로 굽는다(15분 스케줄+dispatch). `dashboard/index.html` 은 그 파일만 읽으며(브라우저 GitHub API 직호출·CONFIG 하드코딩 폐지), data.json 이 없거나 12h 초과로 오래면 라이브 API 폴백. CODE 레포에 `dashboard-ping.yml`(킷)을 설치하면 이슈 이벤트 시 즉시 갱신. **레지스트리 원천은 project.yml 하나다.**

---

## §불변 규칙 (모든 프로젝트·단계 공통 — 각 P{k}.md 전역 규칙으로 복사)

1. 명세에 없는 것 구현 금지, 다음 단계 선행 금지.
2. 모호성은 스스로 정하지 말고 사람에게(세션 A) / `human_blocked`로(gjc).
3. 사전 고정된 게이트 임계·수치는 결과가 나빠도 변경 금지 (바꾸려면 MGMT `[Decision]` 이슈).
4. 커밋은 마일스톤 단위 `P{k}-M{j}: <요약>`. 대용량 데이터/asset 커밋 금지.
5. dev 이슈 1개 = 마일스톤 1개. 완료 시 EVIDENCE(커밋 SHA·결과 경로) 후 CI VERIFIED 기다렸다 close.
6. HUMAN GATE 마일스톤은 자동 통과 금지.

---

## §[CHECKPOINT] 규약

단계 종료·중요 결정 시, 다음 세션 A 가 회고 입력으로 읽도록 **킥오프 이슈에 `[CHECKPOINT]` 코멘트**를 남긴다: 확정 수치·결정·승계 리스크·다음 단계 착안점. (게이트 판정은 `### GATE VERDICT` 로 별도.)

---

## §재개 원라이너 (사람이 복붙)

```text
{PROJECT} 오케스트레이션을 이어서 한다. {OWNER}/{MGMT_REPO} 의 research-ops/ORCHESTRATOR.md 를 읽고
STEP 0(설정 로드)부터: projects/<slug>/project.yml + status.json + CODE 레포 state:* 라벨로 현재 상태를
복원해 요약 보고한 뒤 다음 할 일을 제안하라. 임의로 진행하지 말 것.
```

단계 전환: **"P{k} 완료. 상태 확인하고 P{k+1} 진행해줘."** 한 줄이면 STEP 5→4 루프가 돈다.

---

## §참조

- 상태·증거·게이트 계약: `PROTOCOL.md` · 세션 B: `SESSION_B.md` · 웹 pro 런타임 계약: `templates/pro_orchestrator_prompt.md`
- 운영 계약(액터 모델): `WORKFLOW.md`
- 계획서 정형화: `templates/plan_refinement.md`·`research_plan_template.md`·`plan_html_guide.md`
- 산출물 뼈대: `templates/phase_spec.md`·`phase_report_guide.md`·`issue_milestone.md`·`issue_dev.md`
- 자동화: `templates/bootstrap_project.sh`([셸])·`setup_phase.sh`([셸])·`workflows/`·`gate-watcher/`
- 링크: `guide/`(셋업 마법사) · `dashboard/`(레지스트리) · 실제 예시 **DGCC**
