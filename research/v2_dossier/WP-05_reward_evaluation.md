# WP-05 — Reward, success, termination, evaluation, checkpoint selection

Audit SHA: `289c5434905257ddbdca8542a4ed41c9858e4403`

## Exact semantics

- Distance and success share `correspondence_l2` through one route (`src/dgcc/tasks/reward.py:19-49`). Normalized success threshold is `d<0.05`; raw threshold is `D_raw<0.05·L`. Current rope length is 1 m, so raw threshold is 0.05 m.
- Reward is `r_t=10(d_t−d_{t+1})−0.1+5·1[success]` under locked sprint constants (`reward.py:52-70`; `configs/sprint_t2_v1.yaml:28-31`).
- Horizon is 10, with early success termination; timeout sets both `done` and `truncated` (`src/dgcc/tasks/episode.py:1-18,111-118,291-329`). TD target masks only `done & ~truncated`, so timeouts bootstrap (`src/dgcc/rl/td3.py:135-156,278-293`).
- Evaluator accumulates both undiscounted and discounted returns, but `mean_return` is the undiscounted sum (`src/dgcc/rl/evaluation.py:106-150,176-200,233-269`). Training replay logs the same step reward but does not aggregate episode return.
- `final_d` is runner current distance; `d_at_done` uses terminal snapshot with fallback; `min_d` is minimum active-step distance (`evaluation.py:152-200`). Summary means are direct episode means (`:233-269`).

## Checkpoint selection

- During training, `best.pt` changes only when success is strictly greater; success ties retain the **earlier** incumbent and return is ignored (`scripts/p1_train.py:698-703`).
- Sprint heldout selection reevaluates every checkpoint on val-50 and uses lexicographic max `(success, return, -transitions)`, i.e. success first, then return, then earlier checkpoint (`scripts/sprint_select_ckpt.py:32-36,76-104`). This can differ from `best.pt` because ties use return and evaluations are rerun under guard-on protocol.
- Binary success is the primary selector; continuous return is only a tie-break. That is vulnerable to 100-episode discreteness and checkpoint lottery.

## Retrospective validation analysis

Computed from the final **development validation** episodes of completed V1 seeds 0–2 (300 episodes; no heldout content):

- Pearson correlation `return` vs `final_d`: **−0.562**.
- Mean return: successful **5.854**, unsuccessful **0.354**. Six unsuccessful episodes still had return >2; 154/237 unsuccessful episodes had positive return. Return and success are related but not interchangeable.
- The fixed +5 bonus is approximately **85.4%** of aggregate return among successful episodes (median `5/|return|` 86.4%), so success bonus dominates successful-return scale.
- First-step progress correlation with return: **0.157**; best/min-distance progress correlation: **0.280**. Early shaping progress is a weak predictor of final return.

| Goal family | n | mean return | success | mean final d | mean initial→final progress |
|---|---:|---:|---:|---:|---:|
| L | 42 | 1.360 | .119 | .0911 | .1734 |
| S | 84 | 1.745 | .274 | .0750 | .1270 |
| smooth-random | 66 | 2.211 | .379 | .0649 | .1135 |
| U | 48 | 1.397 | .042 | .0950 | .2176 |
| zigzag | 60 | .969 | .200 | .0884 | .0874 |

U has the greatest progress but lowest success, illustrating why shaping improvement alone is not the winner endpoint.

## Metric admissibility

Use preregistered late-window paired return and final distance for discovery, with success secondary and all per-seed curves visible. Do not use best single checkpoint, existing heldout results, post-hoc family subsets, or predictor/calibration loss as a V2 winner metric. Confirmatory endpoint must remain locked and paired.

## V2 design implication

A response score derived from predicted distance cannot be assumed to optimize success or long-horizon return. Any selection residual must preserve Q and be checked separately for return, binary success, final distance, and family-specific regressions.
