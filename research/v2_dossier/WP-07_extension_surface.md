# WP-07 — Extension surface and backward compatibility

Audit SHA: `289c5434905257ddbdca8542a4ed41c9858e4403`

## Hard-coded extension points

Runtime arm sets are duplicated in:

1. `src/dgcc/rl/sprint_arms.py:18,95-99,308-331` (`SprintArm`, validation, factory);
2. `scripts/p1_sprint_train.py:147-176` (CLI choices/config);
3. `src/dgcc/analysis/sprint_claims.py:32-35,67-86` (heldout arm allowlist/checkpoint identity);
4. `scripts/sprint_stats.py:217-220` (metric-lock non-BB scan);
5. `scripts/g6b_campaign.sh:8-12` and `scripts/generate_sprint_g6b_report.py:16` (campaign/report cohorts);
6. arm-specific configs and parameterized tests (`tests/test_sprint_arms.py`, `test_sprint_driver.py`, `test_sprint_claims.py`).

A new V2 arm therefore cannot be a one-file change even if its algorithm seam is one override.

## Checkpoint compatibility

- V1 schema version is 2; checkpoint stores arm, aux weight, response state, baseline networks/optimizers (`sprint_arms.py:82,223-305`). Same-arm V1 round-trip works; focused test passed (`tests/test_sprint_ckpt.py:10-41`).
- Cross-arm/schema mismatch fails closed (`sprint_arms.py:291-293`). A V2 class should use a new candidate/schema identity rather than pretending to be V1.
- Legacy BB can load into a sprint agent while retaining freshly initialized response parameters (`:282-305`), covered by the passed legacy-load test. That behavior is unsuitable for a V2 that *requires* calibrated response at inference; such a candidate must reject missing state.
- `aux_weight=0` avoids even evaluating `f_resp` and preserves BB numerical/RNG parity (`:178-192`); focused parity test passed.

## Source-bundle versus live-main

Frozen BB bundle metadata pins source commit `786d651` and 37 training-closure blobs (`outputs/metrics/sprint_bb_parity_proof.json:1-40,121-163`). Live HEAD differs in `scripts/p1_train.py` and `src/dgcc/rl/evaluation.py`; model/TD3/replay blobs are unchanged. Source-bundle mode loads the frozen driver/package but deliberately loads the current adapter while its absolute imports resolve to frozen modules (`scripts/p1_sprint_train.py:95-107,134-144`). It is allowed only for BB (`:157-168`).

Important fairness seam: frozen `p1_train.py` predates `wall_guard_k`/raw-final support, so putting sprint eval keys into config does not make the old BB driver consume them. V1 live driver does consume them (`scripts/p1_train.py:599-619,640-648`). Heldout is later run through current evaluator, but training-time validation behavior differs across frozen BB versus live V1 whenever guard incidents occur. This is a cohort/selector caveat, not model parity.

## Minimal diff surface

| Capability | Necessary production files | Shared baseline touched? | Schema change? | Existing-run compatibility |
|---|---|---|---|---|
| Soft selection-weighted actor objective | `sprint_arms.py` override + arm CLI/allowlist/config/report plumbing | No if subclassed | New candidate metadata recommended | BB/V1 unchanged |
| Response diagnostic/rerank in selection | same, overriding `select_actions` | No | Yes: response-required candidate | Existing V1 load only for diagnostics; behavior ID must differ |
| Response-conditioned target/critic | subclass `compute_target` or critic update + plumbing | No | Yes; possibly target response state | V1 unchanged if separate arm |
| Canonical policy delay | `td3.py` + config/checkpoint/tests and all arms | **Yes** | Counter/config semantics | Changes BB/V1 common baseline |

Estimated algorithm diff is ~20–45 production lines for selection/objective seams, but arm/provenance/config/test plumbing adds roughly 5–8 files. Exact count requires a candidate design and is intentionally not fabricated.

## Mandatory answer

- **Q12:** **Selection/objective is the smallest native seam.** It reuses current `h`, actor actions, and Q map and can add zero inference forwards. Critic/selection response use is next; target use expands training contracts; actor response conditioning is largest because it needs two stages.

## V2 design implication

Implement candidates as new subclasses/IDs, not shared-baseline edits, except a separately controlled common TD3 hygiene change. Record candidate ID, parent, architecture/code/config hashes in every checkpoint/run/claim. Preserve BB/V1 evaluator semantics and make response-required loads fail closed.
