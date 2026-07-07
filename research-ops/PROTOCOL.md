# research-ops PROTOCOL — 정형화 계약

> **상태는 라벨로, 증거는 스키마로, 게이트는 사전등록으로.**
> 3층위 모델·역할·불변 규칙 위에서, 상태·증거·게이트를 **기계가 읽는 계약**으로 고정한다.
> 이 계약을 실제로 집행하는 자동화는 `workflows/`, 조회는 `scripts/status.sh`·`dashboard/`.

용어: `MGMT_REPO` · `CODE_REPO` · `gjc`(실행자) · `HUMAN GATE` · `@goal:` 블록 · `[P{k}-M{n}]` 이슈 제목 · `{PROJECT}`.

---

## 1. 라벨 상태기계

**핵심 규칙: dev 이슈는 항상 정확히 1개의 `state:*` 라벨을 보유한다.** 이것이 유일한 기계 판독 진실이다.

### state 라벨 (색상은 bootstrap이 설정)

| 라벨 | 색상 | 의미 |
|---|---|---|
| `state:ready` | 회색 `cccccc` | 착수 대기 (이슈 생성 직후 기본, 또는 soft default 채택 후) |
| `state:running` | 파랑 `1d76db` | gjc 구현 중 |
| `state:verify` | 보라 `8250df` | EVIDENCE 게시됨, CI 검증 대기/진행 |
| `state:done` | 초록 `0e8a16` | CI VERIFIED ✅ 후 close됨 |
| `state:blocked-human` | 빨강 `d73a4a` | HUMAN GATE 대기 (분기) |
| `state:blocked-tech` | 주황 `d93f0b` | 기술 블로커 / 3-strike / CI 실패 (분기) |

### 전이표 (누가 어떤 전이를 수행하는가)

| From → To | 수행 주체 | 트리거 |
|---|---|---|
| (생성) → `ready` | 오케스트레이터 / `setup_phase.sh` | dev 이슈 생성 시 자동 부착 |
| `ready` → `running` | **gjc** | 해당 goal 착수 시 |
| `running` → `verify` | **gjc** | `### EVIDENCE` 댓글 게시 시 |
| `verify` → `done` | **Actions**(evidence-verify) | CI VERIFIED ✅ + gjc가 close |
| `verify` → `blocked-tech` | **Actions**(evidence-verify) | CI VERIFICATION FAILED |
| `running` → `blocked-human` | **gjc** | `### GATE REQUEST` 게시 시 (동시 부착) |
| `*` → `blocked-human` | **Actions**(gate-notify) | 댓글에 `### GATE REQUEST`인데 라벨 누락 시 자가치유 |
| `running` → `blocked-tech` | **gjc** | 3-strike HALT / 환경 블로커 |
| `blocked-human` → `ready` | **사람**(GATE VERDICT) 또는 **Actions**(soft deadline 경과 default 채택) | 판정 회신 / deadline |
| `blocked-tech` → `running` | **gjc** | 블로커 해소 후 재개 |

**단일 state 규칙 위반 처리**: 라벨이 0개 또는 2개 이상이면 대시보드가 이상으로 표시. gate-notify가 GATE REQUEST 댓글 감지 시 `blocked-human`을 보강하되, 기존 state 라벨 제거는 사람/명시적 전이에서만.

### 보조 라벨 (state와 병존)

- `type:dev` | `type:gate` | `type:decision` | `type:milestone` — 이슈 종류
- `phase:P0` .. `phase:P7` — 소속 단계
- `proj:<name>` — 공용 MGMT_REPO에서 프로젝트 구분 (CODE_REPO는 단일 프로젝트라 생략 가능; `[{PROJECT}]` 제목 접두사와 병행)

---

## 2. GATE REQUEST 스키마

HUMAN GATE는 **기계 파싱 가능한 댓글**로 요청한다. gjc는 이 댓글을 게시하는 **동시에** `state:blocked-human` 라벨을 부착한다.

댓글 헤더는 반드시 `### GATE REQUEST`:

```
### GATE REQUEST
id: P1-M3-G1
class: soft | hard
question: <한 줄 — 무엇을 결정해야 하는가>
options:
- (A) ... — <근거 한 줄>
- (B) ... — <근거 한 줄>
default: A            # soft 필수 — 가장 보수적/되돌릴 수 있는 선택지
deadline: 2026-07-05T12:00Z   # soft 필수 — ISO8601 UTC
evidence: <수치·산출물 경로·링크>
impact: <이 결정이 미치는 범위 — 되돌릴 수 있나?>
```

### class 규칙

- **`class: soft`** — 되돌릴 수 있는 결정. `default`·`deadline` **필수**.
  deadline 경과 시 gate-notify(schedule)가 `default`를 자동 채택:
  `⏰ DEADLINE PASSED → DEFAULT (X) ADOPTED (PROTOCOL.md §gate)` 댓글 + 라벨 `blocked-human → ready` 교체 + 푸시.
  **다음 세션이 default를 집행**한다. 사람은 deadline **전까지 언제든 override** 가능(GATE VERDICT 게시 → default 무효).
