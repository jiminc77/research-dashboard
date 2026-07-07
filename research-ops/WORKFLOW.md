# Research Ops Workflow — 운영 계약서 (프로젝트 무관, 현행판)

> 연구를 GitHub Issues/Projects 로 관리하는 **재사용 운영 모델**. 어떤 프로젝트든 동일하게 적용된다.
> 세션 실행 절차·개념 정본은 `ORCHESTRATOR.md`, 상태·증거·게이트 계약은 `PROTOCOL.md`,
> 웹 pro 런타임 계약은 `templates/pro_orchestrator_prompt.md`. 실제 예시는 **DGCC**.

용어: `MGMT_REPO`(관리/대시보드) · `CODE_REPO`(구현) · `PROJECT`/`<slug>` · `P{k}`(단계) · `M{j}`(단계 내 마일스톤).

---

## 1. 3-액터 + 자동화 모델

| 액터 | 무엇 | 어디에 |
|---|---|---|
| **사람** | 킥오프·민감값 제공, HUMAN GATE 판정(GATE VERDICT), 세션 B 부팅, **PR merge** | GitHub |
| **세션 A** | 회고·명세·리포트·status·이슈 발행 계획·세션 B 지시서. 두 변형: **웹 pro**(no-shell·REST/PR) / **셸**(gh CLI). 게이트 코파일럿 | MGMT (문서·리포트·status·이슈) |
| **세션 B + gjc** | 세션 B가 원격에서 gjc 부팅·감시. **gjc 가 실제 코드 구현**·CODE main 직접 push·dev 이슈 self open/close | CODE (코드·dev 이슈) |

자동화(사람 개입 없이 돎):
- **워크플로 4종**(CODE `.github/workflows/`): `pr-verify`(PR 명세·리포트 재검증; MGMT 에도 이것만) · `phase-transition`(단계 완료 시 킥오프 이슈 생성) · `gate-notify`(아웃바운드: GATE REQUEST 자가치유·soft default 채택·ntfy) · `evidence-verify`(EVIDENCE 커밋 재검증).
- **gate-watcher**(리턴 경로): 원격 systemd 데몬. 사람이 GATE VERDICT 게시 → 살아있는 gjc tmux 에 "가서 읽어라" 신호(본문 주입 없음). 설치·경보는 `gate-watcher/`.
- **ntfy**: 킥오프·게이트·완료를 폰으로 푸시.

한 문장: **MGMT = "어느 단계/왜"(세션 A·PR), CODE = "그 단계 실제 작업"(gjc·main), 데몬/워크플로 = 둘을 잇는 자동화.**

**gjc 는 자동 시작되지 않는다** — 사람이 세션 A가 출력한 세션 B 지시서를 새 세션 B 에 붙여넣어 부팅한다.

---

## 2. 상태 = 라벨 (진실의 원천은 GitHub)

- 별도 상태 파일 없음. dev 이슈는 **항상 정확히 1개 `state:*` 라벨** (`PROTOCOL.md §1`).
  `ready → running → verify → done`, 분기 `blocked-human`/`blocked-tech`.
- "지금 어느 단계?" → MGMT `projects/<slug>/research/status.json` + Current milestone.
- "어디까지?" → CODE `state:*` 라벨 분포. "무엇이 확정?" → `projects/<slug>/reports/`·`[Decision]` 이슈.

---

## 3. 게시 = PR (MGMT)

- **MGMT 문서·리포트·status 는 branch+PR 로만.** 직접 main push 금지. `pr-verify` green 후 **사람 merge**. (MGMT 보호 브랜치, 필수 체크 `pr-verify`.)
- 웹 pro 는 이슈 생성도 PR 규율(레포별 1 PR, dev 이슈는 merge/확인 후). 셸 세션은 이슈 스크립트 가능하나 문서/리포트/status 는 위 규율.
- CODE 는 gjc 가 main 직접 push. CODE 브랜치 보호는 P1 종료 시점 도입 예정.

---

