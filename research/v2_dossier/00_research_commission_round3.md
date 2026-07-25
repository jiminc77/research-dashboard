# 07b — GPT Pro 3차 자문 전문: V2 리서치 발주서 (2026-07-25)

> 출처: ChatGPT Pro (Pro effort, "Worked for 41m 59s"), 대화 "ICRA 2027 논문 프레이밍" chatgpt.com/c/6a630a9d-71a0-83ee-bb27-9d820d9e6370 — GitHub 레포 실독 기반.
> 용도: ③ gjc 리서치 세션 발주(WP-0~10 = [V2-PRE]) + 문헌 조사([V2-LIT]) + ④ GPT 4차 설계의 입력. 인수인계는 08 문서 참조.

---

[GPT Pro 3차 자문 답변 — "ICRA 2027 논문 프레이밍" 대화, 2026-07-25, Worked for 41m 59s]
(주: 수식은 페이지 텍스트 추출 특성상 줄바꿈이 섞여 있음. "GitHub +N"은 GPT의 인용 배지 표기임.)

재검증된 출발점

공개 main 기준으로 V1은 s0–s2까지 complete, s3는 아직 observed 상태임. Heldout 결과는 s0 21.5%/+1.532, s1 12.0%/+0.962, s2 33.0%/+2.244로 기록되어 있음. s2는 현재 공개된 BB·V1 전체 중 success와 return 모두 최고이며 paired BB s2를 +3.0%p/+0.217만큼 이김. 다만 최초 3개 paired seed 평균은 V1−BB success −5.17%p, return −0.317이므로, 현 증거는 "상한 부족"보다는 "높은 성능 basin은 존재하나 진입 확률과 lower tail이 불안정함"을 시사할 뿐, 분산 문제만이 원인이라고 확정하지는 못함. [GitHub +1]

코드상 actor는 auxiliary gradient의 영향을 받은 shared h_i ∈ R^256를 이미 입력받음. 따라서 "aux representation을 actor에 노출"하는 방향은 V1과 완전히 새로운 개념이 아니라, action-conditioned z_resp 또는 predicted δm를 명시적으로 actor/decision path에 추가하는가의 문제임. f_resp([h_p,u])는 현재 V1 critic_update에서만 호출되고 inherited actor_update, compute_target, select_actions에서는 사용되지 않음. [GitHub +4]

또 하나의 중요한 코드 사실은 objective mismatch임. Actor는 모든 32 contact에 대한 Q_min 평균을 최대화하지만, deployment에서는 online Q_1 argmax로 contact를 선택하고, TD target에서는 target Q_1로 contact를 선택한 뒤 Q_min으로 평가함. 현재 update()는 critic, actor, target을 매 update마다 모두 갱신하여, original TD3가 제안한 delayed policy update도 구현되어 있지 않음. 이는 V2 architecture 후보뿐 아니라 baseline hygiene 문제로도 별도 조사해야 함. [GitHub +1]

Governance 측면에서는 공개 issue body와 sprint_spec.md가 아직 V1 paper-sprint 및 이전 GNG-2 기준을 가리키고 있으며, 별도 V2 charter는 확인되지 않음. 또한 기존 sprint heldout은 이미 BB/V1 결과를 통해 V2 방향 결정에 영향을 주었으므로, V2의 clean confirmatory claim에는 새로운 미접촉 heldout split이 필요함. 과거 AMD-3에서 제외된 seed 5를 V2 confirmatory에 다시 사용하려면 새 track에 한정된 재사용 근거, 기술 결함 해소 조건, paired BB comparator를 charter에서 명시해야 함. [GitHub +4]

Q1. 레포 코드 분석 과업 명세서

아래 문안을 gjc에게 그대로 전달하는 형태임.

[V2-PRE] DGCC V2 Pre-Design Code Audit
1. Mission

DGCC V2 architecture를 설계하거나 구현하지 말 것. 현재 codebase에서 V2 선택을 가르는 사실을 file/function/line 단위로 검증하고, 각 가능한 integration seam의 semantics, gradient path, RNG effect, compute cost, comparator fairness를 문서화할 것.

최종 보고서는 반드시 다음 세 범주를 분리할 것.

FACT: code, config, committed artifact에서 직접 확인
INFERENCE: 여러 사실로부터 도출했으나 실행 검증 전
OPEN: 추가 instrumentation 또는 smoke test 필요

2. Hard constraints

V2 candidate 구현 및 production run 금지.
새 V2 confirmatory heldout split의 내용 열람·실행 금지.
기존 heldout evaluator는 code inspection만 허용, 실행 금지.
모든 사실에 git commit SHA, file:function, line range, 재현 command 기록.
working tree가 dirty하면 audit 중단 후 상태 보고.
GPU profiling은 synthetic/frozen validation batch만 사용. 새 RL training 금지.
source-bundle path와 live-main path를 각각 감사하고 차이를 보고.
architecture 변경 제안은 하지 말고, 가능한 seam과 그 계약만 보고.
현재 V1/BB heldout aggregate는 이미 공개된 historical context로만 사용. V2 candidate selection metric 계산에 사용 금지.
public issue body 외 comment pin이 있을 경우 comment ID와 content hash까지 별도 확인.

3. Required deliverables

다음 파일 생성.

docs/v2_pre_design_code_audit.md
outputs/reports/v2_code_facts.json
outputs/reports/v2_callgraph.md
outputs/reports/v2_callgraph.dot
outputs/reports/v2_budget_semantics.csv
outputs/reports/v2_rng_ledger.md
outputs/reports/v2_learning_curve_audit.csv
outputs/reports/v2_integration_cost.csv
outputs/reports/v2_governance_gap.md

v2_code_facts.json 최소 schema:

{
"head_sha": "...",
"source_bundle_sha": "...",
"environment": {},
"facts": [
{
"id": "ACTOR-001",
"status": "FACT|INFERENCE|OPEN",
"statement": "...",
"evidence": [
{"path": "...", "function": "...", "lines": "..."}
],
"design_consequence": "...",
"verification_command": "..."
}
]
}

WP-0. Governance, heldout firewall, seed eligibility

검사 대상
sprint_spec.md
scripts/sprint_heldout_eval.py
scripts/sprint_claims.py 또는 동등 claim/manifest code
scripts/*checkpoint*selector*.py
configs/**/*
outputs/reports/sprint_g6a_report.md
outputs/reports/sprint_g6b_report.md
outputs/archive/sprint_crash/**/*
research-dashboard#35
research-dashboard#36
DGCC#17
DGCC#22
관련 pinned comments

필수 작업

현재 V2 charter 존재 여부, commit SHA, issue/comment pin, 첫 V2 run 이전 등록 여부 확인.
기존 t2_sprint_heldout_v1이 V2 confirmatory split으로 재사용되는지 확인.
재사용 예정이면 다음을 BLOCKER로 표시:
- V1/BB 결과가 V2 방향 결정에 이미 사용됨.
- architecture search 이후 동일 split은 clean confirmatory test가 아님.
별도 V2 heldout이 있다면: 생성 시점, generator code SHA, seed, manifest hash, file permission/read audit, candidate process가 접근하지 못한다는 test 확인.
seed 5 관련 crash 두 건을 attempt별로 재구성: simulator failure / rebuild-limit / GPU contention / code defect / environment defect 중 어느 범주인지 근거와 함께 분류.
V2 confirmatory seeds 5–7 각각에 대해 다음 availability matrix 작성:
Seed | BB valid | V1 valid | proposed V2 | same code/config | same execution regime | heldout untouched | technical risk
"V2 > BB" paired claim에 필요한 fresh BB seed 5–7 run이 예산에 포함되어 있는지 확인.
old AMD-3의 seed-5 exclusion이 V1/BB pair에만 적용되는지, 모든 future experiment에 적용되는지 governance text로 판정.
technical retry/replacement rule이 V2 charter에서 사전 고정되어 있는지 확인.

필수 결론 — 다음 중 하나로 판정.
READY: fresh V2 heldout + paired comparator + seed eligibility가 모두 고정됨.
CONDITIONAL: architecture exploration은 가능하나 confirmatory claim contract가 미완성임.
BLOCKED: old heldout reuse, comparator 부재, seed-5 unresolved failure 중 하나 이상 존재.

