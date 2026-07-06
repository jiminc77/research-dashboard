# 단계 리포트 HTML 생성 가이드 (회고 산출물 · 세션 A)

한 단계(P{k})가 끝날 때, **단일 self-contained HTML 리포트**를 만들어 관리 레포
`projects/{project}/reports/P{k}_report.html` 에 커밋한다 (이미 있으면 갱신). 회고(§ 단계 회고)의 산출물이다.

**커밋 전 `research-ops/scripts/lint_report.sh <file>` 통과가 필수다** — 아래 섹션 id 계약·금지어·self-contained 요건을 기계 검증한다. lint 실패 상태로 커밋하지 않는다.

## 원칙

- **단일 self-contained HTML** — 외부 의존은 폰트 CDN(link)만. 외부 스크립트 금지. inline CSS, 반응형 + 인쇄(@media print), lang·UTF-8 지정.
- **`plan_html_guide.md`와 동일 계열 시각 언어** — 흰 캔버스·근검정 잉크·과하지 않은 강조·섹션 리듬·`word-break: keep-all`.
- **자기완결성** — 문서 안의 링크·수치·정의만으로 모든 주장이 검증 가능해야 한다. 약어·프로젝트 고유 용어는 첫 등장 시 정식 명칭을 1회 병기한다 (용어 정의 규칙이며, 독자 수준에 대한 언급이 아니다).
- **모든 주장에 근거 링크** — 이슈/커밋 SHA/파일 경로. 근거 없는 서술·수치 날조 금지.

## 어투 계약 (강제 — lint 검사 대상)

```text
사실 기술 평서형만 쓴다. 다음은 전부 금지:
1. 청중 언급·배려 문구 — "비전문가", "비전공자", "일반 독자/일반인", "누구나 이해",
   "쉽게 말해/쉽게 설명하면/쉽게 풀어", "입문자", "초보자" 및 동급 표현
2. 자기지시 메타 문구 — "이 리포트는 ~을 위해 작성되었다", "~하시면 됩니다" 류 안내체
3. 이모지 · 과장 수식어("놀라운", "획기적", "매우 인상적") · 교육체 비유
4. 결과 없는 전망("잘 될 것으로 기대") — 전망은 승계 리스크 섹션에 근거와 함께만
```

## 데이터 소스 (전부 GitHub에 있음)

- CODE 레포 **`P{k}.md`** — 명세·사전등록 기준 (goal·Exit·primary/guard 임계·HUMAN GATE class).
- **`phase:P{k}` 이슈들** — `### EVIDENCE`(커밋·수치·경로) · `### GATE REQUEST` · `### GATE VERDICT` · PROGRESS 코멘트.
- CODE 레포 **`outputs/{metrics,reports,plots}`** — 확정 수치·플롯·리포트 원본.
- MGMT 레포 **`[Decision]` 이슈** — 사전등록 기준에서 바뀐 결정.

## 필수 섹션 구조 (id 고정 — lint 검사 대상)

| # | 섹션 | `id` | 내용 |
|---|---|---|---|
| 1 | 헤더 | (없음) | 프로젝트 · 단계(P{k}) · 기간 · **최종 판정 배지** `GO / NO-GO / PARTIAL` |
| 2 | 요약 | `summary` | 이 단계의 질문 / 얻은 답 / 다음 단계 진입 근거 — 3~5문장, 사실 서술만 |
| 3 | Goal별 결과 표 | `goals` | M0..Mj 행: 목표 한 줄 / 결과 / primary·guard 지표(**임계 대비** 값) / evidence(커밋 SHA·이슈 링크) |
| 4 | HUMAN GATE 기록 | `gates` | 게이트별: 질문 / 선택지 / 판정(VERDICT) / 근거. 사전등록 기준 변경 시 **[Decision] 링크** |
| 5 | 확정 수치 | `constants` | 다음 단계가 상속하는 고정값 표 |
| 6 | 승계 리스크 & 미해결 | `risks` | 다음 단계로 넘긴 것 (각 항목에 근거 링크) |
| 7 | 산출물 색인 | `artifacts` | `outputs/` 주요 파일·plot 링크(가능하면 raw URL 이미지 임베드) + 관련 이슈 전체 목록 |

## 파일명·위치 규약

- 기본: MGMT 레포 **`projects/{project}/reports/P{k}_report.html`** (멀티프로젝트 레이아웃 — `{project}`는 소문자 프로젝트 slug, 예: `dgcc`).
- GitHub Pages URL로 접근: `https://{owner}.github.io/{mgmtRepo}/projects/{project}/reports/P{k}_report.html`
  (대시보드 "단계 리포트" 카드가 프로젝트별 `docsBase`로 이 목록을 자동으로 링크한다).

## 금지

- **수치 날조 금지** — 모든 수치는 `### EVIDENCE`·`outputs/`에서 **그대로** 가져온다 (반올림·재계산도 근거 명시).
- **근거 없는 서술 금지** — 각 결론에는 이슈/커밋/파일 링크가 붙는다.
- **어투 계약 위반 금지** — 위 금지어 목록. 내용 외 사족(작성 경위, 독자 안내, 감상) 일절 없음.

## 산출물 검증 (커밋 전)

```text
[ ] bash research-ops/scripts/lint_report.sh projects/{project}/reports/P{k}_report.html → OK
[ ] 7개 섹션 모두 존재 (id 계약 일치) · 최종 판정 배지 있음
[ ] 모든 수치가 EVIDENCE/outputs 출처와 일치 (날조 없음)
[ ] Goal 표의 각 행에 evidence 링크(커밋 SHA·이슈) 존재
[ ] HUMAN GATE 판정·근거 기록 · 변경 시 [Decision] 링크
[ ] projects/{project}/reports/P{k}_report.html 로 커밋 · Pages URL로 열림 확인
```
