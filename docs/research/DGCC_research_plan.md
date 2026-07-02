# 연구계획서 — Deformation-Grounded Contact Critic (DGCC)

**Deformation-Grounded Contact Critics: How Should Value Functions Represent Contact Actions for Deformable Linear Object Manipulation?**

작성일: 2026-07-02 · 프로젝트: Locus-VLA / DLO Contact Representation · 상태: 실행 계획 확정본

---

## 1. 연구 개요

Deformable Linear Object(DLO; rope, cable, wire)의 조작에서는 **어느 점을 잡고(contact) 어떻게 움직이는가(motion)**가 성패를 지배한다. 본 연구는 HACMan-style hybrid actor-critic [1] — action을 (contact point p, motion parameter u)로 분해하고 point cloud 위 per-point Q map으로 contact를 선택하는 구조 — 을 DLO로 가져오되, 그 critic이 **접촉이 유발하는 변형 반응(contact-induced deformation response)**이라는 물리적 기제를 명시적으로 표현하도록 구조화한다.

핵심 관찰은 다음 한 문장이다.

```text
Bellman supervision tells the critic which action is valuable,
but not the physical mechanism by which the action becomes valuable.
```

우리는 critic이 contact action의 가치를 추정하기 전에, 그 action이 만들어낼 저차원 변형 반응 δm̂ 을 먼저 예측하도록 하고(supervised, self-labeled), 가치 추정이 이 반응 표현을 경유하도록 하는 세 가지 강도의 구조(auxiliary / soft bottleneck / hard bottleneck)를 체계적으로 비교한다. 주 가설은 다음과 같다: **contact value의 물리 성분은 task 성분보다 정상성(stationarity)이 높으므로, 물리 성분을 명시적으로 분리·supervise한 critic은 black-box critic보다 DLO geometry(길이·강성·마찰)와 task(초기·목표 형상, 장애물) 변화에 더 잘 전이된다.**

이 연구는 단일 방법 제안이 아니라 **"DLO contact critic은 무엇을 표현해야 하는가"에 대한 통제된 연구(study)이며, 그 결과로 가장 강한 형태의 방법(DGCC)을 도출**한다. 최종 연구 질문:

```text
How should a Bellman critic represent contact actions for DLO manipulation —
and how much architectural commitment to the physical deformation response is optimal?
```

기대 기여는 세 가지다.

1. **방법**: Bellman value learning을 보존하면서 critic을 deformation response로 ground하는 DGCC 계열 아키텍처와, per-point contact 선택·action 생성으로의 통합.
2. **과학적 결과**: black-box critic latent의 response 표현 결핍·goal 얽힘(entanglement)을 probing으로 진단하고, "표현 정렬 → OOD 성능"의 기제 수준 연결을 최초로 통제 실험으로 제시.
3. **실용적 강점**: response label이 transition만으로 얻어지는 self-supervised 신호라는 점을 이용한 **reward-free 도메인 적응** — 새 rope에서 보상 신호 없이 물리 head만 적응.

문서 원칙: 본 계획서는 **실행에 필요한 핵심 사슬만** 본문에 담는다. 선제 방어 논리의 전문(예상 반론 상세, 확장 위험 목록, abstract 초안)은 진단 실험 결과가 나오기 전에는 재작성될 수밖에 없으므로 부록으로 분리하고, 게이트 판정 임계와 사전 예측은 결과 확인 전에 고정한다(사전 등록 원칙).

---

## 2. 배경과 문제 정의

### 2.1 DLO 조작에서 contact 선택 문제

DLO는 국소적으로 순응(compliant)하는 물체다. 동일한 motion이라도 어느 점에 접촉하는가에 따라 질적으로 다른 변형이 발생하고, 잘못된 grasp point는 목표 형상을 kinematically 도달 불가능하게 만든다 — 최신 DLO 벤치마크 연구가 이를 명시적으로 지적한다 [23]. 그럼에도 기존 DLO 연구에서 "어디를 잡을 것인가"는 geometric keypoint 예측 [18, 19, 20], dense descriptor 대응 [19], 최근에는 VLM의 상식적 제안 [23]으로 해결되어 왔다. 즉 **접촉점을 그 물리적 효과로 평가하는 방법은 존재하지 않는다.**

### 2.2 Hybrid actor-critic과 black-box critic의 한계

Rigid object 조작에서 HACMan [1]과 그 확장 [2]은 per-point Q map이 object-centric 일반화를 제공함을 보였다. 이 구조는 DLO에 자연스럽게 이식될 수 있다 — action이 정확히 (어디를, 어떻게)로 분해되기 때문이다. 그러나 확인 결과 **HACMan 계열의 DLO 적용은 존재하지 않으며** (HACMan++ [2]의 task suite에도 deformable 없음), 이 이식은 본 연구가 직접 수행해야 하는 작업이자 부분적 기여다.

더 근본적인 한계는 supervision에 있다. Bellman target은 스칼라 value 하나로 "어느 action이 좋은가"만 전달한다. 그 값 안에는 서로 다른 두 요인이 얽혀 있다:

```text
(i)  physics: 이 contact action이 물리적으로 어떤 변형을 만드는가 — task 무관, 국소적
(ii) task:    그 변형이 현재 goal에 유용한가 — task/goal 종속
```

스칼라 supervision은 이 인수분해를 학습할 유인을 주지 않는다. 따라서 black-box critic의 내부 표현은 두 요인이 얽힌, 도메인 특이적 표현이 될 것으로 예측된다 — 이것이 본 연구가 probing으로 직접 검증할 첫 번째 대상이다.

### 2.3 연구 공백

문헌 조사(세 트랙: rigid affordance/contact 예측, DLO manipulation, RL representation)의 교차 검증 결과, 다음 공백이 확인되었다.

```text
G1. 물리적 response에 ground된 per-contact-point critic은 DLO에 존재하지 않는다.
    - deformable per-point value map은 존재하나 task value로만 supervise됨 [17]
    - DLO effect 예측 모델은 존재하나 object-global rollout으로 MPC에 쓰임 [24, 27]
G2. DLO grasp 선택은 전부 geometric/semantic이다 — effect 기반 평가 부재 [18-23]
G3. 저차원 modal shape feature는 single-grasp 연속 servoing에만 쓰였고 [31, 32],
    discrete contact 선택이나 RL critic에 쓰인 적 없다
G4. cross-DLO-geometry transfer의 "원인"을 표현 수준에서 분리한 통제 연구가 없다 [29, 30]
G5. RL 이론에서 1-step action-effect feature의 dynamics-변화 transfer 축은 미점유
    (successor features는 reward-변화 축만 다룸 [44, 45])
```

---

## 3. 가설 도출

가설은 선언이 아니라 다음 네 가지 관찰로부터 유도되며, 각 관찰은 독립적으로 검증 가능한 실험에 대응한다.

### 관찰 1 — Contact 선택이 성패를 지배한다

DLO의 국소 순응성 때문에 contact point 선택이 결과를 질적으로 바꾼다 [18, 23]. 그러나 기존 방법은 접촉점의 물리적 효과를 평가하지 않는다 (§2.1).

→ 대응 실험: contact-criticality를 계층화한 task suite (§7.2), keypoint류 방식 대비 성능.

### 관찰 2 — Bellman label은 물리와 task를 분해하지 못한다

스칼라 value target은 physics 성분과 task 성분의 분해를 유도하지 않는다 (§2.2).

→ 대응 실험: black-box critic latent의 frozen probing과 goal-entanglement 측정 (§7.4).

### 관찰 3 — 물리 성분은 task 성분보다 **서수적으로(ordinally)** 정상적이다

contact→변형의 국소 물리는 goal이 바뀌어도 동일하고, rope geometry가 바뀌면 절대 반응값은 달라지지만 **contact 후보 간 반응의 순서·방향 구조는 보존**된다 — 처음부터 정상성을 이 서수적 의미로 정의한다 (절대 예측값의 불변을 주장하지 않는다). DLO 제어 문헌은 저차원 modal feature와 로봇 motion 사이에 규칙적이고 매끄러운 관계가 존재함을 확립했다 [31, 32]. 반면 value label은 goal이 바뀌는 순간 후보 간 순서까지 통째로 바뀐다.

→ 대응 실험: **상대적 정상성의 직접 측정** — 동일 (s,p,u) 집합에 goal 섭동과 geometry 섭동을 각각 가해, 두 성분의 변동성을 동일 정규화로 대조 (§7.6-0). 이 실험이 없으면 main hypothesis의 because절("physics가 더 정상적")은 downstream 성능으로만 간접 확인되어 인과 사슬이 끊긴다. 보조: probe transfer, ordinal 보존 분석 (§7.6).

### 관찰 4 — Effect 표현의 전이성에 대한 외부 증거가 축적되어 있다

Object flow 같은 physical-effect 표현은 embodiment와 domain을 가로질러 재사용된다 [11, 13, 15, 16]. 반대로 value-equivalent latent(모델이 return 예측에만 최적화된 표현)는 in-distribution 정확도에 특화되어 reward/dynamics 변화에 취약함이 알려져 있다 [42, 43].

