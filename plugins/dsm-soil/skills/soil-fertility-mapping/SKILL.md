---
name: soil-fertility-mapping
description: >-
  Produce national/regional maps of multiple soil fertility properties and nutrients from
  harmonized legacy data with machine learning, and integrate them into a composite Soil
  Fertility Index (SFI) with honest, propagated uncertainty. Use when the goal is a
  multi-property fertility product (texture, pH, CEC, OC, N, P, K, Ca, BD) at broad scale —
  a GSNmap-style national soil-nutrient assessment, a fertility/soil-quality index, or
  region-specific management diagnosis. Triggers: "soil fertility map", "soil fertility
  index", "SFI", "nutrient mapping", "GSNmap", "map N P K", "soil quality index", "national
  soil property maps", "map CEC / pH / texture".
---

# Soil Fertility Mapping

Forged from the DSM knowledge wiki. Anchor source: Abbruzzini et al. 2026
(first national nutrient maps for Mexico, FAO GSNmap). This is a **specialization
of** digital-soil-mapping-workflow — do the general
DSM steps there; this skill adds the **multi-property + fertility-index** layer. Validation defers to
soil-map-validation.

> **STATUS: v0 (Phase 2).** All three pillars grounded, including a **national DSM-SFI worked example**
> (Hounkpatin 2022, Benin). Pillar B (soil-fertility-index)
> now has **four** cited integration routes. Pillar C now carries the **epistemic-coverage layer** —
> AOA/DI + LPD via CAST
> (Meyer & Pebesma 2021, Schumacher 2025) —
> the "where is this map even applicable?" tools that QRF intervals can't provide, under the two-axis frame
> predictive-uncertainty. **Propagating per-pixel property uncertainty into the fertility *class***
> is now grounded as a method (monte-carlo-uncertainty-propagation via spup) — even
> Hounkpatin only classifies from the mean maps; the ⏳ left is a worked national example.

## The three pillars

1. **Per-property maps** — predict each fertility property/nutrient continuously with ML + uncertainty.
2. **Fertility index** — integrate the property maps into a composite SFI, fuzzy zones, or a limiting-factor
   map (three grounded routes → soil-fertility-index).
3. **Uncertainty** — per property *and* propagated into the index, on **both axes**: distributional
   (QRF intervals) *and* epistemic coverage (AOA/LPD).
   This is what makes it defensible.

## The one law to internalize first

**Predictability splits by property, and the model can't fix it** (inherent-vs-management-properties).
- **Inherent / structurally-controlled** (texture, pH, CEC, Ca, BD, mostly OC) → map moderately-to-well
  because their drivers *are* the scorpan covariates. (Abbruzzini R²: pH 0.73, Ca 0.70,
  texture ~0.50–0.60, CEC 0.56, OC 0.52.)
- **Management-driven** (available **P**, total **N**) → map **poorly** (R² 0.19 / 0.26) because their
  drivers — fertilization/cropping/grazing history, short-range geochemistry — are invisible to
  environmental covariates.

This **triangulates across three continents and three methods**: Mexico (Abbruzzini, QRF), France
(Suleymanov; Vaysse) and Africa (Hengl, ensemble ML — **pH CCC 0.90,
extractable P CCC 0.654**). pH always near the top, extractable P always near the bottom. It is a **general
law**, not a dataset quirk. Set per-property confidence tiers **up front**. Don't burn effort tuning models to
rescue N/P — the ceiling is signal, not fit. Fix it (if at all) with denser management-stratified sampling +
**fine** parent-material covariates.

## Pillar A — per-property maps (workflow)

1. **Harmonize the legacy data first** (soil-data-harmonization). Merge multi-source records;
   standardize depth with a **mass-preserving spline** to 0–30 cm; standardize lab methods; window in time
   to match remote-sensing covariates; QC/de-outlier. **Track per-property n** — it will differ, and the
   under-sampled properties (often P, N) will map worst (sampling-design).
2. **Assemble scorpan covariates** (scorpan): bioclimatic (BIO1–19), NDVI metrics + land-use
   class, terrain (elevation, slope, curvature, TWI, MRVBF, MRRTF, catchment). **Add parent-material /
   lithology / carbonate layers** if at all possible — their absence is the single biggest fixable gap for
   P, K, and base status. Harmonize all to one grid/CRS (bilinear continuous, nearest-neighbour categorical).
