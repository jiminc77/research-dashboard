# 새 프로젝트 착수 — 프롬프트 (현행판, thin pointer)

> **정본은 `guide/` 의 셋업 마법사다.** 위저드에 값을 채우면 세션 A 착수 지시서(웹 pro 기준)를 만들어 준다.
> 이 문서는 마법사 없이 손으로 쓸 때의 **fallback** 이다. 개념·절차 정본은 `ORCHESTRATOR.md`.

착수는 두 갈래로 나뉜다:
- **세션 A(LLM)가 하는 일** — 회고·명세·리포트·이슈·세션 B 지시서. (아래 §1 프롬프트)
- **사람(로컬 셸)이 하는 일** — 셸이 필요한 셋업. LLM 세션 A(웹 pro)는 셸이 없으므로 이 부분은 사람이 밟는다. (아래 §2 체크리스트)

---

## 1. 웹 pro 세션 A 착수 프롬프트 (기본 — 값 치환 후 새 세션 A에 붙여넣기)

```text
너는 이 프로젝트의 세션 A(메인 오케스트레이터, 웹 pro 변형)다.
GitHub 쓰기 앱(create_branch/push_files/create_issue)으로 REST 읽기 + branch+PR 게시만 한다.
관리 레포 {OWNER}/{MGMT_REPO} 의 research-ops/ORCHESTRATOR.md · PROTOCOL.md · templates/ 를 먼저 읽어라.
웹 pro 런타임 계약은 templates/pro_orchestrator_prompt.md — 충돌 시 그 문서가 우선.

[프로젝트 설정]
- 구현 레포(CODE_REPO): {OWNER}/{CODE_REPO}   # 없으면 사람이 먼저 생성 (§2)
- 관리 레포(MGMT_REPO): {MGMT_REPO}
- 프로젝트: {PROJECT} · 슬러그: {PROJECT_SLUG} · 단계: {PHASES 예: P0:환경파일럿,P1:베이스라인,...}
- 계획서 초안: 이 메시지에 첨부

[규칙]
- STEP 0(설정 로드)부터. projects/{PROJECT_SLUG}/project.yml 이 있으면 읽고, 없으면 신규 셋업(민감값 공란 유지).
- 민감값(SSH_HOST/WORKDIR/MODEL_MAIN/MODEL_EXEC/NTFY_TOPIC)은 공개 레포에 박제하지 마라 —
  세션 B 지시서(SESSION_B.md)에만 채워 마지막에 사람에게 넘긴다. 그 값은 내가 준다.
- 게시는 branch+PR 로만(main 직접 금지). pr-verify green 후 내가 merge 한다. 이슈도 PR 규율.
- STEP 1: 첨부 초안을 plan_refinement 로 정형화 → projects/{PROJECT_SLUG}/research/ 에 커밋(PR) → 내 승인 대기.
- STEP 2~: ORCHESTRATOR 절차대로 milestone → P0.md(@goal·Exit primary+guard 사전등록, HUMAN GATE class)
  → CODE push → dev 이슈 발행 계획 → 마지막에 세션 B 지시서를 복사 블록으로 출력하고 정지.
- 코드 구현·gjc 직접 조작 금지(세션 B 몫). 판정 금지(사람 몫; 나는 게이트 코파일럿).
- 모호하면 스스로 정하지 말고 나에게 물어라.
```

> 셋업(라벨·워크플로 4종·project.yml·대시보드 등록)이 아직이면, 세션 A 시작 전에 **§2 를 사람이 먼저** 밟는다.

---

## 2. 사람(로컬 셸) 셋업 체크리스트 (프로젝트당 1회 — LLM 세션 A는 셸이 없다)

`gh` 로그인 상태(두 레포 Contents RW + Issues RW)에서 로컬 셸로 실행한다.

