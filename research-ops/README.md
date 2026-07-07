# research-ops — 재사용 연구 오케스트레이션 키트 (프로젝트 무관, 현행판)

연구 프로젝트를 GitHub 로 관리하는 워크플로우를 템플릿화한 모음. 모든 프로젝트에 통용된다.
DGCC 는 이 키트로 돌린 최초의 실제 예시(reference)다.

## 디렉토리 맵

| 경로 | 무엇 |
|---|---|
| `ORCHESTRATOR.md` | **세션 A 실행 지시서 — 개념·절차 정본. 여기서 시작.** |
| `WORKFLOW.md` | 운영 계약(3-액터 + 자동화 모델, 상태=라벨, 게시=PR) |
| `PROTOCOL.md` | 상태·증거·게이트 계약(라벨 상태기계·GATE·EVIDENCE 스키마) |
| `SESSION_B.md` | 세션 B(gjc 감독) 지시서 템플릿 |
| `NEW_PROJECT_PROMPT.md` | 착수 프롬프트 fallback (정본은 `guide/` 마법사) |
| `templates/` | `pro_orchestrator_prompt.md`(웹 pro 런타임 계약) · `phase_spec.md` · `phase_report_guide.md` · `plan_*` · `issue_*` |
| `scripts/` | `bootstrap_project.sh`(라벨·마일스톤) · `setup_phase.sh`(dev 이슈) · `status.sh` · `lint_*.sh` — **셸용** |
| `workflows/` | CODE 레포로 복사하는 워크플로 킷 원본 4종 |
| `gate-watcher/` | 원격 systemd 데몬(리턴 경로) + `alerts/`(경보 유닛) |

## 액터 모델 요약

- **사람** — 킥오프·민감값 제공, HUMAN GATE 판정(GATE VERDICT), **세션 B 부팅**, **PR merge**.
- **세션 A** — 회고·명세·리포트·status·이슈·세션 B 지시서. 두 변형: **웹 pro**(기본, no-shell, REST/PR) / **셸**(gh CLI). 게이트 코파일럿(판정 X).
- **세션 B + gjc** — 세션 B가 원격에서 gjc 부팅·감시. **gjc 가 코드 구현**·CODE main 직접 push·dev 이슈 self open/close. **gjc 는 자동 시작 안 됨**(사람이 부팅).

## 워크플로 4종 + pr-verify 규율

CODE `.github/workflows/` 4종: `pr-verify` · `phase-transition` · `gate-notify`(아웃바운드) · `evidence-verify`.
- **MGMT 게시 규율**: 문서·리포트·status 는 **branch+PR 로만**, `pr-verify` green 후 **사람 merge**(직접 main push 금지). MGMT 에는 `pr-verify` 만 있다. CODE 는 gjc 가 main 직접 push(브랜치 보호는 P1 종료 시 도입).

## gate-watcher

원격 워크스테이션 systemd 데몬. 사람이 GATE VERDICT 게시 → 살아있는 gjc tmux 에 "가서 읽어라" 신호(본문 주입 없음). 설치·경보 유닛: `gate-watcher/README` + `gate-watcher/alerts/`.

## projects/<slug> 컨벤션

```
projects/<slug>/
  research/        # 정형화 계획서(.md/.html), status.json
  reports/         # 단계 리포트 P{k}_report.html
  implementation/  # implementation plan
  project.yml      # 세션 A/B 입력용 비민감 설정 (민감값 {SSH_HOST}/{WORKDIR}/{MODEL_*} 공란 유지)
```

`project.yml` 은 **세션 A/B 입력용**이며, 대시보드 `CONFIG.projects`(하드코딩 레지스트리)와 **용도가 분리**된다 — 서로 참조하지 않는다.

## 상태의 진실은 GitHub

별도 상태 파일 없음. "지금 어느 단계"는 `projects/<slug>/research/status.json` + Current milestone, "어디까지"는 CODE 레포 `state:*` 라벨 분포로 판단한다(`PROTOCOL.md §7`). 세션이 끊겨도 이것만 읽으면 재개된다.

## 새 프로젝트 시작 — 한 줄

**정본**: `guide/` 셋업 마법사에 값을 채운다. 마법사 없이면 `NEW_PROJECT_PROMPT.md`(웹 pro 프롬프트 + 사람 셸 셋업 체크리스트). 이후 **"P{k} 완료. 다음 단계 진행해줘"** 한 줄로 단계가 넘어간다.

## 링크

- 셋업 마법사·운영 가이드: `guide/`
- 대시보드(프로젝트 레지스트리): `dashboard/`
- 상태·증거·게이트 계약: `PROTOCOL.md`
- 웹 pro 런타임 계약: `templates/pro_orchestrator_prompt.md`
- 기준 예시(reference): **DGCC** — `DGCC/P0.md`, dashboard P0–P7 이슈, 완료·확정 수치 기록.
