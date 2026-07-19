---
name: digital-soil-mapping-workflow
description: >-
  Run a digital soil mapping (DSM) project end to end — from framing the target and
  assembling scorpan covariates, through sampling design, model selection, handling spatial
  autocorrelation, training, and producing a map with calibrated uncertainty. Use when
  planning or reviewing any project that predicts a soil property (SOC, texture, pH, …)
  across space (and optionally time) from environmental covariates. Triggers: "digital soil
  mapping", "DSM", "predict soil property from covariates", "soil map", "scorpan", "which
  model for soil mapping", "covariates for soil", "map SOC / soil carbon".
---

# Digital Soil Mapping Workflow

Forged from the DSM knowledge wiki (21 sources). The wiki is the source of truth. Key
pages: scorpan, scale-dependence, sampling-design,
random-forest, spatial-autocorrelation,
geographically-weighted-regression, regression-kriging,
feature-selection, spatiotemporal-dsm,
model-interpretability, sample-representativeness,
spatiotemporal-sampling, soil-informed-ml. Hand off validation to
soil-map-validation and space-time-with-mechanism
to hybrid-process-ml-soc.

> **Posture (SoilML):** direct the workflow with pedological knowledge —
> expert covariate choice, honest uncertainty, mechanism-aware interpretation — don't just feed a model
> rasters. Every step below is a place to inject soil knowledge.

## The foundation: scorpan

DSM predicts a soil property as an empirical function of environmental covariates that
stand in for the soil-forming factors — **soil, climate, organisms, relief, parent
material, age, spatial position** (McBratney 2003). Every step below serves this: gather
covariates for each factor, sample to relate them to measured soil, fit a model, map.

## Workflow

### 1. Frame the target and support
- Property, **depth**, units. For SOC: decide **concentration vs stock**
  (stock needs bulk density + coarse-fragment correction + depth harmonization).
- **Spatial support** you'll report at (point, field, project, region) — it drives
  validation and uncertainty later.
- **Pick the scale deliberately (scale-dependence).** Extent and resolution are a
  modelling decision, not a backdrop: they reorder which covariates matter *and* which model wins.
  **Broad/national** maps are for reporting and strategy (climate + vegetation dominate, terrain
  fades); **local/regional** maps are for site decisions (terrain regains power). Don't reuse a
  national model's covariate set or importance ranking for a field-scale job, or vice versa.
  Note that **extent size itself is a weak predictor of accuracy** — the real driver is
  landscape structure (heterogeneity, autocorrelation,
  distribution shape). A mid-size regional area with a bimodal target can map *worse* than a
  larger national one.
- **Static or space-time?** If you need *change over time*, go to
  spatiotemporal DSM and consider the hybrid skill.

### 2. Assemble covariates (scorpan)
- Families: climate (temperature, precip, bioclimatic), relief (DEM derivatives — slope,
  TWI, TPI, curvature), organisms (NDVI/EVI/NPP, land cover), parent material/soil
  (geochemistry, texture, pH maps), position. Add spectral indices from Landsat/Sentinel/MODIS.
- **Harmonize** all layers to one grid/resolution and projection.
- Reduce redundancy: correlation cut + **VIF**, or recursive feature elimination, or
  **Boruta** (all-relevant). Two cautions: (1) Boruta is **RF-based**
  — a subset selected for RF can *hurt* a kriging/linear model, so match the selector to the model
  family; (2) how many covariates survive is **scale-dependent** (Ngubo
  kept 22/35 regionally but 34/35 nationally as heterogeneity rose).
- Reuse existing products as covariates/priors: soilgrids, openlandmap.
- Match the covariate emphasis to the scale: at **broad scales prioritise long-term climate
  (TerraClimate ET/precip/radiation) and vegetation (NDVI)**; terrain
  derivatives earn their place mainly at **finer scales**. For SOC stock, **soil covariates
  (silt, pH, parent material) can outrank satellite indices** — don't over-rely on spectral data.

### 3. Design the sampling (sampling-design)
- **cLHS** for efficient covariate-space coverage when placing new samples — condition it on
  **covariates only** (never the target). Its edge over simple random sampling is *variance*,
  not mean accuracy: same average score but ~½ the RMSE spread and far fewer catastrophic
  draws, so it's cheap **insurance when n is small**. At n ≥ 300 the design barely matters.
- **Probability sampling** if you need design-based **map-accuracy** validation later.
- **Beyond cLHS** (design catalog): scLHS (adds spatial coverage), **MPRS**
  for **multi-property** builds (one set representative for several properties), cost/accessibility-
  constrained designs for hard terrain, and — for change over time — space-time sampling (record date/season!).
