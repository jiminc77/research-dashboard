# P0 Pilot Gates — 판정 기록

Status: **완료 (2026-07-03, HUMAN SIGN-OFF — DGCC issue #8)**
근거: `DGCC/outputs/reports/p0_final_report.md` (최종 사실 요약), `STEP_LOG.md`, metrics JSON (커밋 `493ea32` 기준)

## M2 — Primary Simulator Decision

- 비교 보고서: `DGCC/outputs/reports/sim_comparison.md`
- **결정: (A) DLO-Lab primary** — "DLO-Lab is the better choice as the primary simulator. MuJoCo should be retained as a fallback and validation baseline." (DGCC issue #3)
- 근거: settle 수렴 100% (mean 1471.7 steps) vs MuJoCo 0% @5000 · GPU batch (n_envs=4 검증) · primitive wall-time 4.77 s vs 5.83 s · 파라미터 setter 커버리지(소성 포함, P0에선 비활성)
- Caveat: settle metric 정의가 sim 간 상이(`max_node_speed` vs `max_abs_qvel`) · DLO-Lab는 `gs.ti_float=gs.qd_float` alias 필요, asset SharePoint 401, pin 취약 → P1 리스크 #3으로 승계. MuJoCo adapter는 M1 상태 frozen fallback (삭제 금지)

## G2 — Length-Goal 정의 게이트

| 라운드 | 정의 | 결과 | 판정 |
|---|---|---|---|
| v1 | 혼합 norm ρ(ΔD, Δ‖c_g‖), n=2445 | ρ=0.126 | FAIL — 진단: anchor-only 0.929 / shape-only 0.023 → **측정 구인 결함**으로 진단 (사람), §8 성분 분해형으로 개정 + 1회 재측정 승인 (임계 0.9 유지) |
| v2 | 성분 분해 (anchor AND shape, correspondence L2) | anchor 0.9847 PASS / shape 0.2571 FAIL | 전체 FAIL — stopping rule 존중, 게이트 재시도 아닌 원인 진단(D1/D2) 지시 + Case A/B/C 사전 등록 |
| v3 | Case A: orientation canonicalization (X_before 기준 단일 flip 결정, 동일 적용) — **버그 수정으로 분류** | anchor **0.9847 PASS** / shape **0.99999 PASS** | **OVERALL PASS** (`g2_correlation_v3.json`) |

- 임계 0.9는 전 라운드 불변. M=8 불변 (M=12/16은 참고 계산만).
- **D 정의 변경 (사람 승인): Chamfer → 길이 정규화 correspondence L2 + orientation canonicalization.** Chamfer는 보고·참고 지표로 강등. Decision 기록: dashboard issue #17, DGCC issue #6.
- Caveat: v3 shape 성분은 orientation-consistency 버그 수정의 검증 성격 — 비자명한 실증 신호는 anchor 성분. **near-goal shape coupling은 P0 증거가 아니라 열린 가설** (P1 리스크 #2로 승계).

## G1 — Stiffness 유효성 게이트

- 측정: 시퀀스 20 (4 template × 5) × seed 3 × stiffness {×0.5, ×1, ×2} (+friction 참고 블록), grasp realism OFF — `g1_effect_size.json`
- Pooled Cohen's d: stiffness 0.5↔1.0 **d=0.061** · 1.0↔2.0 **d=−0.034** · 0.5↔2.0 **d=0.236** (cluster CI [0.041, 0.457]) — between ≈ within-floor. friction은 전부 음수 d (−0.41 ~ −0.52)
- Template 분해 (appendix, small-n 주의): u_bend 양성 (d≈0.80/0.74) vs random_smooth 음성 — pooling 이질성 → P1 리스크 #5
- **판정: (b) 채택** — stiffness를 주 OOD 축에서 강등, length(+discretization) 중심 재편. friction 주 축 승격 안 함, (c) springback 미채택, 소성 활성화 기각 (A2 상충). (DGCC issue #7)
- 방법론적 관찰 (논문 반영 예정): "quasi-static pick-and-place regime에서 탄성/마찰 파라미터 OOD 전이 주장은 그 자체로 검증력이 없다."

## M7 — 수치 고정 (HUMAN SIGN-OFF, DGCC issue #8)

| 항목 | 제안값 | **확정값** |
|---|---|---|
| reward α / c_step / R_succ | 10 / 0.1 / 5 | **10 / 0.1 / 5 — P1 시작값** (P1 중 조정 허용·기록 의무, P1 종료 시 최종 잠금) |
| ε_succ | 0.05·L | **0.05·L 확정** (실행 노이즈 median 0.0315·L 대비 1.6× 여유; P1에서 성공률 천장 관찰 시 재상정) |
| settle 속도 임계 | 1e-3 | **1e-3 불변** |
| settle max_steps | 5000 | **10000으로 증액** (10000에서 수렴 100%, first-crossing max 7608; P1 수집부터 적용, M4 데이터셋 재수집 안 함) |
| 파지 노이즈 / 실패율 | ±1 node / 5% | **유지 확정** (1000-draw 실측 4.9%) |
| OOD length split | [0.8,1.2] → {0.5,0.6,1.4,1.6} m | **확정** + density-preserving n_segments {25,30,70,80} · discretization 축은 고정 L에서 N∈{25,100} (Φ 불변성 실측 1.73% < 2%) |
| OOD stiffness/friction | 조건부 | **reference-only 확정** (본문 claim 제외, appendix 보고) |
| D (reward·성공 판정) | Chamfer | **길이 정규화 correspondence L2 + orientation canonicalization으로 교체 확정** (Chamfer는 보고용) |

## P1 승계 리스크 (6건 — 전부 P1.md 입력으로 승계 확정)

1. Settle budget 경계 (M4 데이터셋 비재수집, 플래그 유지) · 2. Shape-channel coupling 열린 가설 · 3. DLO-Lab 외부 코드 리스크 (ti_float, NaN 4회, pin) · 4. Metric 경계 (L2 vs Chamfer) · 5. Template 이질성 · 6. 렌더링/datagen 운영 노트. 추가: P4+에서 곡률 지배 task로 stiffness 재검토 가능.