→ 대응 실험: 동일 차원의 value-equivalent latent bottleneck 대조군 (§7.5).

### 추론 — Main Hypothesis

```text
critic을 physics 성분(deformation response)과 task 성분(goal conditioning)으로
인수분해하고 physics 성분에 직접 supervision을 주면,
(a) physics 성분은 OOD geometry/task에서 재사용되고
(b) task 성분만 재적응하면 되므로,
black-box value estimation보다 transfer가 우수한 contact representation을 얻는다.
```

겨냥하는 OOD 축: unseen rope length / stiffness / friction / initial shape / goal shape / obstacle layout.

부수 강점: response target은 transition (X_t, a_t, X_{t+1})만으로 계산되는 **self-supervised label**이다. 따라서 새 도메인에서 **보상 신호 없이** physics head를 적응시킬 수 있다 — value-only critic이나 successor feature(w 회귀에 reward 필요 [44])가 갖지 못하는 성질이다.

### 전이가 기대되는 인과 경로 — 사전 등록

OOD stiffness에서는 f_resp의 절대 예측도 부정확해진다. 그럼에도 이득을 기대하는 세 경로를 사전 등록하고 각각 검증한다.

```text
E1. 오류의 국소화 — geometry 변화의 영향이 f_resp에 국한되고,
    response→value 매핑 F_Q는 근사 불변이다.
    검증: f_resp만 few-shot 적응 vs 전체 fine-tune (§7.6)
E2. Ordinal 보존 — 절대 response는 틀려도 contact 후보 간 상대 순서·방향은 보존된다.
    검증: OOD에서 δm̂ 방향 cosine, 후보 ranking 보존율 (§7.6)
E3. Shortcut 차단 — bottleneck이 도메인 특이적 value shortcut 학습을 방지한다.
    검증: probe transfer + matched-dim 대조군 (§7.5, §7.6)
```

### 용어의 조작적 정의 (본 계획서 전체에서 1회 고정)

```text
transfer / generalization   학습 분포 밖 도메인에서의 zero-shot 평가 성능 (두 용어는 동의어로 사용)
adaptation                  새 도메인의 데이터 k개로 일부 모듈을 갱신한 후의 평가 성능
reward-free adaptation      위 갱신에서 reward 신호를 사용하지 않는 경우 (transition만 사용)
정상성(stationarity)        도메인 섭동 하에서 contact 후보 간 순서·방향 구조의 보존 (서수적 정의)
```

---

## 4. 연구 질문과 검증 가능한 주장

### 4.1 핵심 용어

> **Deformation response** — 현재 상태에서 contact action을 실행했을 때 유발되는 quasi-static DLO shape의 저차원 변화.

```text
transition τ_t = (s_t, a_t, s_{t+1}),  a_t = (p_t, u_t)
δm_t = R(X_t, X_{t+1}) = Φ(X_{t+1}) − Φ(X_t)
```

X_t: DLO centerline shape · p_t: contact/grasp point · u_t: motion parameter · Φ: shape → 저차원 response 좌표 map (§6.2). **Φ와 R은 기여(contribution)가 아니라 구현 요소다.** 기여는 critic representation 구조에 있다.

표현 원칙: "contact value는 deformation response에 의해 강하게 **매개된다**(mediated)"로 쓴다. "response가 value를 결정한다" 같은 강한 인과 주장은 하지 않는다. 또한 f_resp를 "world model / dynamics model"로 지칭하지 않는다 — f_resp는 rollout이 불가능한 1-step response head이며, 이 구분이 value-through-model 계열 [39, 40, 41]과의 경계다. Control-theoretic 주장(controllability 추정, Jacobian 학습)은 하지 않되, modal 표현과 motion의 규칙적 관계가 선행연구에서 확립되었다는 사실 [31]은 동기 근거로 인용한다.

### 4.2 Claims

#### Claim 1 — 결핍 진단 (Deficiency)

```text
Black-box Bellman critic latents encode deformation response poorly,
in a goal-entangled and domain-specific way.
```

측정: frozen-latent probe (in-domain / transfer), goal-entanglement (부분공간 분리도), transfer degradation ratio. 주의 — DGCC 자신의 z_resp가 response와 정렬됨은 supervise했으므로 자명하며, claim이 아니라 sanity check로만 보고한다.

#### Claim 2 — 개입 효과 (Intervention)

```text
Response grounding (auxiliary / soft / hard) improves OOD transfer and
sample efficiency over black-box critics; the optimal degree of architectural
commitment depends on the task regime (assumption stack, §5).
```

측정: training/OOD 성공률, return, final shape error, sample efficiency, variant × task-regime 상호작용.

#### Claim 3 — 기제 연결 (Mechanism Link)

```text
Holding the architecture fixed, response-probe transfer quality predicts
OOD manipulation performance.
```

교란 통제 — 2단계로 설계한다. (1) variant 종류는 probe 품질과 OOD 성능의 공통 원인이므로 between-variant 상관은 증거에서 배제한다. (2) 그러나 within-variant 안에서도 λ/response-dim/checkpoint-step 자체가 양쪽의 공통 원인이 될 수 있으므로, 단순 within-variant 상관도 불충분하다. 따라서 주 지표는 **공변량 회귀 후 partial correlation**이다: probe-transfer 점수와 OOD 성능 각각에서 λ, response-dim, checkpoint-step, 학습 진행도의 효과를 회귀로 제거한 잔차 간 Spearman ρ (cluster-robust, seed 단위 클러스터). 보조 지표로 checkpoint-trajectory 상관(단일 run 내 동반 상승)을 본다.

검정력 확보: seed-only 변이(5–10점)로는 검정력이 부족하므로, 사전 검정력 분석으로 필요 표본 수를 산출해 등록한다 — 목표 효과크기 ρ = 0.5, power 0.8, α = 0.05 기준 약 30개 독립 관측점이 필요하며, variant당 (seed × 저장 checkpoint) 조합으로 충족하되 seed 클러스터를 통계에 반영한다.

반증 조건 (사전 등록): partial correlation이 유의하지 않으면 Claim 3은 기각하고 Claim 2로 흡수한다.

#### Claim 4 — Reward-free 적응 (고유 강점)

```text
Adapting only f_resp on unlabeled transitions from a new DLO domain recovers
most of the OOD performance drop — without any reward signal, and better than
reward-free adaptation of ungrounded representations.
```

공정성 원칙 두 가지. 첫째, 모든 대조군이 동일하게 reward-free 조건에서 비교된다. 둘째, **각 대조군에는 "행동에 영향을 줄 수 있는 최대 범위"의 적응을 허용한다** — 사후 head만 갱신하면 Q 경로가 바뀌지 않아 행동이 변하지 않는 허수아비 대조가 되기 때문이다.

```text
(i)   DGCC: f_resp를 새 도메인 transition k개로 적응 (reward 마스킹)
      → δm̂이 바뀌므로 Q 입력과 행동이 실제로 변한다
(ii)  black-box: δm-prediction head를 사후 부착하되, head + encoder(표현 경로 전체,
      Q-head 제외)를 공동 업데이트 → encoder feature가 바뀌어 Q와 행동이 실제로 변한다
(iii) matched-dim: latent-consistency loss로 encoder + latent 공동 적응 → 동일하게 행동 변화 가능
(iv)  참조점: zero-shot / full fine-tune (reward 사용 — 상한 참조)
적응 후 평가는 전 대조군 동일하게 정책 재실행으로 수행한다.
```

성립 조건: (i)이 (ii)와 (iii)를 이겨야 한다. zero-shot만 이기는 것은 기여가 아니다. (ii)(iii)가 행동 변화 경로를 갖지 못하는 설계라면 이 비교는 무효로 간주한다.

---

## 5. 이론적 전제와 적용 범위

Q(s,a)는 일반적으로 discounted 미래 전체에 의존하므로, **1-step response + goal residual은 일반 MDP에서 Q의 충분통계가 아니다.** Hard bottleneck `Q = F_Q(δm̂, c_g, η)`가 근사적으로 유효하기 위한 가정을 명시한다 (state abstraction 이론 [50]의 shape-공간 적용).

```text
A1 (Reward shape-sufficiency)   reward가 shape feature와 goal의 함수다:
                                r_t ≈ ρ(Φ(X_t), Φ(X_{t+1}), Φ(G))
A2 (Approximate shape-Markov)   Φ(X)가 controlled dynamics에 대해 근사 Markov다 —
                                텐션 이력·속도 등 비관측 내부 상태의 영향이 작다
                                (quasi-static regime)
A3 (Response regularity)        response가 point estimate 또는 저차 분포로
                                표현 가능할 만큼 규칙적이다
```

깨지는 경우와 대응:

