# LIT B — Deployment-time learned response/lookahead

## Scope and verdict

**Verdict: CONDITIONAL.** Literature strongly supports combining short learned-model lookahead with a long-horizon terminal value, and strongly warns against pure myopic predicted-progress selection. It does **not** directly validate DGCC's cheapest proposed form—one batched response pass over the existing 32 actor-generated contacts with no action perturbation. That finite-candidate reranker is the only family compatible with the simplicity constraint; CEM/MPPI and ensembles are evidence-bearing references but out of scope as V2 candidates.

## Primary evidence

### 1. Short model rollout plus terminal Q/V

- **Hansen et al., “Temporal Difference Learning for Model Predictive Control”, 2022, ICML, PMLR 162, arXiv:2203.04955.** Primary: https://proceedings.mlr.press/v162/hansen22a.html ; https://arxiv.org/abs/2203.04955
- TD-MPC learns a task-oriented latent transition/reward/value model and performs short-horizon trajectory optimization with a learned terminal value. Its TOLD objective couples consistency, reward, and TD value prediction. Planning samples and iteratively refines action sequences, warm-started by the actor; this is materially more than one extra response forward.
- The key evidence is structural: ablations removing value/model/planning components and horizon analyses support local model use plus terminal value rather than model-only greedy control.

- **Sikchi, Zhou & Held, “Learning Off-Policy with Online Planning” (LOOP), CoRL 2021 / PMLR 164 (2022), arXiv:2008.10066.** Primary: https://proceedings.mlr.press/v164/sikchi22a.html ; https://arxiv.org/abs/2008.10066
- Eqs. (2–3) optimize `Σ_{t=0}^{H-1}γ^t r_t + γ^H V̂(s_H)`. Theorem 1 exposes the tradeoff: longer horizon discounts terminal-value error but compounds model error.
- ARC regularizes candidate trajectory distribution to an actor-derived prior with a KL constraint; its solution weights candidates by `prior × exp(score/η)`. Algorithm 3 uses a finite population, model rollouts, and terminal Q.
- Negative evidence: same-horizon PETS without terminal value is myopic; no-ARC planning increases actor divergence and can destabilize Walker; evaluation-only planning underperforms planning used during collection as well, showing train–deploy mismatch is material; weak regularization in offline use admits OOD overestimated trajectories.

### 2. Deformable-object learned-model planning

- **Yan et al., “Learning Predictive Representations for Deformable Objects Using Contrastive Estimation”, CoRL 2020 / PMLR 155 (2021), arXiv:2003.05436.** Primary: https://proceedings.mlr.press/v155/yan21a.html ; https://arxiv.org/abs/2003.05436
- Learns a contrastive latent forward model from interactions and uses MPC with one-step predictions for rope/cloth tasks; transfers to a real PR2 with domain randomization. This establishes real-robot deformable-object precedent for one-step predictive planning, but not Q-preserving finite contact reranking.

- **Yan et al., “Self-Supervised Learning of State Estimation for Manipulating Deformable Linear Objects”, 2020, IEEE RA-L / ICRA, arXiv:1911.06283.** Primary: https://arxiv.org/abs/1911.06283 ; https://doi.org/10.1109/LRA.2020.2969931
- Uses a learned DLO state estimator and differentiable dynamics inside MPC/MPPI in simulation and on a robot. It strengthens robotics relevance while also showing that published deployment systems pay a multi-sample planning cost.

## Myopic progress versus long-horizon value

| Family | Score | Strength | Failure mode | DGCC implication |
|---|---|---|---|---|
| Pure one-step response/progress | `r̂` or predicted distance only | Cheap, interpretable | Ignores delayed effects; Dreamer “No value” and LOOP PETS-restricted are short-sighted | **NO-GO** as sole selector |
| H-step model + terminal Q/V | predicted rewards plus `γ^H Q/V` | Literature-supported error tradeoff | Planning/model exploitation and compute | Too large if CEM/MPPI/ensemble is required |
| Existing actor candidates + Q-preserving response rerank | keep long-horizon Q, use response as filter/tie-break/residual | Potentially one batched forward, restricted support | Scale/calibration and train–deploy mismatch; no direct primary ablation found | **CONDITIONAL**, diagnostic first |

