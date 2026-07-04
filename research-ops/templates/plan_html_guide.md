# 계획서 HTML 생성 가이드 (ORCHESTRATOR STEP 2 마지막)

정형화된 최종 계획서(.md)를 **보기 쉬운 단일 HTML**로 변환한다. 무거운 변환은 subagent에 위임 가능.
잘 된 예시: `docs/research/DGCC_research_plan.html` (DESIGN-expo.md 적용).

## 입력

- 최종 계획서 `.md` (정형화·사람 승인 완료본)
- 설계 스펙 `DESIGN_SPEC` (`DESIGN-*.md`) — 색·타이포·컴포넌트 토큰. 없으면 아래 기본 스타일.

## 필수 요건 (설계 스펙과 무관하게 지킬 것)

```text
1. 단일 self-contained HTML (외부 의존은 폰트 CDN 정도만). lang 지정, UTF-8.
2. 내용 100% 충실 — 계획서의 모든 문단·표·수식·코드블록·Related Works가 빠짐없이.
3. 구조: 상단 sticky 네비(섹션 앵커) → 히어로(제목·메타) → 목차 → 본문 섹션들 → 하단.
4. 표 = 스타일된 HTML 표, 코드/수식 블록 = 구분되는 블록(가로 스크롤 허용).
5. Related Works: 각 항목에 id(ref-n) 부여, 본문 [n]은 해당 앵커로 링크.
6. 반응형(좁은 화면 대응) + 인쇄 스타일(@media print).
7. 한국어 본문 가독성: 넉넉한 행간, word-break: keep-all.
```

## 설계 스펙 적용

`DESIGN_SPEC`이 있으면 그 토큰(색·폰트·radius·spacing·컴포넌트)을 충실히 따른다. 없으면 기본: 흰 캔버스·근검정 잉크 본문·과하지 않은 강조·섹션 리듬·다크 코드블록.

## 산출물 검증 (완료 전)

```text
[ ] 모든 섹션·Related Works 항목 존재 (요약·누락 없음)
[ ] 본문 [n] 링크가 전부 ref-n 앵커로 연결 (dangling 없음)
[ ] 표·코드블록 개수가 원본 .md와 일치
[ ] 설계 토큰 반영 · 반응형/인쇄 스타일 포함 · 파일 정상 종료(</html>)
```

## 산출

`docs/research/<project>_research_plan.html` — 사람이 브라우저로 열어 확인. 이후 STEP 3로.