```text
장애물/환경 접촉 (A1 위반)   → 저차원 scene feature c_env 추가(§6.4) +
                              "obstacle task에서는 soft가 hard를 역전한다"를 사전 예측으로 등록
텐션·속도·소성 이력 (A2 위반) → quasi-static primitive로 scope 한정, dynamic task는 future work
자기가림·부분관측 (A2 위반)   → 본 연구는 sim state 기반; 인식(perception)은 scope 밖 [21, 26]
```

이 assumption stack은 약점이 아니라 연구 질문의 일부다: **"architectural constraint의 최적 강도는 A1–A3의 성립 정도에 따라 달라진다"**가 본 연구가 검증하는 regime 구조이며, 실험 설계(§7)가 A1이 성립하는 영역과 깨지는 영역을 모두 포함하는 이유다.

이론적 포지셔닝 두 가지를 명시한다. 첫째, auxiliary variant(V1)의 이론적 보증 — latent self-prediction + TD가 value-optimal 해를 보존한다는 결과 — 은 선행연구 [35]의 것이며 본 연구의 정리가 아니다. 둘째, 본 연구는 value-equivalence 원리 [42, 43] ("value에 필요한 것만 모델링하라")로부터의 **의도적 이탈**이다 — in-distribution value 정확도 일부를 희생하고 OOD transfer를 얻는 교환이며, 이 트레이드오프 자체가 실험 대상이다.

---

## 6. 제안 방법

### 6.1 문제 정식화

Goal-conditioned MDP로 정식화한다.

```text
state    s_t = (X_t, scene)   X_t: centerline K=32점 (arc-length 재표본, task frame)
goal     g = (shape template, anchor)                        (§6.2 이원화)
action   a_t = (p_t, u_t)     p_t ∈ {1..K} contact node index
                              u_t = (Δ ∈ R³, h ∈ {low, high})  변위 + 들어올림 높이
primitive: grasp(p) → move(Δ, h) → release → settle   (quasi-static)
episode  최대 T = 10 primitive steps
```

Reward는 **point-space에서 정의**한다 — critic 내부 표현(Φ)과 보상의 좌표계를 분리해, "표현이 보상의 충분통계라서 잘 되는" 순환 구조를 차단하기 위함이다.

```text
r_t = α [D(X_t, G) − D(X_{t+1}, G)] − c_step + 1{D(X_{t+1}, G) < ε_succ} · R_succ
D   = 길이 정규화 bidirectional Chamfer distance (또는 correspondence L2)
기본값: α = 10, c_step = 0.1, R_succ = 5, ε_succ = 0.05·L (파일럿에서 최종 고정)
```

파지 현실성: 파지점 실행 노이즈(±1 node 및 위치 오차)와 확률적 파지 실패(5%)를 기본 포함하고 robustness를 함께 보고한다. 저난도 task군에는 HACMan 계보 [1]와의 연속성을 위해 비파지 poke/push primitive 버전을 병행 옵션으로 둔다.

### 6.2 Response 표현 Φ — geometry-invariant 설계

Transfer 실험이 성립하려면 Φ가 rope 길이·이산화가 달라져도 동일하게 정의되어야 한다. 도메인별 data-PCA는 점 개수가 바뀌면 정의조차 되지 않으므로 배제하고, 다음과 같이 설계한다.

```text
Step 1  Arc-length 재표본: 임의 N점 centerline → 정규화 호길이 σ∈[0,1] 위 고정 K=32점
Step 2  좌표 프레임: task frame 유지 (회전 canonicalization 없음)
Step 3  Φ_DCT: 각 축(x,y,z)의 K점 신호에 DCT-II 적용, 저차 M=8 mode 보존
        Φ(X) ∈ R^{3M=24} — mode 0 = centroid(강체 이동), 저차 mode = 저주파 굽힘
Step 4  δm 정규화: 학습 도메인 δm의 채널별 표준편차로 정규화 (mode-0 제외 — 절대 위치 보존)
```

DCT를 기본값으로 하는 이유: (1) 데이터에 fit하지 않으므로 모든 길이/도메인에서 동일하게 정의됨, (2) modal analysis 문헌 [31]의 mode shape와 직접 연결되는 물리적 정당성, (3) deterministic·재현 가능·해석 가능. 대안 space(pooled PCA, AE latent, geometric feature, raw displacement)는 ablation으로 다룬다.

**Goal의 이원화 — 서로 다른 길이에서 "같은 goal"의 정의.** DCT는 표현 차원을 통일할 뿐, 다른 길이의 rope에서 동일 goal이 무엇인지는 별도로 정의해야 한다 (0.5 m rope용 절대 좌표 goal 곡선을 1.6 m rope는 덮을 수 없다). 아래는 **G2 게이트의 검증 대상인 후보 설계**이며, 게이트 통과 후 확정한다:

```text
shape 성분   정규화 호길이 위 형상 템플릿 (mode ≥ 1, scale-normalized) — 길이 불변
anchor 성분  절대 위치 목표 (한 끝점 또는 centroid의 task-frame 좌표) — mode-0 대응
goal residual: c_g = [Φ_shape(G) − Φ_shape(X_t),  anchor(G) − anchor(X_t)]
성공 판정: 길이 정규화 Chamfer + ε_succ 길이별 보정
```

Sanity check: 동일 물리 shape를 서로 다른 이산화(N=25/50/100)로 인코딩했을 때 Φ 일치를 실행 전 검증한다.

### 6.3 Response Head

```text
deterministic (기본):  δm̂_t = f_resp(s_t, p_t, u_t),  L_resp = Huber(δm̂_t − δm_t)
uncertainty (옵션):    μ_t, log σ_t = f_resp(·),  L_resp = −log N(δm_t | μ_t, diag σ_t²)
                       log σ clipping + variance floor. σ가 크면 Q를 낮추는 hard rule은
                       넣지 않는다 — risk 처리는 Bellman이 학습하게 둔다.
```

f_resp는 **goal을 입력받지 않는다** — 이것이 physics/task 인수분해의 구조적 구현이다. 표현 붕괴(collapse)는 supervised target 덕에 위험이 낮지만, 표현 rank·분산을 학습 내내 로깅한다 [38].

### 6.4 Critic 구조 — 세 가지 강도의 grounding

```text
V1 Auxiliary-only    h = Enc(s,g,p,u);  Q = F_Q(h);  δm̂ = F_resp(h)
                     L = L_Q + λ L_resp — Q는 response 표현을 경유하지 않음
V2 Soft bottleneck   Q = F_Q(δm̂, h_limited, c_g, c_env, η)
                     h_limited: 저차원 context (전체 bypass 금지)
V3 Hard bottleneck   Q = F_Q(δm̂, c_g, c_env, η)
                     Q가 접근 가능한 정보 = 예측 response + goal residual + 저차원 feature
```

보조 feature의 역할과 제약:

```text
c_g    goal conditioning (§6.2 이원화 형태)
c_env  장애물 상대 좌표 등 저차원 scene feature (obstacle task에서만 활성, ≤ 8-dim)
η      실행 가능성/비용: ‖u‖, reachability, collision risk, local curvature (≤ 8-dim)
제약   c_env·η가 full state bypass가 되지 않도록 차원 상한 + full-bypass ablation으로 감시
```

구조적 함의를 투명하게 명시한다: c_g − δm̂ = Φ(G) − Φ(X_{t+1}) 이므로 V3는 본질적으로 "행동 후 shape의 goal residual"에 대한 학습된 value다. 이것이 §5의 A1–A3가 필요한 이유이고, greedy 대조군(§7.5)이 필수인 이유다.

### 6.5 Actor와 Action 생성

```text
per-point actor   u_θ(s, p): 각 후보 node의 motion 제안 (DPG-style로 Q 최대화 학습)
contact 선택      per-point Q의 argmax (평가) / softmax·ε-greedy (탐험)
tie-breaking      DLO 대칭성(양 끝점 등가 등)으로 Q-landscape가 multimodal일 수 있음 —
                  top-k 동률 규칙과 softmax 온도를 명시해 argmax 불안정을 관리
정성 산출물       top-k contact 후보 + 각각의 예측 δm̂ 시각화
                  → "상호작용 예측을 조건으로 한 action 생성"의 직접적 데모
```

### 6.6 학습 목적함수와 안정화

```text
L_total = L_Q + λ L_resp,   λ = 1.0 (기본, {0.1, 1, 10} sweep)
L_Q: y_t = r_t + γ Q_target(s_{t+1}, g, a'_{t+1}),  L_Q = ‖Q − y_t‖²
ranking / contrastive / retrieval / successor loss는 넣지 않는다 — 기여는 loss가 아니라 구조다.
```

**Actor 학습식** — 이산 contact index p는 미분 불가능하므로 gradient 경로를 명시한다 (HACMan [1]의 per-point actor 방식):

```text
L_actor = − E_s [ (1/K) Σ_{p=1..K} Q_min(s, g, p, u_θ(s, p)) ]
- p 선택에는 gradient가 필요 없다 — contact 선택은 critic의 per-point argmax가 담당
- u_θ 갱신은 deterministic policy gradient: 모든 후보 node p에 대해 ∂Q/∂u를
  병렬로 backprop (전-후보 갱신이 기본; 선택된 p만 갱신하는 변형은 ablation)
- Q_min = twin critic의 최솟값 (TD3 관례), target policy smoothing on u 적용
- target action a'_{t+1}: 각 node의 u_target = u_θ'(s_{t+1}, p) 계산 후
  double-Q decoupling으로 p' 선택 (§6.6-1)
```

