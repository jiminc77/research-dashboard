# Research Ops Workflow — 운영 계약서 (프로젝트 무관)

> **상태 표현의 정본은 `PROTOCOL.md`의 라벨 상태기계다.** 본 문서의 `human_blocked` 산문 관례·수동 보드 조작 서술은 라벨·자동화 도입 이전의 맥락이며, 3층위 모델(Docs=지식 / Issues=상태 / Code repo=증거)과 이슈 3종 규약은 그대로 유효하다.

> 연구를 GitHub Issues/Projects로 관리하는 **재사용 운영 모델**. 어떤 프로젝트든 동일하게 적용된다.
> 세션 실행 절차는 `ORCHESTRATOR.md`, 산출물 뼈대는 `templates/`. 잘 채운 실제 예시는 **DGCC**.

용어: `MGMT_REPO`(관리/대시보드 레포) · `CODE_REPO`(구현 레포) · `PROJECT`(약칭) · `P{k}`(단계) · `M{j}`(단계 내 마일스톤).

---

## 1. 멘탈 모델 — 3개 층위를 절대 섞지 않는다

| 층위 | 어디에 | 무엇 | 누가 관리 |
|---|---|---|---|
| **연구 흐름** | MGMT_REPO 이슈 | 전체 계획의 큰 단계 (P0..Pn = milestone) | 사람 (단계 전환 시) |
| **개발 작업** | CODE_REPO 이슈 | 한 단계의 세부 작업 (M0..Mj = dev issue) | gjc (자동 open·close), HUMAN GATE만 사람 |
| **지식** | MGMT_REPO docs/ | 계획서·명세·리포트 | 문서로만, 이슈엔 링크만 |

한 문장: **MGMT_REPO = "어느 단계", CODE_REPO = "그 단계의 실제 작업", docs = "왜/어떻게".**

이슈는 3종류만: **Milestone**(단계) · **Decision**(방향 전환 기록) · **Experiment Result**(결과가 판정에 영향 줄 때).

---

## 2. 한 단계(Phase)의 생애주기 — 이 순서를 반복한다

```
① 명세 작성   templates/phase_spec.md 뼈대로 P{k}.md 작성
              (계획서의 해당 단계 섹션 + 실행 환경(고정) + 전역 규칙 + @goal 마일스톤)
② 이슈 생성   templates/setup_phase.sh 로:
                - MGMT_REPO에 [Milestone] P{k} 1개 (이미 있으면 재사용)
                - CODE_REPO에 dev 이슈 M0..Mj — @goal 순서와 1:1
              → dev 이슈 번호를 P{k}.md의 Goal↔Issue 매핑표에 반영
③ 보드 반영   MGMT_REPO Project 보드에서 P{k}를 Current로 (이전 단계 Done)
④ 실행        CODE_REPO에서 gjc ralplan → ultragoal create-goals --brief-file P{k}.md
              gjc가 dev 이슈를 순서대로 처리, 끝낼 때마다 evidence 코멘트 후 close
⑤ HUMAN GATE  gjc가 human_blocked로 멈추면 사람이 해당 dev 이슈에 결정 코멘트 → 재개
⑥ 단계 종료   dev 이슈 전부 close → 완료 검증 → P{k} milestone Done
              → 방향 변경 시 Decision 이슈 1개 → 확정 수치·승계 리스크를 P{k+1} 입력으로 → ①
```

**사람이 직접 하는 일은 ③, ⑤, ⑥ 뿐.** 개발 이슈 open/close(④)는 gjc가 한다. 오케스트레이터는 ①②⑥을 자동화한다.

---

## 3. HUMAN GATE 규칙

- 명세가 답하지 않는 판단(수치 확정, 도구 선택, 게이트 통과 여부 등)은 **스스로 정하지 않는다.**
- gjc는 근거 자료를 `outputs/`에 만들고 `gjc ultragoal classify-blocker --classification human_blocked --evidence "..."` 로 정지.
- 사람은 해당 dev 이슈에 결정을 코멘트로 남기고 재개.
- 명세에 **HUMAN GATE로 표시된 마일스톤은 자동 통과 금지.**

---

## 4. 불변 규칙 (모든 Phase 공통 — 각 P{k}.md 전역 규칙으로 복사)

1. 명세에 없는 것 구현 금지 (다음 단계 선행 금지).
2. 모호성은 사람에게(에이전트) / human_blocked로(gjc).
3. 사전 고정된 게이트 임계·수치는 결과가 나빠도 변경 금지.
4. 커밋은 마일스톤 단위 `P{k}-M{j}: <요약>`. 대용량 데이터/asset 커밋 금지.
5. dev 이슈 1개 = 마일스톤 1개. 완료 시 evidence(커밋 해시·결과 경로) 코멘트 후 close.

---

## 5. 다중 프로젝트

하나의 공용 MGMT_REPO가 여러 프로젝트를 담을 수 있다 → **milestone 제목에 `[{PROJECT}]` 접두사**로 구분.
대시보드 문서(README·implementation plan)는 프로젝트별 섹션 또는 별도 파일로 분리한다.
(최초 프로젝트 DGCC는 접두사 없이 grandfathered.)

---

## 6. 템플릿·자동화 파일

- `templates/phase_spec.md` — 단계 명세 P{k}.md 뼈대.
- `templates/issue_milestone.md` — MGMT_REPO milestone 이슈 본문 뼈대.
- `templates/issue_dev.md` — CODE_REPO dev 이슈 본문 뼈대.
- `templates/bootstrap_project.sh` — 새 프로젝트의 전체 milestone(P0..Pn) 일괄 생성.
- `templates/setup_phase.sh` — 한 단계의 dev 이슈(M0..Mj) 생성.

> 세션에서 이 워크플로우를 자동 실행하는 절차는 `ORCHESTRATOR.md`를 따른다.
