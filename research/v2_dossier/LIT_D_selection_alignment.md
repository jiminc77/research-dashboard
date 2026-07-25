# LIT D — Selection-aligned hybrid objective

## Scope and verdict

**Verdict: GO for a selection-weighted/soft value-weighted objective family, CONDITIONAL on the code audit confirming DGCC's reported uniform-mean/Q1-argmax mismatch.** HACMan is unusually close: a per-point continuous actor, per-point critic map, Q-based contact choice, and a soft value-weighted actor/target objective. It supplies a simple differentiable alternative to both uniform all-branch training and hard top-1 gradients. The literature does not establish lower-tail variance reduction, so that remains the required DGCC outcome rather than an assumed benefit.

## Primary evidence

### 1. HACMan: spatial parameterized action with soft selection alignment

- **Zhou et al., “HACMan: Learning Hybrid Actor-Critic Maps for 6D Non-Prehensile Manipulation”, 2023, CoRL, arXiv:2305.03942.** Primary: https://arxiv.org/abs/2305.03942 ; https://hacman-2023.github.io/
- Action: discrete object point/contact plus point-specific continuous motion. The actor outputs a motion for every point; the critic outputs a Q map for corresponding point-motion pairs.
- Deployment selects `i*=argmax_i Q_i`. During training, Eq. (4) defines a softmax contact distribution `π_loc(i|s)∝exp(Q_i/β)`. Per-point actor loss is Eq. (5); Eq. (6) weights all point losses by `π_loc`, rather than using a uniform mean or a hard argmax. The target in Eq. (7) likewise takes an expectation under the contact distribution.
- Gradient semantics: hard discrete choice is not differentiated. Soft Q weights give gradients to multiple branches and concentrate them on valuable contacts. The paper uses separate actor/critic PointNet++ weights, reducing direct shared-trunk gradient coupling.
- Evidence: Table 6 reports a large gap between random contact and HACMan on the hardest all-object/6D-goal setting (0.147±0.021 vs 0.854±0.028). The `No Actor Map` ablation is only slightly worse (0.835±0.017), so contact selection/critic mapping is better supported than per-contact actor complexity. The greedy `γ=0` ablation falls to 0.293±0.026, again rejecting myopic contact control. Table 5 shows discrete point selection is much stronger than regressing a free contact coordinate in that setting.
- Limitation: these ablations do not isolate uniform versus soft-Q-weighted actor loss, and do not claim lower seed variance.

### 2. General parameterized-action RL

- **Xiong et al., “Parametrized Deep Q-Networks Learning: Reinforcement Learning with Discrete-Continuous Hybrid Action Space”, 2018, CoRR/arXiv preprint, arXiv:1810.06394.** Primary: https://arxiv.org/abs/1810.06394
- Defines actions `(k,x_k)` with discrete branch `k` and branch parameter `x_k`. A parameter network proposes continuous parameters and Q chooses the discrete branch, establishing the general actor-proposes/Q-selects structure.
- Critical mismatch: branches are semantic fixed actions, not permutation-equivariant object contacts; known parameterized-action methods inherit nonstationary actor–critic coupling and can produce gradients from branches not executed. HACMan is therefore the stronger DGCC analogue.

## Required objective-family comparison

| Family | Objective sketch | Gradient/exploration | Overestimation | Compute | Verdict |
|---|---|---|---|---|---|
| Uniform all-branch | `-(1/K)Σ_i Q_min(i,π_i)` | Dense and stable, but optimizes low-value branches equally; discrete exploration separate | Selection can still amplify Q1 error | No extra forward | Baseline only; weak deployment alignment |
| Hard selected/top-k | `-Q(i*,π_{i*})` or top-k mean | Sparse, discontinuous selection changes; collapse and neglected branches possible | Hard max magnifies estimation error | No/low extra | CONDITIONAL diagnostic, not first choice |
| Soft value-weighted | `-Σ_i stopgrad(w_i)Q(i,π_i)`, `w=softmax(score/β)` | Dense but selection-focused; temperature controls concentration | Use clipped/min score or stop-gradient to contain feedback | Same Q map plus weighting | **GO family**, closest to HACMan |

The exact Q operator is decisive. HACMan's single-critic exposition does not answer whether DGCC should weight/select with Q1 or Qmin. With twin critics, Q1 argmax followed by Qmin evaluation can amplify ranking noise; agreement, margin, and disagreement diagnostics should gate the operator choice.

## Answers to D1–D12

1. **All branches or selected?** HACMan uses all branches with soft Q-derived weights, not a uniform mean or top-1 only.
2. **Discrete choice operator?** HACMan uses critic Q softmax in training and Q argmax at inference. Parameterized-action methods also use Q maximization. Twin-critic Q1-vs-Qmin choice remains OPEN.
3. **Hard argmax gradient?** Avoided by treating location choice as a distribution/weighting; no straight-through estimator is required.
4. **Capacity waste?** Soft weighting is motivated as focusing learning on likely contacts while retaining broader gradients, but a direct capacity-waste ablation is absent.
5. **Top-only collapse?** Plausible and not ruled out; soft weighting is the safer simple family.
6. **Discrete max overestimation?** Standard max-Q risk applies and is potentially stronger across many contacts. Twin-critic agreement/margin diagnostics are required.
7. **Shared features?** HACMan uses separate actor/critic backbones. This weakens support for sending selection-weighted actor gradients into DGCC's shared encoder without routing controls.
8. **Exploration schedules?** HACMan samples locations from Q softmax; continuous action noise is a distinct mechanism. This supports separating contact and motion exploration.
9. **Permutation/topology?** Pointwise maps provide spatial/permutation-compatible semantics. Fixed P-DQN branches do not.
10. **Already implemented versus missing?** Reported DGCC behavior already has per-contact actor output and Q contact argmax; the literature-supported missing piece would be selection-weighted actor/target alignment. Code-level confirmation is blocked by the dirty-tree precondition.
11. **Seed variance?** No direct evidence that the objective reduces variance/lower tail. It must be an explicit test endpoint.
12. **Known instability?** Actor/Q co-adaptation, max overestimation, branch collapse, and exploration starvation. Soft stop-gradient weights, entropy/margin monitoring, and fixed temperature limit risk.

## DGCC design constraints

- Preserve dense gradients initially; prefer soft value weighting over hard top-1.
- Use one frozen/scalar weighting rule and one temperature at most; stop gradients through weights unless a deliberate second-order feedback contract is established.
- Align actor, target, and deployment operators or document each remaining asymmetry.
- Track Q1/Qmin argmax agreement, top-1 margin, contact entropy, selected-contact churn, and per-contact gradient norm.
- Separate “canonical baseline correction” from novelty: if current behavior merely diverges from the intended HACMan-style objective, frame it as alignment rather than a new model module.

## Rubric (1 weak, 5 strong)

| Criterion | Score | Basis |
|---|---:|---|
| Causal fit | 5 | Directly targets the reported train/deploy operator mismatch. |
| Simplicity | 5 | Reweights an existing candidate/Q map; no new module. |
| Prior evidence | 4 | HACMan is structurally close, though key loss ablation is absent. |
| Train–deploy consistency | 5 | Same value ranking can govern train and inference. |
| Model exploitation risk | 5 | No learned response model added. |
| Seed robustness | 2 | Lower-tail claim unproven. |
| Real deployability | 5 | No extra inference forward required. |
| Paper clarity | 5 | Hybrid objective aligned to actual contact selection. |
| Baseline fairness | 5 | Compute can remain matched. |
| Tuning burden | 4 | One temperature; operator choice must be locked. |
