---
name: soil-map-validation
description: >-
  Validate soil property maps and SOC (organic carbon) predictions rigorously —
  choosing cross-validation strategy, computing and interpreting accuracy metrics,
  checking that uncertainty is honest, and aggregating uncertainty to the reporting
  support. Use when reviewing, designing, or reporting the accuracy of a digital soil
  map, an SOC stock/density prediction, a RothC/process-model simulation, or an
  MRV/carbon-credit estimate. Triggers: "validate soil map", "is this SOC model any
  good", "cross-validation for spatial data", "prediction interval / PICP", "map
  accuracy", "uncertainty of the mean", "which metric".
---

# Soil Map & SOC Prediction Validation

Forged from the DSM knowledge wiki (12 sources, 2017–2026). The wiki remains the source
of truth; this skill is the distilled, actionable version. Key wiki pages:
validation-verification, accuracy-metrics,
spatial-cross-validation, uncertainty-aggregation,
sampling-design, spatial-autocorrelation,
model-interpretability.

## Core discipline (the non-negotiables)

1. **Validate the uncertainty, not just the prediction.** A map without calibrated
   uncertainty is half-validated. Always check both accuracy *and* interval coverage.
2. **Report temporal skill separately from spatial skill.** A model can nail the spatial
   pattern of SOC stock yet fail completely on *change over time* (model efficiency ≈ 0).
   Never let a good static R² imply the change map is trustworthy.
3. **Match the validation to the estimand.** "How good is this model at unsampled
   locations?" (cross-validation) is a different question from "how accurate is this map
   over the area?" (design-based validation on a probability sample). Say which you mean.
4. **Aggregate uncertainty to the reporting support.** Point-level RMSE massively
   overstates the uncertainty of a field/project/national mean. Aggregating collapses it
   (~66% empirically) — but only if you account for spatial error correlation.
5. **Model choice is regime-dependent.** Small samples + heterogeneous/non-stationary
   terrain can make classical spatial regression beat ML (ML can score *negative* R²).
   Don't assume Random Forest is the right baseline; test alternatives.
6. **Judge designs/models on the whole distribution, not one run.** Two sampling designs can
   tie on mean accuracy yet differ sharply in *variance* — the SD of RMSE is where the
   difference lives. Compare with repeated runs (paired seeds) and report the spread.
7. **Define every metric exactly.** "R²" alone is ambiguous — Pearson vs Spearman,
   variance-explained (can go negative) vs squared-correlation (cannot). State the formula
   or your numbers aren't comparable to anyone else's.

## Validation workflow

1. **State the target and support.** Property (SOC %, stock t/ha, density kg/m³), depth,
   and the spatial support you'll report at (point, field, project, region, nation).
2. **Check the sampling design and size.** Was it a probability sample (enables design-based
   validation) or a model-training design like cLHS (does not, by itself)? See
   sampling-design. Small n (<~150) → variograms and interval estimates are
   fragile; flag it. **Sanity-check the sample size against a learning curve** — accuracy
   plateaus around n ≈ 200 (density ≈ 1 obs/2 km²) and nothing below ~30 is reliable; a map
   built far below its plateau is under-sampled regardless of its headline R². When the
   design was **cLHS**, confirm it was conditioned on **covariates only** — conditioning on
   the target (a real code bug in the wild) inflates apparent accuracy.
3. **Pick a cross-validation strategy** (see table below) appropriate to the spatial
   structure and the estimand. Beware **data leakage** when covariates are interpolated
   (kriged/IDW) from the same samples — rebuild those covariate layers *inside each fold*.
4. **Compute accuracy metrics** (below) — always ≥ one of each: magnitude (RMSE),
   systematic bias (ME), skill (R²/MEC/NSE), agreement (CCC).
5. **Check residual spatial structure.** Compute Moran's I *on the residuals*. ≈0 → the
   model absorbed the spatial structure; still high → it didn't (add spatial covariates,
   use a spatially-aware model, or krige the residuals).
6. **Validate the uncertainty.** PICP ≈ nominal (e.g. 90%)? Also useful: accuracy plots
   and the standardized squared prediction error (median → 0.455). Under/over-coverage
   means the intervals lie.
