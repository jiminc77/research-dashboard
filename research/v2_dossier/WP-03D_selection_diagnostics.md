# WP-03D — Frozen-checkpoint selection diagnostics

## Executive verdict

1. **Weighting operator: Qmin.** Deployment-relevant contact selection is the conservative `argmax Qmin`, while Q1/Qmin contact agreement is only **0.393–0.643**. At the Q1-selected contact, `Q1−Q2` is positive in **65.7–78.7%** of states (median **0.00756–0.02474**). Q1 weighting therefore preserves the optimistic selector mismatch that candidate D is meant to remove. Use **stop-gradient Qmin scores to form weights**, and optimize the weighted Qmin actor objective.
2. **Initial softmax temperature: 0.01–0.025 Q units, default 0.01.** At `τ=0.01`, Qmin weighting has 8.1–15.7 effective contacts, top weight 0.230–0.440, and cosine 0.951–1.000 to the hard-Qmin gradient. At `τ=0.025`, it already spreads over 19.7–26.6 contacts. `τ≥0.05` is nearly uniform (26.8–32.0 effective contacts) and is not a useful selection-aligned starting point.
3. **Basin-entry claim: not supported.** Across V1 seeds, pre→post Q1/Qmin agreement changes are mixed (`−0.027`, `+0.093`, `−0.023`; mean `+0.014`). Median margins are essentially flat, and selected `Q1−Q2` changes are mixed. Selection mismatch is real, but this frozen observational sample does **not** show that it consistently prevents basin entry.
4. **Contact collapse: no global collapse.** Every checkpoint uses all 32 contacts; Q1 selection normalized entropy is 0.872–0.958 and maximum share is 0.080–0.190. Some family-local concentration reaches 0.32, but it is not persistent. The dominant issue is high contact-identity churn (Q1 0.710–0.893 over adjacent archived intervals) with low histogram JS divergence (0.024–0.060), i.e. unstable ranking rather than spatial collapse.
5. **Lift-threshold mismatch: real but conditional.** V1 and BB-s2 put only 0–0.61% of all candidate lifts in `[0.45,0.55]`; BB-s6 puts **11.18→14.14%** there, and **12.33→15.00%** among Q1-selected contacts. The strict `lift > 0.5` versus sigmoid-optimized lift issue is material for the lower BB seed, not a universal V1 mechanism.

## Scope, safety, and sample

- DGCC committed source: `289c5434905257ddbdca8542a4ed41c9858e4403`.
- Device: CPU only; `CUDA_VISIBLE_DEVICES=""` is set before importing Torch.
- No optimizer object was constructed, no `.step()` or `.backward()` was called, and `torch.autograd.grad` did not populate actor `.grad` slots.
- Encoder/actor/critic state hashes and process-local Torch/NumPy RNG hashes were snapshotted and verified equal before/after every checkpoint diagnostic.
- The DGCC repository was read only. No source/config file was modified.
- No heldout, M4-heldout, patching-probe path, or split payload was opened. Explicitly observed development-validation goal IDs were independently reconstructed from the committed T2 generator seed/index.
- Sample: **300 states from 300 development-validation episodes**, one deterministic trajectory state per episode, from V1 s0/s1/s2 development raw-evaluation artifacts (100 episodes each). Family counts: `l=42`, `s=84`, `smooth_random=66`, `u=48`, `zigzag=60`.
- Checkpoints: V1 s0/s1/s2 pre/post plus BB s2 upper and BB s6 lower early/late. Churn compares the same 300 states between a checkpoint and its immediately preceding archived checkpoint (24,576 or 25,600 transitions apart). **No synthetic update was executed.**
- Confidence intervals below are Wilson 95% intervals for proportions. Distribution cells use `p05/p50/p95`.
- Full arrays, contact histograms, confidence intervals, quantiles, source hashes, and checkpoint paths are in [`WP-03D_selection_diagnostics.json`](./WP-03D_selection_diagnostics.json).

## 1–3. Q1/Qmin selector agreement, margins, rank, and contact distribution

`Qmin rank` is the rank under Qmin of the Q1-selected contact. Its cell is `mean / top-4 rate / normalized rank-histogram entropy`. `Q1 contact` is `normalized entropy / top contact:share / active contacts`.

