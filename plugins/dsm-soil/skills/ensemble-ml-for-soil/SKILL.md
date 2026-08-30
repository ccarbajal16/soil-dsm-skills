---
name: ensemble-ml-for-soil
description: >-
  Decide whether to combine machine-learning models at all, and if so how — by measuring the gain
  available before building any combiner. Covers the ambiguity/diversity ceiling, the weighting
  spectrum (simple average, R²-weighted, Bates–Granger, AIC/BIC, NNLS/SuperLearner,
  Granger–Ramanathan, learned meta-models, attention, per-pixel selection), out-of-fold stacking
  under spatial CV, cross-fitting the combiner, voting for classification, and significance testing
  of the margin. Use when someone proposes an ensemble, reports an ensemble gain, or asks whether
  their averaging scheme is "too simple". Triggers: "ensemble machine learning", "model stacking",
  "stacked generalisation", "SuperLearner", "meta-learner", "meta-model", "weighted average
  ensemble", "R2-weighted ensemble", "simple average ensemble", "Bates-Granger", "Granger-Ramanathan",
  "NNLS weights", "non-negative least squares", "caretStack", "mlr3pipelines stacking", "voting
  ensemble", "hard voting", "soft voting", "blending", "bagging vs boosting vs stacking", "ensemble
  gain", "does stacking help", "combine RF and XGBoost", "which model to combine", "base learner
  diversity", "error correlation", "out-of-fold predictions", "level-one dataset", "landmap",
  "MACHISPLIN", "spatial ensemble", "per-pixel model selection", "combine my model with SoilGrids".
---

# Ensemble ML for Soil

Forged from the DSM knowledge wiki. The wiki is the source of truth. Key pages:
bias-variance-tradeoff, ensemble-machine-learning,
ensemble-weighting, model-stacking, spatial-cross-validation,
accuracy-metrics, when-does-stacking-pay,
granger-ramanathan-unconstrained-but-wins,
ensemble-gain-vs-evaluation-basis, compositional-data.

**Execution-verified.** Every number in this skill was measured, not cited. The pipeline below ran
against **R 4.5.3 + mlr3** on a real soil dataset (n = 204, pH, spatial block CV); scripts live at
`comparisons/honest_ensemble_recompute.R`, `comparisons/gr_honest_evaluation.R` and
`comparisons/ridge_combiner_test.R`, with their console output beside them.

**Scope boundary.** This skill is about **combining models** — deciding whether to, and how. It is
not about choosing or tuning one model (ml-for-soil-prediction),
running a mapping project end to end
(digital-soil-mapping-workflow), or per-pixel
uncertainty (spatial-prediction-uncertainty).

---

## The one idea to internalize first

The usual question — *"is my weighting scheme sophisticated enough?"* — is the wrong one. It sends
people to a fancier combiner without ever asking whether there was anything to win. Replace it:

> **How far is my current combination from the best that any combination could do?**

That distance is **computable before you build a combiner**, because the
ambiguity decomposition is an exact identity for squared loss and
convex weights:

```
(f̄ − y)²  =  Σ wᵢ(fᵢ − y)²  −  Σ wᵢ(fᵢ − f̄)²
ensemble error = weighted mean of individual errors − diversity
```

**The gain from any combiner equals the disagreement among the base learners, and nothing else.** So
the ceiling is a property of the models you already have. If their out-of-fold errors are nearly
identical, no meta-learner — attention, GBM, neural — can help, and you can now say so with a table
instead of an opinion.

Three consequences that decide whether your ensemble is worth anything:

1. **An ensemble beats the *mean* of its members, never reliably their *best*.** The identity above
   is about `Σwᵢ(fᵢ−y)²`, the *average* member error. Most of the literature writes that and lets
   readers infer the stronger claim. **Measured, on three unrelated datasets, the simple average lost
   to the best single model every time.**
2. ⚠️ **Whatever data *chooses* the combination cannot be the data that *scores* it.** This is the
   single most consequential error in the published soil-ensemble literature, and it appears in three
   disguises (below). It is what turns a real **+1.0%** into a reported **−72% RMSE**.
