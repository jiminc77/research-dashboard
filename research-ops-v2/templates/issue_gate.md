<!--
GATE 이슈/댓글 템플릿 (research-ops v2). PROTOCOL.md §2 스키마를 그대로 쓴다.
- HUMAN GATE goal은 dev 이슈에 type:gate 라벨. 게이트가 열릴 때 아래 ### GATE REQUEST 댓글을 게시.
- gjc는 게시와 동시에 state:blocked-human 라벨을 부착한다 (자가치유는 gate-notify.yml).
-->

# GATE 이슈 헤더 (dev 이슈 본문 상단, type:gate)

goal-id: P{N}-M{k}
phase: P{N}
milestone: P{N} — {단계명}

**HUMAN GATE — {무엇을 사람이 결정하는가}.** gjc는 근거 산출물만 만들고 정지한다.
할 것: {근거 산출물 경로} 생성 → 아래 `### GATE REQUEST` 댓글 게시 + `state:blocked-human` 부착 후 정지.
사전등록: 선택지·판정 기준은 이미 P{N}.md `@goal: M{k}`에 등록되어 있어야 한다 (사후 변경은 `[Decision]` 이슈로만).

---

## 예시 1 — class: hard (go/no-go, 무기한 대기)

```
### GATE REQUEST
id: P1-M5-G1
class: hard
question: P1 베이스라인을 P2로 진행시킬 것인가 (go/no-go)?
options:
- (A) go — accuracy 0.71 >= 임계 0.65, guard success_rate 0.42 > random 0.04
- (B) no-go — baseline 재설계 (guard가 아슬아슬, 데이터 편향 의심)
evidence: outputs/reports/p1_baseline.md, outputs/metrics/p1_baseline.json
impact: 되돌리기 어려움 — P2 전체 설계가 이 baseline 위에 쌓인다. 단계 방향 결정.
```
> hard는 default/deadline 없음. 6시간마다 리마인더 푸시. 사람이 `### GATE VERDICT` 회신할 때까지 정지.

## 예시 2 — class: soft (되돌릴 수 있음, deadline 후 default 자동 채택)

```
### GATE REQUEST
id: P1-M3-G2
class: soft
question: 평가 배치 크기를 무엇으로 고정할까?
options:
- (A) 32 — 안전, VRAM 여유, 재현 쉬움
- (B) 64 — 2배 빠름, VRAM 경계
default: A            # 가장 보수적/되돌릴 수 있는 선택지
deadline: 2026-07-06T09:00Z
evidence: outputs/metrics/batch_sweep.json (32/64 동등 정확도, 64는 VRAM 92%)
impact: 되돌릴 수 있음 — config 한 줄. 결과 지표 불변.
```
> soft는 deadline 경과 시 gate-notify(schedule)가 `default (A) ADOPTED` 댓글 + `blocked-human → ready`.
> 사람은 deadline 전까지 언제든 `### GATE VERDICT`로 override 가능.

## 사람 회신 예시 — GATE VERDICT

```
### GATE VERDICT
id: P1-M5-G1
choice: A
rationale: guard 여유 충분(0.42 >> 0.04), baseline 신뢰. P2 진행.
follow-ups:
- P2 명세에 "데이터 편향 점검"을 승계 리스크로 명시할 것
```
> 회신 후 gjc/오케스트레이터가 `blocked-human → ready` 전환 후 choice를 집행.

---

## 규칙 요약
- gjc: GATE REQUEST 게시 == `state:blocked-human` 부착 (동시).
- soft: default·deadline 필수. hard: 무기한 + 6h 리마인더.
- go/no-go·임계 변경·데이터 폐기·아키텍처 방향 = 반드시 hard.
- 판정은 `### GATE VERDICT`(choice/rationale/follow-ups)로만.
