# research-ops v2 — 솔로 연구자용 GitHub 에이전트 워크플로우 키트

> v1의 **재사용 운영 모델**(MGMT_REPO / CODE_REPO / gjc / HUMAN GATE / `@goal:` 블록 / `[P{k}-M{n}]`)을 그대로 계승한다.
> v2는 **재작성이 아니라 업그레이드**다: 텍스트 관례에 흩어져 있던 상태·증거·게이트를 **기계가 읽는 계약**으로 정형화하고, 알림·검증·대시보드를 **제로 인프라(gh CLI · GitHub Actions · ntfy.sh · 클라이언트 대시보드)**로 자동화한다.
> 세부 규칙은 `PROTOCOL.md`, 세션 절차는 `ORCHESTRATOR.md`, 산출물은 `templates/`·`scripts/`·`workflows/`·`dashboard/`.

---

## 1. v1 → v2 변경 요약 (무엇이 왜 바뀌나)

| 영역 | v1 (기존) | v2 (개선) | 왜 |
|---|---|---|---|
| **상태 표현** | 이슈 제목·본문의 텍스트 관례 (`human_blocked` 산문, "HUMAN 판정" 댓글, Exit 체크리스트) | **라벨 상태기계** — dev 이슈는 항상 state 라벨 정확히 1개 (`state:ready→running→verify→done`, 분기 `blocked-human`/`blocked-tech`) | 상태가 기계 판독 불가 → 대시보드·자동화 불가. 라벨은 API로 쿼리·집계 가능 |
| **알림** | 없음. gjc가 **소유자 본인 계정**으로 게이트 요청을 올려서 GitHub이 본인에게 알림을 안 줌 → 게이트가 평균 **~14h** 대기 | **ntfy.sh 푸시** — `state:blocked-human` 부착/`### GATE REQUEST` 게시 즉시 폰 푸시, 6h마다 리마인더 | 게이트 지연이 전체 처리량의 병목 |
| **게이트 진행** | 무기한 대기. 사람이 볼 때까지 세션 정지 | **soft/hard 이원화** — soft는 deadline 경과 시 default 자동 채택 후 진행, hard만 무기한 대기 | 되돌릴 수 있는 결정까지 사람을 막지 않는다 |
| **증거 신뢰** | gjc **자기신고** 커밋 해시·결과 경로 (검증 없음). 자기 계정이라 아무도 교차확인 안 함 | **CI 재검증** — `### EVIDENCE` 댓글의 SHA를 GitHub Actions가 체크아웃·pytest 재실행, ✅ 후에만 close 허용 | "커밋했다"는 주장과 "실제로 통과한다"는 사실의 분리 |
| **가드 지표** | primary 지표만 게이트 판정 → primary PASS인데 성공률 0%(<랜덤 4%)로 통과 (issue #11) | **primary + guard 강제** — guard 이상치면 primary PASS여도 자동 `blocked-human` | 재앙적 실패의 조용한 통과 방지 |
| **사전등록** | 사후 기준 재정의가 비공식으로 발생 (issue #6/#17) | **사전등록 규칙** — 게이트 기준은 측정 전 P{k}.md에 등록, 사후 변경은 MGMT `[Decision]` 이슈로만 | 결과 보고 기준 바꾸기(HARKing) 차단 |
| **대시보드** | 정적 수동 HTML, 손으로 갱신 → **stale** | **라이브 대시보드** — GitHub 공개 API 무인증 fetch, 5분 자동 새로고침, staleness 배지 | 진실의 원천은 GitHub. 손 갱신 제거 |
| **부트스트랩** | 라벨 없음, milestone 0개, 수동 | `bootstrap_project.sh` — 라벨·GitHub milestone 멱등 일괄 생성 | 상태기계의 전제(라벨) 자동 확보 |
| **이슈 번호 backfill** | `setup_phase.sh` 후 P{k}.md 매핑표에 **손으로** 번호 기입 | `setup_phase.sh`가 `@goal:` 블록 파싱→이슈 생성→**매핑표 자동 생성/커밋** | 반복 수작업·불일치 제거 |

**계승(그대로 유지)**: 3층위 멘탈 모델(연구 흐름/개발 작업/지식), 오케스트레이터 6-STEP, 역할 경계, `[{PROJECT}]` 접두사 다중 프로젝트, 불변 규칙, DGCC 실제 예시.

---

## 2. 무중단 적용 순서 (DGCC P1 진행 중 가정)

진행 중인 P1을 **깨지 않고** 얹는다. 각 단계는 독립적이며 비파괴다.

**① 라벨만 먼저 (비파괴, ~5분)**
```bash
bash scripts/bootstrap_project.sh \
  --labels-only \
  jiminc77 research-dashboard DGCC DGCC \
  "P0:환경파일럿,P1:베이스라인,P2:...,P7:..."
```
`--labels-only`는 이슈·milestone을 만들지 않고 **라벨만** 양 레포에 멱등 생성한다. 기존 이슈는 건드리지 않는다.

**② 워크플로 2개 + ntfy (~10분)**
- `workflows/gate-notify.yml`, `workflows/evidence-verify.yml`을 **CODE repo**(`DGCC`)의 `.github/workflows/`에 커밋.
- 폰에 **ntfy 앱** 설치 → 임의의 토픽(예: `dgcc-gate-9f3a2b`)을 **구독**.
- 그 토픽명을 CODE repo에 secret 등록: `gh secret set NTFY_TOPIC -R jiminc77/DGCC` (또는 Settings → Secrets → Actions).
  > 토픽명은 URL로 노출되면 누구나 푸시 가능하니 **추측 불가능한 문자열**을 쓴다.

**③ 라이브 대시보드 (~10분)**
- `dashboard/index.html`을 **MGMT repo**(`research-dashboard`)에 커밋.
- Settings → Pages → Branch `main` / 폴더 지정 → 활성화. `https://jiminc77.github.io/research-dashboard/dashboard/`에서 접속.
- 무인증 공개 API만 쓰므로 토큰 불필요. 라벨 없는 기존 이슈도 제목 `[P{k}-M{n}]` regex로 잡힌다.

**④ 진행 중 P1은 그대로, P2부턴 v2 본격 적용**
- P1은 지금 방식대로 마무리한다(라벨은 ①에서 생겼으니 원하면 손으로 붙여도 됨).
- **P2 명세부터** `ORCHESTRATOR.md`(v2)와 신규 `templates/issue_dev.md`·`issue_gate.md`, `setup_phase.sh`(자동 backfill)를 적용한다.

**⑤ 다음 프로젝트부터 풀 부트스트랩**
- `--labels-only` 없이 `bootstrap_project.sh`를 돌려 띻벨 + phase별 GitHub milestone까지 일괄 생성.

---

## 3. 새 프로젝트 퀵스타트

```bash
# 0) 전제: gh CLI 로그인
gh auth status

# 1) 라벨 + milestone 부트스트랩 (양 레포)
bash scripts/bootstrap_project.sh \
  jiminc77 research-dashboard <CODE_REPO> <PROJECT> \
  "P0:환경파일럿,P1:베이스라인,P2:제안기법,P3:평가"

# 2) CODE repo에 워크플로 커밋 + secret
cp workflows/*.yml <CODE_REPO_LOCAL>/.github/workflows/ && git -C <CODE_REPO_LOCAL> add -A && git -C <CODE_REPO_LOCAL> commit -m "ci: research-ops v2 gate/evidence workflows" && git -C <CODE_REPO_LOCAL> push
gh secret set NTFY_TOPIC -R jiminc77/<CODE_REPO>      # 값 = ntfy 앱에서 구독한 토픽

# 3) MGMT repo에 대시보드 커밋 → Pages 활성화 (dashboard/index.html CONFIG에 프로젝트 추가)

# 4) 오케스트레이션 시작 (ORCHESTRATOR.md Kickoff 프롬프트 복붙)
#    STEP 0 self-check → STEP 3 milestone → STEP 4 P{k}.md + setup_phase.sh → gjc 위임
bash scripts/setup_phase.sh P0 <CODE_REPO_LOCAL>/P0.md    # @goal 파싱 → dev 이슈 + 매핑표 자동

# 5) 상태 확인은 언제든
bash scripts/status.sh jiminc77 <CODE_REPO> research-dashboard
```

이후는 v1과 동일: `"P{k} 완료. 상태 확인하고 P{k+1} 진행해줘."` 한 줄로 STEP 4→3 루프가 돈다. 차이는 상태가 **라벨로 보이고**, 게이트가 **폰으로 오고**, 증거가 **CI로 검증되고**, 대시보드가 **살아있다**는 것.

---

## 4. 파일 지도

```
research-ops-v2/
  README.md                     # 이 문서 — 변경 요약·적용 순서·퀵스타트
  PROTOCOL.md                   # ★ 핵심 정형화 계약: 라벨 상태기계·GATE/EVIDENCE 스키마·사전등록
  ORCHESTRATOR.md               # v2 세션 지시서 (v1 6-STEP + STEP 0 self-check + 띻벨 전이)
  templates/
    issue_dev.md                # 자기완결형 dev 이슈 (AC·작업 체크리스트·EVIDENCE 참조)
    issue_gate.md               # GATE 이슈/댓글 템플릿 (hard/soft/VERDICT 예시)
  scripts/
    bootstrap_project.sh        # 라벨 + milestone 멱등 생성 (--labels-only)
    setup_phase.sh              # @goal 파싱 → dev 이슈 + 매핑표 자동 backfill
    status.sh                   # 한 방 상태 조회 (blocked/running/verify/진행률)
  workflows/
    gate-notify.yml             # (CODE repo) ntfy 푸시·리마인더·soft default 자동 채택
    evidence-verify.yml         # (CODE repo) EVIDENCE SHA 체크아웃·pytest 재검증
  dashboard/
    index.html                  # (MGMT repo) 라이브 대시보드, 무인증 API, 다중 프로젝트
```

원칙 한 줄: **상태는 라벨로, 증거는 스키마로, 게이트는 사전등록으로. 인프라는 제로.**
