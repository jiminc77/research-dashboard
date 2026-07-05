# 단계 리포트 HTML 생성 가이드 (회고 산출물 · 세션 A)

한 단계(P{k})가 끝날 때, **제3자가 맥락 없이 읽어도 이해되는 단일 self-contained HTML 리포트**를 만들어
관리 레포 `docs/reports/P{k}_report.html` 에 커밋한다 (이미 있으면 갱신). 회고(§ 단계 회고)의 산출물이다.

## 원칙

- **단일 self-contained HTML** — 외부 의존은 폰트 CDN 정도. inline CSS, 반응형 + 인쇄(@media print). lang·UTF-8 지정.
- **`plan_html_guide.md`와 동일 계열 시각 언어** — 흰 캔버스·근검정 잉크·과하지 않은 강조·섹션 리듬·`word-break: keep-all`.
- **제3자 가독성** — 프로젝트/단계 배경을 모르는 독자도 이해되게 (약어 첫 등장 시 풀어쓰기).
- **모든 주장에 근거 링크** — 이슈/커밋 SHA/파일 경로. 근거 없는 서술·수치 날조 금지.

## 데이터 소스 (전부 GitHub에 있음)

- CODE 레포 **`P{k}.md`** — 명세·사전등록 기준 (goal·Exit·primary/guard 임계·HUMAN GATE class).
- **`phase:P{k}` 이슈들** — `### EVIDENCE`(커밋·수치·경로) · `### GATE REQUEST` · `### GATE VERDICT` · PROGRESS 코멘트.
- CODE 레포 **`outputs/{metrics,reports,plots}`** — 확정 수치·플롯·리포트 원본.
- MGMT 레포 **`[Decision]` 이슈** — 사전등록 기준에서 바뀐 결정.

## 필수 섹션 구조

1. **헤더** — 프로젝트 · 단계(P{k}) · 기간 · **최종 판정 배지**(GO / NO-GO / PARTIAL).
2. **30초 요약** — 이 단계의 질문 / 얻은 답 / 다음 단계로 넘어간 이유. 비전문가용 3~5문장.
3. **Goal별 결과 표** — M0..Mj 행: 목표 한 줄 / 결과 / primary·guard 지표(**임계 대비** 값) / evidence(커밋 SHA·이슈 링크).
4. **HUMAN GATE 기록** — 게이트별: 질문 / 선택지 / 판정(VERDICT) / 근거. 사전등록 기준 대비 변경이 있었다면 **[Decision] 링크**.
5. **확정 수치** — 다음 단계가 상속하는 고정값 표.
6. **승계 리스크 & 미해결** — 다음 단계로 넘긴 것.
7. **산출물 색인** — `outputs/` 주요 파일·plot 링크(가능하면 raw URL 이미지 임베드) + 관련 이슈 전체 목록.

## 파일명·위치 규약

- 기본: MGMT 레포 **`docs/reports/P{k}_report.html`**.
- 프로젝트가 여럿이면: **`docs/{PROJECT}/reports/P{k}_report.html`**.
- GitHub Pages URL로 접근 가능함을 명시: `https://{owner}.github.io/{mgmtRepo}/docs/reports/P{k}_report.html`
  (대시보드 "단계 리포트" 카드가 이 목록을 자동으로 링크한다).

## 금지

- **수치 날조 금지** — 모든 수치는 `### EVIDENCE`·`outputs/`에서 **그대로** 가져온다 (반올림·재계산도 근거 명시).
- **근거 없는 서술 금지** — 각 결론에는 이슈/커밋/파일 링크가 붙는다.

## 산출물 검증 (커밋 전)

```text
[ ] 7개 섹션 모두 존재 · 최종 판정 배지 있음
[ ] 모든 수치가 EVIDENCE/outputs 출처와 일치 (날조 없음)
[ ] Goal 표의 각 행에 evidence 링크(커밋 SHA·이슈) 존재
[ ] HUMAN GATE 판정·근거 기록 · 변경 시 [Decision] 링크
[ ] 반응형·인쇄 스타일 포함 · </html> 로 정상 종료
[ ] docs/reports/P{k}_report.html 로 커밋 · Pages URL로 열림 확인
```
