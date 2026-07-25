# WP-10 — Pre-V2 contract-test specification

Audit SHA: `289c5434905257ddbdca8542a4ed41c9858e4403`  
Scope: analysis/specification only; no candidate implementation.

## Existing coverage verified

Focused CPU command ran six existing tests and passed `6/6` in 0.90 s: aux-weight-zero parity/RNG, V1 round-trip, legacy BB load, arm initial-hash parity, actor gradient isolation, and target selection/evaluation decoupling.

| Contract area | Existing evidence | Gap |
|---|---|---|
| `aux_weight=0` BB parity | `tests/test_sprint_arms.py:82-105`; code skips response at `sprint_arms.py:178-192` | Extend to multi-update full state/trace under any new candidate |
| V1 round-trip/legacy BB | `tests/test_sprint_ckpt.py:10-41`; passed | New V2 schema and response-required fail-closed |
| Shared initial hash | `tests/test_sprint_driver.py:58-75`; passed | Remove/guard discarded baseline construction and add all candidates |
| Actor/target isolation | `tests/test_sprint_arms.py:68-80`, `test_rl_units.py:177-195`; passed focused actor test | Explicit call-count contracts for each new seam |
| Source bundle parity | `tests/test_sprint_parity.py:38-119`, `test_sprint_driver.py:77-128` | V2 must not mix live modules; frozen BB driver eval-flag divergence needs a comparator contract |
| Heldout claim mechanics | `tests/test_sprint_claims.py`, `test_t2_heldout_eval.py:69-172` | Same-identity direct file open is still possible; no fresh V2 split/process denial |
| Q operator primitives | `tests/test_rl_units.py:102-175`; focused decoupling test passed | No Q1/Qmin argmax agreement/contact-weight objective test |
| Checkpoint selector | `tests/test_sprint_select.py:28-45` | Candidate tournament late-window selector is absent |

## Required fail-closed V2 tests

| ID | Contract | Exact assertion |
|---|---|---|
| CT-01 | BB parity | Candidate disabled/weight zero matches BB actions, Q, target, optimizer state, counters, and RNG at locked tolerance for multiple updates. |
| CT-02 | V1 immutable round-trip | Existing V1 checkpoint load→save→load preserves tensors, optimizers, metadata, update count, deterministic actions, and zero deploy response calls. |
| CT-03 | Shared-backbone hash | BB/V1/V2 shared tensor bytes match under isolated construction generators. |
| CT-04 | RNG purity | Snapshot Python/NumPy/Torch CPU/all CUDA/named generators; deterministic candidate forward changes none. |
| CT-05 | RNG partition | Planner/contact/env/replay/eval/target-noise generators are distinct; injected draw in one stream leaves all others unchanged. |
| CT-06 | Fresh split OS denial | Candidate process `open/stat/read` on V2 confirmatory path fails and external logger records attempt. |
| CT-07 | Evaluator denylist | Candidate/train process cannot import/exec evaluator or obtain a split capability. |
| CT-08 | 300k semantic golden | Assert ε values/horizon, replay capacity/overwrite, 290,816 update counts, 12 eval ordinals, and checkpoint thresholds. |
| CT-09 | Provenance metadata | Checkpoint/run/claim require candidate ID, parent ID, code SHA, config SHA, architecture hash, source-bundle SHA. |
| CT-10 | Technical-failure registry | Inject simulator/nonfinite/checkpoint failures; append-only registry records every attempt independently of performance. |
| CT-11 | All-attempt immutability | Successful, failed, retried, and superseded IDs cannot be deleted or overwritten. |
| CT-12 | Evaluator parity | BB/V1 synthetic fixture matches reference reward, success, timeout bootstrap, lift threshold, and summary metrics. |
| CT-13 | Response state fail-closed | Candidate requiring response rejects missing, V1-only, wrong-arm, or wrong-version state before selection. |
| CT-14 | Seam call counts | R1: selection exactly one response call, actor/target zero; R2/R3/R4 analogous explicit expected counts. |
| CT-15 | Target completeness | Any response-conditioned backup requires declared target/frozen response version; omission raises before update. |
| CT-16 | Source isolation | Every imported file hash belongs to declared bundle/commit; live-main mixing aborts. |
| CT-17 | Exact resume trace | Uninterrupted vs split/resumed CPU run matches replay indices, noise, actions, losses, counters, eval ordinals, and checkpoint hashes after boundary. |
| CT-18 | Contact operator | Hand-built Q1/Q2 maps prove actor weights, target selector/evaluator, deployment selector, ties, and stop-gradient weighting. |
| CT-19 | Lift boundary | Values below/at/above 0.5 satisfy the exact `>0.5` execution rule while training relaxation remains differentiable. |
| CT-20 | Compute cap | Forward counters and preregistered synchronized profile reject undeclared calls or >25% cap. |

## Acceptance gate

CT-01–16 and CT-18–20 are mandatory before discovery; CT-17 is additionally mandatory for any continuation claim. CT-06/07/10/11 are protocol blockers and cannot be waived as flaky tests. Fixtures must be synthetic/frozen non-heldout, declare shape/dtype/device/seed/tolerance, snapshot state, and never silently fall back.

## V2 design implication

Current tests are strong for V1 parity and one-shot heldout mechanics but insufficient for a new candidate identity, process-level heldout firewall, exact resume, immutable attempt registry, response call routing, and selection-aligned objective. Freeze these tests before candidate code.