3. **Select features per property** (feature-selection): RFE (or Boruta) run **separately for
   each target** — the informative set differs by property; don't force one shared set.
4. **Model — QRF or an ensemble, both with per-pixel uncertainty.**
   - **QRF** is the FAO GSNmap default: one forest, per-pixel
     interval from its terminal-node distribution. Vaysse showed
     it beats regression kriging for *honest* uncertainty under **sparse legacy data** (RK's nugget-heavy
     variograms under-estimate uncertainty) — the usual national/regional data regime.
   - **Ensemble ML / SuperLearner** (Hengl)
     stacks RF + XGBoost + deepnet + regularized GLM and reads uncertainty from the ensemble's bootstrap
     spread — more robust across a many-property suite, at higher compute cost. RF is the best single base
     learner either way.
   - **Two-scale covariates** (coarse climate + fine EO/DTM) lift accuracy for physical properties without
     blowing up compute (scale-dependence).
5. **Validate** (SKILL): report the **GSNmap metric panel per property**
   — R², RMSE, CCC, COE, IOA, FAC2 — so no weak nutrient hides behind one number. Judge **uncertainty with
   accuracy plots** (classic R² is blind to interval calibration — Vaysse).
   Use an **independent hold-out**, and do **spatial cross-validation with de-clustered points**
   (Hengl: 30–100 km blocks; or **kNNDM**,
   the CAST default that matches CV nearest-neighbour distances to the prediction geometry) — improving on
   Abbruzzini's k-fold-only, which is optimistic under autocorrelation →
   spatial-cv-validity. **Then compute the AOA under the *same*
   CV** (CAST) and mask each property map — see Pillar C.

## Pillar B — the fertility index (grounded → soil-fertility-index)

The DSM papers map the properties but **don't build an index** — this is the composite step you add. Pick one
of three cited integration routes (soil-fertility-index):

- **Weighted additive index + PCA Minimum Data Set** (Supriyadi) —
  reduce indicators with PCA (eigenvalue ≥ 1), **score** each (more/less/optimum-is-better), **weight** by PCA
  loading, **sum** to a continuous `SFI = Σ Wᵢ·Sᵢ`. Transparent and weight-explicit. **Down-weight or exclude
  the low-confidence nutrients (N, P)** so the index doesn't inherit their uncertainty (inherent-vs-management-properties).
  **Runnable end-to-end via soilquality** (`pca_select_mds` → `score_indicators` → `compute_sqi_properties`):
  it adds **AHP weighting** with a consistency check (`ahp_weights`, CR<0.10 — weights on *ecological priority*, not
  just PCA variance) and explicit **scoring functions** (`score_optimum` linear/quadratic for pH, `score_threshold`
  for nutrient classes). Point/compensatory — use it to derive the weights/scores/MDS (and a validation SFI), then
  apply the rule pixelwise; for a national map prefer the non-compensatory threshold route below.
- **Unsupervised fuzzy clustering into zones** (Valera, FKCN) —
  cluster the stacked property maps (Mahalanobis distance) into fertility classes with fuzzy membership maps;
  no labels needed, pick class count by FPI.
- **Supervised ML classification** (Abdullah) — if you have
  labelled fertility classes, train an ensemble (Extra Trees / RF); highest reported accuracy, but needs a
  spatial labelled ground truth.
- **Pixelwise expert-threshold classification** (Hounkpatin, ⭐ the national
  route) — map each property, then classify every pixel by **agronomic threshold rules** (e.g. Sys 1976, 5 classes)
  on the stacked maps. No labels, no PCA, **non-compensatory** and agronomically transparent — the natural default
  for a **policy-facing national** SFI. This is what an actual national DSM-SFI (Benin) did.
- **Agronomic realism — limiting-factor aggregation:** the threshold route above is already non-compensatory; or
  use **Nemerow** (mean + minimum) / a **Liebig limiting-factor map** (fertility = the scarcest property per pixel)
  so a high value can't mask a critical deficiency.

**The upgrade — propagate uncertainty into the fertility class (now grounded as a method).**
Hounkpatin quantifies national per-pixel property uncertainty (QRF model
spread **+** data sensitivity from repeated holdout refits) but still classifies from the **mean** maps — so the
fertility class carries no probability. The step: **Monte-Carlo
propagation** — draw each property from its QRF/ensemble
distribution, re-run the SFI/classification each draw → map the class **probability + entropy**. Do it
**rigorously**: model the **spatial autocorrelation** of each property's errors *and* the **cross-correlation
between properties**, or the class uncertainty is understated. The operational tool is **spup**
(`defineUM`→`defineMUM`→`genSample`→`propagate`; the C/N-ratio vignette is a near-exact template — swap the C/N
function for your SFI rule). Propagate **inside the AOA** and carry the mask
onto the class map. ⏳ remaining: a worked national example — no corpus paper completes it.

