# DGCC V2 pre-design research summary

Date: 2026-07-25  
Live/clean-clone HEAD: `289c5434905257ddbdca8542a4ed41c9858e4403`  
Frozen BB source bundle: commit `786d651`

## Executive conclusion

The strongest pre-design direction is **D: selection-aligned hybrid objective**, with **C: canonical TD3 delayed updates** treated as a common baseline-hygiene control rather than architecture novelty. **B: deployment-time response use** remains conditional: one `B×32` response pass is vectorizable, but CPU network-only profiling shows ~39% extra selection-module time, train/deploy mismatch and model exploitation remain real, and pure one-step predicted progress is unsupported. **A: direct action-conditioned actor input** is NO-GO as a one-pass mechanism because `u` must exist before `z_resp(h,u)`. **E: gradient routing** is NO-GO unless repeated gradient conflict is measured in at least two V1 seeds.

A clean confirmatory V2 claim is currently **BLOCKED by governance**, independently of architecture quality: no V2 charter, no fresh V2 split/process firewall, no valid BB seed-5 completion, no fresh paired BB 5–7 budget, and no V2-specific technical retry rule exist.

## Audit integrity

The live checkout was dirty, so it was not audited. A clean local clone of committed HEAD was created without modifying/stashing user state; clean status and SHA parity were verified. Code, committed development metrics, frozen-bundle metadata/proof, and public governance issues were read-only. No heldout JSON content, training/eval run, candidate implementation, commit/branch, or GPU operation occurred. CPU-only synthetic response/vector timing and six focused existing unit tests were run.

## Twelve mandatory answers

| # | Answer | Evidence |
|---:|---|---|
| 1 | **Yes. V1 actor receives auxiliary information indirectly.** | Auxiliary MSE updates the shared encoder (`src/dgcc/rl/sprint_arms.py:155-200`); actor later consumes full encoder `h`, though actor update detaches encoder (`src/dgcc/rl/td3.py:347-374`). |
| 2 | **No, not for one-pass action-conditioned conditioning.** | `ResponseHead` requires `(h_p,u)` (`sprint_arms.py:50-67`), while actor must first emit `u`. A proposal/refinement second pass or critic/selection use is required. |
| 3 | **Yes. `f_resp` is completely unused in deployment and target paths.** | Sole behavioral call is auxiliary MSE at `sprint_arms.py:191`; inherited target/actor/selection paths contain none (`td3.py:250-294,347-374,408-454`). |
| 4 | **Yes, `B×32` scoring is vectorizable; “small overhead” is not established.** | CPU test produced `(256,32,24)` in one flattened call. `f_resp` p50/p95 3.96/4.06 ms; encoder+actor+Q1 p50 sum ~10.24 ms, about 39% relative overhead. GPU/robot timing is OPEN. |
| 5 | **No. Actor and deployed contact objectives are not aligned.** | Actor maximizes uniform all-contact Qmin mean (`td3.py:358-365`); deployment uses hard online-Q1 argmax (`:426-447`). |
| 6 | **Yes. Delayed actor and target updates are missing.** | `update()` performs critic, actor, and targets every update (`td3.py:386-402`). Canonical TD3 delays actor/targets, conventionally `d=2`. |
| 7 | **No. Fresh 600k and 300k continuation are different experiments.** | ε horizon changes 90k→180k; 500k replay overwrites ~100k early rows; updates/evals/checkpoint opportunities change. |
| 8 | **No. Current contract cannot exactly continue.** | Checkpoint saves networks/optimizers/update count but not replay, RNGs, driver/env/episode/eval/selector state (`td3.py:492-535`; `sprint_arms.py:237-305`). Driver has no resume CLI. |
| 9 | **Current deterministic V1 extra forward need not break pairing; stochastic V2 computation would.** | One NumPy RNG is shared by contact/action exploration, simulator, and replay (`p1_train.py:430-442,523-528`). Target noise uses global Torch RNG because update gets no explicit generator. |
| 10 | **No. There is no fresh V2 confirmatory heldout.** | Only `t2_sprint_heldout_v1` is registered (`sprint_claims.py:15-17,32`); no V2 split/charter exists, and existing sprint outcomes informed V2. File mode 0664 is not process denial. |
| 11 | **No. Valid fresh paired BB 5–7 comparators are not available/budgeted.** | BB s5 and byte-identical rerun both failed by rebuild limit; BB s6/7 exist in an older cohort; no fresh matched BB/V2 5–7 plan is pinned. |
| 12 | **Selection/objective is the minimum-diff seam.** | It reuses current actor/Q candidate map and adds no inference forward. Selection-side response diagnostic/rerank is next; target/actor response use expands contracts. |

## Core code findings

### Actor/contact/target mismatch

