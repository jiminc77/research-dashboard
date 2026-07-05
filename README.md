# research-dashboard

연구 프로젝트를 GitHub 이슈·라벨·Actions로 굴리는 **오케스트레이션 관리 레포(MGMT_REPO)**.

> **Docs = 지식 · Issues = 상태 · 라벨 = 상태기계 · Code repo = 증거.**

## 바로가기

| | |
|---|---|
| 📊 **라이브 대시보드** | https://jiminc77.github.io/research-dashboard/dashboard/ |
| 📖 **사용 설명서** — 새 프로젝트 셋업 · 단계 세션 · 게이트 대응 · ntfy | https://jiminc77.github.io/research-dashboard/guide/ |
| 📐 운영 계약 | [`research-ops/PROTOCOL.md`](research-ops/PROTOCOL.md) |
| 🤖 세션 지시서 | [`research-ops/ORCHESTRATOR.md`](research-ops/ORCHESTRATOR.md) |

## 구조

- `research-ops/` — 재사용 키트 (계약 · 지시서 · 템플릿 · 스크립트). 프로젝트 독립.
- `docs/` — 프로젝트 문서 (연구계획서 · 명세 요약 · 게이트 리포트).
- `dashboard/` · `guide/` — GitHub Pages 정적 페이지. 상태는 API로 실시간 렌더 — 수동 갱신 없음.
- 이슈 2종 — `[Milestone]` 단계 관리 · `[Decision]` 기준 변경 기록.

## 진행 중 프로젝트

- **DGCC** — 구현 레포: https://github.com/jiminc77/DGCC (dev 이슈 · evidence · CI 검증은 그쪽)

상태의 진실은 라벨과 대시보드다. **이 README에는 상태를 적지 않는다.**