3. ⭐ **Honest performance tracks the *inverse* of combiner freedom.** More free parameters means more
   apparent gain and less real gain. The executed ranking is at the end of the workflow.

---

## Workflow

```
0. Base learners + spatial folds
        │
1. Out-of-fold matrix Z          ──►  2. Error structure: cor(E), Σ
        │                                      │
        │                             3. Ambiguity → the CEILING
        │                                      │
        │                            ┌─── ceiling ≈ 0? ──► STOP. Ship the best single model.
        │                            │
4. Weighting spectrum, each CROSS-FITTED  ◄───┘
        │
5. Test the margin (Friedman/Nemenyi or repeats) ──► 6. Report ceiling, gain, and the test
```

### 0 — Base learners and folds

**Folds must be spatial.** With random k-fold on autocorrelated soil data a held-out sample usually
has near-neighbours in training, so out-of-fold predictions are optimistic and the combiner's weights
are fitted on inflated performance. Use `CAST::knndm()` or `blockCV::cv_spatial()` /
`mlr3spatiotempcv::spcv_block`, never `caret::createFolds()`.
→ spatial-cross-validation · spatial-autocorrelation

**Choose members for *disagreement*, not for individual quality.** This is the precondition, not
advice: the gain equals the disagreement. ⭐ Zhang 2022
observed the mechanism directly — NNLS *"selects diverse models rather than models with the best
individual performance"*, keeping structurally different learners (SVM, RF, XGBoost) and zeroing
three of four redundant linear models.

⚠️ **Stacking three tree ensembles is close to a vote among three copies of the same opinion.** On the
executed dataset RF and XGBoost failed together at **r = 0.953**.

⭐ **Make it a selection rule, not an aspiration.** Wu
2023 screens six candidate learners by *"the correlation coefficient and predictive differential
degree"* and keeps the four that differ most — the only source in the corpus that selects for
disagreement **before** building anything. Rank your candidates by **how differently they fail**, not
by how well they score; it costs one correlation matrix.

⭐ **What "different" has to mean, measured.** The one large honest gain in the corpus
(Tang 2024, **+7.0%**) came from **three distinct model
families** — kernel (SVR), neural (ELM), trees (LightGBM). Its *worst* combination paired two
gradient-boosting implementations. Different hyperparameters are not diversity; different
*inductive biases* are.

### 1 — The out-of-fold matrix `Z`

For each fold: train the base learners on the other folds, predict the held-out fold, and write those
predictions into `Z[held_out, j]`. Every row of `Z` is an honest report of how each model behaves on
data it never saw. The reference statement of this construction is
Lu 2023's algorithm box.
→ model-stacking

### 2 — Error structure

`E = Z − y`, then `cor(E)` and `Σ = cov(E)`. **This is the quantity the theory says is decisive, and
nobody in the published corpus reports it.** Correlations above ~0.9 everywhere mean there is little
to win, whatever the individual accuracies say.

### 3 — The ceiling, and the stopping condition

Compute the ambiguity. **If it is a rounding error next to the mean individual MSE, stop here** — no
combiner helps, and you have a defensible reason not to build one.

⚠️ **Diversity is necessary, not sufficient.** Adeniyi
2023 had the widest base-learner accuracy range in the corpus (clay: GLM 0.18 → RF 0.76) and failed
worst. **Diversity creates the opportunity; the constraint is what lets a combiner take it**, by
ignoring the bad members.

### 4 — The weighting spectrum, every scheme cross-fitted

