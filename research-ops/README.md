# research-ops — 재사용 연구 오케스트레이션 키트 (프로젝트 무관)

연구 프로젝트를 GitHub로 관리하는 워크플로우를, **매번 처음부터 설명하지 않기 위해** 템플릿화한 모음.
DGCC 전용이 아니라 **모든 프로젝트에 통용**된다. DGCC는 이 키트로 돌린 최초의 실제 예시(reference)다.

## 무엇이 들어 있나

| 파일 | 역할 | 대상 |
|---|---|---|
| `ORCHESTRATOR.md` | **세션 실행 지시서.** (계획서 + 구현 레포 주소) → milestone 생성 → 단계별 명세·이슈 → gjc 위임 → 완료 확인 → 다음 단계 반복. **여기서 시작.** | 에이전트 |
| `WORKFLOW.md` | 운영 계약서 — 3층위 모델·레포 구성·단계 생애주기·규칙 | 에이전트 + 사람 |
| `templates/phase_spec.md` | 단계 명세 `P{k}.md` 뼈대 (gjc brief) | 에이전트 |
| `templates/issue_milestone.md` | 관리 레포 milestone 이슈 본문 뼈대 | 에이전트 |
| `templates/issue_dev.md` | 코드 레포 dev 이슈 본문 뼈대 | 에이전트 |
| `templates/bootstrap_project.sh` | 새 프로젝트의 전체 milestone(P0..Pn) 일괄 생성 | 스크립트 |
| `templates/setup_phase.sh` | 한 단계의 dev 이슈(M0..Mj) 생성 | 스크립트 |

## 새 프로젝트 시작하는 법 — 한 줄

에이전트에게 `ORCHESTRATOR.md §7`의 kickoff 프롬프트를 복붙하고, 입력 4개만 채운다:

```text
research-ops/ORCHESTRATOR.md 를 읽고 STEP 1부터 진행해줘.
- 연구 계획서: {경로/URL}
- 구현 레포: {URL}
- 관리 레포: research-dashboard
- 실행 환경: SSH_HOST=.., WORKDIR=.., HARDWARE=.., 도구=..
```

그러면 에이전트가: 계획서 파싱 → milestone 일괄 생성 → P0.md + dev 이슈 생성 → gjc 실행을 너에게 넘김.
이후 **"P{k} 완료. 다음 단계 진행해줘"** 한 줄로 단계가 넘어간다.

## 다음 단계로 넘기는 법 — 한 줄

```text
P{k} 완료. 상태 확인하고 P{k+1} 진행해줘.
```

에이전트가 완료 검증(ORCHESTRATOR §4) 후 다음 단계 명세·이슈를 만든다.

## 상태의 진실은 GitHub

별도 상태 파일 없음. "지금 어느 단계"는 관리 레포의 Current milestone, "어디까지"는 코드 레포 dev 이슈의 open/closed로 판단한다. 세션이 끊겨도 이것만 읽으면 재개된다.

## 기준 예시 (reference)

**DGCC** — `DGCC/P0.md`(잘 채운 명세), dashboard의 P0–P7 milestone 이슈, `docs/reports/P0_pilot_gates.md`(완료·확정 수치 기록). 새 단계·새 프로젝트를 만들 때 답안지로 참고하라.
