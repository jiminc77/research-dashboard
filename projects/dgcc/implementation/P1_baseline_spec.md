# P1 — Black-box Baseline 구축 명세 (요약)

**Canonical 명세: [`DGCC/P1.md`](https://github.com/jiminc77/DGCC/blob/main/P1.md)** — gjc(ralplan → ultragoal) 실행 brief. 충돌 시 canonical 우선.

## 목적

P0의 `DLOLabEnv` 위에 HACMan-style black-box contact critic baseline을 T1–T2에서 안정 학습. 이 baseline은 P2 probing의 **진단 대상**이자 P3의 **주 대조군** — 품질 기준은 SOTA가 아니라 "재현 가능하고 진단 가능한, 비자명하게 학습된 critic".

## 입력 (P0 확정 사항)

- Primary sim: **DLO-Lab** (`gs.ti_float` alias, pin 고정, NaN 규약 필수) · MuJoCo adapter frozen
- 불변 수치: ε_succ=0.05·L · settle 1e-3/10000 · grasp realism ±1node/5% · **D = 길이 정규화 correspondence L2 + orientation canonicalization** (Chamfer는 보고용) · K=32, M=8
- 조정 허용 (기록 의무, M6에서 최종 잠금): reward α=10, c_step=0.1, R_succ=5 · RL 하이퍼파라미터
- **승계 리스크 6건** → P1.md §4 반영표 (settle 경계, shape coupling 열린 가설, DLO-Lab 리스크, metric 경계, template 이질성, 렌더링 노트)

## Milestones (DGCC repo issue #9–#15)

| M | 내용 | Gate |
|---|---|---|
| M0 | T1(3종)/T2(goal 생성기, train 500/val 50/eval 100) task·episode 레이어, 처리량 프로브 (n_envs 64/128/256) | |
| M1 | 네트워크 (chain encoder + twin per-point critic + per-point actor) + TD3 루프 (double-Q decoupling, L_actor 전-후보) | |
| M2 | 안정성 계측 (Q 통계·과대추정 갭·argmax entropy·NaN 카운터) + T1-a 스모크 + random 참조선 | 스모크 2회 실패 시 human |
| M3 | T1 본 학습 3 task × 3 seed (run당 1e5 transitions) — per-template 분해 보고 | 판정 미달 시 human |
| M4 | T2 본 학습 3 seed (run당 3e5) — held-out 100 goals 최종 1회 평가, HER는 조건부 human 승인제 | 판정 미달 시 human |
| M5 | **Latent 추출 API + 체크포인트 MANIFEST** (P2 인수 인터페이스) | |
| M6 | 기준 성능 리포트 + **reward 상수 최종 잠금** | ✔ HUMAN sign-off |

## P2로의 인수물

체크포인트 MANIFEST · latent API (`docs/latent_api.md`) · random 참조선 · T1/T2 기준 성능표 · P2 승계 리스크 목록 (`p1_final_report.md` §6-7).