## 4. 흐름 다이어그램 (한 단계 = 이 순서 반복)

```
[사람] 킥오프/재개 프롬프트 (민감값 제공)
   │
[세션 A] STEP0 설정 로드(projects/<slug>/project.yml) → 회고(전 단계 리포트·CHECKPOINT·VERDICT)
   │         → P{k-1} 리포트 HTML + status.json (PR)
   │         → P{k}.md 명세(@goal·primary+guard·불변값 verbatim) → CODE push
   │         → dev 이슈 M0..Mj 발행(type:dev·phase:P{k}·state:ready)
   │         → 세션 B 지시서(SESSION_B.md 값 채움) 복사 블록 출력 → 정지
   ▼
[사람] 세션 B 지시서를 새 세션 B에 붙여넣어 부팅
   ▼
[세션 B] 원격 ssh·tmux·모델설정 → gjc ralplan → ultragoal create-goals
   ▼
[gjc] dev 이슈 순차 처리: running → EVIDENCE(primary+guard) → verify
   │        └ evidence-verify CI가 커밋 재검증 → VERIFIED ✅ → gjc close(done)
   │        └ HUMAN GATE: GATE REQUEST + blocked-human 후 정지
   ▼
[사람] ntfy 수신 → 이슈에 GATE VERDICT (세션 A 코파일럿이 초안 보조)
   │        └ gate-watcher가 gjc tmux에 "읽어라" 신호 → gjc 재개·집행
   ▼
[phase:P{k} open 이슈 0] → phase-transition이 P{k+1} 킥오프 이슈 자동 생성 + ntfy
   ▼
[사람] "P{k} 완료" → [세션 A] 완료검증 → status/milestone Done(PR) → 다음 STEP4
```

---

## 5. 사람 접점 (사람이 직접 하는 일만)

1. **킥오프/재개** — 세션 A 에 프롬프트 붙여넣기 + 민감값(SSH_HOST/WORKDIR/MODEL_*/NTFY_TOPIC) 제공.
2. **세션 B 부팅** — 세션 A 가 출력한 지시서를 새 세션 B 에 붙여넣기 (gjc 는 자동 시작 안 됨).
3. **HUMAN GATE 판정** — 이슈에 `### GATE VERDICT` 게시 (soft 는 deadline 내 override, hard 는 무기한 대기).
4. **PR merge** — `pr-verify` green 확인 후 MGMT PR merge. (세션 A 는 merge 안 함.)
5. **"P{k} 완료" 신호** — 세션 A 가 완료 검증 후 다음 단계로.
6. **NTFY_TOPIC secret 등록**·**gate-watcher 설치**(최초 1회, 로컬 셸/원격) — `gate-watcher/README`.

---

## 6. 불변 규칙 (모든 Phase 공통 — 각 P{k}.md 전역 규칙으로 복사)

1. 명세에 없는 것 구현 금지 (다음 단계 선행 금지).
2. 모호성은 사람에게(세션 A) / `human_blocked`로(gjc).
3. 사전 고정된 게이트 임계·수치는 결과가 나빠도 변경 금지 (바꾸려면 MGMT `[Decision]` 이슈).
4. 커밋은 마일스톤 단위 `P{k}-M{j}: <요약>`. 대용량 데이터/asset 커밋 금지.
5. dev 이슈 1개 = 마일스톤 1개. EVIDENCE 후 CI VERIFIED 기다렸다 close.
6. HUMAN GATE 마일스톤은 자동 통과 금지.

---

## 7. 다중 프로젝트

하나의 공용 MGMT_REPO 가 여러 프로젝트를 담는다 → **제목 `[{PROJECT}]` 접두사** + 라벨 `proj:<name>`, 경로 `projects/<slug>/`. 대시보드는 `CONFIG.projects` 레지스트리로 사람이 등록(→ `dashboard/`). (최초 프로젝트 DGCC 는 grandfathered.)

> 세션에서 이 워크플로우를 자동 실행하는 절차·개념 정본은 `ORCHESTRATOR.md`.