- **`class: hard`** — 되돌리기 어렵거나 방향을 가르는 결정. **무기한 대기**, 자동 채택 없음. 6시간마다 리마인더 푸시.
  **다음은 반드시 hard**: go/no-go(단계 통과 여부), 게이트 임계값 변경, 데이터/실험 폐기, 아키텍처 방향 선택.

### GATE VERDICT (사람 회신 스키마)

사람은 같은 이슈에 `### GATE VERDICT` 댓글로 회신한다. 회신 후 gjc/오케스트레이터가 `blocked-human → ready`로 전환하고 집행한다.

```
### GATE VERDICT
id: P1-M3-G1
choice: B
rationale: <왜 이 선택인지>
follow-ups:
- <추가 지시나 후속 작업, 없으면 생략>
```

### 판정 전달 자동화 (gate-watcher)

원격 데몬 `research-ops/gate-watcher/`가 실행 세션의 ledger(blocked)를 감시하다, `state:blocked-human` 라벨이 붙은 open 이슈에서 **GATE VERDICT 코멘트(author=사람 계정, 첫 줄 `### GATE VERDICT`, `choice:` 필드)**를 감지하면 실행 세션 tmux에 "가서 읽어라" 신호만 전달한다(본문 주입 없음 — 세션이 직접 fetch·재검증). 전달 확인 = 판정 코멘트의 👀 reaction. 판정 게시 시 `gate-notify`의 verdict-label job이 `blocked-human → ready`를 기계적으로 전환한다(집행 세션은 착수 시 `running`으로). **구 계약("## HUMAN 판정" + [RESUME])은 폐지 — 본 스키마가 유일한 판정 형식이다.**

---

## 3. 사전등록 규칙 (pre-registration)

- 게이트의 **선택지·판정 기준(임계값·primary/guard 지표)은 결과를 측정하기 전** 해당 `P{k}.md`에 등록한다 (`@goal:` 블록 Exit + 전역 규칙).
- 결과를 본 **후** 기준을 바꾸는 것은 **금지가 아니라 절차화**한다: **MGMT_REPO `[Decision]` 이슈**(`type:decision`)를 통해서만 — 무엇을·왜·기존 기준 대비 어떻게 바꾸는지 기록하고 판정한다.
- 이슈 본문/댓글에서 사후 임의 재정의는 위반. Decision 이슈 없이 바뀐 기준으로 통과시키지 않는다.

한 줄: **기준을 바꿀 수 있다. 단, 결과를 본 뒤라면 Decision 이슈에 남겨야만.**

---

## 4. EVIDENCE 스키마

gjc는 goal 완료 시 `### EVIDENCE` 헤더 댓글로 증거를 남기고 `state:running → verify`로 전환한다.

```
### EVIDENCE
goal-id: P1-M3
commits:
- 9f3a2b1  # origin/main에 실재하는 SHA (CI가 이 SHA를 체크아웃해 재검증)
tests:
- cmd: uv run pytest -q tests/test_baseline.py
  result: 24 passed
  exit: 0
artifacts:
- path: outputs/metrics/p1_baseline.json
  sha256: <필요 시>          # 대용량·재현 검증 대상일 때
metrics:
  primary: {name: accuracy, value: 0.71, threshold: ">=0.65", pass: true}
  guard:   {name: success_rate, value: 0.00, random: 0.04, ok: false}   # ★ 필수
deviations: <명세와 달라진 점, 없으면 "없음">
```

### close 규칙

- **EVIDENCE 댓글 + CI VERIFIED ✅ 후에만 close**한다. gjc가 자기신고만으로 close하지 않는다.
- evidence-verify 워크플로가 `commits`의 SHA를 체크아웃·`pytest` 재실행 → 성공 시 `✅ VERIFIED` 댓글 + `state:verify` 확정, 실패 시 `❌ VERIFICATION FAILED` + `state:blocked-tech` + 푸시.

### guard-metric 규칙

- 모든 게이트/EVIDENCE는 **primary 지표와 guard 지표를 함께** 보고한다.
- **primary가 PASS여도 guard 이상치**(예: `success_rate 0% < random 4%`)면 자동으로 `state:blocked-human` — primary만 보고 통과 금지. gjc가 guard `ok:false`를 발견하면 EVIDENCE 대신 GATE REQUEST(class:hard)로 전환한다.

---

## 5. HEARTBEAT (진행 상황)

- 이슈당 **진행 댓글 1개를 계속 편집**한다. 새 댓글로 도배하지 않는다. 헤더 `### PROGRESS`:

```
### PROGRESS
- [x] AC1 데이터 로더
- [x] AC2 베이스라인 학습 루프
- [ ] AC3 평가·지표 산출  ← 진행 중
updated: 2026-07-05T09:12Z
next-eta: 2026-07-05T13:00Z
```