| Arm/seed | Phase | Step | Q1/Qmin agreement [95% CI] | Q1 margin p05/p50/p95 | Qmin margin p05/p50/p95 | Qmin rank mean/top4/H | Q1 contact H/top:share/active |
|---|---:|---:|---:|---:|---:|---:|---:|
| V1 s0 | pre | 125,952 | 0.563 [0.507, 0.618] | .00045/.00521/.03188 | .00035/.00482/.03327 | 3.95/.747/.533 | .940/0:.110/32 |
| V1 s0 | post | 225,280 | 0.537 [0.480, 0.592] | .00040/.00514/.03721 | .00042/.00501/.03760 | 3.18/.823/.505 | .934/8:.080/32 |
| V1 s1 | pre | 250,880 | 0.500 [0.444, 0.556] | .00064/.00656/.02856 | .00054/.00601/.02460 | 4.39/.737/.587 | .872/31:.143/32 |
| V1 s1 | post | 300,032 | 0.593 [0.537, 0.647] | .00056/.00651/.05262 | .00045/.00638/.05223 | 3.66/.800/.491 | .891/31:.170/32 |
| V1 s2 | pre | 125,952 | 0.490 [0.434, 0.546] | .00034/.00383/.01546 | .00020/.00324/.01451 | 3.85/.770/.566 | .940/31:.113/32 |
| V1 s2 | post | 225,280 | 0.467 [0.411, 0.523] | .00022/.00398/.08677 | .00016/.00343/.06663 | 4.10/.770/.581 | .951/31:.113/32 |
| BB s2 | early | 125,952 | 0.643 [0.588, 0.695] | .00050/.00447/.03571 | .00045/.00397/.03764 | 2.97/.840/.440 | .931/31:.107/32 |
| BB s2 | late | 300,032 | 0.590 [0.534, 0.644] | .00041/.00430/.28540 | .00024/.00387/.21255 | 2.75/.863/.446 | .958/0:.083/32 |
| BB s6 | early | 125,952 | 0.527 [0.470, 0.582] | .00044/.00577/.03878 | .00040/.00492/.04036 | 4.90/.713/.596 | .893/0:.190/32 |
| BB s6 | late | 300,032 | 0.393 [0.340, 0.450] | .00038/.00522/.04919 | .00037/.00440/.03935 | 5.91/.637/.689 | .944/0:.083/32 |

Interpretation:

- Agreement is far from interchangeable-selector territory at every checkpoint. BB s6 late is the strongest counterexample: only 39.3% agreement and the Q1-selected contact has mean Qmin rank 5.91.
- Median top-two margins are only 0.00324–0.00656. Contact identity is therefore sensitive to small critic changes even though aggregate spatial usage remains broad.
- Qmin contact histograms are similarly broad: normalized entropy 0.885–0.966, max share 0.070–0.213, and all 32 contacts active (full counts in JSON).

## 4–6, 9–10. Critic disagreement, gradient budget/overlap, churn, and lift

`Q1−Q2` is `p50 / positive rate`. Gradient budget is `per-contact norm CV / largest budget share / cosine with Q1-selection histogram`. Churn is `Q1 rate / Qmin rate / Q1 histogram JS`. Lift mass is `all candidates / Q1-selected` in `[0.45,0.55]`.

