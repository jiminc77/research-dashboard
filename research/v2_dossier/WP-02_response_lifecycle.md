# WP-02 — `f_resp` / `z_resp` lifecycle and integration seams

Audit SHA: `289c5434905257ddbdca8542a4ed41c9858e4403`

## Complete call graph

`SprintTD3Agent.__init__` constructs `ResponseHead` outside the caller's global RNG stream and adds its parameters to the critic optimizer (`src/dgcc/rl/sprint_arms.py:84-120`). During `TD3Agent.update` (`src/dgcc/rl/td3.py:386-402`), dynamic dispatch enters `SprintTD3Agent.critic_update`; for V1 with `aux_weight>0`, it forms executed `h_p(B,256)` and `u(B,4)`, computes `δm=Phi_DCT(X_after)−Phi_DCT(X_before)`, calls `f_resp(h_p,u)`, and adds MSE to Q loss (`sprint_arms.py:155-200`). No other production call exists. Save/load serialize `f_resp.state_dict` (`:237-305`).

## Yes/no lifecycle verdicts

| Claim | Verdict | Evidence |
|---|---|---|
| Called only in training | Yes | Sole behavioral call at `sprint_arms.py:191`; save/load calls are state I/O. |
| Used in target backup | No | Inherited target path `td3.py:250-294`; no response call or target response head. |
| Used in actor loss | No | Inherited actor path `td3.py:347-374`. |
| Used in exploration selection | No | Inherited `select_actions`, `td3.py:408-454`. |
| Used in deterministic/heldout eval | No | Same inherited selection; evaluator swaps agent but does not call response (`scripts/sprint_heldout_eval.py:74-102,145-150`). |
| Saved/restored | Yes | `sprint_arms.py:250-255,282-305`. Incompatible arm/schema fails closed at `:291-293`. |

## Exact tensor contract

`ResponseHead`: concat `(B,256)+(B,4)=(B,260)` → Linear/ReLU 256 → Linear/ReLU `z_resp(B,256)` → Linear `δm_hat(B,24)` (`sprint_arms.py:50-67`). Output has no final activation. It inherits input dtype/device; production tensors are float32 on `agent.device`. Ground truth `δm` is NumPy DCT difference converted to float32/device (`:70-76,183-186`).

## Vectorization test

A CPU-only synthetic test flattened `(B=256,K=32)` to 8,192 rows and made one `ResponseHead` call, then reshaped to `(256,32,24)`. Assertion passed: float32, CPU. After five warmups/20 samples, p50=3.53 ms and p95=3.96 ms on the stated workstation. A second 30-sample profile measured p50/p95=3.96/4.06 ms. This proves vectorizability, not GPU/robot latency.

## Seam ledger

| Seam | Input/output and forwards | Gradient semantics | Train effect | Deploy effect |
|---|---|---|---|---|
| R1 selection rerank | flatten `h,u_all` → one `f_resp` → `(B,32,24)` | no-grad at selection | none unless collection distribution changes later replay | direct |
| R2 target | target `h′,u′_all` → response | target/no-grad; would need a target/frozen response contract | direct backup change | none |
| R3 actor | proposal `uθ`, response, refinement | second actor stage; response differentiability must be chosen | direct | indirect/direct |
| R4 critic/residual | executed/candidate `h,u,δm_hat` → modified Q | must specify whether gradients enter response/encoder | direct | direct if scoring used |
| R5 diagnostic | same as R1, metrics only | no-grad and no RNG | none | none |

R3 is circular as a one-pass concat: `z_resp` cannot exist until provisional `u` exists. R1/R4 can consume action-conditioned response without circularity.

## Mandatory answers

- **Q3:** **Yes.** Current `f_resp` is completely absent from deployment, actor, and target paths.
- **Q4:** **Yes for tensor vectorization; overhead verdict is conditional.** `B×32` works in one call. CPU network-only cost is nontrivial (see WP-09), and GPU/robot timing remains OPEN because GPU use was forbidden.

## V2 design implication

R5 is the lowest-risk first measurement. R1 is the smallest deployment use; R4 is the smallest train+deploy response use. R3 is not a simple one-pass change. Missing/incompatible response state already fails for sprint-arm mismatches, but a new candidate needs an explicit metadata/schema version.
