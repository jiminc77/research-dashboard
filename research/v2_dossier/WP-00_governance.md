# WP-00 — Governance, heldout firewall, seed eligibility

Audit SHA: `289c5434905257ddbdca8542a4ed41c9858e4403`  
Frozen BB source-bundle commit: `786d651` (`outputs/models/frozen_m4_bundle/bundle_metadata.json:2-5,44`)

## Preflight and audit basis

The live checkout was dirty, so the live-tree audit stopped as required. A separate local clone of committed HEAD was then created at `/tmp/dgcc-v2audit-289c543`; its `git status --short` was empty and SHA matched. All code citations below are repository-relative committed-HEAD lines. No heldout JSON content, training/eval command, or GPU was touched. The existing frozen bundle was inspected only through metadata/manifest and committed parity proof.

## Confirmed governance facts

- **No V2 charter exists in committed HEAD or public DGCC issues.** Repository filename search found no V2 charter/config/split; GitHub issue search `repo:jiminc77/DGCC V2 charter` returned no result. The active epic is explicitly V1/BB (`DGCC#17` body), and `sprint_spec.md:14-17` defines BB/V1/matched/random only.
- The sole sprint split is `t2_sprint_heldout_v1`: canonical path and digest are hard-coded in `src/dgcc/analysis/sprint_claims.py:15-17,32-35`. Claim-before-load, exclusive `O_EXCL`, digest validation, and access logging are implemented at `:198-254`.
- That split is **not a filesystem firewall**: mode observed by `stat` is `0664`; candidate code in the same identity can open the path directly. The capability API prevents accidental evaluator misuse, not arbitrary file reads. The parity proof only establishes that the frozen training closure has no split reference (`outputs/metrics/sprint_bb_parity_proof.json:142-163`).
- No `t2_v2_confirmatory_*` split, V2 manifest, candidate denylist, or V2 access logger exists. Existing sprint heldout outcomes have already informed V2 direction, so `t2_sprint_heldout_v1` cannot be a clean V2 confirmation split.
- Public pins are V1 paper-sprint pins, not V2 registration. Relevant owner-comment body hashes (UTF-8 SHA-256): research-dashboard#36 comment `4985555011` → `ef41fe10…93bf9`; σ pin `5005338262` → `7791c5ee…72136`; AMD-3 `5029630655` → `d14cc7c6…cca02`; DGCC#22 seed-5 verdict `5029426419` → `8e4f261f…3e93`.

## Seed 5 reconstruction

| Attempt | Evidence | Classification |
|---|---|---|
| BB s5 | DGCC#22: eval2 at 50,176, rebuild chain 9 > limit 8, magnitude covenant dominant, crash checkpoint/archive preserved | Simulator/settle failure that hit the preregistered rebuild limit; technical/environment failure, not performance. No code-defect evidence. |
| BB s5r | Same seed/config and byte-identical initial hash; eval1 at 25,600, same rebuild 9 pattern | Reproduced simulator/settle + rebuild-limit failure. GPU contention was contextual but not established as root cause. |
| Disposition | DGCC#22 comment 5029426419; research-dashboard#36 AMD-3 pin | BB/V1 seed-5 pair excluded from that paper-sprint, no replacement, paired n=7. The text is scoped to BB/V1 sprint; future V2 reuse is neither prohibited nor authorized. |

## Confirmatory availability matrix

| Seed | BB valid | V1 valid now | Proposed V2 | Same code/config/regime | Heldout untouched for V2 | Technical risk |
|---:|---|---|---|---|---|---|
| 5 | **No** | Deliberately not run | None | No contract | No fresh split | High: same technical class reproduced twice |
| 6 | Yes, sprint BB completed | Not complete at audit | None | No V2 contract | No fresh split | Medium: historical recovery incidents |
| 7 | Yes, sprint BB completed after retries | Not complete at audit | None | No V2 contract | No fresh split | Medium/high: ENOSPC attempt plus rebuild-limit retry history |

There is no registered budget for fresh paired BB 5–7 under a V2-fixed regime. Reusing BB s6/s7 while freshly running only s5 would mix cohorts.

## Required decision

**BLOCKED.** Architecture exploration can proceed on development data, but a confirmatory claim cannot. Blockers are: no fresh V2 heldout/firewall, no V2 charter before first run, no valid BB seed-5 comparator, no fresh paired BB 5–7 budget, and no V2-specific retry/replacement rule.

## Mandatory answers

- **Q10:** No. A fresh V2 confirmatory heldout is not present or registered; the existing sprint split is already development-informed.
- **Q11:** No. Seeds 6/7 have historical BB runs, seed 5 has no valid BB completion, and no fresh matched V2 comparator budget is pinned.

## V2 design implication

Before candidate implementation, register candidate IDs, fresh split hash/generator SHA, actual process-level read denial, paired BB/V2 seeds and execution regime, seed-5 disposition, immutable attempts, and symmetric technical retry rules. Without this, a winning architecture cannot support the intended headline.
