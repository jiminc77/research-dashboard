# WP-01 — Actor input, gradient path, contact/action semantics

Audit SHA: `289c5434905257ddbdca8542a4ed41c9858e4403`

## Confirmed code facts

- Node input is `(B,32,7)=[x_i(3),σ_i(1),g_i−x_i(3)]` (`src/dgcc/models/networks.py:40-46,85-119`). Encoder output is the full per-node `h∈R^(B×32×256)` (`:122-148`).
- Actor receives the **entire** `h`, not a preselected `h_p`; its shared pointwise MLP maps each node independently to four outputs (`:186-212`). Cross-node information is already present through encoder global max-pool broadcast (`:143-147`), but the actor MLP itself has no inter-node operation.
- Actor emits `Δ=tanh(raw[:3])·0.15` and a sigmoid lift relaxation; executed lift is binarized as `high iff value>0.5` (`networks.py:199-212`; `src/dgcc/rl/td3.py:440-447`).
- Actor update computes online encoder features under `torch.no_grad`, evaluates both critics for all 32 actor actions, and minimizes `-mean(Qmin)` (`td3.py:347-374`). Encoder is detached; actor receives gradients only through `u`. Existing unit test confirms this (`tests/test_rl_units.py:177-195`).
- V1 auxiliary loss backpropagates jointly through encoder, critic, and `f_resp`, while actor parameters are absent (`src/dgcc/rl/sprint_arms.py:155-200`). Thus future actor inputs change indirectly as the shared encoder changes, even though actor steps never receive auxiliary gradients.

## Execution-mode tensor/gradient table

| Mode | Encoder input/output | Actor input/output | Critic/contact/Q | Encoder grad | Actor grad | `f_resp` |
|---|---|---|---|---|---|---|
| Replay critic update | before `(B,32,7)` → online `h(B,32,256)` | none online; target actor participates only in no-grad backup | replay `p`, executed `u(B,4)` → online Q1,Q2 | Yes, TD + V1 aux | No | **Yes**, once on executed `(h_p,u)` for V1 (`sprint_arms.py:169-192`) |
| Actor update | before → online full `h`, inside no-grad | full `h` → `u_all(B,32,4)` | Q1/Q2 over all contacts; `Qmin` uniform mean | No | Yes | No (`td3.py:347-374`) |
| TD target | next → target `h′` | target full `h′` → `u′_all` | target Q1 argmax contact; selected target Qmin after smoothing | No (`@no_grad`) | No | No (`td3.py:250-294`) |
| Exploration rollout | current → online full `h` | full `h` → all actions | online Q1 greedy contact, then ε replacement; Gaussian Δ noise | No | No | No (`td3.py:408-454`) |
| Deterministic eval | same | same | online Q1 argmax; no action noise | No | No | No |
| Heldout eval | inherited deterministic selection | inherited | online Q1 argmax; heldout driver only swaps/loads agent (`scripts/sprint_heldout_eval.py:74-102,145-150`) | No | No | No |

## Operator facts

- Actor objective: `L_actor=−E[(1/32)Σ_p min(Q1,Q2)(h_p,π(h_p))]` (`td3.py:358-365`).
- Deployment: `p=argmax_p Q1(h_p,π(h_p))` (`:426-447`).
- Target selection: `argmax target-Q1`; selected action is smoothed then evaluated by target `min(Q1,Q2)` (`:258-293`).
- Contact is a discrete index and receives no actor gradient. Lift is differentiable in actor/critic training but thresholded at execution.

## Mandatory answers

- **Q1:** **Yes.** V1 actor already receives auxiliary information indirectly because auxiliary loss updates the shared encoder that produces the actor's future `h`; it does not receive `z_resp`/predicted `δm` explicitly.
- **Q2:** **No for action-conditioned `z_resp(h,u)` in one pass.** Actor must first produce `u`. A direct explicit path requires proposal→response→refinement, or response use on critic/selection after proposal.

## V2 design implication

“Actor does not see physics” is false. The real choices are selection/objective alignment, critic-side response use, or a two-pass actor. Any actor-input proposal must prove new information beyond the already response-shaped `h` and account for action circularity.