## Pillar C — uncertainty (thread it through everything)

Uncertainty has **two axes** (predictive-uncertainty) — report **both**, because they answer
different questions and one is blind to the other:

**Axis 1 — aleatoric / distributional ("how variable is the outcome here?")**
- **Per pixel, per property**: QRF prediction intervals; validate calibration with
  PICP and, principled, with proper scoring
  rules (CRPS / pinball). Conformal prediction is a model-agnostic
  alternative when you don't want to commit to QRF's machinery.
- **Per property confidence tier**: from the metric panel — decide which maps carry **field-scale**
  decisions (texture, pH, CEC, Ca) vs only **regional gradients** (N, P). State it on every product.

**Axis 2 — epistemic / coverage ("has the model even seen anything like here?")** — the layer QRF intervals
and RF ensemble SD **cannot** see (Meyer & Pebesma: their spatial
patterns *disagree* with the true error under extrapolation). For clustered national legacy data this is the
decisive layer. **The full engine for both axes is spatial-prediction-uncertainty** — use it for the uncertainty product; the essentials:
- **AOA + DI** (CAST `aoa()`): mask every property map to
  where the model is applicable — outside the AOA the CV error simply does not hold. **The AOA
  threshold depends on the CV design** — compute it under kNNDM/spatial CV, never random CV on clustered data.
- **LPD** (CAST `aoa(..., LPD = TRUE)`): grade
  reliability *inside* the AOA by how many training points support each pixel — it predicts error better than
  DI alone and exposes thinly-supported zones a low DI would wave through.
- Calibrate DI/LPD → expected RMSE for a per-pixel performance map; use it to target **resampling** of
  low-coverage areas (active learning, sampling-design).

**Into the index**: Monte-Carlo propagation via spup
(Pillar B) — a fertility index without an uncertainty layer is half a product. Mask/annotate the final SFI with the
AOA + LPD so the class map states *where* it is applicable, not only *what* it predicts.

- **Aggregate to the reporting support** when quoting regional means (uncertainty-aggregation).

## Pitfalls

- Expecting a good N/P map from environmental covariates — it's a signal ceiling, not a model failure.
- One shared covariate set / one metric for all properties — hides property-specific behaviour.
- Building the SFI from raw values instead of agronomically-scored (0–1) properties.
- Letting a heavily-weighted low-confidence nutrient dominate the index.
- Shipping the index without propagated uncertainty, or without stating per-property confidence.
- Reporting only k-fold accuracy under spatial autocorrelation (add spatial CV).
- Skipping harmonization — depth/lab/temporal mismatches masquerade as soil variation.

## Provenance
Anchor: Abbruzzini et al. 2026 (national QRF nutrient maps, Mexico, GSNmap; property-differentiated
predictability; harmonization; metric panel). National/continental companions: Hengl et al. 2021 (Africa,
30 m, ensemble ML, spatial CV, per-pixel error) and Vaysse & Lagacherie 2017 (foundational QRF-for-uncertainty
vs RK under sparse data; accuracy plots). Pillar B (index) grounded in soil-fertility-index via Hounkpatin 2022 (⭐ national DSM-SFI by
pixelwise expert-threshold classification, Benin), Supriyadi 2025 (PCA-MDS weighted-additive SFI),
Valera 2025 (FKCN fuzzy clustering), and Abdullah 2025 (supervised ensemble classification); runnable via the
**soilquality R package** (Carbajal — PCA-MDS + AHP weighting with consistency check +
scoring functions → `compute_sqi_properties`). Reuses the DSM
machinery from the wiki (scorpan, quantile-regression-forests,
ensemble-machine-learning, feature-selection, sampling-design,
accuracy-metrics, spatial-cross-validation, scale-dependence,
landscape-heterogeneity) and the DSM and
validation skills. **Remaining ⏳: uncertainty propagation into the
index at scale** (Monte-Carlo) — chase Hounkpatin 2022 (Benin). Full citations in the wiki `sources/`.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
