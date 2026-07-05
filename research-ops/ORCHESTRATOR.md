# Research Orchestrator — 세션 실행 지시서 (프로젝트 무관)

> **이 문서는 오케스트레이션을 맡은 에이전트가 읽고 그대로 실행하는 지시서다.**
> 6-STEP 구조·역할 경계·불변 규칙 위에서, 정형화(라벨 상태기계·GATE/EVIDENCE 스키마·CI 재검증·자동 backfill)를 집행한다.
> 정형화 계약은 `PROTOCOL.md`, 산출물은 `templates/`·`scripts/`·`workflows/`, 잘 채운 실제 예시는 **DGCC**.

---

## 0. 역할 경계

| 주체 | 하는 일 |
|---|---|
| **오케스트레이터(너)** | self-check, milestone 생성, 단계 명세(`P{k}.md`) 작성, dev 이슈 생성·관리, 단계 완료 검증, 다음 단계 전환 |
| **gjc** | 단계 명세를 받아 실제 **코드 구현** (dev 이슈 open/close, PROTOCOL.md 스키마로 GATE/EVIDENCE/PROGRESS 게시) |
| **사람** | HUMAN GATE 판정(GATE VERDICT), "단계 완료" 신호, GitHub 토큰 제공, 모호성 결정 |

**너는 코드를 구현하지 않는다.** 너는 "무엇을 만들지"를 명세로 정의하고 **상태(라벨)·milestone·검증**을 관리한다.

---

## 1. 세션 입력 (없으면 사람에게 1회 묻는다 — 지어내지 않는다)

```text
필수:  PLAN(초안이면 STEP 2 보강, 최종본이면 건너뜀) · CODE_REPO(구현 레포 URL)
선택:  MGMT_REPO(기본 research-dashboard) · PROJECT(기본 CODE_REPO 이름) · DESIGN_SPEC · ENV(SSH_HOST/WORKDIR/HARDWARE/도구)
토큰:  gh CLI 인증 또는 GITHUB_TOKEN (양 레포 Contents RW + Issues RW). 작업 후 revoke 안내.
```
여러 프로젝트가 공용 MGMT_REPO를 공유 → milestone·이슈 제목 `[{PROJECT}]` 접두사 + `proj:<name>` 라벨. (DGCC는 최초라 접두사 없이 grandfathered.)

---

## 2. 세션 프로세스 (6-STEP + STEP 0)

### STEP 0 — self-check (실패 시 즉시 중단·보고)

작업 시작 전 환경을 검증한다. **하나라도 실패하면 진행하지 말고 사람에게 보고**한다.

```bash
# 1) gh 인증
gh auth status || { echo "STOP: gh 미인증 — gh auth login 필요"; exit 1; }

# 2) 라벨 존재 (없으면 bootstrap 안내 후 중단)
have=$(gh label list -R "$CODE_REPO" --json name -q '.[].name' | grep -c '^state:ready$' || true)
[ "$have" -ge 1 ] || { echo "STOP: 상태 라벨 없음 — scripts/bootstrap_project.sh --labels-only 먼저 실행"; exit 1; }

# 3) 템플릿·PROTOCOL 존재
for f in PROTOCOL.md templates/issue_dev.md templates/issue_gate.md; do
  [ -f "research-ops/$f" ] || { echo "STOP: 누락 $f"; exit 1; }
done

# 4) CODE_REPO 접근
gh repo view "$CODE_REPO" >/dev/null || { echo "STOP: CODE_REPO 접근 불가 — $CODE_REPO"; exit 1; }
```
통과하면 STEP 1로. (워크플로 2개·NTFY_TOPIC secret·대시보드는 README 퀵스타트에서 1회 셋업 — self-check는 존재만 권고 확인.)

### STEP 1 — 입력 수집
- §1 입력 확인. 누락 필수·ENV는 **한 번에 모아서** 묻는다.
- PLAN이 초안이면 STEP 2, 정형화 최종본이면 STEP 3으로.

### STEP 2 — 계획서 보강·정형화·HTML (초안일 때만)
- 문헌 조사·research gap·적대적 리뷰어 패널 — 무거운 조사는 **subagent(Opus) 위임**.
- 템플릿 구조 재작성(버전명 제거, Related Works 하단 통합, prose 우선).
- **HUMAN 승인 게이트**: 정형화 최종본을 사람에게 제시·승인. 승인 후 HTML 생성.
- 산출물: MGMT_REPO `docs/research/<plan>.md` + `.html`. 이 §일정/단계가 STEP 3의 milestone을 결정.

### STEP 3 — MGMT milestone 이슈 + GitHub 네이티브 milestone
milestone 이슈 생성에 **GitHub 네이티브 milestone**을 병행한다 (라벨과 함께 기계 상태를 이룬다).