왜 설계를 가르는가: 가장 좋은 V2를 찾아도 heldout 또는 comparator provenance가 오염되면 "BB를 이긴 confirmatory architecture"라는 headline이 성립하지 않음.

WP-1. Actor input, gradient path, contact/action semantics

검사 대상
src/dgcc/models/networks.py — build_node_features, Encoder.__init__, Encoder.forward, Actor.__init__, Actor.forward, _QHead.forward, TwinCritic.forward
src/dgcc/rl/td3.py — TD3Agent.features, TD3Agent._q_all_candidates, TD3Agent.critic_update, TD3Agent.actor_update, TD3Agent.compute_target, TD3Agent.select_actions, TD3Agent.update
src/dgcc/rl/sprint_arms.py — SprintTD3Agent.critic_update

필수 작업

다음 execution mode별 tensor/gradient table 작성.
Mode | Encoder input | Encoder output | Actor input | Critic input | Contact selection | Q operator | Encoder grad | Actor grad | f_resp call
(rows: replay critic update / actor update / TD target / exploration rollout / deterministic eval / heldout eval)

반드시 확인할 사항:
- Actor가 받는 것은 selected h_p가 아니라 전체 h ∈ R^{B×32×256}인지.
- Actor의 각 node output이 다른 node와 독립된 shared MLP인지.
- Actor update에서 encoder가 no_grad 또는 detach되는지.
- Auxiliary loss gradient가 encoder를 통해 actor의 미래 입력 분포를 바꾸는지.
- lift가 actor 내부에서는 sigmoid continuous relaxation이고 실제 환경에서는 0.5 threshold로 binarize되는지.
- Actor objective가 all-contact mean인지, selected contact만인지.
- Contact p가 actor gradient를 받지 않는 discrete argmax인지.
- Q1/Q2/Qmin이 train, target, deployment에서 각각 어떻게 사용되는지.

현재 architecture는 7-D node feature를 256-D per-node representation으로 변환하고, actor가 이를 바로 사용함. 따라서 "actor가 physics를 전혀 보지 않는다"는 설명은 코드상 틀리며, 정확한 표현은 "actor는 response-supervised shared embedding을 간접적으로 사용하지만 explicit action-conditioned response prediction은 사용하지 않는다"임. [GitHub +3]

왜 설계를 가르는가: actor input 확장이 실제 신규 정보인지 단순 중복 concat인지, 그리고 actor pathway를 바꿔야 하는지 critic/selection pathway만 바꿔야 하는지를 결정함.

WP-2. f_resp/z_resp lifecycle 및 사용 가능한 접합점

검사 대상 — 전체 repository에서 다음 명령 실행.
git grep -nE '\bf_resp\b|\bz_resp\b|ResponseHead|delta_m_from_batch'
git grep -nE 'select_actions|actor_update|compute_target|q_min_executed'
git grep -nE 'load_checkpoint|save_checkpoint|state_dict'

중점 함수:
src/dgcc/rl/sprint_arms.py — ResponseHead.z_resp, ResponseHead.forward, delta_m_from_batch, SprintTD3Agent.__init__, SprintTD3Agent.critic_update, SprintTD3Agent.save_checkpoint, SprintTD3Agent.load_checkpoint, create_sprint_agent
src/dgcc/rl/td3.py — actor_update, compute_target, select_actions, q_min_executed
scripts/p1_train.py — collect_round, deterministic_eval
scripts/sprint_heldout_eval.py

필수 작업

f_resp의 전체 call graph 작성.
다음 주장을 code-level로 yes/no 판정:
- training에서만 호출됨
- target backup에서는 호출되지 않음
- actor loss에서는 호출되지 않음
- exploration action selection에서는 호출되지 않음
- deterministic evaluation에서는 호출되지 않음
- heldout evaluation에서는 호출되지 않음
- checkpoint에는 저장되고 복구됨
z_resp와 δm의 exact shape, activation, dtype, device 확인.
B×32개의 actor-proposed action을 f_resp로 한 번에 vectorize할 수 있는지 synthetic test.
다음 seam마다 필요한 tensor shape, 추가 forward count, gradient semantics, behavioral effect를 문서화. 구현은 금지.

Seam ID | 위치 | 입력 | 출력 | train behavior 변경 | deploy behavior 변경
R1 | select_actions: u_all 생성 후, Q ranking 전 | h, u_all | z_resp 또는 δ̂m | no/optional | yes
R2 | compute_target: target actor 후 | h', u'_all | predicted response | yes | no
R3 | actor_update: provisional actor action 후 | h, u_θ | response feature | yes | indirect
R4 | critic input 또는 residual branch | h, u, δ̂m | modified Q | yes | yes
R5 | eval-only candidate diagnostic | h, u_all | calibration metrics | no | no

z_resp(h,u)가 action-dependent이므로 actor input으로 직접 넣을 때 발생하는 circular dependency를 명시:
- actor가 u를 내기 전에 z_resp 계산 불가
- one-pass concat인지
- proposal→response→refinement two-pass가 필요한지
- critic-side scoring으로만 쓸 수 있는지

현재 f_resp는 V1 critic loss에만 연결되고, inherited action-selection 및 target code는 이를 호출하지 않음. [GitHub +3]

왜 설계를 가르는가: V2가 "훈련용 auxiliary를 실제 control computation으로 승격"하는 작은 diff가 될 수 있는지, 아니면 새 two-stage architecture가 필요한지를 결정함.

WP-3. Hybrid action objective와 train–deployment alignment

검사 대상
src/dgcc/rl/td3.py — select_p_star, compute_target, critic_update, actor_update, update, select_actions

필수 작업

다음 세 operator를 수식과 code line으로 병렬 정리.
L_actor = −E[(1/K) Σ_p Q_min(h_p, π(h_p))]
p_deploy = argmax_p Q_1(h_p, π(h_p))
p_target = argmax_p Q_1^target(h'_p, π^target(h'_p))
그리고 target evaluation은 선택된 p_target에서 Q_min^target을 사용한다는 점 확인.

추가 instrumentation 설계만 작성 — 아래 지표를 기존 frozen checkpoints에서 계산하는 offline script 명세 작성.
- Q_1 argmax와 Q_min argmax agreement.
- Top-1/Top-2 contact margin.
- Candidate rank entropy 및 contact-index 사용 분포.
- Q_1 − Q_2 disagreement at selected contact.
- All-contact actor gradient norm distribution.
- Deploy-selected contact와 mean-actor-loss 기여 contact의 overlap.
- Goal family별 contact concentration.
- Late acceleration 전후 contact-margin 변화.
- Actor update 이후 selected contact가 바뀌는 빈도.
- Lift relaxation 값의 0.5 근처 mass와 실제 binarization instability.

TD3 conformity audit — Original TD3 대비 다음 표 작성.
Component | Original TD3 | DGCC current | Difference likely material? | Existing evidence
(rows: twin critic / target policy smoothing / delayed actor update / delayed target update / actor Q operator / hybrid contact selection)

현재 DGCC는 actor와 targets를 매 update마다 갱신함. Original TD3의 delayed policy update는 function approximation error를 줄이기 위한 핵심 구성으로 제시됨. 다만 이를 적용하는 것은 우선 baseline correction/stability control로 분류하고, 자동으로 V2 novelty로 간주하지 말 것. [GitHub +1]

왜 설계를 가르는가: V2 성능 병목이 response information 부재가 아니라 actor objective와 실제 선택 operator의 불일치 또는 noncanonical TD3 update cadence일 가능성을 판별함.

WP-4. 300k→600k budget semantics, replay, resume

검사 대상
src/dgcc/rl/td3.py — TD3Config, epsilon_schedule, update
src/dgcc/rl/replay.py — ReplayBuffer.__init__, ReplayBuffer.add_batch, ReplayBuffer.sample
scripts/p1_train.py — TrainingRun.__init__, collect_round, train_updates, eval_and_checkpoint, save_run_summary, run, CLI --total-override
checkpoint save/load paths 전부

필수 작업

