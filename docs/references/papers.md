# References Index

전체 문헌 리뷰: 연구 계획 [`DGCC_research_plan.md`](../research/DGCC_research_plan.md) §12 Related Works (55편, 주제별 A–F).
여기는 빠른 참조용 인덱스만 유지한다.

## Backbone

- HACMan (CoRL 2023, 2305.03942) · HACMan++ (RSS 2024, 2407.08585) — per-point Q map. **DLO 적용은 부재 (직접 검증) — baseline은 우리가 port**

## Novelty threats (필수 인용·비교)

- Foresightful Dense Affordance (ICCV 2023, 2303.11057) — deformable per-point value map → value-only map ablation으로 대응
- TD-MPC2 (ICLR 2024) / VPN / MuZero — value-equivalent latent → matched-dim 대조군으로 대응
- Flow 계열: FlowBot3D (RSS 2022) · General Flow (CoRL 2024) · Im2Flow2Act (CoRL 2024) → GreedyResp 대조로 대응
- UniIntervene (2026, 2606.12372) — action-conditioned consequence → value head

## DLO manipulation

- DLO-Lab (2026, 2606.04206) — **P0 후보 sim A** (github.com/UMass-Embodied-AGI/DLO-Lab)
- DEFORM (CoRL 2024) · G-DOOM (ICRA 2022) · DeformNet (2402.07648) · IRP (RSS 2022)
- Untangling 계열: Grannen (CoRL 2020) · Sundaresan (ICRA 2020) · Viswanath (RSS 2022) · HANDLOOM (CoRL 2023)
- 일반화 baseline: GenORM/GenDOM (2023) · HEPi (2502.07005)

## Modal / shape features (Φ 정당화)

- Yang et al., modal analysis shape control (T-RO 2023, 2207.01249) · Navarro-Alarcon (IJRR 2014)
- DCT modes on arc-length resampled centerline = 본 연구의 Φ 기본값

## RL representation 이론

- Voelcker et al. (RLC 2024, 2406.17718) — self-prediction+TD 이론 (V1의 배경) · BYOL-AC (2406.02035) · Tang (ICML 2023) · Ni (ICLR 2024)
- SF (NeurIPS 2017) / FB / TD-JEPA — reward-transfer 축 (우리와 상보적 대비)
- VAML / Value Equivalence (NeurIPS 2020) — 의도적 이탈 대상
- 정상성(stationarity) 직접 측정 (P5) 관련: state abstraction (Li-Walsh-Littman 2006)

## Probing 방법론

- AtariARI (NeurIPS 2019, 1906.08226) — frozen-latent linear probe 프로토콜 (P2의 표준)
- DBC (ICLR 2021) · MICo (NeurIPS 2021) — behavioral metric 대안

## Benchmarks / 평가

- SoftGym (CoRL 2020) · DaXBench (ICLR 2023) — secondary 후보 (P6 교차 검증)
- rliable (NeurIPS 2021) — IQM + stratified bootstrap CI