이 정식화가 §1의 "critic 개선 → action 생성 개선" 연결의 구체적 근거다: actor는 per-point Q를 통해서만 학습되므로, critic 표현의 개선이 곧 motion 제안 u_θ의 개선으로 전파된다.

이산 contact 선택이 만드는 고유 문제를 관리한다:

```text
1. 이산 argmax 과대추정: target의 max over 32 nodes는 twin-critic만으로 부족 —
   후보 선택(critic 1)과 평가(critic 2)를 분리하는 double-Q decoupling을 전 모델 동일 적용
2. HER: 초기에는 미사용. 도입 시 relabeling을 명시 정의 — 최종 X_T를 G로 relabel,
   reward는 point-space D로 재계산, c_g도 일관 재계산 (좌표계 불일치 주의)
3. 안정성 로깅 (전 모델 공통 보고): Q-value 통계, 과대추정 갭(Q vs 실현 return),
   gradient norm, argmax 후보 entropy — "grounding이 성능을 올렸다"와
   "학습을 안정화했다"를 분리 해석하기 위한 필수 계측
```

### 6.7 구현 세부 사양

네트워크 (state 기반, 총 ~1–2M params; larger-critic 대조군은 파라미터 일치):

```text
node feature     (x_i ∈ R³, 호길이 좌표 σ_i, goal 대응점 잔차) → shared MLP(64)
chain encoder    1D CNN 3층 (kernel 5, dilation 1/2/4, d=128) + global max-pool broadcast
                 → per-node embedding h_i ∈ R^128 (국소+전역 문맥)
f_resp           MLP(256, 256): [h_p, global, u] → δm̂ ∈ R^24 (또는 μ, log σ)
F_Q              MLP(256, 256): variant별 입력(§6.4) → per-point Q
actor            MLP(256, 128): h_i → u_i (tanh 스케일링, ‖Δ‖ ≤ u_max)
```

RL 하이퍼파라미터 기본값 (파일럿에서 조정 후 전 모델 고정):

```text
γ = 0.95 (T=10 단기 horizon) · τ = 0.005 · lr = 3e-4 (Adam) · batch 256
replay 1M · UTD 1 · warmup 5k random steps
탐험: ε-greedy over p (1.0 → 0.1 anneal, 200k steps) + Gaussian noise on u (σ = 0.2·u_max)
target policy smoothing on u · 평가: deterministic, 25k step마다 task당 100 episodes
checkpoint 선택: in-distribution validation task 성능 기준 (OOD 결과에 비접근 — leakage 차단)
```

---

## 7. 실험 계획

실험은 5개 층으로 구성된다: (0) 실행 전 파일럿 게이트 → (1) 기제 검증(probing) → (2) 구조 검증(variant 비교) → (3) 정책 성능 → (4) OOD 일반화 + 적응. **성공률보다 표현 검증이 먼저다** — 이 논문은 critic representation 연구이기 때문이다.

### 7.1 실험 환경

```text
결정 절차 (Phase 0 내):
  후보 primary: DLO-Lab [23] — centerline state, 강성/소성/마찰/신축 파라미터화,
                grasp-point action 내장, differentiable. 단 2026-06 공개로 성숙도 미검증
  fallback:     MuJoCo cable composite — 성숙·고속·재현성, bend/twist stiffness 파라미터화
  절차: 두 sim에 동일 T1 task를 실제 구동·비교 후 primary 확정 (문서 게이트가 아닌 실구동 게이트)
  secondary:    DaXBench [53] 또는 SoftGym [52] rope — 기존 문헌과의 접점 확보,
                핵심 OOD 결론 중 최소 1축(length)을 secondary에서 재현해 sim-artifact 여부 검증
state: sim ground-truth centerline (N=50) → K=32 재표본. 인식은 scope 밖 [21, 26]
```

### 7.2 Task Suite — contact-criticality 계층화

```text
T1  Local shaping (criticality 低, A1–A3 성립)
    straighten / single bend / endpoint reposition — 3 tasks
    목적: response-contact 연결 검증, greedy 등가 영역 확인
T2  Global shape matching (中)
    절차 생성 goal (S/U/L/zigzag 계열): train 500 / held-out eval 100
    비대칭 goal 포함 — 잘못된 contact 선택 시 1-step 도달 불가하게 설계
    목적: contact 선택의 가치가 드러나는 주 무대
T3  Long-horizon (高) — 두 성질을 분리해 별도 무대를 둔다
    T3c 비단조 · A1 성립 (장애물 없음):
        crossing-order / fold-reversal task — 목표와의 point-distance는 작지만
        위상(교차 순서, 접힘 방향)이 달라, 일시적으로 distance를 크게 늘려야만
        도달 가능. 장애물이 없어 A1이 성립하는 상태에서 비단조성만 요구한다.
        instance: train 30 / unseen eval 15
        → hard vs GreedyResp의 결정 무대. Bellman의 기여가 A1 위반과 얽히지 않고
          단독으로 발현되는 유일한 영역이므로 이 분리가 없으면 hard의 승부 무대가
          "hard가 지도록 설계된 무대(A1 위반)"와 겹치는 자기모순이 생긴다
    T3a peg routing (2–3 pegs): 비단조 + A1 부분 위반 (환경 접촉)
        layout: train 20 / unseen eval 10
    T3b obstacle-aware placement: A1 위반 — c_env 필요성 검증
    목적: Bellman 필요성(T3c)과 regime 교차(T3a/b)를 분리 검증
평가: task/seed당 100 episodes, deterministic policy
```

### 7.3 실행 전 파일럿 게이트

본 실험 전 반드시 통과해야 하는 두 게이트를 정의한다. 통과 실패 시 실험 축을 재구성한다.

```text
G1  Stiffness 유효성 게이트
    문제의식: quasi-static grasp-move-release-settle에서 최종 배치는 기하·마찰·중력이
    지배하고, 탄성 강성은 release 시 springback에만 남을 수 있다 —
    그 경우 stiffness OOD는 격차 자체가 없어 검증 불능(vacuous)이 된다.
    절차: 동일 (p,u) 시퀀스를 강성만 바꿔 실행, 최종 shape 분포의 효과크기 측정.
    판정: 효과크기 작음 → (a) stiffness를 주 OOD 축에서 강등하고 length/friction/goal 중심
          재편, 또는 (b) springback이 결과를 좌우하는 task(장력 하 routing, 곡률 정착
          shaping) 추가, 또는 (c) 부분 소성 활성화 — 단 (c)는 A2를 약화시키므로
          hard variant 적용 범위와의 상충을 명시하고 선택.

G2  Length-goal 정의 게이트
    §6.2의 이원 goal 정의(shape 템플릿 + anchor)가 구현·검증된 후에만 length OOD 실행.
    검증 1: 서로 다른 길이 rope에서 동일 goal 템플릿의 성공 판정 일관성 수동 확인.
    검증 2 (정량): reward 좌표계(point-space D)와 critic goal 좌표계(Φ-space c_g)의
    방향 정합 — 무작위 transition 표본에서 ΔD와 Δ‖c_g‖의 Spearman 상관 ρ ≥ 0.9 요구.
    "D 감소 ⇔ Φ-residual 감소"가 보장되지 않으면 critic이 보상과 다른 방향을
    최적화하게 되므로, 미달 시 mode 수 M 또는 D의 정의를 조정 후 재검증.
```

### 7.4 검증 게이트 1 — Black-box Critic Latent Probing

**질문: 표준 black-box contact critic은 이미 deformation response를 (transferable하게) 인코딩하는가?** 본 연구의 동기가 실측으로 성립하는지 확인하는 Go/No-Go 실험이다. 방법론은 RL 표현 probing의 표준 프로토콜 [47]을 따른다.

```text
절차: baseline 학습 → critic freeze → probe 학습 → in-domain 평가 → probe transfer
      (domain A에서 학습한 probe를 domain B latent에 그대로 적용)
데이터: 도메인당 200k transitions (학습 정책 replay 50% + uniform random 정책 50%),
       80/10/10 split. linear probe = ridge (α는 CV), nonlinear = MLP(128) 2층
지표: R² (전체/mode별), transfer degradation ratio = 1 − R²_B/R²_A
```

Controls — 각각이 배제하는 대안 가설을 명시한다:

