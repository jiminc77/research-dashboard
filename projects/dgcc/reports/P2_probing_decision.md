# P2 Probing 게이트 — Decision Report

Status: Not started (P0 → P1 이후)

질문: 표준 black-box contact critic이 이미 deformation response를 (transferable하게) 인코딩하는가?

사전 고정 임계 (연구 계획 §7.4 — 변경 금지):

- linear probe R² < 0.5 ∧ raw 대비 ΔR² > 0.2 → **Go (결핍 확인)**
- in-domain R² ≥ 0.7 ∧ transfer degradation ≥ 40% → **Go (OOD-motivated)**
- 모두 높음 → pivot 분기 (Decision 1)
- 모두 낮음 → response 정의 수정 1회 재시도, 재실패 시 중단

Controls: A raw-input / B random latent / C nonlinear upper-bound / D shuffled target / E transfer control / F goal-entanglement (부분공간 분리).

## 결과

(pending)

## 판정

(pending)
