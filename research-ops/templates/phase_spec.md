# {PROJECT} P{N} — {단계 이름} 구현 명세 (gjc 실행용)

작성일: {DATE} · 대상 실행자: gajae-code (gjc), ralplan → ultragoal
연구 배경: `{MGMT_REPO}/projects/{project}/research/{PLAN_FILE}` (참고용 — 충돌 시 **본 명세가 우선**)

> 이 문서의 첫 `@goal:` 이전 내용은 **모든 goal에 적용되는 전역 컨텍스트·제약**이다.
> 작성 지침·계약: `research-ops/PROTOCOL.md`, 세션 절차: `research-ops/ORCHESTRATOR.md`. 잘 채운 예시: `DGCC/P0.md`.
> 이전 단계에서 이월된 확정 수치·승계 리스크가 있으면 아래 §0/전역 규칙에 반드시 반영한다.

---

## 0. 이 단계의 목적 (2~3문장)

{이 Phase가 무엇을 만들고, 무엇을 판정하며, 다음 단계에 무엇을 넘기는지}

## 1. 실행 환경 (고정 — 변경 금지)

- 접속: `ssh {SSH_HOST}`
- 작업 루트: `{WORKDIR}` (이미 존재; 이 디렉토리 밖 파일 생성·수정 금지)
- HW/OS: {GPU}, {OS}, headless
- Python/도구: {PY_VER}, {ENV_TOOL}
- 렌더링/특이사항: {RENDER}
- git 원격: `{CODE_REPO_URL}` (branch: `{BRANCH}`)
- 금지: sudo, 시스템 패키지 변경, 드라이버/CUDA 변경, 타 사용자 디렉토리 접근

## 2. 전역 규칙 (PROTOCOL.md 계약을 이 단계에 맞게 구체화)

1. 명세에 없는 것 구현 금지. 특히 범위 밖: {이 Phase에서 만들면 안 되는 것 나열}.
2. 모호성은 스스로 정하지 말고 `gjc ultragoal classify-blocker --classification human_blocked --evidence "<질문+선택지>"` 후 정지. `STEP_LOG.md`에도 기록.
3. HUMAN GATE 마일스톤({목록})은 산출물 생성 후 반드시 정지, 사람 결정 대기.
4. 게이트 임계·수치({핵심 임계 나열})는 결과가 나빠도 변경 금지.
5. 커밋: 마일스톤 단위 `P{N}-M<k>: <요약>`, push. 대용량 데이터/asset 커밋 금지.
6. 이슈 연동: 완료 시 해당 issue에 evidence 코멘트 후 close (`gh` 미인증이면 STEP_LOG에 기록만, 정지하지 않음).
7. 재현성: 모든 스크립트는 `--seed`+yaml config, 결과에 config·commit hash 메타 포함.
8. 검증: Exit 기준은 가능한 한 `pytest`로 기계 검증. 산출물 `outputs/{metrics,plots,reports}`.
9. `STEP_LOG.md`에 모든 goal 시작/완료/블로커/질문을 timestamp와 기록.

## 3. Goal ↔ GitHub Issue 매핑 (setup_phase.sh 실행 후 실제 번호로 확정)

| Goal | 코드 레포 issue |
|---|---|
| M0 | #? |
| M1 | #? |
| … | … |

## 4. 디렉토리 구조 (M0에서 생성 — 이 구조 밖 파일 금지)

```
{작업 루트}/
  P{N}.md  README.md  STEP_LOG.md  ...
  src/...
  scripts/...
  tests/...
  outputs/{data,metrics,plots,reports}/   # data는 .gitignore
```

## 5~8. (필요 시) 공통 인터페이스·스펙 정의

{이 Phase가 쓰는 공통 자료구조·수식·프로토콜을 여기에. P0의 §5–§8 참고.}

---

## 9. gjc 실행 순서 (사람 참고용)

```
cd {WORKDIR}
gjc ralplan --interactive "P{N}.md 명세를 읽고 실행 계획 수립"
gjc ultragoal create-goals --brief-file P{N}.md
```

---

@goal: M0 — {마일스톤 제목}

**목표:** {한두 문장}

구현할 것: {구체 목록}

구현 방법: {접근}

구현하면 안 되는 것: {이 마일스톤에서 금지}

Exit(다음 goal 진행 조건):
- [ ] {기계 검증 가능한 조건 — pytest/로그/산출물}
- [ ] 커밋 `P{N}-M0: ...` push, 해당 issue 처리

@goal: M1 — {마일스톤 제목}

**목표:** ...

구현할 것: ...
구현하면 안 되는 것: ...
Exit:
- [ ] ...

@goal: M2 — {HUMAN GATE 예시}

**HUMAN GATE — {무엇을 사람이 결정}.** gjc는 근거 자료만 만들고 정지한다.

할 것: {근거 산출물} 생성 → `classify-blocker --classification human_blocked --evidence "M2: <결정 필요 + 선택지>"` 후 정지.

구현하면 안 되는 것: 자율 결정, 결정을 가정한 선행 구현.

Exit:
- [ ] 사람 결정이 issue/STEP_LOG에 기록된 후에만 다음 goal 진행

{... 필요한 만큼 @goal 반복 ...}

@goal: M{k} — {단계 종료 보고 / HUMAN sign-off}

**목표:** 이 Phase 결과 종합 + 다음 단계에 넘길 수치·결정 고정, 사람 최종 승인.

Exit:
- [ ] `outputs/reports/p{N}_final_report.md` 생성
- [ ] 사람 승인 후 issue close, 커밋 push
- [ ] **P{N} 종료 — P{N+1}은 별도 명세**
