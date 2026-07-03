# DGCC Research OS

DGCC (Deformation-Grounded Contact Critic) 연구를 GitHub Issues / Projects로 관리하는 대시보드 레포.
운영 기준: [docs/research_ops_manual.html](docs/research_ops_manual.html) — 문서는 지식, Issue는 상태, Project는 흐름.

## Current Snapshot

| 항목 | 값 |
|---|---|
| Current Milestone | [P1 — Black-box Baseline 구축](https://github.com/jiminc77/research-dashboard/issues/10) |
| Phase | P1 — Baseline |
| Main Question | How should a Bellman critic represent contact actions for DLO manipulation? |
| Last Decision | P0 HUMAN SIGN-OFF (2026-07-03) — primary sim=DLO-Lab, G2 PASS(v3), G1 verdict (b), 수치 고정 ([기록](docs/reports/P0_pilot_gates.md)) |
| Next | P1 실행 (gjc, `DGCC/P1.md`) → T1/T2 baseline → latent API → P2 probing |
| Manual | [docs/research_ops_manual.html](docs/research_ops_manual.html) |
| Research Plan | [docs/research/DGCC_research_plan.md](docs/research/DGCC_research_plan.md) |

## Repo Split

| Repo | 역할 |
|---|---|
| [research-dashboard](https://github.com/jiminc77/research-dashboard) | 연구 관리: docs, milestone issues, decisions, reports, references |
| [DGCC](https://github.com/jiminc77/DGCC) | 구현 코드: gjc 실행 명세(P0.md·P1.md), src, configs, outputs, 구현 단위 issues |

## Docs = Knowledge

- 연구 계획 (최종): `docs/research/DGCC_research_plan.md` / `.html`
- 구현 플로우 (P0–P7): `docs/implementation/DGCC_implementation_plan.md`
- P0 명세 요약: `docs/implementation/P0_env_pilot_spec.md` · **결과: [`docs/reports/P0_pilot_gates.md`](docs/reports/P0_pilot_gates.md)**
- P1 명세 요약: `docs/implementation/P1_baseline_spec.md` (canonical: `DGCC/P1.md`)
- 게이트/결정 리포트: `docs/reports/`
- 참고문헌 인덱스: `docs/references/papers.md`

## Milestone Issues

| Milestone | Phase | Status |
|---|---|---|
| [DGCC Research Blueprint](https://github.com/jiminc77/research-dashboard/issues/4) | N/A | Done |
| [P0 — 환경·파일럿 (2-sim + δm + G1/G2)](https://github.com/jiminc77/research-dashboard/issues/9) | P0 | **Done** (2026-07-03 sign-off) |
| [P1 — Black-box Baseline 구축](https://github.com/jiminc77/research-dashboard/issues/10) | P1 | **Current** |
| [P2 — Probing 게이트 (Controls A–F)](https://github.com/jiminc77/research-dashboard/issues/11) | P2 | Next |
| [P3 — 구조 비교 게이트 (V1/V2/V3 + GreedyResp)](https://github.com/jiminc77/research-dashboard/issues/12) | P3 | Backlog |
| [P4 — 본 학습](https://github.com/jiminc77/research-dashboard/issues/13) | P4 | Backlog |
| [P5 — 기제 분석 (정상성·transfer·reward-free)](https://github.com/jiminc77/research-dashboard/issues/14) | P5 | Backlog |
| [P6 — OOD · Ablation](https://github.com/jiminc77/research-dashboard/issues/15) | P6 | Backlog |
| [P7 — 집필](https://github.com/jiminc77/research-dashboard/issues/16) | P7 | Backlog |

Decision records:

- [Adopt final research plan — P0–P7 (supersedes GNG framing)](https://github.com/jiminc77/research-dashboard/issues/8)
- [G2 게이트 정의 정제 — 성분 분해 + correspondence L2 (임계 0.9 유지)](https://github.com/jiminc77/research-dashboard/issues/17)
- [Use minimal rope_response_probe for GNG-0](https://github.com/jiminc77/research-dashboard/issues/7) — superseded

## Issue Types (3종만)

- **Milestone** — Project에 올리는 유일한 단위. 연구 흐름 표시.
- **Decision** — GO/PIVOT/NO-GO 또는 방향 변경 시.
- **Experiment Result** — 결과가 milestone decision에 영향을 줄 때만.

## Project Setup

Project fields: `Status` (Backlog/Current/Blocked/Done) · `Phase` (N/A, P0…P7) · `Decision` (Pending/GO/PIVOT/NO-GO/INCONCLUSIVE/N/A) · `Doc` · `Updated`. `Stage` field는 쓰지 않음. Current column에는 milestone 하나만 유지 (현재: P1).
