# LIT A — Explicit actor exposure to predictive information

## Scope and verdict

**Verdict: NO-GO for direct one-pass `z_resp(h,u)`/`δm` actor conditioning; CONDITIONAL only for an action-independent predictive state feature.** The closest primary literature either (a) gives the actor an action-independent predictive state while reserving action-conditioned features for the critic, or (b) lets the actor consume a pre-action latent world-model state. None of the reviewed methods resolves the algebraic circularity of feeding `z(s,a)` to the same one-pass actor that must first produce `a`. An action-independent feature would also be close to DGCC V1's already auxiliary-shaped shared representation, so it has weak incremental content.

## Primary evidence

### 1. OFENet — action-independent actor feature, action-conditioned critic feature

- **Ota et al., “Can Increasing Input Dimensionality Improve Deep Reinforcement Learning?”, 2020, ICML, PMLR 119:7424–7433, arXiv:2003.01629.** Primary: https://proceedings.mlr.press/v119/ota20a.html ; https://arxiv.org/abs/2003.01629
- Method: `z_o=φ_o(o)` replaces the actor observation; `z_{o,a}=φ_{o,a}(z_o,a)` replaces the critic observation-action input. The online auxiliary next-observation prediction loss is Eq. (1). Algorithm 1 computes both representations before updating the base RL agent.
- Mechanism placement: action-independent predictive expansion is used by the actor and critic; action-conditioned expansion is critic-side. It is trained and used at deployment, but no rollout planner is added.
- Evidence: Table 1 reports five-seed continuous-control results across SAC/TD3/PPO. Gains are broad but not universal: TD3+OFE is worse on Hopper and Humanoid, which rejects an unconditional “more predictive dimensions always help” claim. The setting is low-dimensional MuJoCo state, making it more relevant than image-only representation work.
- Missing controls: the paper's central treatment intentionally raises dimensionality; it does not cleanly establish a DGCC-like capacity-matched “physics content versus added parameters” control, nor a predictor-error threshold that guarantees policy gain.

### 2. Latent world-model state as policy input, not current-action response as policy input

- **Hafner et al., “Dream to Control: Learning Behaviors by Latent Imagination”, 2020, ICLR, arXiv:1912.01603.** Primary: https://arxiv.org/abs/1912.01603 ; https://dreamrl.github.io/
- Method: the actor receives the current latent state, `a_τ ~ q_φ(a_τ|s_τ)` (Eqs. 2–3), while action-conditioned transition dynamics predict future latent states (Eq. 1). Actor gradients traverse imagined latent trajectories and λ-returns (Eqs. 5–8); the world model is fixed during behavior learning.
- Ablation: the “No value” ablation and Figs. 4/7 show that finite-horizon predicted reward without terminal value is short-sighted and sensitive to horizon. This supports preserving long-horizon value rather than using a response prediction as a myopic policy input.
- Critical mismatch: Dreamer is a model-based visual-control rewrite with imagined rollouts, not a one-module/one-forward addition to TD3.

- **Lee et al., “Stochastic Latent Actor-Critic”, 2020, NeurIPS, arXiv:1907.00953.** Primary: https://arxiv.org/abs/1907.00953 ; https://rl-slac.github.io/slac/index_files/slac_neurips2020.pdf
- Method: the default critic consumes latent samples, but the actor consumes observation-action history (Eqs. 8–10), explicitly avoiding perfect latent-state access. The actor/critic input ablation reports strong sensitivity to critic latent input but relative indifference to actor latent input.
- Design consequence: predictive information may be more valuable on value/scoring paths than as an explicit actor input.

## Answers to A1–A10

1. **Direct actor latent or shared encoder?** Both exist, but the closest simple low-dimensional method (OFENet) gives the actor only action-independent `z_o`; action-conditioned `z_{o,a}` is critic-side. SLAC does not require latent actor input.
2. **Action dependence?** Actor-facing features in the simple methods are pre-action/action-independent. Action-conditioned predictions live in critic or transition paths.
3. **Circularity solution?** No reviewed one-pass method feeds `z(s,a)` into the actor that emits that same `a`. Dreamer solves a different problem by feeding pre-action state and rolling dynamics after action. DGCC would require proposal→response→refinement or critic/selection-side scoring.
4. **Sharing/routing?** OFENet shares learned observation features across actor/critic and adds action-conditioned critic features; Dreamer separates world-model fitting from behavior updates; SLAC asymmetrically places latent input in the critic.
5. **Auxiliary targets?** OFENet predicts next observation; Dreamer predicts latent transitions/reward/observations; SLAC fits a sequential latent model. None validates DGCC's 24-D DCT `δm` as sufficient actor information.
6. **Goal-relative?** These mechanisms are generally task/observation based, not evidence that a goal-agnostic deformation target is sufficient for goal-conditioned control.
7. **Efficiency, asymptote, variance?** OFENet reports learning and final-return gains but mixed TD3 results and no lower-tail-specific conclusion. Dreamer emphasizes sample efficiency. Seed-variance rescue is not established.
8. **Capacity-matched control?** Insufficient for the proposed DGCC claim; a same-parameter non-predictive feature control would be required.
9. **Low-dimensional evidence?** OFENet provides it; Dreamer/SLAC are mainly image-control evidence.
10. **Calibration threshold?** No transferable predictor-error threshold was found. Policy adoption therefore requires a DGCC-specific frozen-checkpoint calibration gate.

## DGCC design constraints

- Treat “actor sees no physics” as an invalid framing; the admissible question is explicit *action-conditioned* response use versus an already response-shaped representation.
- A one-pass direct concat of `z_resp(h,u)` into the actor is not a well-defined computation graph.
- The smallest literature-consistent explicit feature seam is critic/selection-side action-conditioned use, not actor input.
- Any actor-feature experiment needs a capacity-matched nuisance-feature control, predictor-calibration stratification, and seed-level lower-tail reporting.

## Rubric (1 weak, 5 strong)

| Criterion | Score | Basis |
|---|---:|---|
| Causal fit | 2 | No evidence that explicit actor features cure basin-entry variance. |
| Simplicity | 2 | Action-conditioned input forces a second pass; action-independent input is duplicative. |
| Prior evidence | 3 | OFENet is positive in low-dimensional control but mixed under TD3. |
| Train–deploy consistency | 4 | OFENet/Dreamer use actor-facing features at both train and deploy. |
| Model exploitation risk | 3 | Lower than planning, but uncalibrated features can mislead policy gradients. |
| Seed robustness | 1 | Lower-tail evidence absent. |
| Real deployability | 4 | One action-independent feature pass is feasible. |
| Paper clarity | 2 | Increment over V1 is hard to isolate. |
| Baseline fairness | 3 | Capacity and compute matching are required. |
| Tuning burden | 3 | At least feature choice/weight and calibration gate remain. |
