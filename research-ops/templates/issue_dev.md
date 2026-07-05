**목표:** {한두 문장}

- 명세: `P{N}.md`의 `@goal: M{k}` 블록 ({관련 스펙 섹션})
- 라벨: `state:ready` `type:dev` `phase:P{N}` (+ HUMAN GATE goal이면 `type:gate`)

**Exit**
- [ ] {기계 검증 조건 — pytest/로그/산출물}
- [ ] metrics: primary {지표·임계} · guard {지표·임계}
- [ ] 커밋 `P{N}-M{k}: ...` push (origin/main)

**규약 (PROTOCOL.md)**
- 착수 시 `state:running`. 진행은 `### PROGRESS` 댓글 1개를 편집(≥4h 간격).
- 사람 판단 필요 시 `### GATE REQUEST` 게시 + `state:blocked-human` (soft면 `default`·`deadline` 필수).
- 완료 시 `### EVIDENCE`(commits · tests · artifacts · **primary+guard**) → CI VERIFIED ✅ 후 close.
- guard 이상치면 primary PASS여도 GATE REQUEST(hard). 동일 문제 3회 실패 시 HALT(`state:blocked-tech`).