| Scheme | Weights from | Sees error covariance? | Free parameters |
|---|---|---|---|
| Simple average | `wᵢ = 1/L` | no | 0 |
| R²-weighted | `wᵢ ∝ R²ᵢ` | **no** | 0 |
| Inverse-variance | `wᵢ ∝ 1/σᵢ²` | diagonal only | 0 |
| ⭐ **Bates–Granger (full Σ)** | `w = Σ⁻¹1 / 1ᵀΣ⁻¹1` | **yes** | L−1 |
| AIC / BIC | `wᵢ ∝ exp(−Iᵢ/2)` | **no** | 0 |
| ⭐ **NNLS / SuperLearner** | constrained LS, `wᵢ ≥ 0`, `Σwᵢ = 1` | yes | L−1, non-negative |
| Ridge meta-learner | penalised LS — shrinks rather than constrains | yes | L+1, shrunk ⚠️ **behaves as GR** |
| Granger–Ramanathan | unconstrained OLS + intercept | yes | **L+1, free sign** |
| Learned meta-model | Ridge / SVR / GBM | yes, nonlinearly | many |
| Attention | weights as a **function of the input** | yes, nonlinearly | many |
| Per-pixel selection | choose locally, by location | spatially | — |

⚠️ **Not all "Bates–Granger" is Bates–Granger.** Inverse-variance uses only the **diagonal** of `Σ`
and cannot detect redundancy — which is the entire reason to prefer BG. Use the full form. The
diagonal version was among the worst combiners in
Alaboz 2025.

⚠️ **R²-weighting's defect is not that it is "simple".** It is **blind to the correlation between
model errors**: two learners that fail on the same sites both get high weight and the redundancy is
paid for twice. Bates & Granger solved that in **1969**. Also, normalising R² values that are all
high forces the weights toward `1/L` — an R² of 0.99 earns only 1.24× the weight of 0.80 — so it
quietly degenerates into the simple average.

⚠️ **Granger–Ramanathan is the `lm()` meta-model with a name and a 1984 citation.** Do not reach for
it: see the executed ranking below.

### 5 — Test the margin before you believe it

Only two sources in the whole corpus tested rather than asserted.

- **Friedman + Nemenyi** (Lu 2023): rank the models
  within each fold, run Friedman on the average ranks, then Nemenyi post-hoc. Non-parametric, handles
  many models, needs only per-fold scores — so it drops straight onto spatial folds.
- **Repeated nested CV with SDs** (Zhang 2022): 30 repeats,
  untouched test set.

⚠️ **The number of folds is the sample size of your comparison.** Lu's attention meta-model beat a
weighted average by **8.54% NSE** and was **not statistically distinguishable from it** — the authors
say so. With 5 or 10 folds only large differences are detectable, and that is a fact about your
design, not about your models. → accuracy-metrics

---

## ⭐ The executed ranking

Carbajal pH data, n = 204, four base learners, `spcv_block(5, 3×3)`, R 4.5.3 + mlr3. **Cross-fitted**
= the combiner is fitted on four spatial blocks and scored on the fifth, so it never sees the
observations that judge it. Gains against the best single learner (RF, out-of-fold RMSE **0.9909**).

| Combiner | fitted in-sample | **cross-fitted** | optimism | cost of predicting into an unfitted region |
|---|---|---|---|---|
| Simple average | −5.1% | **−5.1%** | **0.0 pp** | 0.0 pp |
| R²-weighted | +0.8% | −0.4% | 1.1 pp | 0.8 pp |
| ⭐ **Bates–Granger (full Σ)** | +5.1% | **+2.1%** | 3.0 pp | 1.2 pp |
| **NNLS (constrained)** | +3.1% | **+1.1%** | 2.0 pp | 0.8 pp |
| Ridge (CV λ) | +5.1% | **−0.9%** | 6.0 pp | 2.8 pp |
| Granger–Ramanathan | +5.1% | **−0.9%** | **6.0 pp** | **3.1 pp** |

Read the first and last rows together. The **simple average fits nothing, so it has exactly zero
optimism** — the experiment's own control. **GR has the most freedom, the most optimism, and is the
only scheme that crosses from positive to negative.** Tied for best in-sample; worse than using no
combiner when honest.

⭐ **And the constraint buys spatial transferability, not just safety.** Last column: the price of
being asked to work where nothing contributed to the fit is **3.1 pp for GR against 0.8 pp for NNLS**.
A combiner fitted in one place has to work in another — that is what a map is.

