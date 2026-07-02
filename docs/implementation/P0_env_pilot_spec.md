# P0 — 환경·파일럿 명세 (요약)

**Canonical 명세: [`DGCC/P0.md`](https://github.com/jiminc77/DGCC/blob/main/P0.md)** — gjc(gajae-code)가 ralplan → ultragoal로 실행하는 brief. 이 문서는 대시보드용 요약이며, 충돌 시 canonical이 우선한다.

## 목적

RL 이전 인프라 + 파일럿 게이트: (1) 시뮬레이터 2종 실구동 비교, (2) rope state/action 인터페이스·transition 로깅, (3) δm 파이프라인, (4) 게이트 G1/G2 측정 자료 생성. **게이트 판정과 primary sim 결정은 사람이 한다.**

## Milestones (P0.md의 @goal 블록과 1:1, DGCC repo issue #1–#8)

| M | 내용 | HUMAN GATE |
|---|---|---|
| M0 | 작업공간 부트스트랩, 공통 인터페이스/스키마 골격 | |
| M1 | DLO-Lab + MuJoCo cable bring-up, 스모크 테스트, 비교 보고서 | |
| M2 | **Primary sim 결정** | ✔ |
| M3 | (p,u) primitive (grasp→move→release→settle), 파지 노이즈/실패 모델, 파라미터 스윕 API | |
| M4 | Transition 로깅 + δm 파이프라인 (K=32 재표본, DCT M=8, Φ 불변성 테스트) | |
| M5 | 이원 goal + 길이 정규화 Chamfer, **G2 측정** (ΔD vs Δ‖c_g‖ Spearman ρ, 임계 0.9) | ✔ |
| M6 | **G1 측정** — stiffness ×{0.5,1,2} 효과크기 (Cohen's d) | ✔ |
| M7 | 수치 고정표 + P0 종료 보고서 (`p0_final_report.md`) | ✔ (sign-off) |

## 실행 환경

`ssh AILAB-simx-remote`, `/home/simx2204/Workspaces/DGCC`, RTX 6000 · Ubuntu 22.04 · headless (MUJOCO_GL=egl), Python 3.12 + uv.

## 핵심 원칙 (gjc 전역 규칙 발췌)

명세 밖 구현 금지 (RL/baseline/probe는 P1+) · 모호성은 `human_blocked`로 사람에게 · 게이트 임계 변경 금지 · milestone 단위 커밋 `P0-M<k>: ...` · 대용량 데이터/asset 커밋 금지.

## 게이트 이후

- G1/G2 판정과 수치 확정 결과는 [`docs/reports/P0_pilot_gates.md`](../reports/P0_pilot_gates.md)에 기록.
- 사람 sign-off 후 P1 명세 작성 (별도 문서).
