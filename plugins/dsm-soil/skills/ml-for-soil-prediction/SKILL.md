---
name: ml-for-soil-prediction
description: >-
  Choose, tune, and reason about machine-learning models for predicting soil properties
  (SOC, texture, pH, …) — Random Forest, Quantile Regression Forests, gradient boosting,
  and deep learning — including per-pixel uncertainty and interpretability. Use when the
  task is the ML modelling craft itself: which algorithm, how to tune it, how to get honest
  uncertainty, whether deep learning is worth it, why an ML model underperforms. Triggers:
  "random forest for soil", "QRF", "which ML model", "deep learning soil", "CNN / ANN soil
  carbon", "hyperparameters", "feature importance / SHAP", "prediction interval", "ML model
  gives bad R²".
---

# Machine Learning for Soil Prediction

Forged from the DSM knowledge wiki (21 sources). The wiki is the source of truth. Key
pages: random-forest, quantile-regression-forests,
deep-learning, feature-selection, accuracy-metrics,
model-interpretability, spatial-cross-validation,
scale-dependence. For the full project flow use
digital-soil-mapping-workflow; for
validation depth use soil-map-validation.

## The engines

| Model | Use it for | Notes |
|-------|-----------|-------|
| **Random Forest** | default workhorse | robust to noise/skew, no distribution assumptions, handles non-linearity; tune ntree (~200–1000), mtry (≈√p) |
| **spatialRF** | absorbing spatial autocorrelation | internally generates spatial predictors; strong performer |
| **Quantile Regression Forests (QRF)** | **per-pixel uncertainty** | full conditional distribution → prediction intervals; the go-to for uncertainty |
| **Gradient Boosting** | sequential error-correcting ensemble | can be accurate but tuning-sensitive |
| **Deep learning (CNN/ANN)** | spatial context, multi-task, large scale | CNN uses covariate windows / multi-property; **often only matches a tuned RF on tabular data** |

## Golden rule: bigger/deeper ≠ better

The corpus is blunt about this. A **tuned Random Forest frequently beats deep learning** on
tabular soil+covariate data (Sarkar: RF 0.87 vs ANN 0.78), and in **small-sample,
non-stationary regimes ML can lose outright to classical spatial regression** — even
scoring **negative R²** (Carbajal). Meanwhile RF wins elsewhere (Parvizi). **Model choice is
regime-dependent**: match the model to sample size, heterogeneity, and available spatial
covariates — don't reach for the fanciest tool by default. **DL has a data-size threshold**: Padarian's
multi-task CNN *crushed* Cubist on ~19k spectra but *lost* to it on 390 samples — deep learning pays off
only with a large, information-rich dataset (dense covariate stacks, spectra), where **multi-task**
(predicting correlated properties jointly) adds real synergy. Below that, a tuned RF/QRF (or GWR) wins.

## Overarching posture: direct the model with soil knowledge (SoilML)
The through-line of everything below is **soil-science-informed ML (SoilML)**:
ML finds non-linear patterns, but pedological knowledge must **guide covariate choice, model design,
and interpretation** so predictions stay physically plausible — not resting on spurious, snapshot
correlations. Three levers (Yang & Li 2026; Minasny 2024):
(1) **expert covariate selection** (choose drivers known to shape soil — e.g. parent
material for nutrients — over a blind hundreds-of-layers dump); (2) **knowledge in structure/loss**
(PINN-style; feasible for neural nets, not fixed-structure RF → for RF, encode knowledge via covariates
and the hybrid route); (3) **soil-meaningful pretext tasks** for self/semi-supervised learning under
label scarcity. The process+ML hybrid and the
"association ≠ causation" caution are **instances** of SoilML, not separate ideas. Posture: *you direct,
the model executes* — don't just feed it rasters.

## Workflow

1. **Prepare data.** Assemble scorpan covariates; reduce redundancy
   (correlation + VIF, or recursive feature elimination). Watch **data leakage**
   when covariates are interpolated from the same samples (rebuild those layers inside CV folds).
   For principled feature selection, **Boruta** (all-relevant) keeps
   even weak-but-interacting predictors — but it is **RF-based, so it biases toward RF**: don't reuse an
   RF/Boruta subset to feed a kriging or linear model (it *helped RF but hurt RK* in Ngubo). Retained-set
   size also grows with landscape heterogeneity/extent (scale).
   **Engineer features, not just select them** (feature-selection): band/geophysical **ratios**
   (gamma Th/U/K), explicit **spatial terms** (coordinates/distances — blend with environmental covariates
   or you get artificial boundaries), and **interaction/polynomial terms** (Ca:Mg, Na×pH) encode soil
   chemistry a raw stack misses. ⚠️ Engineered features + small n = overfitting — validate on real,
   independent data.