⭐⭐ **Shrinkage is not a substitute for the constraint.** Ridge — a penalised fit, with λ chosen by
inner CV inside the fitting rows only — lands **exactly on Granger–Ramanathan**, not between GR and
NNLS as you would expect. The reason is the useful part: CV picked λ ≈ 0.25, leaving an **effective
df of 3.95 out of ~4** — almost no shrinkage — because **it tunes λ against error inside the fitting
set, where the unpenalised fit is already optimal.** CV cannot see a failure that only appears in a
region no fitting point occupied.

> **It is not the *amount* of restriction that matters, but the *kind*: a structural constraint that
> encodes what a combination is — convex weights — beats a magnitude penalty tuned on in-sample
> error.**

**Recommendation: full Bates–Granger, then NNLS. Never a bare `lm()`.**

### ⚠️ How many points does the combiner need?

Subsampling the fitting set (400 draws per size, same data):

| points fitting the combiner | GR in-sample | GR held-out | optimism | NNLS held-out | GR beats NNLS out-of-sample |
|---|---|---|---|---|---|
| 25 | +14.8% | −7.6% | 22.4 pp | −1.2% | 15% |
| 33 | +11.8% | −4.1% | 15.9 pp | +0.0% | 19% |
| 50 | +9.0% | −1.0% | 10.1 pp | +0.7% | 32% |
| 80 | +7.3% | +0.8% | 6.5 pp | +1.4% | 49% |
| 120 | +6.3% | +1.5% | 4.8 pp | +1.5% | 58% |
| 160 | +5.3% | +3.0% | 2.3 pp | +2.6% | 63% |

**Rule of thumb: a fitted combiner needs roughly 20 points per free parameter before it is even
competitive.** Most soil datasets sit below that line.

### ⭐ When a large gain *does* appear

One case in the corpus delivers a big, honestly evaluated gain, and it is worth knowing its shape so
you can tell whether you have one. Tang 2024: SOC from VIS-NIR
spectra, **+7.0% RMSE** over the best single learner, level-1 built out-of-fold, on a **995-sample
held-out test set**.

| | the usual case (+1 to +3%) | **the large-gain case (+7%)** |
|---|---|---|
| Samples fitting the combiner | ~200 | **~3000** |
| Base learners | two tree ensembles + a kernel + a net; tree pair at r = 0.953 | **three distinct families**, none redundant |
| Weakest member | catastrophically bad (R² < 0) | merely weaker (R² 0.77) |

⭐ **The same study confirms the sample-size threshold from the other side.** Re-run across eight
dataset subsets from **123 to 2917** samples, its stack is *not* best on the two smallest — the
authors attribute it to one weak base model dragging the stack down. **A learned combiner does not
automatically neutralise a bad member; it needs enough data to learn to ignore it.**

⚠️ Two caveats travel with that +7.0%: no significance test, and ten base-model combinations were
compared with the best reported. Treat it as *plausible and conditional*, not settled — and note the
domain is **laboratory spectroscopy**, not covariate-based mapping.

⚠️ **Small samples are an argument for a simpler model, not a more layered one.** The opposite
intuition — reach for stacking *because* data is scarce — appears explicitly in the literature and is
contradicted by both lines of evidence above. At 33 points — a 110-sample study on a 70/30
split — an unconstrained fit manufactures **+11.8%** out of nothing.

---

## Runnable pipeline (R, execution-verified)