다음 세 경우를 분리해 table 작성.
Property | 300k fresh | 600k fresh | 300k→600k exact continuation
(rows: epsilon decay endpoint / expected critic updates / expected actor updates / expected target updates / replay maximum age / oldest data overwrite / optimizer state preserved / replay preserved / NumPy RNG preserved / Torch/CUDA RNG preserved / episode/env state preserved / eval ordinal preserved / checkpoint-selector comparability)

반드시 수치화할 사항:
- eps_p_fraction=0.3이므로 300k fresh의 contact exploration decay horizon과 600k fresh horizon.
- replay capacity 500k에서 600k collection 시 overwrite되는 초기 transition 규모.
- warmup 이후 collected active transition당 update 수.
- current actor/target update count.
- eval/checkpoint 수와 eval 후 episode reset 횟수.
- 600k가 단순 "추가 300k 학습"이 아니라 exploration/replay distribution을 바꾸는지.
- current checkpoint가 저장하지 않는 state: replay arrays, _next, size / np.random.Generator.bit_generator.state / Torch CPU/CUDA RNG states / target-noise generator / transitions / episode index / eval ordinal / environment/reset state / best-checkpoint state / diagnostics history.
- exact continuation 구현 시 필요한 최소 serialization contract.

현재 epsilon_schedule은 total budget의 비율로 정의되며, replay는 500k fixed ring임. Training checkpoint는 networks, optimizers, update count를 저장하지만 training driver의 replay/RNG/env bookkeeping 전체를 복구하지 않음. 따라서 현 상태에서 --total-override 600000은 clean extension과 동일하지 않음. [GitHub +5]

왜 설계를 가르는가: 600k candidate가 architecture improvement인지 단순 exploration·replay·compute 차이인지 분리하지 못하면 V2 headline이 무효화됨.

WP-5. Reward, success, termination, evaluation, checkpoint selection

검사 대상
src/dgcc/tasks/reward.py — distance_to_goal, is_success, step_reward
src/dgcc/tasks/episode.py — EpisodeConfig, BatchedEpisodeRunner.begin_episodes, BatchedEpisodeRunner.step, reset/retry paths
src/dgcc/goals/distance.py
src/dgcc/goals/dual_goal.py
src/dgcc/tasks/t2.py
src/dgcc/evaluation.py 또는 동등 evaluator
scripts/p1_train.py — deterministic_eval, eval_and_checkpoint
sprint checkpoint selection/claim scripts

필수 작업

Reward 수식을 exact code route와 함께 작성.
Success threshold를 normalized/raw unit 모두로 표현.
Episode horizon, early success termination, timeout truncation 확인.
Timeout transition이 TD target에서 bootstrap되는지 확인.
Return이 discounted인지 undiscounted인지, evaluation과 training log가 같은 정의인지 확인.
mean_final_d, mean_min_d, mean_d_at_done, mean_return, binary success의 exact 계산 경로 확인.
best.pt 선택과 sprint heldout용 selected checkpoint 규칙 차이 확인.
Success tie에서 earlier/later checkpoint가 선택되는지 확인.
Validation checkpoint selection이 binary success 중심인지 continuous metric 중심인지 확인.

다음 retrospective 분석 실시:
- return–final distance correlation
- success–return disagreement
- high return/zero success episodes
- success bonus가 total return을 지배하는 정도
- goal family별 reward contribution
- stepwise progress가 마지막 shaping 성능을 예측하는 정도
V2 winner rule에서 쓸 수 있는 metric과 쓸 수 없는 metric을 구분.

현재 reward와 success는 동일한 correspondence_l2 경로를 사용하고, reward는 one-step distance reduction, step cost, success bonus의 합임. Episode horizon은 10이며 success 시 조기 종료, timeout은 truncated로 기록되어 TD target에서 bootstrap됨. [GitHub +3]

왜 설계를 가르는가: V2가 binary success를 높이는지, progress shaping만 개선하는지, 또는 checkpoint lottery만 개선하는지를 분리함.

WP-6. RNG ledger와 paired-seed fairness

검사 대상 — 전체 repository:
git grep -nE 'np\.random|default_rng|torch\.rand|torch\.randn|manual_seed|Generator|fork_rng'

특히:
scripts/p1_train.py — TrainingRun.__init__, collect_round, train_updates, deterministic_eval
scripts/p1_sprint_train.py — create_seeded_agent, SprintTrainingRun.__init__
src/dgcc/rl/td3.py — compute_target, select_actions
src/dgcc/rl/sprint_arms.py — response-head initialization

필수 작업

RNG ledger 작성.
RNG | Initial seed | Consumers | Shared across subsystems? | Saved/restored? | Candidate-dependent consumption risk
(rows: NumPy training RNG / eval RNG / simulator RNG / replay sampling RNG / contact exploration RNG / Torch global RNG / target smoothing RNG / response-head init RNG / proposed planner RNG)

중점 확인:
- 현재 self.rng가 exploration, environment step, replay sampling에 공용인지.
- V2가 candidate perturbation 또는 stochastic planning을 추가하면 downstream replay/environment randomness까지 바뀌는지.
- agent.update()에 explicit torch.Generator가 전달되지 않아 target policy noise가 global Torch RNG를 쓰는지.
- 새 module 초기화가 target-noise sequence를 변경하는지.
- p1_sprint_train.py가 base agent를 한 번 생성한 후 retained sprint agent로 교체하는 구조의 RNG·CUDA allocator 영향.
- same-seed BB/V1/V2의 shared backbone initial hash가 설계 의도대로 비교 가능한지.

현재 training loop는 동일 NumPy generator를 action selection, environment step, replay sampling에 전달하며, sprint driver는 inherited TrainingRun에서 baseline agent를 만든 뒤 reseed하여 retained sprint agent로 교체함. [GitHub +3]

왜 설계를 가르는가: 추가 model call이나 planner random draw가 seed-matched comparison을 architecture 차이가 아닌 RNG stream 차이로 오염시키는 것을 방지함.

WP-7. V2 extension surface와 backward compatibility

검사 대상
scripts/p1_sprint_train.py
src/dgcc/rl/sprint_arms.py
configs/sprint*.yaml
checkpoint loaders
source-bundle validation
claim/manifest generators
tests concerning arm enums and schema

필수 작업

현재 SprintArm 및 CLI --arm이 bb/v1/matched/random으로 hard-coded된 모든 위치 목록.
새 arm 추가 시 수정되는 파일 수와 line count 추정.
Current V1 checkpoint를 V2 code에서 load할 때 schema compatibility.
f_resp를 쓰지 않는 BB path가 bitwise 또는 tolerance-equivalent하게 유지되는지.
source-bundle mode에서 live-main V2 module이 섞일 가능성.
run tag, output filename, claim manifest, checkpoint metadata에 candidate ID와 architecture hash를 넣을 seam.
한 candidate 수정이 shared TD3 baseline을 바꾸는지 subclass-only diff인지 구분.

최소 diff surface를 아래 형식으로 보고.
Candidate capability | Files necessarily touched | Shared baseline touched? | Checkpoint schema change? | Existing-run compatibility

왜 설계를 가르는가: owner의 "simple, literature-grounded, small diff" 제약을 정량화하고 BB/V1 path regression을 막음.

WP-8. Historical learning-curve 및 late-acceleration audit

데이터
outputs/metrics/p1_run_sprint_t2_v1_s*.json
outputs/metrics/p1_run_sprint_t2_bb_s*.json
관련 archived/reuse BB run JSON
selection manifests

필수 작업

각 run에 대해 25k checkpoint별 다음 long-format CSV 작성.
arm, seed, cohort, transitions, val_success, val_return, mean_final_d, mean_min_d, overestimation_gap, q1_std, actor_grad_norm, critic_grad_norm, aux_loss, nan_count, magnitude_count, rebuild_count, wall_s, selected_checkpoint

