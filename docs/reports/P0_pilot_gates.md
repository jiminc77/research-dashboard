# P0 Pilot Gates — 판정 기록

Status: Pending (P0 진행 중)

## M2 — Primary Simulator Decision

- 비교 보고서: `DGCC/outputs/reports/sim_comparison.md`
- 선택지: (A) DLO-Lab (GPU-batched, 내장 rope API, 신생 스택) / (B) MuJoCo cable (성숙, CPU 전용)
- **결정:** (pending)
- 근거:

## G2 — Length-Goal 정의 게이트

- 검증 1 (정성): 길이 {0.5, 1.0, 1.6} m × goal 템플릿 3종 시각화 — `DGCC/outputs/plots/g2_goal_consistency_*.png`
- 검증 2 (정량): ΔD vs Δ‖c_g‖ Spearman ρ = (pending) — 임계 **ρ ≥ 0.9** (변경 금지)
- **판정:** (pending)
- 조치:

## G1 — Stiffness 유효성 게이트

- 측정: stiffness ×{0.5, 1, 2}, 시퀀스 20 × seed 3 — `DGCC/outputs/reports/g1_report.md`
- 효과크기 (Cohen's d): (pending)
- **판정:** (a) stiffness 축 유지 / (b) 강등 + length 중심 재편 / (c) springback task 추가 — (pending)

## M7 — 수치 고정 (사람 확정)

| 항목 | 제안값 | 확정값 |
|---|---|---|
| reward α / c_step / R_succ | 10 / 0.1 / 5 | |
| ε_succ | 0.05·L | |
| settle 속도 임계 | 1e-3 | |
| 파지 노이즈 / 실패율 | ±1 node / 5% | |
| OOD length split | [0.8,1.2] → {0.5,0.6,1.4,1.6} m | |
