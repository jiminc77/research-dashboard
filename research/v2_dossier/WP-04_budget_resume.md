# WP-04 — 300k→600k budget, replay, resume

Audit SHA: `289c5434905257ddbdca8542a4ed41c9858e4403`

## Exact code semantics

- `eps_p_fraction=.3`; horizon is `int(total_budget*.3)` (`src/dgcc/rl/td3.py:58-76,159-165`). Thus contact ε decays over **90,000** transitions at 300k and **180,000** at 600k.
- Replay is a fixed ring with capacity 500,000 (`td3.py:65-68`; `src/dgcc/rl/replay.py:69-96,133-154`). A fresh 600k run overwrites about **100k earliest transitions**; with 1,024 batching the loop ends at 600,064, so 100,064 positions have been overwritten.
- Collection calls `train_updates(count)`; after replay reaches warmup 10,240, it executes `count×UTD` updates (`scripts/p1_train.py:422-535,747-785`; sprint config `configs/sprint_t2_v1.yaml:17-27`). With 1,024 batches, 300k ends at 300,032 and observed updates are 290,816 (`outputs/metrics/p1_run_sprint_t2_v1_s0.json:97-100`). Fresh 600k projects to 600,064 transitions and 590,848 updates.
- Because `TD3Agent.update` updates critic, actor, and targets together, all three update counts currently equal 290,816 at 300k and would equal 590,848 at fresh 600k (`td3.py:386-402`).
- Evaluation threshold is every 25k; batching yields 12 evals at 300k and 24 at 600k. Every successful eval saves a checkpoint and then restarts training episodes (`p1_train.py:640-708,759-797`).

## Comparison table

| Property | 300k fresh | 600k fresh | Exact 300k→600k continuation |
|---|---:|---:|---|
| ε decay endpoint | 90k | 180k | Must retain 90k if “extra budget only”; current total-based API would stretch if restarted with 600k |
| Critic/actor/target updates | 290,816 each | 590,848 each | Additional 300,032 if state/round boundary exact |
| Replay age/overwrite | no capacity overwrite | 100,064 early rows overwritten | Depends on serialized ring; must continue existing cursor |
| Eval/checkpoints | 12 | 24 | 12 more with preserved ordinal |
| Optimizers/networks | fresh | fresh | Agent checkpoint preserves these |
| Replay/RNG/env/driver state | fresh | fresh | **Not serialized** |

## Checkpoint and resume gap

Agent checkpoint stores six network states, two optimizer states, config/reward metadata, and `update_count` (`td3.py:492-535`; V1 adds `f_resp` and arm metadata at `sprint_arms.py:237-305`). It does **not** store replay arrays/cursor/size, NumPy generator, Torch CPU/CUDA RNG, environment/episode state, transitions, episode index, eval ordinal/history, best-success/selected checkpoint, diagnostics history, or target-noise generator state. The driver has no `--resume`/checkpoint CLI (`p1_train.py:811-818`). `--total-override` changes only total budget at construction (`:161-203`).

## Mandatory answers

- **Q7:** **No.** Fresh 600k and 300k continuation are different experiments under current schedules, replay ages, initialization, and checkpoint opportunities.
- **Q8:** **No.** Exact continuation is impossible under the current serialization/driver contract.

## Minimum continuation contract

Serialize agent/optimizers; complete replay and cursor; transitions/update/episode/eval counters; every NumPy and Torch RNG; environment and active episodes or an explicitly locked boundary restart; scheduler state; selector/best state; diagnostics and provenance. Verify uninterrupted versus split CPU traces from the boundary.

## V2 design implication

Exclude 600k from the 300k architecture tournament. Any post-lock 600k study must match BB/V1/V2 transitions, updates, exploration horizon, replay capacity, eval opportunities, and wall time, and distinguish fresh from exact continuation.