## Answers to B1–B13

1. **One-step model score or terminal Q?** Terminal Q/V combination is better supported; model-only greedy is negatively ablated.
2. **Placement?** Literature supports terminal-value lookahead and actor-regularized candidate scoring. For a minimal DGCC seam, filter/tie-break or bounded residual is more defensible than replacing Q.
3. **Existing finite candidates only?** LOOP/TD-MPC use finite sampled populations but still optimize action sequences. Direct evidence that only reranking an actor's fixed 32 candidates is sufficient was not found; this remains OPEN.
4. **OOD exploitation control?** Restrict to actor-generated actions, use actor prior/regularization, and fail closed on poor calibration. LOOP's ARC and offline pessimism ablations support these controls.
5. **Single model or ensemble?** Robotics/model-based methods often use ensembles or uncertainty; the deformable contrastive-model paper shows a single learned representation can drive simple MPC. A single DGCC head is plausible but not guaranteed safe.
6. **Horizon?** Theory gives a model-error/value-error tradeoff, not a universal optimum. H=1 is justifiable only as the bounded-error/simplicity corner while retaining terminal Q.
7. **Deploy-only mismatch?** Likely material. LOOP's evaluation-only planning ablation underperforms use during data collection. A deploy-only DGCC reranker must be treated as a distinct policy and tested against target/training alignment.
8. **Actor divergence/OOD?** Yes; ARC's raison d'être and ablations are direct evidence. Restrict candidates rather than perturbing actions.
9. **24-D DCT scoring/decoding?** OPEN because the mandatory repository audit stopped before target semantics were inspected. Literature does not establish that DCT coefficients are directly goal-scoreable; explicit decoding or a learned goal-relative score may be needed.
10. **Q/model scale?** LOOP avoids ad-hoc addition by using model rewards plus discounted terminal value under one return scale. A DGCC additive residual introduces `λ`; tie-break/filtering can reduce scale coupling but still needs preregistered calibration.
11. **DLO real deployment?** Yes: both Yan et al. papers deploy learned dynamics/representations for rope/DLO manipulation on robots, though through MPC rather than a single Q rerank.
12. **Latency?** Published systems accept MPC/MPPI latency; no evidence gives DGCC/Franka timing. The required local GPU profile was forbidden by kickoff, so latency remains OPEN.
13. **Accurate model but worse policy?** LOOP's planning ablations and model/value error theorem show model quality alone is insufficient; distribution shift, actor divergence, terminal value error, and myopia can dominate.

## DGCC design constraints

- Never replace long-horizon Q selection with pure predicted one-step progress.
- First diagnostic should score only the 32 actor-proposed actions, consume no RNG, and report calibration by candidate rank/margin; no perturbation search.
- Any behavioral use must specify whether response is a bounded residual, tie-break, or filter; additive use needs one locked scale parameter.
- Train-only/deploy-only asymmetry requires an explicit call-count contract and an ablation against matching use during data collection/backup.
- Ensemble/CEM/MPPI candidates violate the stated one-module/one-forward simplicity ceiling unless later evidence overturns it.

## Rubric (1 weak, 5 strong)

| Criterion | Score | Basis |
|---|---:|---|
| Causal fit | 3 | Can improve selection but basin-entry evidence is indirect. |
| Simplicity | 3 | Fixed-candidate rerank is simple; published planners are not. |
| Prior evidence | 4 | Strong model+terminal-value and deformable-robot evidence. |
| Train–deploy consistency | 2 | Deploy-only use is directly cautioned by LOOP. |
| Model exploitation risk | 2 | Central failure mode; actor restriction helps. |
| Seed robustness | 2 | Lower-tail-specific evidence is weak. |
| Real deployability | 3 | Robot precedent exists, but timing is unknown. |
| Paper clarity | 5 | “Use learned physics at decision time while preserving Q” is clear. |
| Baseline fairness | 3 | Forward count and wall time must be matched/reported. |
| Tuning burden | 3 | One scale/gate is possible; planning variants explode knobs. |