```text
A  raw (s,p,u) probe          response가 애초에 예측 가능한 target인가
B  random frozen latent       latent가 random feature보다 나은가
C  nonlinear upper-bound      정보가 있으나 linear 접근 불가한 경우의 구분
D  shuffled target            probe가 dataset shortcut으로 맞추는가
E  transfer control           degradation이 표현 문제인가 target 분포 이동인가
   (B에서 직접 학습한 probe와 비교)
F  goal-entanglement          latent가 goal에 따라 변하는 것 자체는 정상이다 (Q는 goal의
   함수여야 하므로). 측정 대상은 "response-예측 성분과 goal-예측 성분의 선형 분리 가능성":
   F-1 두 성분의 예측 방향 간 principal angles
   F-2 goal 성분을 회귀로 제거한 잔차에서 response probe R²의 하락량
   → 분리 불가능(entangled)하면 관찰 2의 직접 증거
```

판정 기준 — **지금 이 문서에서 사전 고정한다.** "파일럿 후 임계 설정"은 사전 등록 원칙과 상충하므로, 파일럿의 용도는 측정 분산·실행 가능성 추정으로 한정하고 임계 자체는 아래 수치로 확정한다:

```text
확정 임계:
  linear R² < 0.5 ∧ raw-input probe 대비 ΔR² > 0.2      → Go (결핍 확인)
  in-domain R² ≥ 0.7 ∧ transfer degradation ≥ 40%       → Go (OOD-motivated)
  in-domain·transfer 모두 높음 (R² ≥ 0.7, degradation < 40%) → §8 Decision 1의 pivot 분기
  모두 낮음 (raw-input probe R² < 0.3 포함)                → No-Go 절차 ↓

No-Go stopping rule (실질적 중단 규칙 — "무한 재시도" 방지):
  response 정의 수정은 사전 명시된 대안 집합(§6.2의 ablation space) 안에서 1회만 허용.
  재시도에서도 raw-input probe가 임계 미달이면 "response는 이 세팅에서 예측 불가능한
  target"으로 결론짓고 연구를 중단 또는 전면 재설계한다.
```

### 7.5 검증 게이트 2 — 구조 비교와 대조군 체계

V1/V2/V3와 대조군들을 소규모 suite(T1 + T2 부분 + T3a 1개)에서 비교한 후 상위 2–3개 variant로 본 실험을 진행한다. **비교는 성공률만으로 하지 않는다** — representation 지표(probe, transfer)와 OOD 지표를 함께 본다.

**필수 최소 집합 — 5종 (Phase 3에서 전부 실행).** 이 5종만으로 연구의 핵심 질문이 전부 판정된다:

| # | 모델 | 배제하는 대안 가설 | Phase |
|---|---|---|---|
| 1 | Black-box critic (HACMan-style DLO port) | — 진단 대상이자 주 대조군 | P1–P3 |
| 2 | **Matched-dim value-equivalent latent** — V3와 완전 동형 아키텍처·동일 차원에서 supervision target만 교체 (physical δm → next-latent-consistency). 1-요인 대조 | **"물리 grounding이 아니라 저차원 bottleneck이면 뭐든 좋은 것 아닌가"** — 최중요 단일 대조군 (Kill criterion의 K1) | P3– |
| 3 | **GreedyResp** — f_resp로 1-step residual descent, Bellman 없음. node별 u 후보 64개 샘플링(+CEM 2회 정제) 후 예측 residual 감소 최대 (p,u) 선택 | **"RL이 필요 없는 것 아닌가"** — T3c(비단조·A1 성립)가 판정 무대 | P3– |
| 4 | V1 / V2 / V3 | grounding 강도 축 (study의 축) | P3– |
| 5 | Value-only per-point map — auxiliary 제거 + long-horizon value target (dense affordance 방식 [17]의 동일 코드베이스 구현) | "per-point value map은 이미 있다 [17]" — 최대 novelty 위협 | P3– |

GreedyResp의 f_resp 데이터 출처 (공정성 고정): **공통 off-policy 데이터셋** (warmup random + baseline replay 혼합, 총 예산 동일)으로 **1회 학습 후 공유**하고, selection 방식만 분기한다. DGCC의 f_resp(RL 공동 학습)와의 차이는 명시 보고.

**후순위 ablation (GNG1 프루닝 후, Phase 4–6에서 상위 variant에만 적용):**

| 모델/조작 | 목적 | Phase |
|---|---|---|
| + larger critic (파라미터 일치) | "파라미터가 많아서" 배제 | P4 |
| Reward-prediction bottleneck | "reward 정보면 충분한가" 분리 | P4–P6 |
| Shuffled target / random frozen bottleneck / full bypass | target 의미 / 구조 효과 / bypass 붕괴 | P6 |
| deterministic vs uncertainty / λ sweep / dim sweep {12, 24, 48} / DCT vs pooled-PCA vs AE | 구현 선택 민감도 | P6 |

외부 비교 (setting 차이는 "동일 데이터 예산" 조건으로 관리, 한계 명시):

| 모델 | 목적 | Phase |
|---|---|---|
| Goal-conditioned Transporter (cable) [9] | supervised pick-place value map 계열 대비 | P6 |
| (여력 시) GenDOM식 param-conditioned policy [29] 또는 HEPi [30] | 일반화 경쟁 진영 대비 | P6 |
| (appendix) dense affordance 원 구현 재현 [17] | 내부 구현 비교의 보조 — 부실 재현 리스크 격리 | P6+ |

사전 예측 등록 — 결과 확인 전 고정하여 어느 방향의 결과든 정보가 되게 한다:

```text
P1  A1–A3 성립 영역(T1, T2 무장애물)에서 hard ≥ soft ≥ aux > black-box
P2  A1 위반 영역(T3b)에서 soft > hard (c_env 제거 시 hard 열세 심화)
P3  OOD geometry에서 grounding variant와 black-box의 격차가 in-domain보다 확대
P4  GreedyResp는 T1에서 경쟁적, T3c(비단조·A1 성립)에서 큰 격차로 실패 —
    hard vs greedy의 분리 판정은 A1 위반과 얽히지 않는 T3c에서만 내린다
```

### 7.6 기제·표현 분석

```text
0  상대적 정상성의 직접 측정 (main hypothesis의 because절 검증 — 가장 우선)
   고정된 (s,p,u) 표본 집합에 대해 두 종류의 섭동을 독립적으로 가한다:
   - task 섭동: goal만 변경 (geometry 고정) → Q-target(및 학습된 Q)의 변동
   - physics 섭동: geometry(길이/강성)만 변경 (goal 고정) → δm_gt의 변동
   두 변동을 동일 정규화(각자의 in-domain 표준편차)로 스케일 후 직접 대조:
   - 분산비 (physics 성분 변동 / task 성분 변동)
   - 서수 지표: 각 섭동 하에서 contact 후보 ranking 보존율 (관찰 3의 서수적 정의와 정합)
   기대: δm의 ranking 보존율 ≫ Q-target의 ranking 보존율
   → 이 실험이 "physics가 task보다 정상적"을 downstream 성능이 아닌 직접 측정으로 검증한다
1  Linear probe 비교 — black-box / V1 / V2 / V3의 latent에서 response decode (§7.4 프로토콜)
2  Probe transfer across domains + ordinal 보존 분석:
   OOD에서 δm̂ 방향 cosine similarity, top-k contact ranking 보존율 (경로 E2 검증)
3  Reward-free 적응 (Claim 4): 새 도메인 transition k ∈ {0, 64, 256, 1024} (reward 마스킹)
   (i) f_resp-only vs (ii) black-box+사후 δm-head vs (iii) matched-dim latent-consistency
   vs (iv) full fine-tune 참조 (경로 E1 검증)
4  Alignment-performance 상관 (Claim 3): within-variant Spearman ρ (주 지표) +
   checkpoint-trajectory 상관 (보조). between-variant 상관은 교란으로 배제
5  Goal-entanglement 분석 (§7.4 Control F를 전 variant로 확장)
6  NN response consistency (Recall@K, silhouette by response cluster), UMAP/t-SNE (보조 시각화)
```

### 7.7 OOD Generalization Suite

축의 위계를 정직하게 고정한다. 가정을 깨지 않는 깨끗한 physics-OOD 축은 사실상 **length(+discretization)** 하나로 수렴하므로, length를 **primary 축**으로 명시 승격하고 논문의 "across geometries" 표방 범위도 이에 맞춰 기술한다. stiffness/friction은 G1 게이트 결과에 따르는 조건부 보조축이다.

```text
primary   length          L ∈ [0.8, 1.2] m → {0.5, 0.6, 1.4, 1.6} m  (goal은 §6.2 이원 정의)
          discretization  N ∈ {25, 100} (학습 N=50과 상이 — Φ 불변성 검증)
보조      initial/goal    분포 shift (held-out 형상군) — task 성분 transfer
조건부    stiffness       k × {0.5, 2.0}   (G1 통과 시에만 주장에 포함)
          friction        μ × {0.5, 2.0}   (A2 부분 위반 명시)
regime    obstacle        unseen layout (T3) — P2 검증용
주: 구체 split 수치는 G1/G2 게이트 통과 후 확정하는 잠정값이다.
보고: 축별 분해 + zero-shot / few-shot(reward-free) / full fine-tune 3단계
```

