# 계획서 보강·정형화 프로세스 (ORCHESTRATOR STEP 2)

받은 **초안 계획서**를 학회(예: ICML/ICLR/ICRA/CoRL) 수준으로 끌어올리고, `research_plan_template.md` 구조에 맞춰 정형화한 뒤, `plan_html_guide.md`로 HTML을 생성한다.
잘 된 실제 예시: DGCC (초안 v3/v4 → `docs/research/DGCC_research_plan.md` + `.html`).

## 원칙

- **단단한 핵심 아이디어와 논리 전개가 최우선.** 방어 논리로 갑옷을 두르기 전에, 가설이 왜 나왔는지(관찰→추론 사슬)와 그것이 논리적으로 성립하는지를 먼저 세운다.
- **무거운 작업은 subagent(Opus)로 위임.** 문헌 조사·코드베이스 분석·적대적 리뷰는 병렬 subagent로. (메인 세션만 상위 모델 사용 규칙이 있으면 준수.)
- **날조 금지.** 인용은 제목·저자·학회·연도·arXiv ID를 웹으로 검증. 확인 안 된 건 [미확인] 표기.
- 모호한 방향 결정(스코프·핵심 가설 변경 등)은 스스로 정하지 말고 사람에게 묻는다.

## 절차 (A → F)

```text
A. 문헌 조사   주제 트랙별로 subagent 병렬 파견 →
               관련 연구 정리 + 가져올 insight + novelty 위협(가장 가까운 선행 3편) 도출
B. Gap 분석    조사 결과로 이 아이디어가 차지하는 빈자리(research gap)를 명시
C. 비판적 검토 가설 도출 논리·논리적 결함·실험 설계 허점·novelty 위협을 심각도 순으로 진단
D. 적대적 리뷰 subagent를 리뷰어 패널(해당 학회 관점)로 세워 최대한 공격 →
               치명/중대 지적을 계획서에 반영 (사전 등록·게이트·kill criterion 등)
E. 정형화      research_plan_template.md 구조로 재작성:
               - 내부 버전명(v3/v4 등) 제거, 최종본으로
               - Related Works는 본문에 링크만, 문서 하단에 통합 섹션
               - 리스트 남발 대신 prose·문단, 실행 공백(수치·프로토콜·인터페이스) 보강
               - PI에게 보여도 납득할 수준
F. 검증        인용·수치·논리 자기모순 재점검 (필요 시 subagent 검증)
```

각 절차의 산출물(문헌 리뷰·gap·비판·리뷰 로그)은 보조 문서로 남겨 근거를 보존하되, 최종 계획서 본문은 template 구조를 따른다.

## HUMAN 승인 게이트 (필수)

정형화된 최종 계획서를 사람에게 제시하고 승인받는다. **이 계획서가 이후 모든 단계(milestone·P{k}.md)의 근거**이므로, 사람 확인 없이 STEP 3으로 넘어가지 않는다. 사람이 수정 요청하면 반영 후 재확인.

## 출력

```text
docs/research/<project>_research_plan.md    최종본 (버전명 없음, Related Works 하단)
docs/research/<project>_research_plan.html  plan_html_guide.md 로 생성
(보조) 문헌 리뷰·gap·리뷰 로그 등은 docs/research/ 또는 별도 폴더에
```

이 최종 계획서의 **일정/단계 섹션**(template §단계)이 STEP 3 milestone과 각 P{k}.md의 입력이 된다.
