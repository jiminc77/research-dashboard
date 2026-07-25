# LIT E — Auxiliary gradient routing and scheduling

## Scope and verdict

**Verdict: NO-GO unconditionally; CONDITIONAL GO only after repeated DGCC gradient-conflict or norm-dominance evidence.** The literature supplies tools for conflict projection and scale balancing, but neither establishes that a physics auxiliary loss should always be surgically modified. Adaptive methods also add failure modes and tuning. The brief's activation rule—consistent conflict in at least two completed V1 seeds—is well aligned with the evidence.

## Primary evidence

### 1. Conflict projection/gating

- **Yu et al., “Gradient Surgery for Multi-Task Learning” (PCGrad), 2020, NeurIPS, arXiv:2001.06782.** Primary: https://arxiv.org/abs/2001.06782 ; https://proceedings.neurips.cc/paper/2020/hash/3fe78a8acf5fda99de95303940a2420c-Abstract.html
- Algorithm: for task gradients `g_i,g_j`, when cosine similarity is negative, project `g_i ← g_i - (g_i·g_j/||g_j||²)g_j`; aggregate projected gradients. The paper's “tragic triad” combines conflicting direction, large curvature, and gradient-magnitude imbalance.
- Evidence includes supervised multi-task learning and multi-task RL, with ablations against unmodified joint training. The intervention is optimizer-side, consumes per-task gradients, and introduces ordering/randomization details; it is not a free scalar schedule.
- Limitation for DGCC: PCGrad treats tasks symmetrically. The RL control objective is primary and the response loss instrumental, so blindly preserving the auxiliary task is not necessarily desirable.

- **Du et al., “Adapting Auxiliary Losses Using Gradient Similarity”, 2018/2020, arXiv:1812.02224.** Primary: https://arxiv.org/abs/1812.02224
- Mechanism gates/scales an auxiliary gradient according to its cosine with the main gradient, directly matching a primary-plus-auxiliary setting. It provides a simpler diagnostic-to-intervention bridge than symmetric surgery: a persistently negative cosine argues for suppressing rather than preserving auxiliary updates.

### 2. Gradient-scale balancing

- **Chen et al., “GradNorm: Gradient Normalization for Adaptive Loss Balancing in Deep Multitask Networks”, 2018, ICML, PMLR 80:794–803, arXiv:1711.02257.** Primary: https://proceedings.mlr.press/v80/chen18a.html ; https://arxiv.org/abs/1711.02257
- Learns task weights so each shared-layer gradient norm approaches `Ḡ[r_i]^α`, where `r_i` is relative inverse training rate; see Eqs. (1–4) and Algorithm 1. Measuring only the last shared layer added about 5% training time in the reported NYUv2 setup.
- Positive evidence: compared with equal/static/uncertainty weighting on vision multi-task benchmarks.
- Negative evidence: large `α` can push weights toward zero and become unstable; on MTFL, stuck majority-classifier tasks were increasingly overweighted because slow learning was mistaken for a need for more gradient. This is particularly dangerous for a saturated or imperfect auxiliary response target.

## Answers to E1–E7

1. **Does negative cosine predict control harm?** It is a mechanistic warning, not a sufficient predictor. PCGrad supports conflict as an optimization pathology; DGCC must correlate conflict windows with later return/contact diagnostics across seeds.
2. **Simplest stabilization?** First fixed `λ`/decay ablations and stop-gradient routing; next, main-gradient cosine gating. PCGrad/GradNorm are more complex and should not be first-line candidates.
3. **Where to route?** The literature supports operating on shared parameters or a chosen shared layer. For DGCC, measure encoder TD-versus-aux gradients separately from response-head-only gradients; response-head private parameters do not create task conflict.
4. **Late auxiliary drift?** Plausible but not directly established for DGCC. Test whether auxiliary norm/cosine becomes dominant after predictor convergence before adopting decay.
5. **Dynamic versus fixed?** Not consistently universal. GradNorm beats several baselines in its benchmarks but has instability/pathological-task failures; it does not dominate all fixed schedules for all primary-aux settings.
6. **Tuning-free reproducibility?** No. PCGrad has task-order details; GradNorm has `α`, layer choice, and weight dynamics; cosine gating has thresholds/smoothing choices.
7. **Physics-aux negative results?** The reviewed general literature shows auxiliary/multitask negative transfer is real, but no close DLO TD3 study demonstrates a universal physics-aux failure. This weakens an unconditional candidate.

## Activation and diagnostic contract

GO only if at least two completed V1 seeds show one or more of:

1. sustained negative TD-versus-aux encoder gradient cosine in comparable late-training windows;
2. auxiliary encoder-gradient norm dominating TD norm by a preregistered ratio;
3. auxiliary loss/gradient remaining large after response calibration plateaus while policy metrics regress.

Required offline instrumentation specification:

- compute TD and auxiliary gradients on the same frozen replay batches;
- report cosine, each norm, norm ratio, layerwise concentration, and bootstrap intervals by checkpoint;
- do not step optimizers or alter RNG/global model state;
- correlate diagnostics with later validation return/contact entropy across at least two seeds;
- distinguish encoder-shared gradients from response-head-private gradients.

If activated, retain at most two mechanism families:

| Family | Minimal intervention | Main risk | Verdict |
|---|---|---|---|
| Fixed/decayed auxiliary routing or cosine gate | one schedule/gate on encoder auxiliary gradient | threshold/schedule selection | First conditional choice |
| PCGrad projection | project only conflicting encoder task gradients | complexity and symmetric-task assumption | Backup only |

GradNorm is evidence for diagnosis and a negative-control baseline, but its tendency to upweight stuck tasks makes it a poor five-day V2 default.

## Rubric (1 weak, 5 strong)

| Criterion | Unconditional | If conflict verified | Basis |
|---|---:|---:|---|
| Causal fit | 1 | 5 | Entire case depends on observed conflict. |
| Simplicity | 3 | 3 | Fixed decay is simple; surgery is not. |
| Prior evidence | 3 | 4 | Strong general MTL, weak DLO-control transfer. |
| Train–deploy consistency | 4 | 4 | Training-only routing intentionally leaves inference unchanged. |
| Model exploitation risk | 5 | 5 | No decision-time model use. |
| Seed robustness | 2 | 3 | No direct lower-tail proof. |
| Real deployability | 5 | 5 | No inference overhead. |
| Paper clarity | 2 | 4 | Clear only with measured conflict. |
| Baseline fairness | 4 | 4 | Added training compute must be reported. |
| Tuning burden | 2 | 3 | Fixed gate can limit knobs; adaptive methods add them. |
