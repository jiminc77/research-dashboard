<!--
자기완결형 dev 이슈 템플릿 (research-ops v2, BMAD 스토리 차용)
원칙: gjc가 이 이슈 하나만 읽고 실행 가능해야 한다. 외부 문서 왕복 없이 착수 가능하도록 컨텍스트를 인용한다.
라벨: state:ready, type:dev(또는 type:gate), phase:P{k}  — setup_phase.sh가 부착
-->

goal-id: P{N}-M{k}
phase: P{N}
depends-on: [P{N}-M{k-1}]        # 선행 goal, 없으면 []
milestone: P{N} — {단계명}        # GitHub 네이티브 milestone

## 목표
{한두 문장 — 이 goal이 무엇을 완성하는가}

## 컨텍스트 (P{N}.md 앵커 인용)
> P{N}.md `@goal: M{k}` 블록에서 인용:
> {해당 스펙 문단을 그대로 붙여넣는다}
>
> 관련 공통 스펙: {P{N}.md §5–§8 중 해당 부분, 또는 "지정 없음"}

**출처 규칙: P{N}.md에 근거가 없으면 "지정 없음"이라고 명기하고 추측하지 않는다.** 모호하면 `### GATE REQUEST`로 물어본다.

## 인수 기준 (Acceptance Criteria)
- **AC1**: {기계 검증 가능한 조건 — 무엇이 존재/통과해야 하는가}
- **AC2**: {...}
- **AC3**: {...}

## 작업 체크리스트 (각 항목에 AC 매핑)
- [ ] {작업 1} (AC: 1)
- [ ] {작업 2} (AC: 1, 2)
- [ ] {작업 3} (AC: 3)
- [ ] 커밋 `P{N}-M{k}: <요약>` push (origin/main)

## Exit (완료 조건)
- 테스트: `uv run pytest -q {대상 파일/마커}` → 전부 통과 (exit 0)
- 지표:
  - **primary**: {지표명} {임계, 예: accuracy >= 0.65}
  - **guard**: {가드 지표명} {정상 범위, 예: success_rate > random(0.04)}   # 필수
- 산출물: `outputs/{metrics,plots,reports}/...` 경로 명시

## EVIDENCE 요구 (PROTOCOL.md §4)
완료 시 `### EVIDENCE` 댓글: goal-id / commits(origin/main 실재 SHA) / tests(cmd+result+exit) / artifacts / metrics(**primary+guard**) / deviations.
게시와 동시에 `state:running → verify` 전환. **CI VERIFIED ✅ 후에만 close.**

## 금지 사항
- 명세에 없는 것 구현 금지, 다음 goal 선행 금지.
- 게이트 임계·수치 임의 변경 금지 (사후 변경은 MGMT `[Decision]` 이슈로만).
- 대용량 데이터/asset 커밋 금지.
- guard 이상치를 primary PASS로 덮지 말 것 — 발견 즉시 `### GATE REQUEST`(class:hard).
- 진행 보고는 `### PROGRESS` 댓글 **편집** (새 댓글은 GATE/EVIDENCE/VERDICT만).

<!-- HUMAN GATE goal인 경우 아래를 사용 (type:gate 라벨) — 상세는 templates/issue_gate.md
     산출물(근거) 생성 후 ### GATE REQUEST 게시 + state:blocked-human 부착, 사람 결정 대기. 자율 결정 금지. -->