각 OOD 축이 어느 가정을 건드리는지의 대응을 명시한다 — "가정을 지키는 축은 효과가 작고, 효과가 큰 축은 가정을 깬다"는 긴장이 존재하며, 이를 숨기지 않고 축 선택의 근거로 삼는다.

| OOD 축 | 위반 가정 | 함의 |
|---|---|---|
| length | 없음 (이원 goal 정의 후) | grounding transfer의 가장 깨끗한 검증 축 |
| stiffness | 없음 (준정적 유지 시) | 단 G1 게이트로 유효성 선확인 |
| friction | A2 부분 위반 (정지마찰 이력) | response 노이즈 증가 — uncertainty head의 활약 지점, hard 열화를 사전 예측에 포함 |
| initial/goal shape | 없음 | task 성분 transfer 검증 (physics 성분 고정) |
| obstacle layout | A1 위반 | 사전 예측 P2의 검증 축 |
| discretization | 없음 | Φ 불변성의 순수 sanity 축 |

### 7.8 평가 프로토콜과 통계

```text
seed ≥ 5 (최종 표 8–10) · rliable IQM + 95% stratified bootstrap CI [55]
per-task · per-OOD-axis 분해 보고 · 학습 곡선 AUC · 안정성 지표 동시 보고 (§6.6)
판정 기준·사전 예측(P1–P4)·반증 조건은 결과 확인 전 문서로 고정
코드·설정·데이터 생성 스크립트 공개 전제
```

### 7.9 계산 예산

```text
가정: state-based 1 run ≈ 1–2 GPU-day (병렬 env), 2–5M env-steps/run
게이트 2 (§7.5 필수 집합): RL 학습 6 모델(black-box, V1–V3, matched-dim, value-only)
  × 3 task × 3 seed ≈ 54 runs ≈ ~110 GPU-day (달력 3주, 병렬)
  + GreedyResp는 f_resp 1회 학습(공통 데이터셋) + 평가만 (미미)
본 실험: 프루닝 후 3–4 모델 × 전체 task × 8 seed + 후순위 ablation ≈ 250–350 runs
총 상한: ~600 GPU-day — 8-GPU 노드 기준 달력 2–3개월 내 소화 가능
probe/분석/정상성 측정: 단일 GPU 수준 (병목 아님)
```

---

## 8. 결과 해석 프레임워크

어느 결과가 나와도 다음 단계가 정의되어 있도록, 그리고 **어떤 결과가 나오면 가설을 버릴 것인지**까지 사전에 고정한다.

### Decision 1 — Probing 게이트 (§7.4) 이후

| 결과 | 결정 |
|---|---|
| 결핍 확인 (probe 낮음) | 이상적 Go — Claim 1 그대로 진행 |
| in-domain 높음 + transfer 낮음 | Go — OOD transfer 중심 서사로 강화 (스토리 정합) |
| 모두 높음 | bottleneck 필요성 약화 → pivot: sample efficiency / reward-free 적응(Claim 4) / uncertainty 중심 재구성. Claim 4는 이 경우에도 독립적으로 성립 가능 |
| 모두 낮음 | response 정의 수정 (대안 space, dim 조정, transition averaging) 후 재시도 |

### Decision 2 — 구조 비교 (§7.5) 이후

판정 규칙만 사전 등록한다 (시나리오별 논문 서사는 결과 이후의 일이므로 여기서 확정하지 않는다):

| 결과 | 허용되는 결론 |
|---|---|
| Hard (V3) 최선 | "Q를 response 경유로 제약"하는 강한 구조 claim 허용 — 단 적용 범위는 A1 성립 regime으로 한정 |
| Soft (V2) 최선 | grounding claim은 유지, "bottleneck" 표현은 약화 |
| Auxiliary (V1) 최선/동률 | 구조 제약 claim 폐기 — 알려진 auxiliary 이론 [35]의 인스턴스임을 인정하고, 신규성은 기제 분석·cross-geometry·reward-free 적응으로 재배치 |
| Regime 교차 (P1+P2 동시 확인) | "constraint의 최적 강도는 A1–A3 성립도가 결정한다" — 본 study가 목표하는 완결형 결론 |
| 전부 무효과 | task 난이도·OOD split·response 정의 재검토 (G 게이트로 회귀) |

### Decision 3 — GreedyResp 대비 (판정 무대: T3c)

| 결과 | 해석 |
|---|---|
| DGCC > Greedy (T2, T3c) | Bellman + grounding 시너지 입증 |
| T1–T2 동률, T3c만 우위 | 사전 예측 P4와 일치 — claim 범위를 "비단조(Bellman-necessary) regime"으로 한정. T3c 인스턴스 수(45개)로 검정력 담보 |
| T3c 포함 전 구간 동률 | RL 성분 무의미 → "predictive response model + greedy selection"으로 연구 재정의 |

### Kill Criterion — 가설 기각 조건

세 조건의 동시 성립을 요구하면 K2·K3의 측정 특성상 사실상 발동 불가능한 기준이 되므로, **K1 단독을 1차 기각 조건**으로 한다.

```text
K1 (주 기준, 단독 발동): matched-dim value-equivalent 대조군이 primary OOD 축(length)을
   포함한 전 축에서 DGCC와 통계적 동률
   → "physical grounding은 저차원 bottleneck의 일반 효과 이상을 제공하지 않는다"로
     grounding 고유 기여를 기각. negative result로 처리하고 다른 포장을 하지 않는다.
K2 (보조 진단): reward-free 적응의 공정 대조 (i) vs (ii)(iii)에서 우위 소멸
K3 (보조 진단): partial correlation (Claim 3) 유의하지 않음
   → K2·K3는 K1 성립 시 기각의 견고성 확인 및 부분 기각(어느 claim이 살아남는지)의
     판정에 사용한다.
```

### Claims → Evidence Map

| Claim | 실험 | 성공 조건 |
|---|---|---|
| 가설 전제 (상대적 정상성) | §7.6-0 직접 측정 | physics 섭동 하 δm ranking 보존율 ≫ task 섭동 하 Q-target ranking 보존율 |
| C1 결핍 | §7.4 probe + Control F | black-box: 낮은 probe transfer, 높은 entanglement |
| C2 개입 효과 | §7.2 성능 + §7.7 OOD | grounding variant가 black-box·matched-dim·GreedyResp를 각각 격파 |
| C3 기제 연결 | §7.6-4 상관 | 공변량 회귀 후 partial correlation 유의 + 양(+) |
| C4 reward-free 적응 | §7.6-3 | f_resp-only가 공정 대조 (ii)(iii) 대비 우위 |
| (조건부) regime 구조 | §7.5 P1/P2 | variant × regime 상호작용 확인 |

---

## 9. 위험 관리

실행을 실제로 좌우하는 핵심 위험 5건만 본문에 둔다 (확장 목록은 부록 B):

| 위험 | 영향 | 완화 |
|---|---|---|
| stiffness OOD가 준정적에서 vacuous | main hypothesis의 OOD 축 일부 검증 불능 | G1 게이트 — 본 실험 전 효과크기 확인 필수, 미달 시 length 중심 재편 |
| length OOD의 goal 정의 불명확 | transfer 실험 전체 해석 불능 | §6.2 이원 goal 후보 설계 + G2 게이트 (방향 정합 정량 검증 포함) |
| matched-dim 대조군 동률 | grounding 고유 기여 기각 | Kill criterion K1으로 정직 처리 — negative result 전환 경로 사전 확정 |
| 이산 argmax 과대추정으로 baseline 불안정 | 모든 비교의 기저선 오염 | double-Q decoupling + 안정성 로깅 분리 보고 (§6.6) |
| DLO-Lab 미성숙 | 인프라 단일 실패점 | 2-sim 실구동 비교 후 확정 + secondary sim에서 핵심 결론 1축 재현 |

---

## 10. 일정과 산출물

| 단계 | 기간 | 산출물 (게이트) |
|---|---|---|
| P0 환경·파일럿 | 4주 (~8월 초) | 2-sim 실구동 비교 → primary 확정 · δm 파이프라인(재표본+DCT+이원 goal) · **G1·G2 게이트 통과** · reward/OOD split 수치 고정 |
| P1 Baseline 구축 | 5주 (~9월 중순) | HACMan-style DLO port + 이산 argmax 안정화 · 안정성 로깅 · latent 추출 API · T1–T2 기준 성능 |
| P2 Probing 게이트 | 2주 (~9월 말) | probe suite + Controls A–F · **§7.4에 사전 고정된 임계로 Go/Pivot 판정** (파일럿은 분산 추정용으로만 사용) |
| P3 구조 비교 게이트 | 3주 (~10월 말) | V1/V2/V3 + GreedyResp + matched-dim + value-only map 소규모 비교 · P1–P4 대조 · **variant 프루닝 (상위 2–3개)** |
| P4 본 학습 | 5주 (~12월 초) | 선택 variant 본 학습 · T1–T3 전체 · uncertainty 옵션 |
| P5 기제 분석 | 3주 (~12월 말) | probe/transfer/ordinal/상관/entanglement/reward-free 적응 (공정 대조 포함) |
| P6 OOD·ablation | 5주 (~2월 초) | OOD 전 축 · ablation 전체 · secondary sim 재현 1축 |
| P7 집필 | 6주 (~3월 중순) | 논문 초고 → 내부 리뷰 → 투고 |