```bash
# 1) 라벨 상태기계 + CODE phase 마일스톤 (멱등; bootstrap 이 라벨/마일스톤 생성)
bash research-ops/scripts/bootstrap_project.sh \
  {OWNER} {MGMT_REPO} {CODE_REPO} {PROJECT} "P0:환경파일럿,P1:베이스라인,P2:제안기법,P3:평가"

# 2) 워크플로 4종 + 불변값 매니페스트를 CODE repo .github/ 로 복사·커밋
cp research-ops/workflows/{pr-verify,phase-transition,gate-notify,evidence-verify}.yml \
   {CODE_REPO_LOCAL}/.github/workflows/
cp .github/immutables.txt {CODE_REPO_LOCAL}/.github/immutables.txt
git -C {CODE_REPO_LOCAL} add -A && git -C {CODE_REPO_LOCAL} commit -m "ci: research-ops workflows" && git -C {CODE_REPO_LOCAL} push

# 3) ntfy topic secret (프로젝트마다 고유 topic) → 폰 ntfy 앱에서 그 topic 구독
gh secret set NTFY_TOPIC -R {OWNER}/{CODE_REPO}     # 값: {project}-gates-{랜덤}

# 4) gate-watcher 설치 (원격 워크스테이션, 최초 1회; 재부팅 생존)
#    research-ops/gate-watcher/README + alerts/(경보 유닛) 참고
```

체크리스트:
- [ ] CODE_REPO 존재 (없으면 `gh repo create {OWNER}/{CODE_REPO} --private`)
- [ ] 라벨 상태기계 + phase 마일스톤 생성 (1)
- [ ] 워크플로 4종 + `.github/immutables.txt` CODE 에 커밋 (2)
- [ ] `NTFY_TOPIC` secret 등록 + 폰 구독 (3)
- [ ] gate-watcher 설치·상시가동 (4)
- [ ] `projects/{PROJECT_SLUG}/project.yml` 생성(민감값 공란) — 세션 A가 PR 로 하거나 사람이 커밋
- [ ] 대시보드 `CONFIG.projects` 에 프로젝트 등록 (사람이 `dashboard/index.html` 편집; project.yml 과 별개)

> 민감값(SSH_HOST/WORKDIR/MODEL_*)은 `project.yml` 공개본에 **채우지 않는다**. 세션 B 지시서에만 넣는다.

---

## 3. 셸 세션 A 변형 (짧게 — 세션 A가 셸/`gh` 를 가진 경우)

셸이 있는 세션 A(Claude/CLI)면 §2 의 셸 셋업을 세션 A가 대신 실행할 수 있다. 프롬프트는 §1 과 동일하되 첫 문단만 교체:

```text
너는 이 프로젝트의 세션 A(셸 변형)다. gh CLI 사용 가능.
관리 레포 research-ops/ORCHESTRATOR.md · PROTOCOL.md · templates/ 를 읽고 STEP 0(설정 로드)부터.
셋업은 bootstrap_project.sh·워크플로 복사·라벨 생성을 직접 실행해도 된다.
단, MGMT 문서/리포트/status 게시는 여전히 branch+PR(pr-verify green 후 사람 merge). dev 이슈는 setup_phase.sh 가능.
민감값은 공개 레포에 박제 금지 — 세션 B 지시서에만. (이하 §1 [규칙] 동일.)
```

---

## 4. 단계 전환·재개 (한 줄)

```text
단계 전환:  P{k} 완료. 상태 확인하고 P{k+1} 진행해줘.
재개:        {PROJECT} 오케스트레이션 이어서. ORCHESTRATOR §STEP0로 projects/<slug>/project.yml +
             status.json + CODE state:* 라벨로 상태 복원해 요약 보고 후 다음 할 일 제안. 임의 진행 금지.
```

> 이전 단계 확정값/리스크를 넘길 땐 한 줄 덧붙인다:
> "P0 확정 수치·승계 리스크는 projects/<slug>/reports/P0_report.html 참고해 P1.md 에 반영해줘."