- Encoder transforms `(B,32,7)` to full `(B,32,256)` using local convolutions plus broadcast global max pool (`src/dgcc/models/networks.py:85-148`). Actor is a shared per-point MLP over all nodes (`:186-212`).
- Actor update detaches encoder and uses uniform `mean(min(Q1,Q2))` over 32 contacts (`td3.py:347-374`).
- Deployment chooses contact with online Q1 argmax; target chooses with target Q1 and evaluates selected smoothed action using target Qmin (`td3.py:250-293,408-454`).
- Lift is sigmoid during optimization and executed with strict `>0.5` threshold (`networks.py:199-212`; `td3.py:440-447`).

### Response lifecycle

`f_resp`: `(B,260)→256→z_resp(256)→δm_hat(24)` with ReLUs and linear output (`sprint_arms.py:50-67`). It is trained only on replay-executed actions via DCT displacement MSE (`:155-200`), has no target network, and is serialized/restored (`:237-305`). The current actor/deployment policy never consumes it.

### Budget and continuation

At n_envs=1024, current 300k runs end at 300,032 with 290,816 critic/actor/target updates and 12 evals. Fresh 600k projects to 600,064, 590,848 of each update, 24 evals, ε decay over 180k instead of 90k, and 100,064 overwritten replay positions. `--total-override` is not resume.

### Reward/evaluation

Reward is `10(d_t−d_{t+1})−0.1+5·1[success]`; success is normalized `d<0.05` (raw 0.05 m at L=1 m); horizon is 10; success terminates early; timeout truncation bootstraps (`reward.py:26-70`; `episode.py:291-329`; `td3.py:135-156`). `mean_return` is undiscounted. Training `best.pt` uses strict success improvement; sprint selector uses success, then return, then earlier checkpoint (`p1_train.py:698-703`; `sprint_select_ckpt.py:32-36`).

A 300-episode final-validation retrospective across V1 s0–2 found return/final-distance correlation −0.562; unsuccessful episodes can still have high positive shaping return; the success bonus is ~85.4% of aggregate successful return. U-family showed large progress but only 4.2% success. Response-derived myopic progress therefore cannot substitute for long-horizon Q/success evaluation.

### Learning curves

The 120-row audit covers 10 completed BB/V1 runs at all 25k evaluations. V1 s0 is +0.070 at 150.5k then +1.426 at 225.3k; s1 remains negative through 275.5k then reaches +1.032 final; s2 accelerates earlier, reaching +0.805 at 150.5k and +1.960 at 225.3k. A 150k hard kill at return `<0.1` falsely rejects s0/s1; even `<0` falsely rejects s1. This supports lower-tail/basin-entry and late-window evaluation, not early best-seed selection.

### Source-bundle fairness

Frozen BB bundle pins commit `786d651` and an authenticated 37-file closure (`outputs/metrics/sprint_bb_parity_proof.json:1-40,121-163`). Core network/TD3/replay blobs match live HEAD, but frozen `p1_train.py`/evaluation predate sprint wall-guard/raw-final behavior. V1 live training consumes those flags; frozen BB driver does not, creating a validation/selector cohort caveat when incidents occur even though model code is parity-locked.

## Evidence balance: Direction D

### Credit