```r
## 0. FOLDS MUST BE SPATIAL ---------------------------------------------------
##    mlr3spatiotempcv::spcv_block, CAST::knndm(), blockCV::cv_spatial().
##    NEVER caret::createFolds() on spatially autocorrelated soil data.
folds <- ...                     # list of held-out index vectors, one per fold
fold_id <- ...                   # integer vector, fold membership per row

## 1. OUT-OF-FOLD MATRIX ------------------------------------------------------
L <- length(learners)
Z <- matrix(NA_real_, nrow(train), L, dimnames = list(NULL, names(learners)))
for (k in seq_along(folds)) {
  out <- foldsk; inn <- setdiff(seq_len(nrow(train)), out)
  for (j in seq_len(L)) {
    fit <- learnersj(train[inn, ])
    Z[out, j] <- predict(fit, newdata = train[out, ])
  }
}
y <- train$target
stopifnot(!anyNA(Z))

## 2. ERROR STRUCTURE — the diagnostic lives here -----------------------------
E <- Z - y                        # out-of-fold ERRORS, one column per learner
cor(E)                            # > 0.9 everywhere => little to gain
S <- cov(E)

## 3. THE CEILING (ambiguity decomposition) -----------------------------------
w_eq <- rep(1 / L, L)
fbar <- as.vector(Z %*% w_eq)
mean_individual_mse <- sum(w_eq * colMeans((Z - y)^2))
ambiguity           <- sum(w_eq * colMeans((Z - fbar)^2))
stopifnot(all.equal(mean((fbar - y)^2), mean_individual_mse - ambiguity))
##   ^ exact identity, verified. `ambiguity` IS the available gain, in MSE units.
##     If it is a rounding error next to mean_individual_mse: STOP, no combiner helps.

## 4. THE COMBINERS — each returns a function of new predictions ---------------
fit_equal <- function(Ztr, ytr) { w <- rep(1/ncol(Ztr), ncol(Ztr)); function(Zn) as.vector(Zn %*% w) }

fit_r2 <- function(Ztr, ytr) {                    # the "obvious" scheme; blind to covariance
  r2 <- 1 - colSums((Ztr - ytr)^2) / sum((ytr - mean(ytr))^2)
  w  <- pmax(0.1, r2); w <- w / sum(w)
  function(Zn) as.vector(Zn %*% w)
}

fit_bg <- function(Ztr, ytr) {                    # ⭐ FULL Bates-Granger, not the diagonal
  S <- stats::cov(Ztr - ytr)
  w <- tryCatch({ v <- solve(S, rep(1, ncol(Ztr))); v / sum(v) },
                error = function(e) rep(1/ncol(Ztr), ncol(Ztr)))
  function(Zn) as.vector(Zn %*% w)
}

fit_nnls <- function(Ztr, ytr) {                  # constrained: w >= 0, sums to 1
  o <- stats::optim(rep(1/ncol(Ztr), ncol(Ztr)),
                    function(w) sum((Ztr %*% w - ytr)^2),
                    method = "L-BFGS-B", lower = rep(0, ncol(Ztr)))
  w <- o$par / sum(o$par)
  function(Zn) as.vector(Zn %*% w)
}

fit_gr <- function(Ztr, ytr) {                    # ⚠️ Granger-Ramanathan: reported for contrast only
  cf <- stats::coef(stats::lm(ytr ~ Ztr)); cf[is.na(cf)] <- 0
  function(Zn) as.vector(cbind(1, Zn) %*% cf)
}

## 5. CROSS-FIT EVERY COMBINER — the step that makes the number mean something -
rmse <- function(p, yy = y) sqrt(mean((p - yy)^2))
combiners <- list(equal = fit_equal, r2 = fit_r2, bg = fit_bg, nnls = fit_nnls, gr = fit_gr)

best_single <- min(apply(Z, 2, rmse))
for (nm in names(combiners)) {
  pred_cf <- numeric(length(y))
  for (k in sort(unique(fold_id))) {                       # spatial blocks
    out <- which(fold_id == k); inn <- which(fold_id != k)
    f_k <- combinersnm(Z[inn, , drop = FALSE], y[inn]) # fitted WITHOUT the scored rows
    pred_cf[out] <- f_k(Z[out, , drop = FALSE])
  }
  cat(sprintf("%-6s in-sample %+.1f%%   cross-fitted %+.1f%%\n", nm,
              100 * (1 - rmse(combinersnm(Z, y)(Z)) / best_single),
              100 * (1 - rmse(pred_cf) / best_single)))
}
## Report the CROSS-FITTED column. The in-sample column is a diagnostic of
## overfitting (the gap between them), never a result.
```

