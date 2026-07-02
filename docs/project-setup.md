# Project Setup

상세 기준은 [research_ops_manual.html](research_ops_manual.html) 참조. (이 문서는 요약 스텁)

## Project fields

| Field | Type | Values |
|---|---|---|
| `Status` | Single select | Backlog / Current / Blocked / Done |
| `Phase` | Single select | N/A / P0 / P1 / P2 / P3 / P4 / P5 / P6 / P7 |
| `Decision` | Single select | Pending / GO / PIVOT / NO-GO / INCONCLUSIVE / N/A |
| `Doc` | Text | 대표 문서 링크 |
| `Updated` | Date | 마지막 의미 있는 갱신일 |

`Stage` field는 쓰지 않음 — Project item 자체가 milestone이므로 개념 충돌. Current column에는 milestone 하나만 유지 (현재: P0).