| Arm/seed | Phase | Q1−Q2 p50/positive | Gradient budget CV/top/cos(hist) | hard-Q1 vs uniform cos | hard-Qmin vs uniform cos | hard-Q1 vs hard-Qmin cos | Incoming churn Q1/Qmin/JS | Lift mass all/selected |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| V1 s0 | pre | .00965/.677 | .469/.064/.772 | .924 | .875 | .914 | .873/.860/.041 | .0011/.0033 |
| V1 s0 | post | .01118/.703 | .451/.089/.772 | .364 | .434 | .932 | .783/.767/.034 | .0013/.0000 |
| V1 s1 | pre | .01824/.700 | .546/.076/.572 | .816 | .907 | .936 | .773/.777/.042 | .0033/.0067 |
| V1 s1 | post | .01076/.657 | .388/.059/.722 | .976 | .959 | .990 | .710/.753/.035 | .0061/.0033 |
| V1 s2 | pre | .01174/.760 | .389/.063/.842 | .837 | .925 | .962 | .893/.873/.039 | .0000/.0000 |
| V1 s2 | post | .01491/.757 | .494/.066/.803 | .162 | .012 | .966 | .797/.767/.036 | .0000/.0000 |
| BB s2 | early | .00756/.677 | .401/.058/.741 | .713 | .472 | .758 | .817/.840/.033 | .0000/.0000 |
| BB s2 | late | .01036/.717 | .517/.074/.765 | .454 | .262 | .958 | .797/.763/.024 | .0000/.0000 |
| BB s6 | early | .01308/.697 | .390/.064/.637 | .980 | .960 | .955 | .887/.897/.060 | .1118/.1233 |
| BB s6 | late | .02474/.787 | .245/.049/.820 | .642 | .492 | .806 | .840/.873/.033 | .1414/.1500 |

Additional distribution evidence:

- Selected `Q1−Q2` p05/p50/p95 spans `−.0522/.0076/.0469` at the narrow end to `−.0202/.0149/.1292` and `−.0263/.0104/.2404` in high-tail checkpoints. The positive median and positive-rate majority are consistent with Q1 optimism at its own selected contact.
- Per-contact gradient norm CV is 0.245–0.546; the largest contact consumes only 4.9–8.9% of the summed per-contact norm budget. Uniform optimization is not spending all gradient budget on one contact.
- Hard-Q1 and hard-Qmin actor gradients remain broadly aligned (cosine 0.758–0.990), but either selected gradient can diverge sharply from the current uniform objective (minimum cosines 0.162 for hard-Q1 and 0.012 for hard-Qmin). Candidate D changes the update direction materially in some frozen states.
- High individual churn with low histogram JS means contact labels exchange rank while the spatial distribution remains broad. This supports soft selection over hard argmax, but does not support a contact-collapse diagnosis.

## 6. Soft weighting temperature sweep

Each cell is `effective contacts / mean top weight / cosine to hard-Q1 / cosine to hard-Qmin`. Scores are detached before softmax. The optimized value is weighted Qmin in every case.

| Arm/seed | Phase | Q1 τ=.01 | Qmin τ=.01 | Q1 τ=.025 | Qmin τ=.025 | Q1 τ=.05 | Qmin τ=.05 |
|---|---:|---:|---:|---:|---:|---:|---:|
| V1 s0 | pre | 12.2/.359/.989/.926 | 12.7/.340/.946/.981 | 23.6/.156/.981/.931 | 23.6/.155/.950/.957 | 28.5/.090/.970/.932 | 28.5/.089/.945/.940 |
| V1 s0 | post | 10.0/.388/.978/.955 | 10.2/.381/.932/.992 | 21.2/.184/.962/.953 | 21.4/.181/.947/.987 | 27.1/.112/.955/.954 | 27.2/.110/.949/.981 |
| V1 s1 | pre | 7.2/.448/.972/.940 | 8.4/.400/.863/.951 | 19.0/.190/.945/.970 | 20.3/.165/.849/.935 | 27.0/.097/.886/.950 | 27.6/.087/.833/.922 |
| V1 s1 | post | 7.5/.470/.998/.993 | 8.1/.440/.992/.997 | 19.0/.224/.992/.991 | 19.7/.206/.986/.990 | 26.4/.120/.982/.983 | 26.8/.111/.976/.980 |
| V1 s2 | pre | 14.6/.260/.985/.990 | 15.7/.230/.945/.994 | 25.8/.110/.943/.991 | 26.6/.095/.914/.982 | 29.8/.068/.909/.980 | 30.2/.061/.896/.975 |
| V1 s2 | post | 12.6/.348/.998/.970 | 13.6/.321/.959/.998 | 23.1/.181/.993/.974 | 23.8/.164/.938/.990 | 27.7/.120/.983/.973 | 28.3/.107/.910/.975 |
| BB s2 | early | 12.8/.345/.987/.756 | 12.9/.335/.721/.988 | 24.0/.159/.972/.741 | 24.2/.153/.698/.982 | 28.6/.098/.963/.729 | 28.7/.095/.703/.980 |
| BB s2 | late | 12.0/.376/1.000/.959 | 13.0/.350/.957/1.000 | 22.7/.203/.999/.963 | 23.4/.186/.958/.999 | 27.2/.142/.997/.967 | 27.6/.130/.957/.997 |
| BB s6 | early | 10.9/.381/.995/.953 | 11.3/.372/.982/.981 | 22.4/.165/.989/.959 | 22.7/.160/.970/.981 | 28.3/.086/.986/.961 | 28.4/.084/.975/.975 |
| BB s6 | late | 11.2/.384/.965/.739 | 11.9/.353/.891/.951 | 22.0/.187/.917/.728 | 23.0/.165/.911/.887 | 27.4/.110/.897/.752 | 28.0/.098/.889/.808 |

