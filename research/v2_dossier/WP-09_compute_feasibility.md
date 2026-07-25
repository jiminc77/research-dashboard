# WP-09 — Compute and real-deployment feasibility

Audit SHA: `289c5434905257ddbdca8542a4ed41c9858e4403`

## Boundary

Kickoff prohibited every GPU operation. No CUDA context, checkpoint, simulator, training, evaluation, or heldout data was used. Only CPU synthetic float32 tensors and freshly initialized modules were profiled; results are shape/relative-cost evidence, not GPU or Franka latency.

## Module and call facts

Current deterministic selection calls encoder once, actor once over all 32 contacts, and online Q1 once over all candidates (`src/dgcc/rl/td3.py:408-454`). A response rerank would add one flattened `ResponseHead` call. `ResponseHead` has 138,776 parameters; encoder 205,696; actor 99,204; twin critic 267,778. Shapes and modules are defined at `src/dgcc/models/networks.py:122-212` and `src/dgcc/rl/sprint_arms.py:50-67`.

## CPU synthetic profile

Protocol: B=256, K=32; five warmups; 30 samples (20 for the first vectorization check); `torch.no_grad`; wall-clock around synchronous CPU calls. Workstation CPU is AMD Ryzen 9 9950X3D2.

| Operation | Shape | p50 ms | p95 ms | Calls/action |
|---|---|---:|---:|---:|
| Encoder | `(256,32,7)→(256,32,256)` | 2.14 | 2.59 | 1 |
| Actor all contacts | `(256,32,256)→(256,32,4)` | 3.49 | 3.60 | 1 |
| Q1 all contacts | 8,192 rows `[h,u]→Q1` | 4.61 | 4.83 | 1 |
| Twin Q all contacts | 8,192 rows → Q1,Q2 | 10.29 | 10.41 | 0 in deployment; 1 in actor update |
| `f_resp` all contacts | 8,192 rows → `(256,32,24)` | 3.96 | 4.06 | +1 for response rerank |

The batched response output assertion passed at `(256,32,24)`, float32 CPU. Relative to encoder+actor+Q1 module time, one response pass adds about **39% CPU network-only latency**. It therefore breaches the brief's 25% warning threshold on this CPU microbenchmark, though simulator/robot-cycle percentage may be much smaller and GPU fusion may differ.

## Candidate scaling

- Existing-contact response scoring is `M=1`: one 8,192-row call.
- Action perturbations `M∈{4,8,16}` scale response rows and memory approximately linearly to 32,768/65,536/131,072 before accounting for planner/Q rescoring. No CPU/GPU timing was run for perturbations because fixed-candidate evidence already shows >25% network-only overhead and the literature/simplicity gate disfavors random search.
- Training V1 calls response only on executed batch `B`, not `B×32` (`sprint_arms.py:169-192`), so current auxiliary training overhead is much lower than deployment reranking would be.

## OPEN GPU/robot protocol

A separately authorized profile must use frozen non-heldout batches, CUDA events or synchronized timers, warmup exclusion, p50/p95, peak allocated memory, complete `select_actions`, M scaling, simulator-step ratio, 300k wall projection, and Franka stop-and-go sensor/control budget. Current evidence cannot estimate real-robot latency.

## V2 design implication

Selection-objective alignment adds zero inference forwards and is compute-safe. Response reranking is technically vectorizable but **CONDITIONAL** on GPU/robot profiling; even M=1 is not “free.” M>1 perturbation planning is out of scope under the small-diff/25% constraint unless later GPU evidence is unexpectedly strong.
