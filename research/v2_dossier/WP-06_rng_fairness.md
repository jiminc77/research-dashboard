# WP-06 — RNG ledger and paired-seed fairness

Audit SHA: `289c5434905257ddbdca8542a4ed41c9858e4403`

## RNG ledger

| RNG | Initial seed | Consumers | Shared? | Saved/restored? | Candidate risk |
|---|---|---|---|---|---|
| NumPy training `self.rng` | run seed (`scripts/p1_train.py:187-191`) | ε contact draws, Gaussian Δ noise (`td3.py:435-446`), simulator step (`p1_train.py:440-442`), replay sampling (`:523-528`) | **Yes across policy/env/replay** | No | Any candidate random draw shifts all downstream streams |
| Eval RNG | seed+501 per eval (`p1_train.py:604-628`) | evaluator action callback/simulator | Separate and recreated | No need across one eval; ordinal matters | Deterministic policy ignores action RNG, simulator may consume it |
| Goal/reset RNGs | SeedSequence-derived (`episode.py:173-209,359-385`) | goal pool/reset episodes | Separate local generators | No | Candidate episode timing can alter reset counter/state |
| Torch global CPU/CUDA | `torch.manual_seed(seed)` before agent (`p1_train.py:187-199`) | base module initialization; target noise when generator omitted | Global | No | New unisolated module changes target-noise sequence |
| Target smoothing | `generator=None` in training (`p1_train.py:527`; `td3.py:250-273`) | `torch.randn` target noise | Uses global Torch RNG | No | Extra global RNG consumption breaks pairing |
| Response-head init | derived seed; `fork_rng` + explicit generator (`sprint_arms.py:112-140`) | response weights only | Intentionally isolated | Weights in checkpoint; generator state not needed later | Low for current deterministic head |
| Matched/random controls | fixed CPU generators (`sprint_arms.py:23-32`) | projection/target creation | Isolated explicit | Regenerated from saved seed | Low |
| Proposed planner RNG | absent | — | — | — | Must be separate and serialized |

## Sprint-driver construction seam

`SprintTrainingRun` first runs baseline `TrainingRun.__init__`, which constructs a baseline agent, then reseeds and replaces it with the retained sprint agent (`scripts/p1_sprint_train.py:178-197`). Reseeding plus isolated response initialization preserves retained shared-weight hashes; existing test confirms arm routing and initial-hash parity (`tests/test_sprint_driver.py:58-75`). However the discarded agent can affect Python/CUDA allocator state, and its construction is unnecessary overhead. It does not currently change declared RNG streams after reseed.

The current V1 forward and auxiliary loss are deterministic and add no random draws. Same-seed BB/V1 can therefore preserve shared initial weights and target-noise position **provided update counts/control flow remain paired**. Different actions immediately change simulator/replay data by design; pairing is common-random-number coupling, not bitwise trajectory equality.

## Verification

Focused CPU tests passed (6/6), including `aux_weight=0` baseline/RNG parity and initial hash routing. Code facts also show one NumPy generator is shared and target noise uses global Torch because `agent.update` receives no generator.

## Mandatory answer

- **Q9:** **Current deterministic V1 extra computation does not inherently break RNG pairing, but a stochastic V2 planner would.** Because action exploration, simulator, and replay share one NumPy stream, any candidate random draw contaminates all downstream randomness. Any unisolated module initialization can also shift global Torch target noise.

## V2 design implication

Use deterministic fixed-candidate operations first. Split NumPy streams by exploration, environment, replay, and evaluation; pass an explicit target-noise generator; isolate candidate initialization/planning generators; serialize them; and test RNG state deltas plus shared-backbone hashes. Same integer seed alone is not fairness evidence.