Across all ten checkpoints:

| τ | Q1 effective/top/cos hard-Q1/cos hard-Qmin | Qmin effective/top/cos hard-Q1/cos hard-Qmin | Decision |
|---:|---:|---:|---|
| .01 | 11.1/.376/.987/.918 | 11.8/.352/.919/.983 | Best measured starting point; Qmin tracks deployed selector |
| .025 | 22.3/.176/.969/.920 | 22.9/.163/.912/.969 | Upper end of initial range; already diffuse |
| .05 | 27.8/.104/.953/.918 | 28.1/.097/.903/.953 | Too close to uniform |
| .10 | 30.2/.072/.939/.916 | 30.4/.068/.895/.940 | Reject as initial value |
| .25–2.0 | 31.2–31.9/.052–.034 | 31.3–31.9/.051–.034 | Effectively uniform; reject |

**Recommendation:** implement detached Qmin softmax weights and initially test `τ ∈ {0.01, 0.025}`, with `τ=0.01` as the single default and hard-Qmin as a diagnostic reference. Do not make temperature trainable in the first arm. Log effective-contact count and top weight; a practical guard is effective contacts roughly 8–20. This range is diagnostic, not a performance claim.

## 7. Goal-family concentration

Cells are `Q1/Qmin agreement / Q1 selection entropy / Q1 max share`. Family sizes are fixed at `l=42`, `s=84`, `smooth_random=66`, `u=48`, `zigzag=60`.

| Arm/seed | Phase | l | s | smooth_random | u | zigzag |
|---|---:|---:|---:|---:|---:|---:|
| V1 s0 | pre | .62/.78/.14 | .58/.83/.23 | .67/.86/.15 | .50/.90/.08 | .43/.91/.08 |
| V1 s0 | post | .48/.74/.19 | .52/.89/.11 | .45/.89/.12 | .75/.81/.17 | .52/.92/.08 |
| V1 s1 | pre | .43/.77/.21 | .54/.82/.18 | .47/.77/.17 | .56/.73/.19 | .48/.83/.15 |
| V1 s1 | post | .60/.80/.19 | .55/.82/.20 | .70/.70/.21 | .50/.80/.15 | .62/.86/.13 |
| V1 s2 | pre | .55/.81/.17 | .46/.84/.15 | .52/.88/.17 | .50/.80/.15 | .45/.91/.10 |
| V1 s2 | post | .50/.84/.14 | .51/.90/.11 | .53/.92/.09 | .35/.83/.15 | .40/.87/.12 |
| BB s2 | early | .69/.73/.29 | .74/.91/.10 | .67/.86/.12 | .58/.85/.12 | .50/.89/.08 |
| BB s2 | late | .38/.78/.14 | .63/.92/.08 | .65/.85/.11 | .60/.81/.15 | .60/.88/.12 |
| BB s6 | early | .52/.80/.12 | .54/.80/.25 | .58/.73/.32 | .44/.81/.12 | .53/.82/.12 |
| BB s6 | late | .40/.86/.12 | .32/.87/.13 | .44/.86/.15 | .44/.80/.15 | .40/.89/.12 |

No family shows persistent single-contact capture. The largest family-local share, 0.32 for BB-s6 early `smooth_random`, falls to 0.15 late. Agreement weakness is also not V1-specific: BB family agreement ranges from 0.32 to 0.74.