7. **Aggregate to the reporting support.** Fit a variogram/correlogram of the standardized
   prediction errors; integrate to the area-mean variance (Monte-Carlo). For *change*,
   include the cross-correlation of errors between time steps.
8. **Explain the uncertainty (optional but valuable).** SHAP on the uncertainty tells you
   which covariate to sample next — and note the drivers of the estimate are *not*
   necessarily the drivers of confidence.

## Cross-validation strategy selection

| Strategy | Use when | Watch out |
|----------|----------|-----------|
| Random k-fold (RCV) | quick screen, weak spatial structure | **over-optimistic** under spatial autocorrelation |
| Spatial CV (SCV) | spatially structured data; want conservative estimate | validates, does **not** fix spatial structure; disputed as a *map-accuracy* tool |
| LOOCV | small n; paired with pass/fail tests | high variance; still model-eval, not map-accuracy |
| Leakage-free / whole-mapping-process CV | covariates interpolated from the same samples | must rebuild kriged/IDW layers per fold |
| Design-based (probability sample) | certifying **map accuracy** for MRV | needs a probability sample up front |
| Population-based (exhaustive reference) | a dense/exhaustive "truth" raster exists; benchmarking designs/protocols | truth is often itself a model output → tests reproducibility, not field accuracy |

## Metrics reference

| Metric | Answers | Optimum |
|--------|---------|---------|
| RMSE / MAE | error magnitude (data units) | 0 |
| ME (mean error) / Bias | systematic over/under-prediction | 0 |
| R² / MEC / NSE | skill vs predicting the mean (same Nash-Sutcliffe idea, three names) | 1 (can be **negative** = worse than the mean) |
| CCC / LCCC | agreement with the 1:1 line (catches high-R²-but-biased) | 1 |
| PICP | share of obs inside the nominal prediction interval | = nominal |
| Moran's I of residuals | leftover spatial structure | 0 |

- **MEC = NSE = R²-style modelling efficiency** — don't be fooled by the different names.
- A **negative R²/MEC** means the model is worse than just using the mean — a real,
  reported outcome (RF/GB in small-sample Andean terrain). Treat it as a red flag that the
  model or the covariates or the sample size is wrong for the regime.

## Common pitfalls (each cost someone a wrong conclusion)

- **Random CV on autocorrelated data** → inflated accuracy that evaporates in use.
- **Leaked covariates** (kriged from the validation points) → artificially high R².
- **Point RMSE quoted as project uncertainty** → over-pessimistic MRV deductions.
- **Same-data fit reported as predictive skill** → it isn't; needs independent test.
- **One R² for everything** → hides bias (use CCC) and hides temporal failure (report change separately).
- **Assuming ML is the right model** → in small-sample/non-stationary terrain it can lose to GWR.
- **Comparing a single run** → mean accuracy can hide a design/model with far worse variance; report SD over repeated runs.
- **"R²" left undefined** → Spearman-R² and Pearson-R² are different numbers; state which, or don't cross-compare.
- **Under-sampled map with a good R²** → check n against the learning-curve plateau (~200); a high score on too few points is fragile.
- **cLHS conditioned on the target** → inflated accuracy that won't reproduce; condition on covariates only.
- **Ignoring extrapolation** → ship an extrapolation-risk layer so users know where the model is guessing.
  The dedicated tools are the **area of applicability (AOA) + local data point density (LPD)** — see
  spatial-prediction-uncertainty for the coverage axis
  (this skill owns the distributional side: CV, metrics, PICP, aggregation).

## Provenance
Distilled from: Wadoux 2026 (MRV, aggregation, PICP), Wadoux 2019 (accuracy plots, δ),
Jafari 2026 (residual Moran's I), Shi 2026 (leakage-free CV), Lai 2026 (temporal MEC≈0),
Ma 2026 (fit≠skill, NSE), Hengl 2026 & Tian 2025 (CCC, prediction intervals, extrapolation
risk, ~66% aggregation), Rohmer 2024 (SHAP for uncertainty), Sarkar 2025 & Carbajal 2025
(model choice regime-dependent; negative R²), Bouasria 2023 (learning-curve sample sizing,
report metric SD not single runs, define R² exactly, population-based evaluation, cLHS
target-leakage bug). Full citations in the wiki `sources/`.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
