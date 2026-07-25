# WP-03 — Hybrid objective and TD3 conformity

Audit SHA: `289c5434905257ddbdca8542a4ed41c9858e4403`

## Three current operators

1. **Actor:** `L_actor=−E[(1/K)Σ_p Q_min(h_p,π(h_p))]`, `K=32` (`src/dgcc/rl/td3.py:347-365`).
2. **Deployment:** `p_deploy=argmax_p Q1(h_p,π(h_p))` (`:408-447`).
3. **Target:** target actor proposes all contacts; `p_target=argmax_p Q1_target`; at that contact, smoothed action is evaluated with `min(Q1_target,Q2_target)` (`:250-293`; selector primitive `:87-101`).

Therefore actor training is **not selection-aligned** with deployment: it uniformly improves all branches under Qmin, while deployment takes a hard Q1 maximum. Target selection and deployment share Q1 argmax, but target evaluation switches to Qmin.

## Update cadence

`TD3Agent.update` performs critic update, actor update, target soft update, and increments one counter on **every** update (`td3.py:386-402`). There is no policy-delay field or modulo condition.

## TD3 conformity table

| Component | Original TD3 | DGCC current | Likely material? | Evidence |
|---|---|---|---|---|
| Twin critic | Two critics | Yes | Beneficial baseline component | `networks.py:174-183`; `td3.py:320-323` |
| Target policy smoothing | Gaussian, clipped | σ=.05, clip=.1 | Present | `td3.py:270-277`; config `:71-72` |
| Delayed actor update | Every `d=2` critic updates conventionally | Every update | **Yes, credible stability defect** | `td3.py:386-402`; TD3 Algorithm 1/Table 2 |
| Delayed target update | With delayed actor | Every update | **Yes** | same |
| Actor Q operator | Q1 at actor action in canonical continuous TD3 | Uniform all-contact Qmin | Material hybrid-specific deviation | `td3.py:358-365` |
| Hybrid contact selection | N/A | hard online/target Q1 argmax | Material max/overestimation seam | `td3.py:264-277,430-431` |

Primary source: Fujimoto et al., ICML 2018, Algorithm 1 and Table 2, https://proceedings.mlr.press/v80/fujimoto18a.html. Delay is a baseline correction/stability control, not V2 novelty.

## Existing evidence and missing instrumentation

Current diagnostics log Q candidate entropy, Q1 std, gradient norms, and overestimation gap, but do not record Q1-vs-Qmin argmax agreement, contact margins, selected-contact disagreement, per-contact actor gradients, contact churn, or lift mass near 0.5. The requested frozen-checkpoint instrumentation does not exist and was not implemented under this commission.

Required offline script: on development/frozen batches only, compute Q1/Qmin argmax agreement, top-1/2 margin, rank entropy/contact histogram, selected Q1−Q2, per-contact actor-gradient norm, selected-versus-uniform-loss overlap, goal-family concentration, pre/post acceleration margin, post-update contact churn, and lift `[0.45,0.55]` mass. It must snapshot RNG/model state and make no optimizer step.

## Mandatory answers

- **Q5:** **No.** Actor objective and deployed contact selector are not aligned.
- **Q6:** **Yes.** Canonical delayed actor and target updates are absent.

## V2 design implication

The smallest causally matched candidate is a soft selection-weighted actor objective (and possibly aligned target expectation), not a new response module. Separately test canonical `d=2` cadence as common hygiene. Do not combine both changes under one candidate ID: otherwise architecture effect and baseline correction are inseparable.