- DGCC has a directly confirmed objective/deployment mismatch and zero-delay actor/target cadence.
- HACMan is structurally close: per-point continuous actor, per-point Q map, soft Q-weighted actor/contact distribution in Eqs. 4–7, hard Q argmax inference (Zhou et al., CoRL 2023, arXiv:2305.03942: https://arxiv.org/abs/2305.03942).
- Soft value weighting preserves dense gradients, targets the observed operator seam, adds no module/inference forward, and stays within one main knob (temperature/operator).

### Debit

- HACMan does not isolate uniform versus soft-weighted actor loss in its key ablation and does not prove seed lower-tail reduction.
- Twin-critic Q1 versus Qmin weighting is unresolved; hard max can amplify overestimation/contact collapse.
- Required DGCC diagnostics—Q1/Qmin argmax agreement, top margin, contact churn, per-contact gradients, lift threshold mass—are not currently logged.

### Verdict

**GO mechanism family, conditional on frozen-checkpoint diagnostics.** Prefer soft selection weighting over hard top-1; keep any canonical policy-delay change as a separate candidate/control.

## Evidence balance: Direction B

### Credit

- TD-MPC and LOOP support short model lookahead **with terminal long-horizon value**, not model-only greedy selection (Hansen et al., ICML 2022: https://proceedings.mlr.press/v162/hansen22a.html; Sikchi et al., CoRL/PMLR 2022: https://proceedings.mlr.press/v164/sikchi22a.html).
- LOOP's ARC constrains planned actions toward the actor; its no-value/no-ARC/eval-only ablations expose myopia, exploitation, and train/deploy mismatch.
- Deformable-object robot studies establish learned forward-model planning precedent (Yan et al., CoRL 2020: https://proceedings.mlr.press/v155/yan21a.html; RA-L/ICRA 2020: https://arxiv.org/abs/1911.06283).
- DGCC can batch existing 32 actor actions through one response call without random search.

### Debit

- Closest positive papers usually use trajectory optimization/multiple samples and sometimes ensembles; direct evidence for one fixed-candidate response rerank is absent.
- Pure predicted one-step progress is myopic and rejected by literature/validation semantics.
- Current response is trained on executed replay actions only; candidate-rank calibration/OOD error is unmeasured.
- CPU M=1 response forward adds ~39% network-only selection time; GPU/robot latency remains unknown.
- Deployment-only use would change policy without matching actor/target training, a negative LOOP ablation pattern.

### Verdict

**CONDITIONAL.** R5 diagnostic-only on existing candidates is admissible first. Behavioral use must preserve Q as terminal/primary value, use no stochastic perturbations, lock one scale/gate at most, and pass calibration, RNG, checkpoint, and latency gates. Pure response greedy and M>1 planning are NO-GO under current evidence.

## Evidence balance: Direction C

### Credit

- Original TD3 Algorithm 1 delays actor/targets; Table 2 shows material task-dependent benefit (Fujimoto et al., ICML 2018: https://proceedings.mlr.press/v80/fujimoto18a.html).
- Replay capacity/ratio/policy age are causal, interacting variables (Fedus et al., ICML 2020: https://proceedings.mlr.press/v119/fedus20a.html).
- Few-run point estimates and best-seed claims are fragile; paired deltas, intervals, profiles, and all-run disclosure are required (Agarwal et al., NeurIPS 2021: https://proceedings.neurips.cc/paper/2021/hash/f514cec81cb148559cf475e7426eed5e-Abstract.html).
- Delayed cadence has zero inference cost and can be fixed canonically (`d=2`) without a tuning sweep.

### Debit

- Delayed-update benefits are not universal and no hybrid-contact lower-tail proof exists.
- Applying cadence only to V2 changes the baseline; applying it to all arms creates a new common baseline requiring fresh matched BB.
- 600k alters exploration/replay/update/checkpoint semantics and has weak architecture novelty.
- Exact continuation is not currently implementable.

### Verdict

**GO as isolated common hygiene/performance control; NO-GO as standalone architecture headline.** Keep 600k outside the 300k tournament.

## Directions A and E

- **A:** OFENet gives the actor action-independent predictive features and critic action-conditioned features, with mixed TD3 gains (Ota et al., ICML 2020: https://proceedings.mlr.press/v119/ota20a.html). Dreamer/SLAC feed pre-action latent state or emphasize critic latent input, not one-pass `z(s,a)` actor input. Direct action-conditioned actor concat is **NO-GO**.
- **E:** PCGrad projects conflicting gradients; GradNorm balances norms but can overweight stuck tasks (Yu et al., NeurIPS 2020: https://proceedings.neurips.cc/paper/2020/hash/3fe78a8acf5fda99de95303940a2420c-Abstract.html; Chen et al., ICML 2018: https://proceedings.mlr.press/v80/chen18a.html). Activate only after same-batch TD-vs-aux encoder gradient cosine/norm conflict repeats across at least two V1 seeds.

## Ranked constraints for fourth-round design

1. **Governance first:** create/pin V2 charter, process-level fresh-heldout firewall, paired fresh BB/V2 5–7 regime/budget, seed-5 rule, immutable attempt registry.
2. **Instrument WP-03 diagnostics on frozen development checkpoints** before choosing Q1/Qmin/temperature weighting.
3. **Keep TD3 delay isolated** from the architecture candidate; classify it as common hygiene.
4. **Selection-aligned objective is the leading simple family** because it directly fits the confirmed mismatch and adds no inference compute.
5. **Response use remains diagnostic/conditional** until candidate-response calibration and authorized GPU/robot profile pass; preserve long-horizon Q and forbid pure one-step greedy.
6. **No 150k hard kill.** Rank by preregistered late-window paired return, worst-seed guard, final distance, then success/compute/complexity.
7. **Separate RNG streams and full provenance** before any stochastic or new-module candidate.
8. **Do not call explicit actor exposure or gradient surgery a V2 candidate** without their circularity/conflict activation evidence.

## Deliverables and verification

- `WP-00_governance.md` … `WP-10_contract_tests.md`: code/governance facts, line citations, mandatory answers, design implications; WP-08 includes 120 long-format rows.
- `LIT_A_actor_exposure.md` … `LIT_E_gradient_routing.md`: method-level primary-source reviews, negative evidence, verdicts, and rubrics.
- `STEP_LOG.md`: kickoff estimate and every WP/LIT completion.
- Verification: clean clone SHA/status; CPU synthetic response/vector profile; six focused existing tests passed. GPU, training, eval, and heldout data execution were not performed.