2. **Pick the algorithm — evaluate several, don't assume.** **No algorithm is universally best**
   (Radočaj, Córdoba, Padarian review); the winner depends on the data, landscape, and purpose.
   RF/QRF are the **safe defaults** (top-ranked for national SOC across France/Czech and for SOM/P/pH
   in Argentina), but **popularity ≠ accuracy**: Radočaj's audit found **KNN and GBM underrated** (try
   them more) and **Cubist, MLR, SVM overrated** relative to their fame. So: shortlist RF/QRF + GBM/KNN +
   a spatially-explicit option (GWR/RK) when n is small or terrain is complex, and **benchmark them on the
   same CV** — pick on measured performance, not habit.
3. **Tune modestly.** RF: ntree ~200–1000 (diminishing returns past a few hundred), mtry ≈
   √p, min node size. Use grid/random search with **cross-validation**. Over-tuning rarely
   pays; feature selection and spatial handling matter more.
4. **Get uncertainty.** Prefer **QRF** for per-pixel prediction intervals. For neural nets,
   bootstrap (model-error variance) + a mean-variance head (data noise). Validate the
   uncertainty with **PICP** (≈ nominal) and accuracy plots — an ML map without calibrated
   uncertainty is half-done.
5. **Interpret.** Global **variable importance** (permutation, mean-decrease-in-accuracy)
   and local **SHAP/PDP/ALE**. Recurring top predictors: soil
   depth, terrain, vegetation, parent material — often **soil covariates outrank spectral
   indices** for SOC. Three cautions: drivers of the *prediction* ≠ drivers of *confidence*;
   **attribution ≠ causation** (SHAP ranks association, not mechanism — pair with SEM/GCCM); and
   **variable importance is model-relative** — RF/Cubist/SVM give *divergent* rankings for the same data
   (Córdoba), so don't read one model's ranking as the truth about drivers. **Interpretability is the point,
   not a footnote** (Padarian): the goal of advanced ML in soil is
   to *improve understanding*, not just predict → SoilML.
6. **Validate** with the soil-map-validation
   skill (CV strategy, RMSE/ME/CCC, temporal separately, residual Moran's I).

## Reading the metrics (accuracy-metrics)
- **RMSE/MAE** magnitude · **ME/Bias** systematic error · **R²/MEC/NSE** skill (can be
  **negative** = worse than the mean) · **CCC** agreement (catches high-R²-but-biased) ·
  **PICP** interval honesty · **NRMSE** (RMSE normalized by range/mean — dimensionless, good for
  **comparing across datasets/scales**; under-used per Radočaj). If R² is negative, the model/covariates/sample
  size mismatch the regime — change the approach, don't just re-tune.

## Diagnose overfitting: train vs test gap
**RF's "overfit-proof" reputation is conditional.** Always compare training fit to an independent
holdout / CV. A large gap — Ngubo saw RF **train R²≈0.93–0.94 →
test ≈0.53–0.55** — signals memorised noise from high-dimensional inputs, heterogeneous terrain, or a
non-representative sample. In the same study **regression kriging under-fit training (R²≈0.29–0.37) yet
generalised as well or better**: strong calibration is *not* evidence of a good map. If the gap is wide,
prune covariates, add spatial handling, or switch model family — don't ship on OOB/training numbers.

## When ML isn't enough
- **Temporal change** — pure ML extrapolates poorly in time; use
  spatiotemporal setups or fuse with a process model via
  hybrid-process-ml-soc.
- **Strong non-stationarity / tiny samples** — consider
  GWR or regression-kriging.

## Pitfalls
- Defaulting to deep learning where a tuned RF matches it.
- Leaked covariates → inflated accuracy.
- Reporting predictions without calibrated uncertainty.
- Re-tuning to fix a negative R² that signals a wrong-regime model.
- Ignoring residual spatial autocorrelation (check Moran's I on residuals).
- **Trusting training/OOB fit** — RF can memorise; judge on a holdout/CV (train–test gap = overfit).
- **Reusing an RF-based feature subset for a non-RF model** — Boruta biases toward RF.

## Provenance
**v1** (ML-understanding upgrade). Distilled from Jafari, Shi, Wadoux (2019 & 2026), Hengl, Tian, Sarkar,
Rohmer, Carbajal, Parvizi, Mousavi, Ngubo, Yang & Li 2026 (**SoilML** + DL paradigms), and the ML-understanding
batch: **Padarian 2020** (meta-review: no universal winner, parsimony + interpretability), **Radočaj 2024**
(15-algorithm audit; popularity≠accuracy; NRMSE), **Padarian 2018** (CNN/multi-task; DL data-size threshold),
**Campbell 2019** (feature engineering: geophysical/spatial covariates), **Nwamekwe 2025** (feature engineering;
small-n overfitting caution), **Córdoba 2025** (QRF best in Argentina; variable importance is model-relative).
Full citations in the wiki `sources/`.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