- **새 댓글을 만드는 것은 `### GATE REQUEST` · `### EVIDENCE` · `### GATE VERDICT` 뿐.** 나머지 진행 보고는 PROGRESS 댓글 편집.
- 장기 실행 goal은 **최소 4시간 간격**으로 PROGRESS를 갱신한다. 대시보드·`status.sh`가 `updated`로 **staleness(4h+ stale)**를 표시한다.

---

## 6. 3-strike HALT (BMAD 차용)

- **동일 문제를 3회 수정 시도해도 실패**하면 자율 재시도를 멈춘다.
- `state:blocked-tech` 부착 + `### GATE REQUEST`(class:hard)로 사람에게 에스컬레이션 — 무엇을 3번 시도했고 각각 왜 실패했는지, 선택지를 제시.
- 무한 루프·토큰 소모·조용한 우회(명세 이탈)를 차단한다.

---

## 7. 세션 재개 — 라벨 쿼리 원라이너

상태 복원은 별도 상태 파일이 아니라 **라벨 쿼리**로 한다. 새 세션 시작 시 먼저 실행:

```bash
# 지금 사람을 기다리거나 실행 중인 것 (재개 우선순위)
gh issue list -R "$CODE_REPO" \
  --label "state:blocked-human" --state open \
  --json number,title,labels,updatedAt,url

gh issue list -R "$CODE_REPO" \
  --label "state:running" --state open \
  --json number,title,updatedAt,url

# 기술 블로커
gh issue list -R "$CODE_REPO" --label "state:blocked-tech" --state open \
  --json number,title,updatedAt,url

# 전체 스냅샷은 scripts/status.sh 가 색상·경과시간까지 요약
```

진실의 원천은 GitHub이다. 그 상태를 **라벨로 즉시 쿼리 가능**하게 만든다.

---

## 7-B. 쓰기 규율 (PR-only publish)

LLM 세션(세션 A — **웹 pro 포함**)의 repo 쓰기는 **branch+PR 로만** 한다. default branch(main) 직접 push 금지.

- **게시 확정 조건**: PR 이 `pr-verify` 로 **green** 이고 **사람이 merge** 해야 게시로 확정된다. 세션은 스스로 merge 하지 않는다.
- **branch+PR 절차**: `create_branch`(예: `phase/P{k+1}-kickoff`) → `push_files` → PR(base=main). 레포별 1 PR(MGMT·CODE). PR 본문에 evidence 링크 + 불변값 이월 확인 명시. 불변값 매니페스트를 건드리면 `[Decision]` 이슈 인용 필수(`check_immutables.sh` 강제).
- **`pr-verify` 워크플로**: `research-ops/workflows/pr-verify.yml`(양 레포 `.github/workflows/` 로 무수정 복사). `on: pull_request` 만 — 직접 push 는 트리거하지 않는다. 변경 파일 종류별로 킷 린터(리포트·@goal 명세·불변값·status)를 조건 실행하고 결과를 step summary 에 쓴다. job 이름은 `pr-verify` 고정.
- **직접 push 잠정 허용 대상**: (1) **gjc** — CODE 레포에서 phase 실행 중 milestone 커밋을 main 에 직접 push(P0/P1 운영 방식), (2) **유지보수 세션** — 킷 정비. 그 외 LLM 세션 게시는 PR-only.
- **branch protection 활성화 (P1 종료 시)**: P1 이 끝나 gjc 의 직접 push 의존이 사라지는 시점에 CODE 레포에 required status check `pr-verify` 를 켠다. 절차: **Settings → Branches → Add branch protection rule** → 대상 `main` → **Require a pull request before merging** + **Require status checks to pass** 에서 `pr-verify` 지정. (P1 실행 중에는 켜지 않는다 — gjc 직접 push 가 막힌다. 이 문서에 절차만 문서화하고 활성화는 P1→P2 전환에서 수행.)

한 줄: **LLM 세션 게시 = branch+PR → pr-verify green → 사람 merge.** 직접 push 는 gjc(phase 실행)와 유지보수 세션에만 잠정 허용, P1 종료 시 protection 으로 고정.

---

## 8. 요약 카드 (gjc·오케스트레이터가 외울 것)

1. dev 이슈 = state 라벨 정확히 1개. 착수 `running`, 증거 후 `verify`, CI ✅ 후 `done`.
2. 게이트는 `### GATE REQUEST` + `blocked-human` 동시. soft는 default·deadline 필수, hard는 무기한.
3. 증거는 `### EVIDENCE`(primary+guard). CI VERIFIED 후에만 close.
4. guard 이상치면 primary PASS여도 `blocked-human`.
5. 기준 사후 변경은 MGMT `[Decision]` 이슈로만.
6. 진행은 `### PROGRESS` 댓글 편집(≥4h). 3-strike면 HALT.
