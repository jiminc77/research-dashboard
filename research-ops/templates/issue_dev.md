**목표:** {한두 문장}

- 명세: `P{N}.md`의 `@goal: M{k}` 블록 ({관련 스펙 섹션})
- HUMAN GATE: {예/아니오}

**Exit**
- [ ] {기계 검증 조건 — pytest/로그/산출물}
- [ ] 커밋 `P{N}-M{k}: ...` push

완료 시 evidence(커밋 해시, 결과 파일 경로) 코멘트 후 close.
{HUMAN GATE인 경우: 산출물 생성 후 human_blocked로 정지, 사람 결정 대기.}
