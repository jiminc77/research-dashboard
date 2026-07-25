# LIT C — Budget extension and stability

## Scope and verdict

**Verdict: GO as baseline hygiene/characterization, NO-GO as a standalone V2 architecture headline.** Canonical TD3 delayed policy/target updates have direct algorithmic and ablation support. Replay capacity, replay ratio, training horizon, and checkpoint opportunities are causal experimental variables, so 600k cannot be treated as “the same experiment for longer” unless schedules and state continuation are explicitly controlled. Few-seed selection must expose uncertainty rather than crown a best checkpoint/seed.

## Primary evidence

### 1. Canonical TD3 cadence

- **Fujimoto, van Hoof & Meger, “Addressing Function Approximation Error in Actor-Critic Methods”, 2018, ICML, PMLR 80:1587–1596, arXiv:1802.09477.** Primary: https://proceedings.mlr.press/v80/fujimoto18a.html ; https://arxiv.org/abs/1802.09477
- Algorithm 1 updates both critics each iteration, but updates the actor and all target networks only every `d` critic updates; the standard `d=2` means one actor/target update per two critic updates. Target policy smoothing and clipped double Q are separate components (target Eq. 15).
- Section 5.2 motivates delay as protection against high-variance critic estimates. Table 2 ablates delayed policy updates (`TD3 - DP`): removal materially hurts Hopper and Ant, but not every task, so the correction is evidence-backed hygiene rather than a guaranteed variance cure.

### 2. Replay is not semantically neutral

- **Fedus et al., “Revisiting Fundamentals of Experience Replay”, 2020, ICML, PMLR 119:3061–3071, arXiv:2007.06700.** Primary: https://proceedings.mlr.press/v119/fedus20a.html ; https://arxiv.org/abs/2007.06700
- Separates replay capacity, replay ratio (learner updates per environment transition), and oldest-policy age. Experiments show their effects interact with algorithm components such as n-step returns; larger replay helps Rainbow substantially in reported settings but not vanilla DQN. Thus capacity and update/data ratio cannot be assumed inert or universally monotone.

- **Zhang & Sutton, “A Deeper Look at Experience Replay”, 2017, arXiv:1712.01275.** Primary: https://arxiv.org/abs/1712.01275
- Demonstrates buffer size is a consequential hyperparameter and that very large buffers can hurt in some settings. This supports treating a 500k ring under 600k collection as a changed data-age distribution, not just more samples.

### 3. Few-run evaluation

- **Agarwal et al., “Deep Reinforcement Learning at the Edge of the Statistical Precipice”, 2021, NeurIPS, arXiv:2108.13264.** Primary: https://arxiv.org/abs/2108.13264 ; https://proceedings.neurips.cc/paper/2021/hash/f514cec81cb148559cf475e7426eed5e-Abstract.html
- Shows that point estimates from a handful of runs are unstable. Recommends stratified-bootstrap intervals, performance profiles, probability of improvement, optimality gap, and interquartile mean (25% trimmed mean). With only one task and three locked seeds, all paired deltas and uncertainty must remain visible; IQM is not a magic substitute for sample size.

- **Henderson et al., “Deep Reinforcement Learning That Matters”, 2018, AAAI, arXiv:1709.06560.** Primary: https://arxiv.org/abs/1709.06560 ; https://ojs.aaai.org/index.php/AAAI/article/view/11694
- Documents sensitivity to seeds, implementation, and reporting choices, reinforcing fixed protocols and full-run disclosure.

## Answers to C1–C12

1. **TD3 cadence?** Critics every iteration; actor and targets every `d` critic iterations, conventionally `d=2` (Algorithm 1).
2. **Lower-tail evidence?** Table 2 supports task-dependent performance/stability benefit, not a direct lower-tail guarantee. DGCC must measure seed-level margin/gradient diagnostics.
3. **Hybrid evidence?** No direct discrete-contact/continuous-motion delayed-update study was found; transfer is plausible but unverified.
4. **Exploration under doubled horizon?** Literature gives no universal rule. For a pure budget ablation, hold the absolute 300k decay schedule fixed; fraction-based stretching changes the intervention.
5. **Capacity below total transitions?** Effects are algorithm/task dependent. A 500k ring can be valid, but overwrite/data age must be treated as part of the experimental condition.
6. **Replay ratio?** Keep collection and gradient-update budgets separately declared. A nominal ratio of one is not equivalent to “same learning” when policy-delay cadence changes.
7. **Fresh 600k or continuation?** Fresh matched 600k is clean for total-budget comparison; exact 300k→600k continuation is clean only with full state serialization. Neither belongs beside 300k architecture candidates as if compute matched.
8. **Optimizer/replay reset?** Resetting either changes optimization and data distributions; it is a new regime, not exact continuation. Direct universal effect direction is not supported.
9. **Does longer training rescue bad seeds?** Not guaranteed. Nonmonotonic and seed-specific learning makes best-seed extension especially vulnerable to selection bias.
10. **Checkpoint selection?** Predeclare fixed final or late-window aggregate. Do not select the best single checkpoint after viewing curves; report all checkpoints and selection opportunities.
11. **Few-seed robust metric?** Paired per-seed deltas, interval estimates, probability of improvement, and complete curves. IQM is useful across larger task/run collections but n=3 remains weak.
12. **Novelty?** A canonical TD3 correction is common-base hygiene. If it fixes DGCC, report it transparently and do not label it the architectural contribution.

## Experiment-contract consequences

- Common stabilized baseline: compare every architecture on identical delayed actor/target cadence if that correction is adopted.
- Budget ledger must expose transitions, critic updates, actor updates, target updates, replay capacity/age, exploration horizon, eval count, wall time, and checkpoint opportunities.
- Distinguish: fresh 300k, fresh matched 600k, exact serialized continuation, and warm-start/reset continuation.
- Winner metrics should use a preregistered late window and worst-seed guard; no best-checkpoint lottery.
- Performance utility and paper novelty receive separate ratings.

## Rubric (1 weak, 5 strong)

| Criterion | Score | Basis |
|---|---:|---|
| Causal fit | 4 | Noncanonical cadence is a credible approximation-error source. |
| Simplicity | 5 | Policy-delay correction is tiny; continuation serialization is not. |
| Prior evidence | 5 | Original TD3 plus replay/evaluation literature. |
| Train–deploy consistency | 4 | Primarily training hygiene; deployment graph unchanged. |
| Model exploitation risk | 5 | No response-model exploitation. |
| Seed robustness | 3 | Evaluation guidance is strong; direct lower-tail effect is not. |
| Real deployability | 5 | No added inference cost. |
| Paper clarity | 2 | Weak standalone novelty. |
| Baseline fairness | 5 | Properly applied as a common base. |
| Tuning burden | 5 | Canonical `d=2` adds no search degree if fixed. |