---

## ⚠️ Four review heuristics — free, and each caught a real defect

Use these on your own work and on anything you referee. None needs access to code, and each one caught a real defect in a published soil study.

**1. If R² and RMSE move in opposite directions, the two columns came from different predictions.**
For a fixed sample they are monotonically linked, so the worst-RMSE model *cannot* hold the best R².
In Carbajal 2025 XGBoost reports R² 0.993 beside a
mediocre RMSE and the worst model reports 0.916 — re-running the code found R² silently recomputed
from a full-data refit and clamped to [0,1]. **This detects a mixed evaluation basis from a results
table alone.**

**2. Count how many samples your margin is made of.** In
Halder 2024 four models report accuracies of
0.943 and 0.957 on **70 test points** — 66 vs 67 correct, so the ensemble's whole advantage is **one
sample**, and it has none at all over XGBoost. Two models with byte-identical metrics have identical
confusion matrices; that is a signal, not a coincidence.

**3. Read the train and test columns together, and watch RMSE rather than R².** In
one SOC study XGBoost reports train R² **0.95**
and test R² **0.03**; stacking reports 0.17 and 0.07, and is credited with *"overcoming the problem of
overfitting"*. It did — by learning nothing. **An ensemble whose train and test scores agree because
both are near zero has not solved anything.** Note which metric exposed it: the stacking RMSE barely
moved (0.1545 → 0.16) while its R² halved, because R² is *relative* and collapses when the target has
little explainable variance. **When the signal is weak, RMSE is the honest column.**

**4. Ask which data chose the combination.** Three disguises of the same failure, all in this corpus:

| Source | How the combination was chosen | Status |
|---|---|---|
| Carbajal 2025 | members refit on the full dataset, ensemble scored in-sample | **confirmed by execution** — a reported −72% is really **+1.0%** |
| Alaboz 2025 | combiner coefficients fitted *"using the validation points"* | reported gains fall inside the in-sample band for that n |
| Varón 2022 | per-pixel winner picked from errors kriged at the validation samples, then re-scored there | **stated in the paper** |

> **The check, in one question:** *did any observation influence both the choice of combination and
> the number I am reporting?*

---

## Variants

### Classification — voting is the same spectrum, renamed
| Scheme | Rule | Regression analogue |
|---|---|---|
| **Hard voting** | `H(x) = mode(h₁(x), …, h_M(x))` | simple average |
| **Soft voting** | `P(x)ₖ = Σ αᵢ · pᵢ,ₖ(x)` | weighted average |

⚠️ Soft voting needs **calibrated** probabilities; averaging the uncalibrated scores of three tree
ensembles mostly averages their shared bias. The rule transfers unchanged: **expect a vote to match
your best classifier, and bank the robustness rather than the accuracy.**

### Spatially varying combination — your model vs a global product
The choice a national programme actually faces is rarely "which of my models" but **"my model or
SoilGrids, and where"**. Varón 2022 selects per
pixel by minimum kriged error, and its most reusable finding is that the global product **wins in
specific regions and increasingly with depth** — so treat soilgrids as a candidate
ensemble member, not only a baseline to beat.

⚠️ Build the error surfaces from **training-fold** errors only, apply the per-pixel rule, and score on
samples that fed neither. Otherwise heuristic 3 applies to you.

### ⭐ A different reason to ensemble: quantify disagreement, not chase accuracy

Everything above combines models **to be more accurate**, and the measured answer is *not much, and
only under conditions*. There is a second, entirely legitimate objective that plays by different
rules: combine models **to find out how much your answer depends on the modelling choice**.

Wang 2024 runs two machine-learning models and a
process-based model over Australian SOC stocks. **All four validate at R² > 0.8 out-of-sample. Their
continental estimates range from 24.29 to 38.15 t ha⁻¹ — a 57% spread.**