## 8. Acceleration/basin-entry contrast

| Arm/seed | Contrast | Δ agreement | Δ Q1 margin p50 | Δ Qmin margin p50 | Δ selected Q1−Q2 p50 | Δ selection entropy | Δ max share | Δ hard-Q1/uniform cos |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| V1 s0 | pre→post | −.027 | −.000071 | +.000193 | +.001531 | −.0059 | −.030 | −.560 |
| V1 s1 | pre→post | +.093 | −.000042 | +.000374 | −.007473 | +.0194 | +.027 | +.160 |
| V1 s2 | pre→post | −.023 | +.000150 | +.000192 | +.003171 | +.0109 | .000 | −.675 |
| BB s2 | early→late | −.053 | −.000169 | −.000101 | +.002807 | +.0268 | −.023 | −.259 |
| BB s6 | early→late | −.133 | −.000548 | −.000521 | +.011661 | +.0508 | −.107 | −.338 |

V1 mean agreement is 0.518 pre and 0.532 post. Two seeds worsen and one improves; Wilson intervals overlap within each pair. Margins do not open consistently after acceleration, and the Q1 optimism gap does not move in one direction. BB late checkpoints do show lower agreement and larger optimism gaps, most strongly in lower BB-s6, which establishes that the mismatch can intensify with training but not that it blocks V1 basin entry. A causal answer requires the separately governed Qmin-weighted intervention; it cannot be inferred from these frozen snapshots.

## Parameter and RNG immutability proof

All ten `state before == state after`; all ten `RNG before == RNG after`. Each state hash covers sorted encoder, actor, and critic state-dict tensor names, dtypes, shapes, and bytes. Full checkpoint-file SHA-256 is included to bind the state hash to the archived input.