다음 historical predictor를 계산하되 V2 winner metric으로 아직 채택하지 말 것.
- 100k, 150k, 200k, 225k metric과 final validation metric의 rank correlation.
- 150–225k 및 200–300k return AUC.
- 175–225k, 225–300k return slope.
- first threshold-crossing time.
- best checkpoint와 final checkpoint 차이.
- success와 continuous metrics의 lead/lag.
- late-acceleration 정의 후보별 sensitivity.
Leave-one-seed-out 방식으로 early-stop rule의 false-reject rate.
V1 s0 같은 late improver가 150k rule에서 제거되는지 명시.
s2가 초기부터 좋은 seed인지 늦게 급상승한 seed인지 구분.

V1 s0는 약 150.5k에서 validation success 6%, return 0.070이었으나 이후 크게 개선되어 heldout 21.5%/+1.532를 기록함. 따라서 150k return 기반 hard kill은 이미 관찰된 viable run을 오기각할 수 있음. [GitHub +1]

왜 설계를 가르는가: V2가 최고 성능을 높이는지, late acceleration을 앞당기는지, low-performing basin 진입을 막는지를 구분하고 안전한 racing rule을 설계함.

WP-9. Compute 및 real-deployment feasibility profiling

필수 작업

Frozen checkpoint와 synthetic batch에서 다음을 측정.
Operation | Batch shape | GPU latency p50/p95 | Peak memory | Calls/action | Estimated real-robot latency
(rows: encoder B×32 / actor all contacts B×32 / twin Q all contacts B×32 / f_resp all contacts B×32 / f_resp × action perturbations B×32×M / complete select_actions)

CUDA synchronization을 포함한 정확한 timing protocol 사용.
Warm-up 제외.
M ∈ {1,4,8,16} action candidate scaling 측정.
Simulator step 대비 network overhead 비율 측정.
Franka stop-and-go loop에서 감당 가능한 inference budget 추정.
300k run wall time에 추가되는 학습 overhead 추정.
후보가 baseline 대비 25% 이상 wall-time 증가할 가능성이 있으면 표시.

왜 설계를 가르는가: lookahead가 simulation에서는 작아 보여도 real deployment 또는 5일 exploration budget을 붕괴시키는지 판별함.

WP-10. Pre-V2 contract tests

구현할 architecture가 아니라, 이후 모든 candidate가 통과해야 할 test 명세 작성.

필수 test:
- aux_weight=0에서 BB parity.
- Unmodified V1 checkpoint round-trip.
- Current V1 inference가 f_resp 호출 없이 기존 output과 동일.
- Same seed shared-backbone initial hash parity.
- Candidate-specific forward가 global RNG를 소비하지 않는지.
- No V2 process can open V2 confirmatory split.
- No candidate can invoke heldout evaluator.
- Current 300k configuration의 epsilon/replay/update semantics 불변.
- Checkpoint metadata에 candidate ID, code SHA, config SHA, parent architecture ID 포함.
- Technical failure가 performance 결과와 무관하게 자동 기록됨.
- All candidate attempts가 immutable run registry에 들어감.
- Candidate code가 BB/V1 evaluator semantics를 변경하지 않음.
- V2 candidate가 f_resp를 사용할 경우 response-head checkpoint absence를 fail-closed 처리.
- Deployment-only feature가 target/actor training에서 우연히 사용되지 않는지 call-count assertion.
- Training-use feature가 target network에 누락되는 경우 명시적 failure.

gjc 최종 답변에서 반드시 판정할 12개 질문
1. V1 actor는 auxiliary information을 이미 간접적으로 받는가?
2. Explicit z_resp/δm actor conditioning은 one-pass로 가능한가?
3. f_resp는 현재 deployment와 target path에서 완전히 미사용인가?
4. B×32 candidate response scoring은 작은 overhead로 vectorize 가능한가?
5. Actor objective와 deployed contact-selection objective는 정렬되어 있는가?
6. Original TD3의 delayed actor/target update가 누락되어 있는가?
7. 600k fresh와 300k continuation은 현재 동일한 실험이 될 수 있는가?
8. Current replay/RNG/checkpoint contract로 exact continuation이 가능한가?
9. V2 추가 연산이 paired RNG fairness를 깨뜨리는가?
10. 새 V2 confirmatory heldout은 기존 sprint heldout과 분리되어 있는가?
11. Seed 5–7에 valid paired BB comparator가 존재하거나 실행 예산이 잡혀 있는가?
12. 최소 diff로 가능한 seam은 actor, critic, selection, target 중 어디인가?

Q2. 문헌 조사 발주서

아래 문안을 literature agent에게 그대로 전달하면 됨.

[V2-LIT] DGCC V2 Literature Due Diligence
1. 목적

DGCC V2 최종 architecture를 설계하지 말 것. 아래 각 방향에 대해:
- 기존 연구에서 실제로 사용한 mechanism
- mechanism이 actor, critic, auxiliary model, deployment 중 어디에 연결되는지
- 왜 성능이 개선된다고 주장하는지
- 어떤 ablation이 그 주장을 지지하는지
- 어떤 조건에서 실패하거나 효과가 사라지는지
- DGCC에 적용할 경우 필요한 최소 diff
- DGCC의 known failure mode와 맞는지
를 primary source 기준으로 조사할 것.

2. 문헌 선정 규칙

Conference paper, journal paper, official preprint, official code만 evidence로 사용.
Survey/blog는 검색 출발점으로만 사용.
각 paper마다 exact equation/algorithm/figure/table 번호 기록.
"representation learning에 좋다" 수준의 추상 요약 금지.
Visual RL에서만 검증된 결과와 low-dimensional state control 결과 분리.
Train-time auxiliary와 deployment-time use를 반드시 분리.
Positive result뿐 아니라 negative ablation과 compute overhead도 기록.
후보당 최대 하나의 새 module, 하나의 altered objective, 또는 하나의 extra forward pass라는 simplicity 기준으로 평가.
Large ensemble, CEM planning, transformer rewrite는 evidence가 압도적이지 않으면 OUT-OF-SCOPE.
최종 verdict는 GO, CONDITIONAL, NO-GO 중 하나.
Design proposal은 하지 말고, 4차 설계에 필요한 constraints와 evidence만 반환.

3. Required outputs
literature/v2_literature_matrix.csv
literature/v2_direction_A_actor_representation.md
literature/v2_direction_B_response_lookahead.md
literature/v2_direction_C_budget_stability.md
literature/v2_direction_D_hybrid_selection_alignment.md
literature/v2_direction_E_aux_gradient_routing.md
literature/v2_design_consequences.md
literature/v2_bibliography.bib

v2_literature_matrix.csv columns:
direction, paper, venue_year, primary_source, official_code, observation_type, action_space, base_RL_algorithm, aux_target, actor_input, critic_input, model_used_at_train, model_used_at_deploy, planning_horizon, extra_forward_passes, gradient_routing, main_ablation, negative_result, compute_overhead, closest_DGCC_analogy, critical_mismatch, verdict

Direction A. Auxiliary/predictive representation을 actor에 명시적으로 노출

DGCC V1에서는 auxiliary loss가 shared encoder를 바꾸므로 actor는 이미 response-supervised h_i를 간접적으로 사용함. 조사 대상은 이보다 강한 explicit predictive feature conditioning임. Predictive-information auxiliary, online feature expansion, representation/RL decoupling은 직접적인 출발 문헌군임.

A1. 기존 연구에서 actor가 predictive latent를 직접 입력받는가, 아니면 auxiliary-trained shared encoder만 입력받는가? → 후자뿐이면 DGCC V1과 실질적으로 동일하므로 "actor exposure" 후보를 제거
A2. Predictive latent가 action-independent인가 action-conditioned인가? → Action-independent면 one-pass concat 가능. Action-conditioned면 proposal–refinement 또는 critic-side use 필요
A3. z(s,a)를 actor에 넣을 때 action circularity를 어떻게 해결하는가? → 문헌상 안정적인 one-step 해결책이 없으면 explicit actor-conditioning을 NO-GO
A4. Actor와 critic이 동일 predictive encoder를 공유하는가, separate encoder/stop-gradient를 쓰는가? → Shared gradient conflict 위험과 코드 diff를 결정
A5. Auxiliary target이 next observation, reward, inverse dynamics, contrastive future, task-relevant feature 중 무엇인가? → DGCC의 24-D δm가 actor에 충분한 정보인지 판단
A6. Goal-conditioned actor에서 predictive feature가 goal-relative인가 goal-agnostic인가? → 현재 δm만으로 충분한지, goal-relative response가 필요한지 판단
A7. Explicit feature가 sample efficiency만 높이는가, asymptotic performance와 seed variance도 개선하는가? → V2 목표인 lower-tail 안정화와 맞지 않으면 우선순위 하향
A8. Actor input dimensionality 확대 효과를 capacity-matched control로 검증했는가? → 단순 parameter increase인지 physics content인지 분리하는 control 결정
A9. Low-dimensional proprioceptive/state input에서도 효과가 재현되는가? → Image representation 전용 결과라면 DGCC 직접 전이 근거 약화
A10. Feature prediction error와 policy performance 사이에 calibration threshold가 있는가? → V1 f_resp quality gate의 필요성 결정

