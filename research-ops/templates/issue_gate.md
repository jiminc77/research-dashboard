<!--
HUMAN GATE 요청/판정 템플릿. PROTOCOL.md §2 스키마를 그대로 쓴다.
- gjc는 GATE REQUEST 코멘트를 올리는 동시에 state:blocked-human 라벨을 붙인다.
- 사람은 같은 이슈에 GATE VERDICT 코멘트로 회신 → blocked-human을 ready로 되돌린다.
- HUMAN GATE goal은 dev 이슈에 type:gate 라벨.
-->

**HUMAN GATE — {무엇을 사람이 결정하는가}.** gjc는 근거 산출물만 만들고 정지한다.

## gjc가 올리는 요청 (state:blocked-human 동시 부착)

```
### GATE REQUEST
id: P{N}-M{k}-G1
class: soft | hard
question: {한 줄 — 무엇을 결정해야 하는가}
options:
- (A) ... — {근거 한 줄}
- (B) ... — {근거 한 줄}
default: A            # soft 필수 — 가장 보수적/되돌릴 수 있는 선택
deadline: 2026-07-06T09:00Z   # soft 필수 — ISO8601 UTC
evidence: {수치·산출물 경로·링크}
impact: {되돌릴 수 있나 · 미치는 범위}
```

- **soft** = deadline 지나면 Actions가 default 자동 채택(→ ready). 그 전까진 사람이 override 가능.
- **hard** = 무기한 대기, 6시간마다 리마인더. go/no-go·임계값 변경·데이터 폐기는 반드시 hard.

## 사람이 올리는 판정 (→ gjc/오케스트레이터가 ready로 전환)

```
### GATE VERDICT
id: P{N}-M{k}-G1
choice: B
rationale: {왜 이 선택인지}
follow-ups:
- {추가 지시, 없으면 생략}
```