| Checkpoint | File SHA-256 | Model state before | Model state after | RNG before/after |
|---|---|---|---|---|
| V1 s0 pre @125952 | `92fbe745306b05afe94743272415af46d4e557d8dd7a524f4b0c5cdb68b90b7a` | `841aaa6c49fa4c1673a877ac630552d2e111e4a41064d08ebee5f8b2618aab04` | `841aaa6c49fa4c1673a877ac630552d2e111e4a41064d08ebee5f8b2618aab04` | `98bcfa4955f28419da43f6faa4b70b5a937c6e2ec33c9dd565c2a0884152fc37` |
| V1 s0 post @225280 | `c5f9ea535d26afeb8b1f366b6781c050d43ecaa7a4cc7da4f6b5fc3b9caf22c4` | `e53507ece4e6b21e46fa872a02444f782ff92f672dab132545063206969915e7` | `e53507ece4e6b21e46fa872a02444f782ff92f672dab132545063206969915e7` | `98bcfa4955f28419da43f6faa4b70b5a937c6e2ec33c9dd565c2a0884152fc37` |
| V1 s1 pre @250880 | `1ad7b4aed55cea0444611a52e9203a2f7364be1ba5ad21a142187110d32a5ed5` | `0791cb2715ef06bdc16e1d240d96dc51aa91cebc12d1a19d73c0e7b6daec2839` | `0791cb2715ef06bdc16e1d240d96dc51aa91cebc12d1a19d73c0e7b6daec2839` | `98bcfa4955f28419da43f6faa4b70b5a937c6e2ec33c9dd565c2a0884152fc37` |
| V1 s1 post @300032 | `26e29c478f33ac11be23f0fbfd117943d3a48d4f0b1b8dff0f4bf3510d68dff9` | `6fd12133b0e02b61508f98a94bdc9ac89b7eb4c0308b1a6ab282ffd81b537a0d` | `6fd12133b0e02b61508f98a94bdc9ac89b7eb4c0308b1a6ab282ffd81b537a0d` | `98bcfa4955f28419da43f6faa4b70b5a937c6e2ec33c9dd565c2a0884152fc37` |
| V1 s2 pre @125952 | `5d1cc9bd68602de162f4acf5c83b74e6da1b25d56c19b28965a20a20fb1719e2` | `4964f44a26cce07886037130c53d56d4cf1efc128aa68ed0924bb0e639bb7fdd` | `4964f44a26cce07886037130c53d56d4cf1efc128aa68ed0924bb0e639bb7fdd` | `98bcfa4955f28419da43f6faa4b70b5a937c6e2ec33c9dd565c2a0884152fc37` |
| V1 s2 post @225280 | `2c9f3095dbf0ec5bf857c1565a4660b14b1da9f2591797e10c18e8c8c5b5aa56` | `2ab686304cf1d0f0d724e07c43d1fd3df1af0b9c15c11d094f01ae36cd06aa16` | `2ab686304cf1d0f0d724e07c43d1fd3df1af0b9c15c11d094f01ae36cd06aa16` | `98bcfa4955f28419da43f6faa4b70b5a937c6e2ec33c9dd565c2a0884152fc37` |
| BB s2 early @125952 | `63db0e6331298f960ec278466bab735710d1740558e79128bdf656021e8c3f8e` | `24d288751b4359f1a41f2b1e0a5215d3e2007a52c5703bb6aa32482c877ce0a9` | `24d288751b4359f1a41f2b1e0a5215d3e2007a52c5703bb6aa32482c877ce0a9` | `98bcfa4955f28419da43f6faa4b70b5a937c6e2ec33c9dd565c2a0884152fc37` |
| BB s2 late @300032 | `96d07ac4396416865c32d416e3054522ffd232c2ce5ecd5e0ace4a781784a86d` | `cd6b8d2b087ba7d7e9ac092ff05203585cabe56c32c1186794db1bfecd4db4fb` | `cd6b8d2b087ba7d7e9ac092ff05203585cabe56c32c1186794db1bfecd4db4fb` | `98bcfa4955f28419da43f6faa4b70b5a937c6e2ec33c9dd565c2a0884152fc37` |
| BB s6 early @125952 | `a727e26e7d3f37934a53a7625e66df6ce8b9b22b84434d1d8ab902afd4fba663` | `e702f74e771333054c99d6c2e90e2924b35d125d5ceee6853f9bd6116d39ac14` | `e702f74e771333054c99d6c2e90e2924b35d125d5ceee6853f9bd6116d39ac14` | `98bcfa4955f28419da43f6faa4b70b5a937c6e2ec33c9dd565c2a0884152fc37` |
| BB s6 late @300032 | `cfb61c5cabf3533595ead71451d5647e6de06bb4aaa8ffd1567c98681151f071` | `1e8845f7da0e5533ed103b03bcaa47170a18bdb2db45401b32c4f5660ed026ff` | `1e8845f7da0e5533ed103b03bcaa47170a18bdb2db45401b32c4f5660ed026ff` | `98bcfa4955f28419da43f6faa4b70b5a937c6e2ec33c9dd565c2a0884152fc37` |

## Reproduction

Script: [`../tools/wp03d_selection_diagnostics.py`](../tools/wp03d_selection_diagnostics.py)

```bash
CUDA_VISIBLE_DEVICES="" /home/simx2204/Workspaces/DGCC/.venv/bin/python \
  /home/simx2204/v2_research/tools/wp03d_selection_diagnostics.py \
  --repo /home/simx2204/Workspaces/DGCC \
  --out /home/simx2204/v2_research/dossier/WP-03D_selection_diagnostics.json \
  --threads 4
```

The final run processed ten current checkpoints and ten preceding checkpoints in 17.2 CPU-seconds. The JSON records `all_state_hashes_equal=true`, `all_rng_hashes_equal=true`, `optimizer_objects_constructed=false`, `parameter_updates_executed=false`, and `heldout_or_probe_paths_opened=false`.

## Limitations

- One deterministic state per episode gives broad episode/family coverage but is not a replay-buffer frequency estimate; within-episode autocorrelation was avoided by not taking many states from each trajectory.
- Churn is measured across adjacent archived checkpoint intervals, not one optimizer step. A literal one-step counterfactual would violate the no-update constraint. It should be read as incoming interval churn.
- This is an observational frozen-checkpoint diagnostic. It chooses a well-grounded operator and temperature range, but does not establish performance improvement or causality; those require a separately approved development-only intervention.