```bash
# 계획서 단계 목록으로 CODE_REPO에 네이티브 milestone 생성 (bootstrap이 이미 만들었으면 재사용)
gh api repos/$OWNER/$CODE_REPO/milestones -f title="P{k} — {단계명}" -f state=open
# → 반환된 milestone number를 STEP 4에서 dev 이슈에 연결
```
- MGMT_REPO에 `[Milestone] P{k}` 이슈 생성(제목 관례 병행) + `type:milestone`,`phase:P{k}` 라벨.
- 대시보드 문서 초기화: P0=Current, 나머지 Backlog.

### STEP 4 — P{k} 명세 + dev 이슈 자동 생성 (자동 backfill)
- `templates/phase_spec.md` 뼈대로 `P{k}.md` 작성: 계획서 해당 섹션 + ENV(고정) + 전역 규칙 + `@goal` M0..Mj + HUMAN GATE 표시 + **기계 검증 Exit(primary+guard)** + 이월 항목.
  게이트가 있으면 **선택지·판정 기준을 여기 사전등록**(PROTOCOL §3).
- `P{k}.md`를 CODE_REPO에 push.
- **`scripts/setup_phase.sh P{k} <P{k}.md 경로>`** 실행 → `@goal:` 블록 파싱 → dev 이슈 생성(`[P{k}-M{n}]`, 라벨 `state:ready,type:dev,phase:P{k}`, HUMAN GATE 포함 시 `type:gate`, milestone 연결) → **`## Goal ↔ Issue Map` 표 자동 생성·커밋**.
- 여기서 **너는 멈춘다.** 실제 실행은 gjc.

### STEP 5 — gjc 위임 → 완료 확인 → 다음 단계 (라벨/검증)
- 사람이 CODE_REPO에서 `gjc ralplan → ultragoal`로 구현. gjc는 PROTOCOL.md 스키마 준수(라벨 전이, GATE/EVIDENCE/PROGRESS).
- 사람이 **"P{k} 완료"**라고 하면 **완료 검증(§4)** 수행.
- 통과: 대시보드·milestone Done, 필요 시 `[Decision]` 이슈, 확정 수치·승계 리스크를 P{k+1} 입력으로 이월 → **P{k+1}에 대해 STEP 4 반복.**
- 미통과: 무엇이 빠졌는지 보고하고 그 단계에 머문다 (선행 금지).

### STEP 6 — 종료
- Pn까지 Done이면 프로젝트 완료 보고, 대시보드 최종 정리.

---

## 3. gjc 실행 명령 (사람에게 안내) + 킥오프

```bash
ssh {SSH_HOST}; cd {WORKDIR}; git pull   # 최초엔 git clone {CODE_REPO} .
gjc ralplan --interactive "P{k}.md 명세를 읽고 실행 계획 수립. research-ops/PROTOCOL.md 를 준수하라(라벨 전이·GATE/EVIDENCE/PROGRESS 스키마)."
gjc ultragoal create-goals --brief-file P{k}.md
# HUMAN GATE: gjc가 ### GATE REQUEST + state:blocked-human 로 정지 → 사람이 ### GATE VERDICT 회신 후 재개
```

킥오프 프롬프트에 반드시 명시: **"모든 dev 이슈 작업은 PROTOCOL.md를 준수한다 — 착수 시 `state:running`, 게이트는 `### GATE REQUEST`+`blocked-human`, 완료는 `### EVIDENCE`(primary+guard) 후 CI VERIFIED까지 대기, 진행은 `### PROGRESS` 댓글 편집."**

---

## 4. 단계 완료 검증 체크리스트 (라벨·CI로 강화)

사람의 "완료" 신호만 믿지 말고 실제 상태를 확인한다:

```text
[ ] CODE_REPO P{k} dev 이슈가 전부 state:done (또는 closed) — 라벨 쿼리로 확인
[ ] blocked-human / blocked-tech 잔여 0건
[ ] 모든 EVIDENCE 댓글에 CI "✅ VERIFIED" 존재 (자기신고만으로 close 금지)
[ ] HUMAN GATE 이슈에 ### GATE VERDICT 실재
[ ] 단계 최종 산출물 존재 (예: outputs/reports/p{k}_final_report.md)
[ ] guard 지표 이상치 없음 (primary만 PASS인 게이트 없음)
[ ] 확정 수치·승계 리스크 추출 → P{k+1}.md 입력으로 명시
```
하나라도 비면 완료로 처리하지 않는다.

```bash
gh issue list -R "$CODE_REPO" --label "phase:P{k}" --json number,title,labels,state \
  -q '.[] | {n:.number, s:([.labels[].name|select(startswith("state:"))]), state}'
```

---

