---
name: hybrid-process-ml-soc
description: >-
  Design and build hybrid soil-organic-carbon models that fuse a process-oriented model
  (RothC / CENTURY / Millennial) with machine learning (Random Forest / QRF) to predict
  SOC stock in space AND time — getting ML's spatial accuracy together with the process
  model's physically-plausible temporal dynamics. Use when a task needs SOC *change* over
  time (not just a static map), when pure ML gives implausible temporal trends, or when
  integrating mechanistic knowledge into data-driven soil mapping. Triggers: "hybrid soil
  carbon model", "process + machine learning", "POML", "space-time SOC", "RothC + random
  forest", "physically plausible SOC prediction", "knowledge-guided ML for soil".
---

# Hybrid Process + ML SOC Modelling

Forged from the DSM knowledge wiki (19 sources). The wiki is the source of truth. Key
pages: hybrid-po-ml, process-vs-empirical-models,
rothc, random-forest, rothc-calibration,
carbon-inputs, spatiotemporal-dsm. Builds on the
rothc-temporal-modelling and
soil-map-validation skills.

## The problem this solves

Across the whole soil-carbon literature, one split recurs:
- **Machine learning** predicts the **spatial** pattern of SOC well but **fails on temporal
  change** — fitted on a few sampling years it can't extrapolate in time (space-for-time
  substitution breaks; trends come out fluctuating and implausible).
- **Process models (RothC etc.)** capture **temporal dynamics and mechanism** but are less
  accurate spatially and rigid in their inputs.

Neither alone is enough for **space-time** SOC. The answer is to **fuse them**.

> This skill is the flagship instance of **soil-science-informed ML (SoilML)**:
> POML injects a process model's mechanistic knowledge into ML training. The same posture — guide the data-
> driven model with soil science — underlies covariate choice, loss design, and interpretation across DSM.

## The reference method: POML (Zhang et al. 2024)

Use the process model's simulations as **augmented training data** for the ML model —
*not* merely as a covariate. The final fitted model then embeds the space-time
soil–environment relationship.

1. **Run the process model (RothC)** over the full period at all locations: spin-up to
   equilibrium, then forward-simulate every year — including the **unsampled** in-between
   years. This yields a dense-in-time SOC series the samples don't provide.
2. **Train the ML model (Random Forest) on two targets via a weighted loss:**
   `overall_loss = wp · Loss(ŷ, ŷ_PO)_unsampled-years + (1−wp) · Loss(ŷ, y_obs)_sampling-years`
   - `Loss_obs` pulls the model toward **real measurements** (sampling years).
   - `Loss_PO` pulls it toward the **process model's plausible trajectory** (other years).
3. **Tune `wp` ∈ [0,1]** — the weight on the process model. `wp=0` = plain RF; `wp=1` = an
   RF that just mimics RothC. **Sweep it** and pick by cross-validation; the optimum is
   often below the 0.5 default (≈0.3 in the reference study). Rescale per-point PO weights
   by `n_obs / n_sim` so the larger simulated set doesn't swamp the observations.

Result in the reference case: hybrid **RMSE 0.29** vs ML 0.36 vs RothC 0.53; CCC 0.88;
**+19% over ML** — and a smooth, realistic temporal trend ML alone could not produce.

## Alternative integration patterns (know the trade-off)
- **PO output as a covariate** (Xie 2022; regression-kriging with RothC drift) — simpler,
  but the final model depends on a simulated covariate layer at prediction time and doesn't
  internalize the space-time relationship. POML's augmented-target approach is preferred
  when you want a self-contained space-time model.
- **ML to impute PO inputs** — use ML to fill carbon-input / covariate gaps that RothC needs.
- **Saturation-constrained PO** — cap RothC's non-saturating growth (open research).

## Preconditions (get these right or the hybrid inherits the weakness)
- **A credible process run.** Garbage RothC → garbage augmentation. Nail
  carbon inputs (the dominant uncertainty — the reference used
  **fertilizer records, not NPP**, after verifying NPP missed the trend) and calibrate
  (multi-objective, respiration-based if possible).
- **Revisited sampling helps.** Same locations across time greatly ease PO calibration;
  without it, expect larger uncertainty.
- **Consider a microbial term.** The reference added a Michaelis–Menten μ factor to RothC
  (decay responds to microbial biomass) — a small, justified adaptation. RothC is a
  simplified base, not gospel.

## Validation (defer to the soil-map-validation skill)
- Cross-validate with **folds consistent across years** (a location's observation and its
  PO simulation stay in the same fold — no leakage between the two targets).
- Report **RMSE + CCC**, and — critically — inspect the **temporal trend** the hybrid
  produces, not just aggregate accuracy: the whole point is a *plausible* trajectory.
- Report **spatial and temporal skill separately**; a good static RMSE doesn't prove the
  change is right.

## Pitfalls
- Feeding PO output as a covariate and calling it a space-time model (it isn't self-contained).
- Leaving `wp` at the default instead of sweeping it.
- Letting the large simulated set dominate the loss (rescale weights).
- Trusting the hybrid's *future* projections without out-of-time validation.
- A weak/uncalibrated RothC silently poisoning the ML.

## Provenance
Core: Zhang et al. 2024 (POML — the reference realization). Foundation: Lai 2026 (the "RothC
for time, ML for space" thesis + national RothC), Ma 2026 (CenW), the RothC application
cluster (Balugani/Pesce/Afzali/Kaushal — calibration, variants, climate), and the ML/DSM
cluster (Wadoux, Jafari, Shi, Hengl, Tian, Sarkar, Rohmer, Carbajal, Parvizi, Mousavi). Full
citations in the wiki `sources/`.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
