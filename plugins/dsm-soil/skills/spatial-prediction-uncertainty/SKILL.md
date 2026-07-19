---
name: spatial-prediction-uncertainty
description: >-
  Quantify, map, and communicate the uncertainty of a spatial ML prediction on BOTH axes —
  distributional ("how variable is the outcome here?") and epistemic coverage ("has the model
  even seen anything like here?"). Use when you need honest per-pixel uncertainty for a digital
  soil map, nutrient/fertility map, SOC prediction, or any raster ML product: prediction
  intervals, the area of applicability (AOA), the dissimilarity index (DI), local data point
  density (LPD), a DI/LPD→performance map, and targeted resampling of low-coverage zones.
  Triggers: "area of applicability", "AOA", "dissimilarity index", "DI", "local data point
  density", "LPD", "CAST", "aoa()", "where can I trust this map", "extrapolation risk",
  "prediction uncertainty map", "conformal prediction", "proper scoring rule / CRPS", "mask
  the map where the model is guessing".
---

# Spatial Prediction Uncertainty

Forged from the DSM knowledge wiki (sources 2021–2025). The wiki stays the source of truth; this
skill is the distilled, operable version. Core pages: predictive-uncertainty,
area-of-applicability, local-data-point-density,
quantile-regression-forests, probabilistic-scoring,
conformal-prediction, spatial-cross-validation, cast.

**Scope boundaries.** General cross-validation, accuracy metrics, and uncertainty *aggregation* live
in soil-map-validation — defer to it for those. This skill
owns the **uncertainty product itself**: what to compute, how the two axes fit together, and how to
ship a map that states *where* it is applicable, not only *what* it predicts. It is also the **engine
of Pillar C** in soil-fertility-mapping.

## The one idea to internalize first

**Uncertainty has two axes, and the most common tools cover only one of them.**

- **Aleatoric / distributional** — *"How variable is the outcome here, given the model?"* From noise
  and the model's conditional spread. **Irreducible** by more data. Tools: QRF
  prediction intervals, ensemble spread, conformal prediction; evaluated
  by proper scoring rules / PICP.
- **Epistemic / coverage** — *"Has the model ever seen anything like here?"* From lack of data /
  extrapolation into new predictor space. **Reducible** by better-placed data. Tools:
  AOA + DI, LPD, honest
  (spatial) CV.

**The load-bearing warning (Meyer & Pebesma 2021):** QRF intervals
and RF ensemble SD are **blind to extrapolation** — their spatial patterns *disagree* with the true
error where the model predicts into unseen environments. So a pixel can have a **tight interval and
still be wildly wrong** because it is far outside the AOA. Within-model variability ≠ out-of-domain
uncertainty. **Report both axes or the map lies about where it's guessing.** Full frame:
predictive-uncertainty.

For **clustered legacy data** (the national-mapping norm), the coverage axis is the decisive one:
most of the country is predicted far from any sample, and only the AOA/LPD layer flags it.

## Workflow

**1. Frame it.** State the property, support, and *what uncertainty means for the decision* — a
field-scale recommendation needs a tighter, better-covered map than a regional gradient. Decide the
nominal interval (e.g. PI90) and the performance level you'll require.

**2. Get an honest CV FIRST — it sets everything downstream.** Choose the CV to match the sampling
structure: **kNNDM** (CAST default; auto-adapts — random on
random samples, spatial on clustered) or spatial-block CV. **This is not optional housekeeping: the
AOA threshold is derived from CV nearest-neighbour distances, so a mismatched CV (random CV on
clustered data) corrupts the error estimate *and* the applicability map.** Defer the metric panel to
soil-map-validation.

**3. Distributional axis — per-pixel intervals.**
- Default: **QRF** — one forest, per-pixel interval from the
  terminal-node distribution (the FAO GSNmap standard; beats regression kriging for *honest*
  uncertainty under sparse legacy data).
- Multi-property / robustness: **ensemble** bootstrap spread.
- Model-agnostic alternative: **conformal prediction** — valid
  intervals on any trained model, no retraining (⚠️ assumes exchangeability, which spatial covariate
  shift breaks — so it does *not* replace the coverage axis).
- **Validate the intervals:** PICP ≈ nominal; principled generalization =
  proper scoring rules (CRPS, pinball loss) — pick models on
  **coverage, not R²** (a great-R²/bad-coverage map is provably worse).

**4. Coverage axis — mask and grade (the CAST core).**
- Compute the **AOA + DI** with `aoa()` under the *same CV* as step 2.
  **Mask every prediction map to the AOA** — outside it, the CV error simply does not hold.
- Add **LPD** with `aoa(newdata, model, LPD = TRUE)`: it counts
  how many training points support each pixel, graduating reliability *inside* the AOA. It predicts
  error better than DI alone (R² 0.74/0.71 vs 0.57/0.40) and exposes low-DI-but-thin-support zones a
  binary AOA waves through.
- **Calibrate DI/LPD → expected RMSE** (monotone shape-constrained additive model) for a per-pixel
  performance map — then you can restrict the product to a user-defined error level, not just in/out.

**5. Combine and communicate.** Ship, together: the prediction, its **prediction interval**
(distributional), the **AOA mask** + **LPD/DI performance layer** (coverage). Annotate: "inside the
AOA the CV performance holds on average; low-LPD areas carry higher uncertainty; outside the AOA the
map is extrapolation." One layer without the other is half a product.

**6. Act on it (active learning).** Low-LPD / high-DI zones inside the target area are where new
samples buy the most — epistemic uncertainty is *reducible*. Feed those maps into
sampling design to target the next campaign; `trainDI()` lets you test a
proposed design's effect on the AOA cheaply, without refitting.

## CAST quick reference (CAST, R)

| Function | Does |
|----------|------|
| `knndm()` / `nndm()` | fold assignment matching CV↔prediction nearest-neighbour distances (honest AOA threshold) |
| `ffs()` | spatial forward feature selection (target-oriented CV) |
| `aoa(newdata, model)` | DI + AOA for a prediction stack (weights by the model's variable importance) |
| `aoa(newdata, model, LPD = TRUE)` | adds per-pixel LPD |
| `trainDI()` | precompute training DI/threshold — assess a new area/design without recomputation |
| `DItoErrormetric()` | calibrate DI (or LPD) → expected RMSE for a performance map |
| `CASTvis::exploreAOA()` | interactive DI/LPD/AOA exploration |

## Which tool when

| You need… | Reach for |
|-----------|-----------|
| Per-pixel interval, one forest, sparse legacy data | QRF |
| Per-pixel error across many properties / a stacked model | ensemble spread |
| Valid intervals on an arbitrary trained model, no retraining | conformal prediction (mind exchangeability) |
| "Where does my CV performance even hold?" | AOA + DI |
| "How well-supported is each in-AOA pixel?" | LPD |
| Score/compare probabilistic predictions properly | CRPS / pinball |
| Decide where to sample next | LPD/DI map → sampling design |
| Push property uncertainty into a derived class/index (nonlinear) | Monte-Carlo propagation (spup) |

## Pitfalls

- **Quoting only the QRF/ensemble interval** — it's blind to extrapolation; a tight interval outside
  the AOA is a false comfort. Always add the coverage axis.
- **Computing the AOA under random CV on clustered data** — corrupts the threshold; use kNNDM/spatial.
- **Trusting DI alone** — same DI can mean 1 or 10 supporting points; add LPD.
- **Reading LPD as a verdict** — it's a *probability*: a single point can suffice if noise is low;
  where uncertainty comes from *missing predictors* (the hard nutrients N/P — inherent-vs-management-properties),
  more coverage won't save you. LPD grades coverage, not signal.
- **Conformal prediction under covariate shift** — its coverage guarantee assumes exchangeability;
  spatial extrapolation breaks it. Keep AOA/LPD.
- **Picking models on R²** — use PICP / proper scoring rules for the uncertainty.
- **LPD compute blow-up** on large sets — cap max neighbours (loses the performance estimate) or tile.
- **Shipping a map without an applicability mask** — users can't tell prediction from extrapolation.

## Provenance
Distilled from: Meyer & Pebesma 2021 (⭐ AOA + DI; ensemble-SD blind to extrapolation; CV-dependence;
DI→performance calibration), Schumacher et al. 2025 (LPD; beats DI at predicting error; CAST
`aoa(LPD=TRUE)`, kNNDM), Tyralis & Papacharalampous 2024 (predictive distributions; proper scoring
rules — CRPS, pinball), Weytjens 2025 (epistemic vs aleatoric; conformal prediction), with QRF/ensemble
uncertainty from Vaysse 2017, Hengl 2021, Hounkpatin 2022 and the wiki's DSM machinery
(spatial-cross-validation, accuracy-metrics, sampling-design,
model-interpretability). Defers general validation to
soil-map-validation and serves as Pillar C of
soil-fertility-mapping. Propagating per-pixel uncertainty into a
derived *class* (e.g. fertility class) is now grounded as monte-carlo-uncertainty-propagation (tool:
spup); the ⏳ left is a worked national example. Full citations in the wiki `sources/`.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