우선 seed papers: PI-QT-Opt / OFENet / ATC / DeepMDP 및 bisimulation 계열 / SLAC·Dreamer 계열 중 actor가 latent를 쓰는 방식 / Auxiliary task representation을 actor와 critic에 비대칭으로 배치한 연구

Direction B. Learned 1-step response model을 deployment에서 활용

TD-MPC와 LOOP는 짧은 learned-model lookahead에 learned terminal value를 결합하는 대표 구조임. DGCC에서는 pure one-step greedy가 아니라, 기존 long-horizon Q와 response prediction을 어떤 방식으로 결합해야 하는지가 핵심 조사점임.

B1. One-step model score만으로 action을 고르는 방법과 terminal Q를 결합하는 방법 중 어느 쪽이 안정적인가? → 내부 greedy 1% 관측을 고려하여 pure greedy 후보를 제거할지 결정
B2. Learned model을 Q의 additive residual, tie-breaker, candidate filter, terminal-value lookahead 중 어디에 배치하는가? → 가능한 최소 diff seam 결정
B3. Existing actor가 생성한 finite candidates만 rerank해도 효과가 있는가? → CEM/MPPI 없이 단일 extra forward로 끝낼 수 있는지 결정
B4. Candidate action이 replay behavior distribution 밖일 때 model exploitation을 어떻게 막는가? → Actor-generated action만 허용할지, uncertainty gate가 필요한지 결정
B5. Single model로 충분한가, ensemble이 필수인가? → Ensemble이 필수라면 owner simplicity constraint상 우선순위 하향
B6. Short-horizon model error와 terminal Q error 사이의 최적 horizon은 어떻게 결정되는가? → DGCC에서는 H=1만 정당화 가능한지 판단
B7. Model을 deployment에서만 쓰면 training–deployment mismatch가 성능을 해치는가? → Target backup이나 actor objective에도 response use가 필요한지 결정
B8. Model-based scoring이 actor divergence 또는 out-of-distribution action을 유발하는가? → Actor regularization 또는 candidate restriction 필요성 결정
B9. Predicted δm에서 task distance/progress를 계산할 때 decoding이 필요한가? → 24-D DCT target을 직접 score로 쓸 수 있는지, centerline reconstruction이 필요한지 판단
B10. Model score와 Q의 scale normalization을 어떻게 하는가? → 새 λ tuning degree가 하나인지 여러 개인지 판단
B11. Deformable-object planning에서 one-step learned deformation model이 실제 robot deployment에 사용된 사례가 있는가? → Robotics/ICRA framing 강도를 결정
B12. Planning overhead와 perception latency가 어느 정도인가? → Franka stop-and-go 실기 적용 가능성 결정
B13. Model accuracy가 높은데 policy 성능이 나빠지는 negative cases가 보고되었는가? → Model quality만으로 candidate를 채택하지 않도록 failure gate 설정

우선 seed papers: TD-MPC / LOOP (Actor Regularized Control) / Model-Based Value Expansion / STEVE / MBPO / PETS / DLO·deformable-object learned forward-model planning / Q-guided finite candidate reranking 연구

Pure one-step responder를 조사할 때는 반드시 "myopic progress"와 "long-horizon value"의 차이를 별도 표로 정리할 것.

Direction C. Budget 연장과 학습 안정화

Original TD3는 twin critics뿐 아니라 delayed policy update를 function-approximation error 완화의 핵심으로 제시함. Experience replay 연구는 replay capacity와 replay ratio 자체가 성능에 영향을 줄 수 있음을 보여줌. Few-run RL에서는 point estimate만으로 candidate를 선택하기 어렵다는 평가 문제도 별도 고려해야 함.

C1. Original TD3에서 policy delay와 target delay는 정확히 어떤 cadence인가? → Current every-step actor update를 hygiene fix로 공통 적용할지 결정
C2. Policy delay가 mean performance보다 variance/lower tail을 줄인 evidence가 있는가? → V2의 "basin-entry stabilization" 가설 적합성 결정
C3. Hybrid discrete–continuous selection에서도 policy delay evidence가 있는가? → Standard continuous-control 결과의 직접 전이 가능성 판단
C4. Training horizon을 두 배로 늘릴 때 exploration schedule은 absolute step으로 고정하는가 fraction으로 늘리는가? → 600k가 pure budget extension이 되도록 contract 결정
C5. Replay capacity를 total transitions보다 작게 두는 것이 유리한가? → 600k에서 500k buffer 유지/확대 결정
C6. Replay ratio 1을 유지할지, collection budget과 update budget을 분리할지? → 600k transition 효과와 extra gradient update 효과 분리
C7. Fresh 600k와 300k continuation 중 어느 비교가 과학적으로 적절한가? → Resume implementation 필요성 결정
C8. Optimizer/replay reset continuation이 성능에 주는 알려진 영향은 무엇인가? → "continue from V1" 후보 허용 여부 결정
C9. Longer training이 best seed만 개선하고 bad seed는 그대로인 사례가 흔한가? → Budget 연장을 architecture 후보로 볼지 단순 ablation으로 볼지 결정
C10. Nonmonotonic learning curve에서 checkpoint selection을 어떻게 고정하는가? → Best-checkpoint lottery 대신 window-AUC 사용 근거 결정
C11. Few-seed algorithm selection에서 추천되는 robust metric은 무엇인가? → Candidate tournament의 ranking statistic 결정
C12. Standard TD3 correction만으로 개선될 경우 paper novelty를 어떻게 취급하는가? → Headline architecture가 아니라 common stabilized base로 이동할지 결정

중요한 분류 규칙: Canonical TD3 correction 또는 600k budget만으로 좋아지는 방향은 성능 복구 가능성은 높아도 V2 architecture headline 가능성은 낮음. Literature report에서 performance utility와 paper novelty를 별도 점수화할 것.

Direction D. Hybrid contact–continuous action의 selection-aligned objective

DGCC action은 contact node p 선택과 continuous motion u의 결합임. HACMan과 parameterized-action RL은 이 구조와 가장 가까운 선행연구군임. HACMan은 point별 motion parameter를 actor가 만들고 point별 critic map의 최고 Q 위치를 선택하는 구조를 사용함.

D1. Per-discrete-action actor는 모든 branch를 평균해 학습하는가, selected/top-k/softmax-weighted branch만 학습하는가? → Current all-contact mean objective 유지 또는 변경 판단
D2. Discrete choice를 Q_1, Q_min, advantage, expected-max 중 무엇으로 선택하는가? → Train/target/deployment operator 통일 여부 결정
D3. Hard argmax의 non-differentiability를 어떻게 처리하는가? → 추가 estimator 없이 simple objective가 가능한지 판단
D4. All-branch training이 낮은 가치 contact에 actor capacity를 낭비하는가? → Top-k weighting 가설의 근거 판단
D5. Top-contact-only actor update가 branch collapse나 poor exploration을 유발하는가? → Hard selection 후보 제거 여부 결정
D6. Q overestimation이 discrete contact argmax에서 더 심해지는가? → Q1 selection을 유지할지 clipped/ensemble operator가 필요한지 결정
D7. Actor map과 critic map을 공유 feature로 만들 때 gradient routing은 어떻게 하는가? → Current detached encoder actor update의 적절성 판단
D8. Contact index exploration과 motion exploration을 별도 schedule로 관리하는가? → Current ε_p + Gaussian u schedule 개선 필요성 결정
D9. Point/contact permutation, node density, topology 변화에 대한 설계가 있는가? → DLO node representation과의 적합성 판단
D10. HACMan-style objective 중 current DGCC에 이미 구현된 부분과 빠진 부분은 무엇인가? → "새 contribution"과 "baseline mismatch correction" 분리
D11. Simple objective 변경만으로 seed variance가 줄었다는 evidence가 있는가? → V2 최우선 후보 여부 결정
D12. Parameterized-action methods의 known instability는 무엇인가? → 작은 diff라도 실제 위험이 높은 후보 제거