투고 전략: **CoRL 2027 (1순위)**. RSS 2027(1월 마감)은 P4까지 조기 수렴 시에만 검토. 백업: ICLR 2028 / ICRA 2028. ICLR 계열 제출 시 study 프레이밍(기제 분석·regime 구조·사전 등록) 전면화, CoRL/ICRA 제출 시 성능·시스템 결과 전면화 + 실로봇 1-task validation을 stretch goal로 (perception은 tracking 선행연구 [21, 26] 활용).

---

## 11. 논문화 전략

선제 방어의 전문은 진단 실험(§7.4–7.5) 결과가 나오면 다시 쓰게 되므로, 본문에는 논문 골격과 novelty 경계선만 두고 상세 반론 대응·abstract 초안은 부록 A(Phase 7 집필 자료)로 분리한다.

### 11.1 본문 구성

```text
Introduction   관찰 1→4 (§3의 사슬) → 가설 → contributions (method + study + adaptation)
Method         정식화 → assumption stack → DGCC variants → 구현
Experiments    1) mechanism validation (§7.6-0 정상성 직접 측정 포함)
               2) architecture comparison  3) policy performance (+GreedyResp)
               4) OOD + reward-free adaptation  5) ablation·failure 분석
Discussion     regime-dependence · one-step response의 한계 · 실로봇 확장
```

### 11.2 Novelty 경계선 — 핵심 3건

본문 Related Work에서 반드시 그어야 할 경계는 세 건이며, 각각 실험적 방어선이 지정되어 있다:

```text
1. Foresightful dense affordance [17] — deformable per-point "value" map은 이미 존재.
   경계: 우리는 value가 아니라 물리 반응으로 ground한다.
   방어선: value-only per-point map ablation (§7.5 필수 5종의 #5)
2. TD-MPC/VPN/MuZero [39-41] — value-through-latent-model은 성숙한 패러다임.
   경계: 우리의 bottleneck은 물리량에 supervise된 1-step 표현이며 rollout 불가.
   방어선: matched-dim value-equivalent 대조군 (§7.5 필수 5종의 #2)
3. Flow 계열 [11, 15, 16] — effect 표현의 전이성은 이미 입증됨.
   경계: 그들은 effect를 policy/greedy selector에 공급, 우리는 Bellman critic에 결합.
   방어선: GreedyResp 대조 (§7.5 필수 5종의 #3, 판정 무대 T3c)
```

나머지 반론(auxiliary 표준론 [33, 35], successor features [44], 충분성, 실로봇)에 대한 대응 초안은 부록 A.

### 11.3 최종 포지셔닝

```text
We study how Bellman critics should represent contact actions when action values
are strongly mediated by deformation responses — and we show that grounding the
critic in the response yields contact representations that transfer across DLO
geometries and adapt without reward.
```

하지 않을 주장: controllability 추정 · Jacobian 학습 · Φ(DCT/PCA)가 기여라는 주장 · world model 학습 (1-step, rollout 불가) · response가 value를 완전 결정한다는 주장 · auxiliary loss 자체가 novelty라는 주장.

---

## 부록 A. 예상 반론과 대응 (Phase 7 집필 자료 — 결과 확정 후 재작성 전제)

**"TD-MPC/MuZero/VPN [39–41]과 뭐가 다른가?"** — 그들의 latent는 return 최적화에만 맞춰진 value-equivalent 표현이고 multi-step rollout에 쓰인다. DGCC의 bottleneck은 (i) 물리적으로 정의된 shape-change 공간에 supervise되고, (ii) 엄격히 1-step이며 rollout 불가능하고, (iii) 순수하게 critic 표현 제약이다. 실험적으로는 matched-dim 대조군이 직접 방어선이다.

**"Forward-dynamics auxiliary는 UNREAL [33] 이래 표준 아닌가?"** — 맞다. V1이 정확히 그 알려진 아이디어의 인스턴스이며, 언제 돕는지의 이론도 존재한다 [35]. 기여는 auxiliary loss가 아니라 (i) 구조적 개입 강도의 통제 비교, (ii) cross-geometry transfer 축 ([35]는 distractor robustness), (iii) probe 기반 기제 증거, (iv) reward-free 적응이다.

**"Transfer가 목적이면 왜 successor features [44]가 아닌가?"** — SF는 dynamics 고정 하에 reward 변화를 전이한다 (Q = ψ·w). 우리의 표적은 정반대 축인 dynamics/geometry 변화다. 한계도 명시한다: δm̂에는 SF의 closed-form task 재조합성이 없고, 전이는 f_resp의 reward-free 적응으로 매개된다.

**"δm̂은 결국 coarse flow 아닌가 [11, 15, 16]?"** — Flow 계열은 dense effect field를 policy에 공급하거나 greedy selector로 소비한다. 우리는 compact response를 Bellman critic에 결합해 장기 가치를 보존한다. GreedyResp가 T3c에서 실패하는 것이 이 구분의 실증이다.

**"Per-point value map은 deformable에 이미 있다 [17]."** — 그들의 per-point score는 추정된 장기 task value로 supervise된다 — black-box critic의 deformable 유사체다. 우리는 물리 반응 예측으로 critic을 ground하고, 그것이 transfer의 원인임을 probe·상관·동일 코드베이스 ablation으로 보인다.

**"1-step response + goal residual이 Q에 충분한가?"** — 일반적으로 불충분하다. 충분해지는 가정(A1–A3)을 명시했고, 가정이 깨지는 영역에서 soft가 이긴다는 예측(P2)을 사전 등록했다. Regime-dependence는 결함이 아니라 발견 대상이다.

**"실로봇 검증은?"** — CoRL/ICRA 제출 시 T1/T2에서 single real-rope validation (tracking은 [21, 26]). ICLR 계열 제출 시 표현 연구로 scope 한정.

**Abstract 초안 (결과 확정 전 — 구조 참고용):**

```text
Bellman critics learn which contact actions are valuable, but not the physical
mechanism by which an action becomes valuable. In deformable linear object
manipulation, contact value is strongly mediated by the deformation response
induced by contact actions. We study how contact critics should represent this
mechanism: we propose deformation-grounded contact critics (DGCC), which preserve
hybrid actor-critic value learning while structuring the critic around a predicted
low-dimensional deformation response, and we compare auxiliary, soft-, and
hard-bottleneck instantiations. Because response labels are self-supervised,
DGCC additionally enables reward-free adaptation to unseen DLO geometries.
Across [tasks], grounding improves OOD transfer across rope length [and further
axes pending gate G1]; probe analyses show black-box critics encode deformation
response in a goal-entangled, domain-specific way, and response-probe transfer
predicts OOD performance within architectures.
```

## 부록 B. 확장 위험 목록

| 위험 | 영향 | 완화 |
|---|---|---|
| black-box latent가 이미 transferable response 인코딩 | 동기 약화 | §7.4 게이트 선판정 + Decision 1 pivot 경로 |
| hard variant의 정보 부족 (A1 위반 task) | 대표 task 실패 | c_env 설계 + 사전 예측 P2로 등록 (실패 → 발견 전환) |
| Φ의 도메인 간 불일치 | probe transfer 해석 불능 | DCT 기본값 + 재표본 불변성 sanity check |
| GreedyResp 전 구간 동률 | Bellman 성분 무의미 | T3c 설계로 사전 차단 + Decision 3 전환 경로 |
| response 노이즈/확률성 | 학습 불안정 | Huber/NLL, δm 정규화, settle 대기 |
| 외부 baseline 재현 품질 | 비교 무효 | 주 비교를 동일 코드베이스 ablation으로 설계 |
| 계산 폭발 | 일정 지연 | 게이트 프루닝, 순차 확장, §7.9 예산 상한 |

---

## 12. Related Works

본문에서 인용한 문헌을 주제별로 정리한다.

### A. Hybrid actor-critic과 per-point affordance (rigid/articulated)