- **Reusing legacy data?** Assess representativeness first (fuzzy-
  cluster coverage per parent material), then **supplement** only where coverage is thin — the training-side
  companion to the AoA.
- **Size n from a learning curve, not a guess.** Accuracy shows diminishing returns and
  plateaus around **n ≈ 200–300** (density ≈ 1 obs/2 km²); the biggest jump is 25→50; below
  ~30 nothing is reliable. Larger extents need more points to hit the same density.
- Small n (<~150) is a real regime: it constrains model choice (next step) and makes
  variograms/interval estimates fragile.
- **Pre-check the landscape (landscape-heterogeneity).** Before modelling,
  compute the target's **Moran's I** (higher → easier), **Shannon SDI** (higher → harder),
  and **distribution shape** (bimodality hurts). These forecast difficulty better than extent
  size and tell you where to spend the sampling budget.

### 4. Choose the model — regime-dependent, not one-size
This is the decision the corpus is emphatic about: **there is no universal best model.**

| Situation | Prefer |
|-----------|--------|
| General workhorse, decent n, non-linear | Random Forest / QRF |
| Need per-pixel uncertainty | QRF |
| **Small samples + heterogeneous / non-stationary terrain** | GWR / GWRK (can beat ML, which may score negative R²) |
| Strong residual spatial structure | regression-kriging (trend + krige residuals) |
| Spatial context / multi-property / large scale | CNN/ANN (but a tuned RF often matches it) |
| Change over time | spatiotemporal RF/QRF; with mechanism → POML hybrid |

Don't assume RF wins — test at least one spatially-explicit alternative when n is small or
terrain is complex. And weigh **generalisation, not just accuracy**: RF can post a high training
fit yet **overfit** (Ngubo: train R²≈0.93 → test ≈0.53), while RK
under-fits training but generalises — RK even edged RF at the national scale. Judge every candidate
on an independent holdout / CV, never on training fit.

### 5. Handle spatial autocorrelation (spatial-autocorrelation)
Three *different* levers — don't conflate them:
1. **Spatial covariates** (e.g. SEVMs) — modest help.
2. **Spatially-aware algorithm** (spatialRF, GWR) — usually the biggest gain.
3. **Spatial validation** — an honesty check, not a fix.
Diagnose with **Moran's I on the residuals**: ≈0 means the model absorbed the structure.

### 6. Train and interpret
- Tune modestly (RF: ~200–1000 trees, mtry ≈ √p). Avoid **data leakage** when covariates
  are interpolated from the same samples (rebuild those layers inside CV folds).
- **Interpret** with variable importance and SHAP —
  and remember the drivers of the *prediction* differ from the drivers of *confidence*.

### 7. Validate (defer to the validation skill)
Use soil-map-validation: pick the CV strategy for
your estimand, report RMSE + ME + CCC (+ MEC for temporal), validate uncertainty with PICP,
and report temporal skill separately from spatial.

### 8. Map with uncertainty
- Produce the prediction **and** its uncertainty (QRF intervals) **and** an
  **extrapolation-risk** layer flagging where the model is guessing.
- **Aggregate uncertainty to the reporting support** (uncertainty-aggregation) —
  it collapses (~66%) over areas; quote area means with their real (smaller) uncertainty.
- State clearly: **high spatial resolution ≠ high accuracy.**

## Pitfalls
- Assuming RF is the right baseline in every regime (small-sample/non-stationary flips it).
- Ignoring **scale**: reusing a national model's covariates/importance for a local job (or vice versa).
- **Guessing the sample size** instead of sizing it from a learning curve (plateau ≈ 200; floor ≈ 30).
- **Conditioning cLHS on the target** (or bare coordinates) — inflates accuracy that won't reproduce.
- Blaming a big extent for poor accuracy when the real cause is landscape heterogeneity/bimodality.
- Reading high **training** fit as map quality — check the train–test gap for RF overfitting.
- Selecting covariates with an RF-based method (Boruta) then feeding them to a kriging/linear model.
- Leaked covariates inflating accuracy.
- Quoting point RMSE as area uncertainty.
- Treating a static map's R² as evidence the change map is right.
- Shipping a map with no uncertainty or extrapolation-risk layer.

## Provenance
Distilled from Zhang 2017 (DSM review/foundations), Jafari, Shi, Hengl, Tian, Wadoux,
Carbajal, Sarkar, Parvizi, Mousavi, Iticha, Ngubo, Bouasria 2023 (learning-curve sample
sizing, cLHS variance edge, landscape-heterogeneity pre-check), and Zhang 2024 (space-time).
Full citations in the wiki `sources/`.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