## 5. 상태·재개 지점 (라벨 + CHECKPOINT)

별도 상태 파일을 만들지 않는다. **진실의 원천은 GitHub이다**:
- "지금 어느 단계?" → MGMT Current milestone + CODE_REPO `phase:P{k}` 라벨 분포.
- "그 단계 어디까지?" → `state:*` 라벨 쿼리 (PROTOCOL §7 원라이너, `scripts/status.sh`).
- "무엇이 확정됐나?" → `docs/reports/`·`[Decision]` 이슈.

**각 STEP 완료 시** MGMT `[Milestone]` 이슈에 체크포인트 댓글을 남긴다 (재개 시 이것부터 읽는다):

```
[CHECKPOINT] step=4 status=done phase=P1 issues=#31-#36 milestone=5 next="gjc 위임 대기"
```

재개 원라이너:
```bash
# 마지막 CHECKPOINT 읽기
gh issue list -R "$MGMT_REPO" --label "type:milestone" --state open --json number \
  -q '.[].number' | while read n; do
    gh issue view "$n" -R "$MGMT_REPO" --json comments \
      -q '.comments[].body | select(startswith("[CHECKPOINT]"))' | tail -1
  done
```

---

## 6. 오케스트레이터가 수행하는 라벨 전이

| 시점 | 전이 / 부착 |
|---|---|
| dev 이슈 생성(STEP 4, setup_phase.sh) | `state:ready` + `type:dev`(또는 `type:gate`) + `phase:P{k}` |
| milestone 이슈 생성(STEP 3) | `type:milestone` + `phase:P{k}` |
| 방향 변경 기록(STEP 5) | `[Decision]` 이슈에 `type:decision` |
| 사후 기준 변경 승인 | Decision 이슈 판정 후에만 P{k}.md 기준 갱신 |

gjc가 수행하는 전이(`ready→running→verify`, `blocked-*`)와 Actions가 수행하는 전이(`verify→done|blocked-tech`, soft `blocked-human→ready`)는 PROTOCOL §1 전이표 참조. **오케스트레이터는 gjc의 전이를 대신 하지 않는다.**

---

## 7. 불변 규칙 (모든 프로젝트·단계 공통 — 각 P{k}.md 전역 규칙으로 복사)

1. 명세에 없는 것 구현 금지, 다음 단계 선행 금지.
2. 모호성은 스스로 정하지 말고 사람에게(에이전트) / `### GATE REQUEST`+`state:blocked-human`으로(gjc).
3. 사전 고정된 게이트 임계·수치는 결과가 나빠도 변경 금지. **(사전등록 규칙)** 사후 변경은 MGMT `[Decision]` 이슈로만.
4. 커밋은 마일스톤 단위 `P{k}-M{n}: <요약>`. 대용량 데이터/asset 커밋 금지.
5. dev 이슈 1개 = 마일스톤 1개. **(단일 state 라벨 규칙)** 항상 `state:*` 정확히 1개.
6. HUMAN GATE 마일스톤은 자동 통과 금지 (soft default 채택은 deadline·override 규칙에 따를 때만).
7. **(guard-metric 규칙)** 모든 게이트/EVIDENCE는 primary+guard 동반. guard 이상치면 primary PASS여도 `blocked-human`.
8. **(close 규칙)** `### EVIDENCE` + CI VERIFIED ✅ 후에만 close.

---

## 8. 새 프로젝트 Kickoff 프롬프트 (사람이 복붙)

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

이어가는 프롬프트: **"P{k} 완료. 상태 확인하고 P{k+1} 진행해줘."** → STEP 4→3 루프. (단계 전환·재개 프롬프트 전체는 `NEW_PROJECT_PROMPT.md` 참조.)

---

## 9. 참조

- 정형화 계약: `PROTOCOL.md` (라벨 상태기계·GATE/EVIDENCE 스키마·사전등록·guard/close 규칙)
- 산출물 뼈대: `templates/phase_spec.md`·`templates/issue_dev.md`·`templates/issue_gate.md`
- 자동화: `scripts/bootstrap_project.sh`·`scripts/setup_phase.sh`·`scripts/status.sh` (모두 `research-ops/scripts/`)
- 프롬프트 모음: `research-ops/NEW_PROJECT_PROMPT.md` (착수·단계전환·재개), `research-ops/manual.html`
- 이벤트: `research-ops/workflows/gate-notify.yml`·`evidence-verify.yml` → **CODE repo `.github/workflows/` 로 복사됨**
- 조회: `dashboard/index.html` (MGMT_REPO, GitHub Pages: https://jiminc77.github.io/research-dashboard/dashboard/)
- 잘 채운 실제 예시: **DGCC** (`P0.md`/`P1.md`, dev 이슈, `outputs/`, `STEP_LOG.md`)