이 방향은 literature agent가 다음 세 objective family를 반드시 구분해야 함: Uniform all-branch objective / Selection-weighted·top-k objective / Soft value-weighted objective. 각 family의 gradient, exploration, overestimation, compute cost를 비교할 것.

Direction E. Auxiliary gradient routing 또는 loss scheduling

이 방향은 unconditional candidate가 아니라 code diagnostics에서 gradient conflict가 확인될 때만 활성화할 conditional direction임. PCGrad와 GradNorm은 각각 conflicting gradient projection과 gradient-scale balancing을 다루는 대표 연구임.

E1. Auxiliary loss와 TD loss gradient cosine이 negative일 때 실제 control 성능 저하가 예측되는가? → Conflict 측정이 V2 gate로 가치 있는지 결정
E2. Fixed λ, decaying λ, normalized losses, PCGrad 중 가장 단순한 안정화가 무엇인가? → Owner simplicity 제약에 맞는 후보 범위 결정
E3. Auxiliary gradient를 encoder에만, response head에만, critic trunk 일부에만 보내는 선행 설계가 있는가? → Shared encoder interference를 줄이는 최소 seam 결정
E4. Auxiliary task가 일찍 수렴한 뒤 계속 gradient를 주면 representation drift가 생기는가? → Late-stage λ decay 가설 판단
E5. Dynamic weighting이 fixed-weight sweep보다 실제로 일관되게 우수한가? → 복잡한 adaptive weighting을 배제할지 결정
E6. Gradient-surgery 이득이 hyperparameter tuning 없이 재현되는가? → Candidate complexity 대비 기대효과 판단
E7. Physics-informed auxiliary RL의 negative results가 있는가? → "physics supervision은 항상 좋다"는 가정 제거

Activation condition:
GO only if: aux-vs-TD encoder-gradient cosine conflict, severe norm imbalance, or late-stage aux domination is observed consistently in at least two completed V1 seeds.
Otherwise: NO-GO for the five-day V2 search.

Literature agent 최종 synthesis 형식 — 각 방향을 다음 rubric으로 1–5점 평가.
Causal fit: DGCC의 관찰된 late-acceleration/lower-tail 문제를 직접 겨냥하는가
Simplicity: 작은 diff와 적은 hyperparameter로 구현 가능한가
Prior evidence: 가까운 action/observation/robot setting에서 검증되었는가
Train–deploy consistency: 학습과 실제 selection path가 정렬되는가
Model exploitation risk: response model 오차를 악용할 위험이 낮은가
Seed-robustness evidence: 평균뿐 아니라 variance/lower tail 개선 근거가 있는가
Real deployability: Franka stop-and-go loop에 적용 가능한가
Paper clarity: 한 문장 설계 이유와 ablation이 가능한가
Baseline fairness: 같은 budget/compute로 BB와 비교 가능한가
Tuning burden: 탐색할 자유도가 1–2개 이하인가

최종 보고서에서는 각 방향당 최대 2개의 literature-supported mechanism family만 남길 것.

Q3. 예비 가설 순위

3.1 현재 결과의 올바른 해석

s2의 33%는 다음만 보여줌: 현재 backbone과 task에서 높은 성능 policy가 도달 가능함.
보여주지 않는 것: V1이 평균적으로 BB보다 우수함 / 모든 문제는 seed variance뿐임 / 600k로 늘리면 자동으로 모든 seed가 s2 수준에 도달함.

현재 3개 pair의 평균은 V1이 BB보다 낮음. 따라서 V2의 우선 목표는 최고 seed를 33% 이상으로 올리는 것보다 s0/s1 유형의 실패 확률을 줄이고, late-acceleration basin 진입을 더 일찍·자주 발생시키는 것이어야 함. [GitHub +1]

3.2 주관적 prior

아래 확률은 통계적 추정치가 아니라, 현재 code facts와 최초 3개 seed 관찰을 이용한 4차 설계 전 subjective prior임.

Exploratory screen win 정의: Discovery validation seeds에서 late-window continuous metric이 paired BB보다 우수하고 catastrophic lower-tail regression이 없는 경우.
Locked confirmation win 정의: 사전 고정된 새 seeds에서 paired BB 대비 return이 양수이고, direction consistency가 있으며, heldout one-shot에서도 같은 방향인 경우.

순위 | 방향 | Exploratory screen win | Locked confirmation win | ICRA headline 가능성 | 판단
1 | D. Selection-aligned hybrid objective | 35–50% | 20–30% | 20–30% | 가장 작은 diff, 현재 code mismatch와 직접 연결, robotics action structure와 명확히 정렬
2 | B. Q + deployment-time response use | 30–45% | 15–25% | 25–35% | 논문 story가 가장 강함. 다만 response-model extrapolation과 myopia 위험
3 | C. Canonical TD3/stability correction | 35–50% | 20–30% | 5–12% | 성능/lower-tail 개선 가능성은 높지만 standalone novelty 약함
4 | A. Explicit response feature to actor | 20–35% | 10–20% | 15–25% | Actor가 이미 aux-shaped h를 받으며 z_resp(h,u) circularity 존재
5 | E. Gradient routing/scheduling | 10–20% unconditional | 20–35% if conflict verified | 8–15% | Diagnostics가 conflict를 보일 때만 합리적

순위 해석

Direction D를 1순위로 둔 이유는 현재 actor train objective와 actual contact selection이 다른 operator를 사용하며, 이를 조사·정렬하는 것이 response model을 새로 연결하는 것보다 diff와 tuning burden이 작기 때문임. 다만 literature audit 결과 current all-contact objective가 HACMan류에서 의도적으로 정당화된 것으로 확인되면 우선순위가 내려감.

Direction B는 paper-headline prior가 가장 높음. "학습한 physics response를 실제 decision-time에 사용한다"는 이유가 명확하기 때문임. 그러나 pure one-step greedy 방향은 내부 1% 관측 때문에 낮은 prior이며, literature 조사에서는 long-horizon Q를 보존하는 finite-candidate augmentation만 우선 검토해야 함.

Direction C는 architecture 후보라기보다 공통 base hygiene일 가능성이 큼. Original TD3의 delayed policy update 누락이 실제 variance 원인으로 확인되면, 모든 V2 후보가 동일 stabilized base를 사용해야 함. 이를 V2 단독 contribution으로 포장하면 reviewer가 "TD3를 정상 구현했을 뿐"이라고 공격할 가능성이 높음.

Direction A는 명칭과 달리 V1 actor가 이미 physics-shaped shared encoder output을 받는다는 중복 문제가 있음. Explicit action-conditioned response를 넣으려면 대부분 two-pass computation이 필요할 가능성이 높아 owner의 simple-diff 제약과 상충함.

Direction E는 gradient diagnostics 없이 실행하면 일반적인 multitask-learning trick 추가에 그침. Conditional backup이 적절함.

3.3 4차 설계에서 가장 중요하게 볼 기준 (우선순위 순)

