# DGCC Implementation Plan (P0–P7)

최종 연구 계획: [`docs/research/DGCC_research_plan.md`](../research/DGCC_research_plan.md) (§10 일정과 산출물 기준).
구 버전(Phase A–F / GNG 네이밍) 문서는 폐기되었다 — Decision issue "Adopt final research plan — P0–P7" 참조.

| Phase | 내용 | 게이트/산출물 | 실행 명세 |
|---|---|---|---|
| **P0 환경·파일럿** | 2-sim bring-up (DLO-Lab vs MuJoCo cable), (p,u) primitive, transition 로깅, δm 파이프라인(arc-length resample + DCT), 이원 goal | **G1** (stiffness 유효성), **G2** (length-goal 정의, ρ≥0.9), 수치 고정 보고서 | [`DGCC/P0.md`](https://github.com/jiminc77/DGCC/blob/main/P0.md) — gjc (ralplan→ultragoal) |
| P1 Baseline 구축 | HACMan-style black-box contact critic DLO port, 이산 argmax 안정화(double-Q decoupling), 안정성 로깅, latent 추출 API | T1–T2 기준 성능 | P0 종료 후 작성 |
| P2 Probing 게이트 | frozen-critic linear probe + Controls A–F (goal-entanglement 포함), probe transfer | **사전 고정 임계로 Go/Pivot 판정** | 〃 |
| P3 구조 비교 게이트 | V1 aux / V2 soft / V3 hard + GreedyResp + matched-dim + value-only map, 사전 예측 P1–P4 대조 | variant 프루닝 (상위 2–3) | 〃 |
| P4 본 학습 | 선택 variant 본 학습, T1–T3 전체 | 학습 곡선 | 〃 |
| P5 기제 분석 | 상대적 정상성 직접 측정, probe transfer, ordinal 보존, within-variant 상관, reward-free 적응(공정 대조) | Claim 1·3·4 증거 | 〃 |
| P6 OOD·Ablation | OOD 전 축(length primary), 후순위 ablation, secondary sim 재현 1축 | Claim 2 증거, kill criterion 판정 | 〃 |
| P7 집필 | 논문 초고 → 내부 리뷰 → 투고 (CoRL 2027 1순위) | 투고 | 〃 |

운영 규칙: 각 Phase = milestone issue 1개 (research-dashboard), 구현 단위 issue는 code repo(DGCC)에. HUMAN GATE(P0의 M2/M5/M6/M7, P2·P3 판정)는 사람이 결정하며 gjc는 측정·보고까지만 수행한다.
