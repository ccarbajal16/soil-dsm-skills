---
name: soc-stock-mrv
description: >-
  Quantify, report, and verify soil-organic-carbon stock and its change over time for
  carbon markets / MRV (Monitoring, Reporting, Verification) — computing SOC stock,
  estimating change and its uncertainty at the field/project support, and applying the
  uncertainty deduction that determines creditable tons. Use when a task involves soil
  carbon crediting, an MRV framework (VM0042, VT0014), SOC stock-change detectability, or
  reporting SOC with defensible uncertainty. Triggers: "SOC MRV", "soil carbon credits",
  "carbon farming verification", "SOC stock change", "uncertainty deduction", "how much SOC
  can we credit", "monitoring reporting verification soil carbon".
---

# SOC Stock MRV

Forged from the DSM knowledge wiki (20 sources). The wiki is the source of truth. Key pages:
soc-mrv, soc-stock, uncertainty-aggregation,
quantile-regression-forests, sampling-design,
accuracy-metrics. Lean on soil-map-validation
for validation and digital-soil-mapping-workflow
for the mapping.

## What MRV demands

Credible soil-carbon credits require **Monitoring, Reporting, and Verification**: quantify
SOC stock change, quantify its **uncertainty**, and deduct a conservative amount so credited
tons are defensible. The whole game is **honest uncertainty at the support you credit**
(field/project), not per-pixel prediction.

## Three method families (soc-mrv)
1. **Biogeochemical model + sampling** (e.g. VM0042, RothC-type) — forecast-based; assumes
   the model is right. See rothc-temporal-modelling.
2. **Repeated probability sampling** — design-based inference; statistically sound but costly
   and awkward when project fields change over time.
3. **DSM / model-based** (e.g. VT0014, ATLAS-SOC) — outcome-based measurement of actual
   change with quantified uncertainty. Often the scalable choice.
A hybrid (POML) can supply the plausible temporal
trend the pure-DSM route struggles with.

## Workflow

1. **Compute SOC stock** (soc-stock): `stock = SOC[%] × BD × thickness`, summed
   over depth to a common interval, corrected for coarse fragments. Keep the protocol fixed
   — cross-study stock numbers are only comparable under the same BD/depth/definition.
2. **Design sampling** (sampling-design): a **probability sample** enables
   design-based validation; **revisited locations** across time greatly ease change
   estimation. Small n makes variograms/intervals fragile. **Size n from a learning curve**
   (diminishing returns, plateau ≈ 200, density ≈ 1 obs/2 km²; never below ~30). If you use a
   spread design like **cLHS** for the modelling sample, remember its benefit is lower
   variance / fewer bad draws at small n — not higher mean accuracy — and condition it on
   covariates only, never the target.
3. **Predict with per-pixel uncertainty**: QRF gives
   prediction + interval. Pass the three VT0014-style tests: bias ME≈0 (t-test), R²>0,
   **PICP ≥ 90%**.
4. **Aggregate uncertainty to the reporting support** (uncertainty-aggregation) —
   the core MRV move. Fit a variogram/correlogram of standardized prediction errors, then
   integrate to the area-mean variance (Monte-Carlo). Averaging over area **collapses
   uncertainty (~66%)**; a project mean can be <1 Mg/ha even when point SD is 20+.
5. **Estimate change and its variance** between time steps. Include the **cross-correlation
   of errors over time** (ignoring it overestimates uncertainty). Convert SOC (Mg/ha) → CO₂
   with ×**44/12 ≈ 3.67**.
6. **Apply the uncertainty deduction**: credit at a conservative percentile (e.g. **33.3rd**,
   VM0042 "probability of exceedance") of the change distribution. More uncertainty ⇒ fewer
   creditable tons (can hit 0 even with positive mean change).

## Levers that shrink the deduction
- **Larger project area** and **longer monitoring period** both reduce the deduction (more
  averaging, more signal). Typical: ~12% over 5 yr for a small project; <5% for >50,000
  acres or >5 yr.
- **Better model accuracy** (lower prediction error).
- You **cannot** tune the error's temporal correlation — estimate it empirically
  (cross-correlogram).

## Detectability & honesty
- SOC change is generally detectable only over **~3–10 years** given turnover and spatial
  variability — don't credit change shorter than the signal.
- **Sensitive to variogram fitting** (range especially); need ~100–150 points (method of
  moments) or ~50 (REML); cap the range at ~half the area.
- **Report temporal skill separately** — a good static stock map doesn't prove the change is right.

## Pitfalls
- Quoting **point RMSE** as project uncertainty (hugely over-pessimistic → over-deduction).
- Ignoring the temporal error correlation in the change variance.
- Crediting change over a period shorter than its detectability.
- Mixing stock protocols (BD/depth/definition) across baseline and monitoring.
- Treating a training-design (cLHS) sample as a probability sample for design-based claims.

## Provenance
Core: Wadoux 2026 (DSM MRV, uncertainty aggregation, deduction). Support: Lai 2026 & Tian
2025 (aggregation, temporal difficulty), Hengl 2026 (scale), Shi 2026 (sequestration
potential), Bouasria 2023 (learning-curve sample sizing; cLHS variance vs mean). Full
citations in the wiki `sources/`.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