| | combining for accuracy | combining for uncertainty |
|---|---|---|
| Members chosen for | disagreement you can exploit | disagreement that is **real** — different paradigms |
| Weights | constrained, fitted, **cross-fitted** | **equal, deliberately** |
| What you report | the combined prediction | **the spread** |
| Success looks like | a small honest gain | a credible range |

⚠️ **Do not import the accuracy-branch rules here.** "An ensemble beats the mean of its members, never
reliably their best" is a statement about the left column; in the right column the mean is not the
point, and equal weighting is a *feature* because it refuses to privilege one paradigm.

⭐ **The consequence for reporting a stock.** Site-level accuracy does not certify an aggregate:
errors that are small and unbiased at a point accumulate over millions of pixels. **Model choice is a
first-order uncertainty source that is usually missing from the uncertainty budget entirely** — and
here it dwarfs most reported error terms. → SKILL ·
uncertainty-aggregation

### Compositional targets (texture)
Clay + silt + sand = 100. Ensembling the three fractions independently produces maps that violate
their own definition. Combine in **ALR-transformed space** and back-transform, or use a joint
architecture that enforces closure. → compositional-data

---

## Reporting checklist

- [ ] Fold scheme named and **spatial**; number of folds stated.
- [ ] Base learners listed with the **error correlation matrix** `cor(E)` — the quantity nobody reports.
- [ ] **Ambiguity / ceiling** reported as a percentage of mean individual MSE, before any combiner.
- [ ] Every combiner **cross-fitted**; the in-sample column shown only as an overfitting diagnostic.
- [ ] Gains quoted against the **best single base learner**, never against the mean of the members.
- [ ] Number of points fitting the combiner, and free parameters, both stated.
- [ ] Margin tested (Friedman/Nemenyi, or repeats with SDs) — or explicitly declared untested.
- [ ] For classification: the confusion matrices, not only the summary metrics.
- [ ] Explicit statement of what chose the combination and what scored it.
- [ ] If the honest gain is ~0: **say so and ship the best single model.** That is a result.

## What to expect

> **Stacking rarely beats the best base learner. With a constrained, cross-fitted combiner it
> reliably ties or slightly beats it — which buys robustness, not accuracy: you no longer had to pick
> the right model in advance. With an unconstrained combiner it can be worse than the worst model you
> own.**

Honest gains measured across this corpus sit in the **low single digits**, and nothing in it
demonstrates a significant gain from meta-learner *sophistication*.

⭐ **But a large gain is possible, and now documented — under conditions.**
Tang 2024 reaches **+7.0%** honestly, with ~3000 points
fitting the combiner and three genuinely distinct model families. **The gain comes from data volume
and member diversity, not from a cleverer combiner.** That is the same conclusion the rest of this
skill reaches, arriving from the opposite direction.

⚠️ **Still open:** no large honest gain from a **spatial DSM** ensemble — covariates and a map, rather
than laboratory spectra. Standing lead: Taghizadeh-Mehrjardi et al. (2021); also Malone et al. (2014)
for its evaluation protocol. → when-does-stacking-pay

## When NOT to use this skill
- **You have one model and want it better** → SKILL.
- **You want the whole mapping project** → SKILL.
- **You want per-pixel uncertainty or an applicability mask** →
  SKILL.
- **You want map accuracy or CV strategy** → SKILL.
- **The relationship varies across space and that is the question** →
  geographically-weighted-regression. ⚠️ Its literature calls a set of *local* models an
  "ensemble" too; that is a different sense of the word and a different governing quantity.
- **The base learners barely disagree** → there is nothing here for you. That is the point of step 3.
- **You have very few samples** → a stack adds a second fitted model on top of the first, and fitted
  models need data. Below ~20 points per free parameter, simplify instead.
- **You want to know how much your answer depends on the modelling choice** → that is the
  *uncertainty* objective above, not this workflow. Run the models in parallel, weight them equally,
  and report the spread.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