- [1] Zhou et al., **HACMan: Learning Hybrid Actor-Critic Maps for 6D Non-Prehensile Manipulation**, CoRL 2023. arXiv:2305.03942 — per-point Q map + motion parameter의 hybrid action. 본 연구의 architectural parent. DLO 적용 부재.
- [2] Jiang et al., **HACMan++: Spatially-Grounded Motion Primitives for Manipulation**, RSS 2024. arXiv:2407.08585 — primitive 선택으로 확장. task suite에 deformable 없음 (전문 확인).
- [3] Mo et al., **Where2Act**, ICCV 2021. arXiv:2101.02692 — per-point actionability와 action score의 분리 설계. "value vs mechanism" 두-head 분리의 선례.
- [4] Jiang et al., **GIGA: Synergies Between Affordance and Geometry**, RSS 2021. arXiv:2104.01542 — affordance head + auxiliary geometry head 공동 학습이 transferable feature를 만든다는 구조적 유추의 근거.
- [5] Ning et al., **Where2Explore**, NeurIPS 2023 — local geometry의 cross-category 공유가 transfer의 단위라는 증거.
- [6] Wang et al., **AdaAfford**, ECCV 2022. arXiv:2112.00246 — 시각만으로 안 보이는 물리 파라미터는 상호작용으로 회복해야 함 — 물리 grounding 동기.
- [7] Geng et al., **RLAfford**, ICRA 2023 — affordance map과 RL의 co-training 안정성 선례.
- [8] Zeng et al., **Transporter Networks**, CoRL 2020. arXiv:2010.14406 — pick-conditioned place value map.
- [9] Seita et al., **Learning to Rearrange Deformable Cables, Fabrics, and Bags with Goal-Conditioned Transporter Networks**, ICRA 2021. arXiv:2012.03385 — cable 포함 deformable의 goal-conditioned pick-place map. supervised·image-space·deformation grounding 없음 — 핵심 대조군.
- [10] Sundermeyer et al., **Contact-GraspNet**, ICRA 2021. arXiv:2103.14127 — 관측점에 action을 root시키는 per-point contact 파라미터화.

### B. Effect/flow 기반 action 선택

- [11] Eisner, Zhang, Held, **FlowBot3D**, RSS 2022. arXiv:2205.04382 — per-point articulation flow 예측 → argmax 선택. effect 예측은 있으나 learned critic 없음.
- [12] Zhang, Eisner, Held, **FlowBot++**, CoRL 2023. arXiv:2306.12893 — compact articulation descriptor 병행 예측.
- [13] Weng et al., **FabricFlowNet**, CoRL 2021. arXiv:2111.05623 — deformable(cloth)에서 flow 기반 pick/place. supervised IL.
- [14] Seita et al., **ToolFlowNet**, CoRL 2022. arXiv:2211.09006 — tool flow → action 회귀.
- [15] Yuan et al., **General Flow as Foundation Affordance**, CoRL 2024. arXiv:2401.11439 — flow 표현의 cross-embodiment 전이.
- [16] Xu et al., **Im2Flow2Act**, CoRL 2024. arXiv:2407.15208 — flow를 embodiment-bridging interface로 사용.
- [17] Wu, Ning, Dong, **Learning Foresightful Dense Visual Affordance for Deformable Object Manipulation**, ICCV 2023. arXiv:2303.11057 — rope 포함 deformable 위 per-point long-horizon value map. **최근접 선행연구이자 최대 novelty 위협** — task value로만 supervise되며 물리 반응 grounding 없음. 동일 코드베이스 ablation으로 직접 비교.

### C. DLO manipulation

- [18] Grannen, Sundaresan et al., **Untangling Dense Knots by Learning Task-Relevant Keypoints**, CoRL 2020. arXiv:2011.04999 — keypoint 기반 grasp 선택의 대표.
- [19] Sundaresan et al., **Learning Rope Manipulation Policies Using Dense Object Descriptors**, ICRA 2020. arXiv:2003.01835.
- [20] Viswanath et al., **Autonomously Untangling Long Cables**, RSS 2022. arXiv:2207.07813.
- [21] **HANDLOOM**, CoRL 2023. arXiv:2303.08975 — cable centerline tracing (실로봇 확장 시 인식 제공자).
- [22] Luo et al., **Multi-Stage Cable Routing**, 2023. arXiv:2307.08927 — 계층적 IL.
- [23] Cao et al., **DLO-Lab**, 2026. arXiv:2606.04206 — DLO 특화 벤치마크. VLM grasp 제안. "suboptimal grasp는 목표를 kinematically unsolvable하게 만든다" — contact 선택 중요성의 최신 근거.
- [24] Ma et al., **G-DOOM (Latent Graph Dynamics)**, ICRA 2022. arXiv:2104.12149 — keypoint GNN dynamics + per-keypoint MPC.
- [25] Lin et al., **VCD (Visible Connectivity Dynamics)**, CoRL 2021. arXiv:2105.10389.
- [26] Chen et al., **DEFORM (Differentiable Discrete Elastic Rods)**, CoRL 2024. arXiv:2406.05931 — DER 기반 실시간 모델링·추적.
- [27] **DeformNet**, 2024. arXiv:2402.07648 — action-conditioned latent deformation 예측 → MPC. object-global이며 per-contact critic 아님.
- [28] Chi et al., **Iterative Residual Policy (IRP)**, RSS 2022. arXiv:2203.00663 — delta-action → delta-effect 학습. effect 조건화의 방증.
- [29] Kuroki et al., **GenORM / GenDOM**, 2023. arXiv:2306.09872 / 2309.09051 — 물리 파라미터 조건화 + test-time 추정으로 cross-rope 일반화. 경쟁 baseline.
- [30] **HEPi**, 2025. arXiv:2502.07005 — SE(3)-equivariant GNN policy의 unseen object 일반화.
- [54] Caporali et al., **DLO perception and manipulation survey**, IJRR 2026 — per-point RL critic + deformation grounding의 부재 확인.

### D. Modal/저차원 shape 표현 (Φ의 정당화)

- [31] Yang et al., **Model-Free 3-D Shape Control Using Modal Analysis Features**, T-RO 2023. arXiv:2207.01249 — 저주파 mode feature와 motion의 analytic 관계. Φ 선택의 물리적 근거. 단 single-grasp servoing에 한정 — discrete contact 선택·critic에는 미사용.
- [32] Navarro-Alarcon et al., **Uncalibrated Visual Deformation Servoing**, IJRR 2014 — deformation feature 기반 제어의 원조.

### E. RL representation: auxiliary·model-based value·transfer·probing

- [33] Jaderberg et al., **UNREAL**, ICLR 2017. arXiv:1611.05397 — auxiliary task의 원조.
- [34] Schwarzer et al., **SPR**, ICLR 2021. arXiv:2007.05929 — latent self-prediction auxiliary의 표준.
- [35] Voelcker et al., **When does Self-Prediction help?**, RLC 2024. arXiv:2406.17718 — latent self-prediction + TD의 value-optimality 보존. V1의 이론적 배경 (본 연구의 정리가 아님).
- [36] **BYOL-AC**, 2024. arXiv:2406.02035 — action-conditional self-prediction과 Q/advantage 구조의 이론.
- [37] Ni et al., **Bridging State and History Representations**, ICLR 2024. arXiv:2401.08898.
- [38] Tang et al., **Understanding Self-Predictive Learning for RL**, ICML 2023. arXiv:2212.03319 — collapse 방지 조건.
- [39] Oh et al., **Value Prediction Network**, NeurIPS 2017. arXiv:1707.03497.
- [40] Schrittwieser et al., **MuZero**, Nature 2020. arXiv:1911.08265.
- [41] Hansen et al., **TD-MPC2**, ICLR 2024. arXiv:2310.16828 — value-equivalent latent + planning. matched-dim 대조군의 배경.
- [42] Farahmand et al., **VAML / IterVAML**, AISTATS 2017 / NeurIPS 2018 — decision-aware model learning. 본 연구는 이 원리로부터의 의도적 이탈.
- [43] Grimm et al., **The Value Equivalence Principle**, NeurIPS 2020.
- [44] Barreto et al., **Successor Features for Transfer in RL**, NeurIPS 2017. arXiv:1606.05312 — reward-변화 transfer. 본 연구의 dynamics-변화 축과 상보적 대비.
- [45] Touati, Ollivier, **Forward-Backward Representations**, NeurIPS 2021. arXiv:2110.15701.
- [46] **TD-JEPA**, 2025. arXiv:2510.00739 — 최신 zero-shot RL 계열.
- [47] Anand et al., **Unsupervised State Representation Learning in Atari (AtariARI)**, NeurIPS 2019. arXiv:1906.08226 — frozen-representation linear probing의 표준 프로토콜.
- [48] Zhang et al., **DBC**, ICLR 2021. arXiv:2006.10742 — bisimulation 기반 표현 (implicit metric 대안).
- [49] Castro et al., **MICo**, NeurIPS 2021.
- [50] Li, Walsh, Littman, **Towards a Unified Theory of State Abstraction for MDPs**, ISAIM 2006 — assumption stack의 이론적 기반 (model-irrelevance abstraction).
- [51] **UniIntervene**, 2026. arXiv:2606.12372 — action-conditioned consequence 예측 → value head. 구조적 최근접 이웃이나 consequence가 unsupervised VLA latent이며 기제 분석 없음 — 인용·구분 필수.

### F. 벤치마크·시뮬레이터·평가

- [52] Lin et al., **SoftGym**, CoRL 2020. arXiv:2011.07215.
- [53] Chen et al., **DaXBench**, ICLR 2023. arXiv:2210.13066 — differentiable rope 벤치마크.
- [55] Agarwal et al., **Deep RL at the Edge of the Statistical Precipice (rliable)**, NeurIPS 2021 — IQM·stratified bootstrap CI 평가 표준.