1. Observed bottleneck match — Best seed ceiling이 아니라 bad-seed basin과 late acceleration을 직접 겨냥하는가.
2. Native seam — 기존 actor, critic, select_actions, compute_target 중 하나의 module boundary만 바꾸는가.
3. Train–deploy consistency — Training objective가 실제 online Q_1 contact selection 및 hardware inference와 정렬되는가.
4. No circularity — z_resp(h,u)를 actor input으로 쓰면서 별도 proposal/refinement machinery를 무리하게 추가하지 않는가.
5. Model-error containment — f_resp가 actor-generated candidate에서 틀려도 전체 policy를 망가뜨리지 않는가.
6. One-sentence derivation — "현재 구조의 X mismatch 때문에 Y를 추가한다"는 한 문장 논리가 가능한가.
7. At most one main knob — 새 hyperparameter가 1개, 최대 2개인지.
8. Paired-RNG fairness — 추가 forward/random search가 environment/replay RNG를 교란하지 않는가.
9. Matched compute — BB 대비 transition·update·wall budget 차이가 headline을 설명하지 않는가.
10. Real deployment preservation — RealSense–TrackDLO–Franka stop-and-go loop에서 실행 가능하며 simulator oracle을 요구하지 않는가.
11. Ablation identifiability — 성능이 올랐을 때 response content, capacity, extra compute 중 원인을 분리할 수 있는가.
12. Lower-tail evidence — 최고 seed가 아니라 worst seed와 basin-entry rate가 개선되는가.

Q4. 탐색 실험 설계의 뼈대

4.1 권장 tournament 규모

전용 GPU, run당 약 10.2h 기준으로는 4 candidates가 가장 안전함.

구성 | Runs | 예상 GPU 시간 | 평가
3 candidates × 3 seeds | 9 | 91.8h | 단순하고 균형적
4 candidates × 2 seeds + top 2 × 1 seed | 10 | 102h | 권장
5 candidates × 2 seeds + top 2 × 1 seed | 12 | 122.4h | 5일을 모두 소모, crash·profiling margin 없음
5 candidates × 3 seeds | 15 | 153h | 예산 초과

권장 구조:
Stage 0: contract/smoke
Stage 1: 4 candidates × discovery seeds {0,1}
Stage 2: top 2 candidates × tie-break seed {2}
Stage 3: winner lock
Stage 4: fresh confirmatory BB/V2 × seeds {5,6,7}
Stage 5: one-shot fresh heldout

Seeds 0과 1은 현재 V1이 BB보다 낮았던 hard development seeds이고, seed 2는 V1 jackpot seed임. 따라서 seed 0/1을 모든 후보에 먼저 사용하면 lower-tail rescue를 선별할 수 있고, seed 2는 "좋은 basin을 망가뜨리지 않는가"를 확인하는 독립적 third development seed 역할을 함. 이 선택이 existing outcomes를 알고 이루어진 adaptive development임을 charter에 명시해야 하며, confirmatory seeds와 섞어 inferential claim을 만들면 안 됨. [GitHub +1]

4.2 Stage 0 — 실행 전 charter에 고정할 항목

첫 candidate run 이전 GitHub charter 필수 항목:
- Candidate ID 3–5개와 각 allowed mechanism family.
- Discovery seeds와 순서.
- Confirmatory seeds.
- Fresh V2 heldout manifest hash.
- Heldout denylist 및 access logger.
- Primary discovery metric.
- Early-stop rule.
- Top-2 promotion rule.
- Winner selection rule.
- Tie-break rule.
- Technical failure 및 retry rule.
- Candidate 수정 시 새 ID 발급 규칙.
- All-attempt run registry.
- 300k fixed budget.
- 600k를 architecture tournament에서 제외하는 규칙.
- Fresh paired BB comparator plan.
- Seed 5 eligibility 및 prior AMD-3 scope.
- No post-winner hyperparameter tuning.
- Confirmatory run 시작 후 code/config freeze.
- Exploratory와 confirmatory 결과를 논문에서 분리 보고하는 방식.

Fresh heldout
권장: t2_v2_confirmatory_heldout_v1.json 또는 동등한 새 split.
필수 조건:
- V2 candidate process에 file read permission 없음.
- Goal IDs, templates별 실제 goal content도 미공개.
- Candidate selection에는 validation split만 사용.
- Winner code freeze와 confirmatory run 완료 후 1회 접근.
- 기존 t2_sprint_heldout_v1 결과는 historical development data로만 표시.

Seed 5
Seed 5를 유지하려면 charter에 다음 중 하나를 명시해야 함.
A. Root cause resolved: exact fix SHA, reproduction test, smoke pass, retry rule.
B. New execution regime: old AMD-3 exclusion은 old V1-BB sprint pair에만 적용되며, V2 confirmatory는 fresh paired BB/V2 under identical fixed regime로 실행.
C. Fail-closed: seed 5가 동일 technical failure를 재현하면 confirmatory set 자체를 protocol failure로 판정하며 replacement seed를 사후 선택하지 않음.

현재 BB seed 5에는 valid completed comparator가 없으므로, V2 > BB의 paired confirmation을 하려면 BB 5–7을 동일 fixed regime에서 fresh 실행하는 방안이 가장 깨끗함. 기존 BB s6/s7만 재사용하고 s5만 새로 실행하는 혼합은 execution-cohort confound를 다시 만듦. [GitHub]

4.3 Stage 1 — 모든 후보, seeds 0·1

Budget
- 300k transitions 고정.
- UTD, replay, exploration schedule, eval frequency 동일.
- Architecture 이외 config 변경 금지.
- Candidate별 한 개의 main hyperparameter만 허용.
- Candidate 구현에 따라 extra compute가 생기더라도 transition/update budget은 동일.
- Wall time 별도 보고.

Primary development metric
Binary success가 아니라 late-window validation return 사용 권장.
Exact definition: L^R_{c,s} = (1/4) Σ_{t∈{225k,250k,275k,300k}} R^val_{c,s,t}
실제 checkpoint transition이 225280 등으로 어긋나므로, "각 nominal checkpoint에 대응하는 first eval at or after threshold" 규칙을 code로 고정.
Secondary: L^D_{c,s} = (1/4) Σ_{t∈W} D^val_{c,s,t} (lower is better)
success late-window mean은 tertiary.
best single checkpoint는 winner selection에 사용 금지.
이유: Late-acceleration task에서 final checkpoint 하나는 phase noise에 민감함 / Best checkpoint는 후보 수가 많을수록 winner's curse를 확대함 / Binary success는 low-power임.

Comparator
각 discovery seed에 대해 paired BB를 primary comparator로 사용: Δ^R_{c,s} = L^R_{c,s} − L^R_{BB,s}
V1은 secondary comparator: Δ^{R,V1}_{c,s} = L^R_{c,s} − L^R_{V1,s}
Headline 목표가 BB를 이기는 것이므로 candidate ranking의 primary comparator는 BB여야 함. V1보다만 좋아졌지만 BB보다 낮은 후보는 winner eligibility를 얻지 못하게 하는 편이 안전함.

4.4 조기 기각 규칙

25k–100k: Performance 기반 기각 금지. 다음 technical criteria만 사용.
non-finite loss/gradients / contract test failure / checkpoint corruption / hidden-heldout access / initial hash mismatch / repeated simulator protocol failure / wall-time overhead가 preregistered hard cap 초과 / intended module이 실제 call path에서 호출되지 않음 / response model output이 non-finite 또는 constant collapse

150k: Hard kill 금지. Scheduling priority만 부여.
기록할 지표: return at 150k / final distance at 150k / 100–150k return slope / auxiliary loss·calibration / Q1/Q2 disagreement / actor·critic grad norm / contact margin / selected-contact entropy
V1 s0가 150k에서 낮았지만 이후 유효한 수준으로 개선된 사실 때문에, 150k 단일 metric은 futility 판정으로 부적절함. [GitHub]

225k conditional futility stop — 후보가 seeds 0·1에서 모두 다음 조건을 만족할 때만 300k 이전 중단.
- return AUC[150k,225k]가 paired BB와 paired V1 양쪽보다 preregistered harm margin 이상 낮음.
- final-D AUC[150k,225k]도 양쪽보다 harm margin 이상 나쁨.
- return slope[175k,225k] ≤ 0.
- Q collapse, contact collapse, aux divergence 중 하나의 diagnostic failure 존재.
- 두 seed 모두 같은 방향.
Harm margin 수치는 gjc의 historical validation-noise audit 결과로 결정하여 첫 V2 run 전에 pin할 것. 임의로 사후 설정하지 말 것.
한 seed만 나쁘거나 slope가 양수이면 300k까지 완주.

4.5 Stage 1 top-2 promotion rule

Seeds 0·1 완료 후 다음 lexicographic order 사용.
1. Mean paired late-window return delta versus BB: Δ̄^R_c = (1/2) Σ_{s∈{0,1}} Δ^R_{c,s}
2. Worst-seed paired return delta: min_s Δ^R_{c,s}
3. Mean paired final-distance improvement.
4. Mean paired return delta versus V1.
5. Late-window success.
6. Compute overhead.
7. Code diff size 및 hyperparameter 수.

Promotion eligibility:
- 두 seed 중 최소 한 seed에서 BB보다 양수.
- Mean return delta가 양수이거나, predefined near-tie band 안이면서 final distance가 명확히 개선.
- 한 seed가 catastrophic harm bound 아래이면 탈락.
- Technical failure run은 favorable seed만으로 대체하지 않음.

Weighted sum 하나로 합치기보다 lexicographic rule이 좋음. 작은 표본에서 arbitrary metric weights로 winner가 바뀌는 것을 방지함.

4.6 Stage 2 — Top 2, seed 2

Seed 2는 현재 high-performing basin이므로 다음을 확인.
- Candidate가 V1 s2의 좋은 basin을 유지하는가.
- Candidate improvement가 hard seeds에서만 나타나고 good seed를 훼손하지 않는가.
- Lower-tail rescue와 upper-tail preservation을 함께 달성하는가.

Final exploratory winner eligibility:
- mean paired late-window return versus BB > 0 across seeds 0,1,2
- at least 2/3 seeds beat BB on late-window return
- no seed breaches preregistered catastrophic-harm bound
- mean final distance no worse than BB
- throughput overhead within cap
- architecture and hyperparameters remain charter-compliant

Final ranking: 1. Mean paired return delta vs BB. 2. Worst-seed delta vs BB. 3. Win count vs BB. 4. Final-distance delta. 5. Delta vs V1. 6. Complexity/latency.

3/3 win을 요구하면 좋은 후보를 과도하게 제거할 수 있으므로 2/3 + no catastrophic harm가 현실적임. 단, 이는 candidate selection rule이지 superiority inference가 아님.

4.7 Stage 3 — Winner lock

Winner 결정 즉시 다음 freeze: Architecture code SHA / Config SHA / Hyperparameters / Candidate-scoring rule / RNG streams / Replay·update·exploration semantics / Checkpoint-selection rule / Confirmatory seeds / Paired BB protocol / Heldout manifest / Technical failure rule / Statistical analysis / Paper claim language.
Winner 결정 이후의 모든 변경은 V2.1 exploratory로 새 ID를 받아야 하며 confirmatory winner를 대체할 수 없음.

4.8 Stage 4 — Confirmatory seeds 5–7

최소 clean design: BB-fixed × seeds 5,6,7 / V2-locked × seeds 5,6,7
동일 조건: local fixed environment / same source commit family / same total transitions / same replay·update·exploration / same eval goals / same retry rule / no heldout access / paired initial seed / randomized·interleaved execution order가 가능하면 사용.

주의
Locked n=3은 independent validation에는 의미가 있지만, 현재와 같은 고분산 환경에서 "통계적으로 확실한 superiority"를 만들기에는 매우 약함. Few-run RL에서 point estimate만으로 결론을 내리면 불확실성이 크게 남는다는 점이 알려져 있음. [NeurIPS Proceedings]

따라서 결과 해석:
- n=3 confirmatory: 방향 재현과 gross failure 여부
- exploratory seeds 0–2: 개발 데이터로 투명하게 별도 보고
- 최종 paper inference: 가능하면 architecture lock 후 추가 2개 이상 seed 확보
- 추가 seed가 불가능하면 effect size, all-seed plot, paired deltas, exact uncertainty를 모두 공개하고 "statistically decisive" 표현 금지
Exploratory 3 seed와 confirmatory 3 seed를 단순 합쳐 n=6 confirmatory라고 부르면 안 됨. Candidate가 seeds 0–2 결과를 보고 선택되었기 때문임.

4.9 600k 실험의 위치

600k를 300k architecture 후보들과 같은 tournament에 넣지 않는 것이 좋음.
이유: exploration decay horizon 변경 / replay overwrite 발생 / update 수 변경 / checkpoint opportunity 증가 / exact resume 미지원.
권장 위치:
Option 1: Winner 결정 후 BB/V1/V2 각각 matched 600k ablation.
Option 2: Architecture lock 후 V2 300k→600k continuation을 secondary characterization.
Not allowed: V2만 600k, BB는 300k인 상태로 architecture superiority 주장.

4.10 Seed 2–3개 비교의 함정과 완화책

함정 | 발생 방식 | 완화책
Winner's curse | 4–5 candidates 중 우연히 좋은 seed를 선택 | 별도 locked seeds, 모든 후보 공개
Multiple adaptive choices | curve를 보고 objective/hyperparameter 변경 | 모든 변경을 새 candidate ID로 등록
Known-seed overfit | s0/s1 hard, s2 jackpot임을 알고 설계 | exploratory임을 공개하고 seeds 5–7로 독립 검증
Best-checkpoint lottery | 후보마다 가장 좋은 25k point 선택 | late-window AUC 사용
150k false rejection | late acceleration 이전에 제거 | 150k hard kill 금지
Binary-success noise | 100 validation episode에서 몇 건 차이로 순위 변동 | return/final distance primary
Seed×candidate interaction | 특정 architecture가 한 seed에서만 잘 작동 | 동일 paired seeds, top-2 third seed, worst-seed guard
Shared RNG confound | extra random calls가 env/replay sequence 변경 | subsystem별 RNG 분리
Unequal compute | lookahead가 더 많은 inference/search 사용 | transition/update 고정 + wall/forward count 보고
Hyperparameter degrees of freedom | 후보별 튜닝 횟수가 다름 | 후보당 main knob 1개, 전체 attempt 공개
Technical attrition bias | 나쁜 run을 "crash"로 제외 | predeclared technical criteria, symmetric retry
Validation-set overfit | 같은 100 val episodes를 수십 번 사용 | candidate selection에만 사용, 새 heldout 분리
Old heldout contamination | V1/BB heldout 결과가 V2 설계에 영향 | 새 V2 confirmatory split
Comparator cohort confound | V2 fresh local vs BB legacy/mixed | fresh paired BB under same fixed regime
Seed-5 selective re-entry | 과거 제외 seed를 유리할 때 재사용 | 새-track scope와 failure resolution을 사전 등록
Discovery/confirmation pooling | 선택에 사용한 seed까지 confirmatory로 계산 | 두 cohort 별도 보고
Directional result overclaim | n=3 positive mean을 significance로 표현 | paired plot, CI, "directional replication" 표현
Complexity bias | 복잡한 후보가 우연히 더 많은 tuning을 받음 | diff/knob/compute를 winner tie-break에 포함

최종 권고

이번 발주 단계에서 가장 중요한 세 질문은 다음임.
1. V1 성능 분산이 actor–contact selection mismatch 또는 noncanonical update cadence와 연결되는가.
2. f_resp가 actor-generated candidate actions에서 충분히 정확하고 cheap하여 deployment-time signal로 쓸 수 있는가.
3. V2 confirmatory comparison을 fresh heldout 및 paired BB seeds 5–7로 실제 성립시킬 수 있는가.

4차 설계에서는 이 세 답에 따라 후보를 정리하는 것이 적절함.
- Objective mismatch가 강하게 확인되면 Direction D 우선.
- Candidate-response calibration이 강하고 compute가 작으면 Direction B 우선.
- Delayed update가 lower-tail을 설명하면 이를 common stabilized base로 먼저 적용.
- Explicit actor response conditioning은 action circularity를 단순하게 해결하는 선행 구조가 확인될 때만 채택.
- Gradient routing은 실제 conflict 진단이 있을 때만 활성화.

현재 증거만으로는 "더 큰 network"나 "더 긴 training"보다, good seed의 ceiling을 보존하면서 bad seed의 basin-entry 확률을 높이는 하나의 단순한 computation-path 수정이 가장 적합한 V2 탐색 목표임.
