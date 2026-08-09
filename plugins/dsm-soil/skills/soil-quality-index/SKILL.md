---
name: soil-quality-index
description: >-
  Build, validate and interpret a Soil Quality Index (SQI) or Soil Health Index (SHI) from
  measured soil indicators — selecting a minimum data set, scoring indicators, weighting and
  aggregating them, and proving the index actually discriminates. Covers land-use and
  management comparison, degradation quantification, balanced-fertilisation diagnosis,
  structural equation modelling of soil health and its drivers, fuzzy rule-based assessment,
  and estimating indicators from machine learning and remote sensing. Use whenever the goal
  is a composite statement of soil condition rather than a map of one property. Triggers:
  "soil quality index", "SQI", "soil health index", "SHI", "minimum data set", "MDS",
  "indicator scoring", "soil health assessment", "soil degradation index", "SEM soil health",
  "soil quality indicators", "land use soil quality", "fuzzy association rules soil",
  "weighted additive index", "which indicators for soil quality".
---

# Soil Quality Index (SQI / SHI)

Forged from the DSM knowledge wiki. Anchor source:
Yuan et al. 2026 — the only study that runs
the **full factorial of the SQI recipe** on one dataset and ranks which choices matter.
Framing from Fan et al. 2025 (four
decades, 876 papers).

Sibling skills: soil-fertility-mapping (mapping
properties across space, then integrating); soil-map-validation
(validating spatial predictions). **This skill is about constructing and defending the index
itself.**

---

## 0. The one thing to understand before anything else

> **An SQI is not a measurement. It is a recipe applied to measurements.**

Yuan produced **24 different soil health
indices from the same 27 measurements** by varying the recipe. They disagree. All are
defensible.

Three consequences that govern everything below:

1. **Always report the recipe, never just the value.** MDS route, scoring function, weights,
   aggregation formula, and what the limits were relative to.
2. **SQI values from different studies are not comparable** — with one documented exception.
   Most scoring is relative to the study's own sample extremes, so the best site scores ≈1.0
   by construction. Theresa's 0.99 and Huera-Lucero's 0.40 describe different worlds; never
   place them in the same table. **The exception:** an index standardised against a
   *non-degraded reference soil* and reported as a **ratio** is claimed to be comparable
   across studies (Kuzyakov 2020 — see §4).
3. **State the support.** Point? Plot? Field? Catchment? Averaging point SQIs is *not* valid
   upscaling (Drewry 2024).

---

## 1. The four choices, ranked

```
indicators
   ↓  [1] minimum data set      ← LARGEST effect on the answer
   ↓  [2] indicator scoring
   ↓  [3] weighting
   ↓  [4] aggregation           ← smallest effect
  SQI
   ↓  [5] validation            ← the step everyone skips
```

Measured by Yuan. **Spend your care on the
MDS. Do not agonise over the aggregation formula.**

---

## 2. Step 1 — Build the minimum data set

The most consequential step. → minimum-dataset-construction

### Route A — PCA (the conventional default)

1. **Standardise** (z-score) — PCA is scale-sensitive.
2. **Test adequacy**: KMO and Bartlett's sphericity. *Most papers skip this; don't.*
   (Theresa: KMO 0.81, Bartlett p < 0.001.)
3. Retain PCs with **eigenvalue ≥ 1** AND **≥ 5% of variance**.
4. Within each PC keep indicators with `|loading| ≥ 0.9 × max|loading|` (**within 10% of the
   highest**).
5. Where several survive one PC, drop those correlated at **r > 0.6**, keeping the higher loading.
6. Weights = communality / Σ communalities, or PC variance share.

→ `soilquality::pca_select_mds(data, within = 0.10, adequacy = "warn")`; adequacy on its own is
`pca_adequacy()`. ⚠️ `within` defaults to `NULL`, which is *not* the rule in step 4 — see §10.

### Route B — Network analysis (better on Yuan's data)

1. Edges where **Spearman |r| ≥ 0.60, p < 0.01** (no normality assumption).
2. Modules by **Louvain/Blondel** modularity (gephi, or `igraph::cluster_louvain()`).
3. Keep modules with max **eigenvector centrality > 0.6**.
4. Within a module, indicators within **10% of max centrality**; tie-break by **weighted degree**.
5. Weights = centrality / Σ centralities in module.

→ `soilquality::na_select_mds()`. ⚠️ Louvain is randomised: fix `seed`, then **vary it** to check
the selection is real, and pass `component = "all"` on a disconnected network (§10).

### Route C — Expert opinion
Legitimate when data are incomplete or the question is specific.
Chaudhry **deliberately rejected PCA** because
missing data distorts it. Publish the weights.

### The grouping decision — matters as much as the route
| Scheme | Grouping | Yuan's fidelity |
|---|---|---|
| MDS | none | lowest |
| RMDS | physical / chemical / biological | middle |
| **EMDS** ⭐ | **five ecosystem functions** | **R² 0.77 / 0.74**, most stable |

The five functions: **carbon cycling · nutrient cycling · physical structure stability ·
buffering & filtration · biodiversity maintenance**. Pick the highest **norm value**
`N_ik = √(Σ u²_ik·λ_k)` per group. → soil-ecosystem-multifunctionality

→ `soilquality::assign_function_groups()`, then `groups =` on either selector and
`selector = "norm"` on the PCA route. Ungrouped selection routinely leaves **entire functions
unrepresented** — on the package's structured fixture, 2 of 4 covered ungrouped versus 4 of 4
grouped. ⚠️ Nothing in the usual indicator vocabulary measures **biodiversity**, so most indices
cover four functions; say so instead of implying five.

⚠️ **Do not group by physical/chemical/biological.** Maaz
tested that structure by CFA and found **no statistical support** for it; Yuan independently
found functional grouping beat it. Two methods, two continents, same verdict.

### Choosing a route
| Situation | Route |
|---|---|
| Standard dataset, conventional reviewable recipe | **PCA** |
| Non-normal indicators, want fewer + more sensitive | **Network analysis** |
| Missing data, small n, or a specific functional question | **Expert opinion** |
| n in the hundreds, want structure *and* weights from data | **CFA/SEM** (§6) |
| **Any of them** | **group by ecosystem function** |

**Cheap robustness check:** run two routes, keep the intersection — `soilquality::mds_consensus()`.
On Yuan's tillage data **SOC, DOC and soil compaction** survived all six variants. ⚠️ An empty
intersection is a finding, not a bug: PCA selects for variance, the network for centrality, and on
a structured dataset they can agree on nothing.

**Expect biology.** Data-driven selection picks more biological indicators than the
literature's usage frequency suggests — Yuan's NA route chose microbial properties for ~55%
of its MDS; Theresa's PCA returned phosphatase, urease and MBC.

---

## 3. Step 2 — Score the indicators

→ soil-indicator-scoring

**First set the direction** for every indicator: *more is better* (SOC, CEC, WHC, enzymes),
*less is better* (bulk density, compaction, salinity, metals), or *optimum* (pH, and any
agronomic window). Getting this wrong inverts that indicator's whole contribution.

```
LINEAR         more:  S = X / X_max        less:  S = X_min / X
NON-LINEAR     S = 1 / (1 + (x/x₀)^b)      b = −2.5 more · +2.5 less · x₀ = mean
OPTIMUM        more-is-better below the band, less-is-better above, 1 inside
```

⚠️ **b = ±2.5 is inherited, not derived** (traced to Yu et al.). Treat it as a tunable
default and say so.

⚠️ **Linear vs non-linear is genuinely unresolved.** Yuan finds NL > L (R² 0.65 vs 0.56);
Bilgili et al. 2017 — cited inside Yuan's own introduction — found L > NL. Practice is split.
→ linear-vs-nonlinear-scoring
**Compute both. It costs nothing. If your conclusions flip, that is the finding.**
→ `soilquality::score_sigmoid(x, direction, x0, b = 2.5)`, then `sqi_stability()` (§5) to see
whether the ranking moved.

⚠️ **Critical limits sit upstream of the function shape.** Scoring against your own sample's
`X_max` is what makes indices incomparable. For fertility, anchor limits to **crop yield**
(relative cumulative yield regressions); for contamination, to **regulatory limits**.
→ indicator-critical-limits
→ `soilquality::standardize_to_reference(x, reference, direction)` scores against a non-degraded
soil instead of your own extremes — the documented escape from incomparability. ⚠️ Its price is a
defensible reference site (same soil type, parent material, climate, undisturbed); a bad one does
not add noise, it silently rescales every index built on it.

Published limits worth reusing: pH optimum **6.5–7.0** (Arshad & Martin) or **5.5–7.0**
(Chaudhry); minimum soil depth **50 cm**.

---

## 4. Steps 3–4 — Weight and aggregate

→ sqi-aggregation

```
ADDITIVE            SQI = (1/n) Σ sᵢ                       ← avoid
WEIGHTED ADDITIVE   SQI = Σ wᵢ·sᵢ                           ← the workhorse
AREA                SQI = 0.5 · Σ stPᵢ² · sin(2π/n)         ← needs NO weights
```

**Area — read this before using it.** The formula is the **square** of each standardised
parameter (verified against Kuzyakov 2020 eq. 2);
the true polygon area would need `Σ sᵢ·sᵢ₊₁`, which would make the result depend on the
arbitrary order of indicators. Implement the square.

⚠️ **As designed it is a RATIO, not an absolute index.** Kuzyakov standardises against a
**non-degraded reference soil** (reference = 1.0) and reports
`Area_degraded / Area_non-degraded` — his worked figure gives **0.47**, "half the function
lost". *"Comparison with non-degraded soil is required."*

| Use | Standardised against | Comparable across studies? |
|---|---|---|
| **Absolute** (Yuan's adaptation) | your own sample | **no** |
| **Ratio** (Kuzyakov's design) | a non-degraded reference soil | **claimed yes** ⭐ |

The weight-independence people cite is a consequence of **taking a ratio**, not of the
formula. Use the formula without a reference and the incomparability returns. Optimum-type
parameters (pH, permeability) standardise by **distance from the optimum**; compute **per
horizon**; and note the area route **cannot assess multicollinearity**, so pair it with a real
MDS step.

**Do not use the unweighted additive index** unless you have proved it discriminates.
Maaz: it crushed **94%** of plots into the middle
20–80% band vs 61% for a weighted index. Congreves found PCA-weighted **2–10× more
sensitive**. Xue gained **11 points**
of accuracy purely by learning weights instead of fixing them.

**If you cannot defend your weights, use the area method** and remove the step.
→ `soilquality::sqi_area(s, reference)`, or `compute_sqi_df(method = "area", reference = )`.

⚠️ Note `sᵢ²` in the area formula — it penalises unevenness, so Area is **partially
non-compensatory** and is not a monotone rescaling of the weighted sum.

⚠️ **Expert weights can be flatly wrong.** Sarapatka
gave HA/FA the **lowest** weight (0.65) and SOC the **highest** (0.9); the SEM then found
HA/FA dominated the index (β = 0.77) and SOC did not (β = 0.33).
→ sqi-weighting-objectivity

**Always publish your weights.** An SQI without its weights is not reproducible.

---

## 5. Step 5 — Validate (the step everyone skips)

An SQI has **no ground truth**. Three tests, all required.
→ sqi-validation

| Test | What it checks | How |
|---|---|---|
| **Sensitivity** | does it separate? | `SI = SQI_max / SQI_min`, **plus the quantile distribution** |
| **Fidelity** | did the MDS lose signal? | R² of MDS-index vs TDS-index |
| **External** ⭐ | does it predict anything real? | **yield**, known management contrasts |

⭐ **The best validation idea in the corpus:** correlation is the *wrong* diagnostic.
Maaz's SEM and additive indices correlated at
**r = 0.96** — yet one put 94% of sites in the middle band and the other 61%. **Report the
distribution across your decision categories.** An index that calls everything "medium"
cannot inform a decision no matter how well it correlates.

**Test 4 — stability:** recompute under ≥ 2 method combinations. If the ranking flips, report
that rather than picking your favourite.

→ `soilquality::sqi_validate(x, tds, external)` returns all four and **warns** when more than
`middle_band_threshold` (default 0.8) of samples land in the middle bands; `sqi_stability(a, b)`
gives Spearman ρ per pair **plus a flag when the best or worst sample changes** — a high ρ does
not rescue a changed extreme if the extreme is what you act on. ⚠️ `external_r_max` (default 0.9)
catches the other trap: an "external" criterion that is really one of the index's own indicators.

**What nobody does:** put uncertainty on the index. Every SQI in this corpus is a point value.
→ §8.

---

## 6. Playbook — SEM for soil health and its drivers

→ structural-equation-modelling · lavaan · piecewisesem

⚠️ **First: "SEM" names three different estimators.** All three corpus papers say "SEM"; they ran
three methods with different assumptions, diagnostics and sample-size demands. **Pick by n and
design, and never judge one by another's standards.**

| | **CB-SEM** (`lavaan`) | **Piecewise SEM** (`piecewiseSEM`) | **PLS-PM** (`plspm`) |
|---|---|---|---|
| Paper | Maaz (n = 567) | Sarapatka (n = 60) | Wang (8 plots) |
| Latent variables | yes, reflective | no — observed only | composites, reflective **or formative** |
| Random effects | limited | **native, per equation** | no |
| Sample size | **hundreds** | modest | **small — its selling point** |
| Fit statistic | CFI, RMSEA, SRMR | **Fisher's C** (p > 0.05 = good) | **GoF, R², AVE, composite reliability** |

**At small n the answer is not "give up" — it is PLS-PM.** And ⚠️ **never report CFI/RMSEA/SRMR for
a PLS-PM fit**; those do not exist for it. Report GoF, R² per endogenous construct,
composite reliability/AVE for reflective blocks, and **bootstrap CIs** on the paths.

Two distinct uses. **Do not conflate them.**

**(a) SEM *as* the index** — Maaz, needs **n in the hundreds**:
CFA → second-order "soil health" factor → **adjust indicators for inherent properties**
(`soilquality::adjust_inherent()`, or `compute_sqi_df(inherent = ~ soil_type * land_use_history)`
— regress on soil type × land-use history so soils aren't penalised for their parent material;
it runs **before** selection and scoring, and its `$r_squared` tells you how much of each
indicator was inheritance rather than management)
→ handle clustering (Maaz: **ICC > 75%**, so cluster-robust or multilevel) → `ecdf()` to
quantile classes. Fit: **CFI > 0.95, SRMR < 0.08, RMSEA < 0.06, ω > 0.7**. Factor loadings
*are* the weights.

**(b) SEM to *explain* the index** — Sarapatka,
Wang: piecewise SEM with random effects,
refined by **d-separation**, fit by **Fisher's C (p > 0.05 = good)**, then decompose total
effects into direct and indirect.

⚠️ **The circularity trap.** Regressing an SQI on its own components must fit well —
Sarapatka's R² = 0.99 is largely structural, and the authors say so. **Valid:** relative path
coefficients, and paths from variables *not* in the index. **Invalid:** quoting that R² as
predictive skill.

→ `soilquality::check_circularity(index, predictors, data, allow_components = FALSE)` refuses the
overlap by default and labels the legitimate **decomposition** use when you allow it. ⚠️ Pass
`data` — renaming is not laundering: an index built on `OM` regressed against `SOC` is the same
measurement × 1.724, and only the correlation check catches it.

---

## 7. Playbook — by question

| Your question | Route | Anchor |
|---|---|---|
| **Which method should I use at all?** | run the four-choice decomposition; MDS matters most | Yuan 2026 |
| **Compare land uses / management** | PCA-MDS → non-linear scoring → weighted additive → ANOVA | Huera-Lucero |
| **Quantify degradation** | SQI as *response*; piecewise SEM to find the mediator; don't assume SOC is the signal | Sarapatka |
| **Degradation as a *fraction of function lost*** | SQI-area **ratio** vs a non-degraded reference soil; plus sensitivity/resistance vs SOC change | Kuzyakov |
| **Balanced fertilisation** | PCA-MDS → linear scoring → WAI → **validate against yield**; optimise doses, don't maximise | Theresa |
| **Soil health scoring at scale** | CFA/SEM; adjust for inherent factors; check discrimination | Maaz |
| **Fertility index specifically** | the fertility branch, incl. non-compensatory threshold routes | soil-fertility-index |
| **Land-use pressure at catchment scale** | ⚠️ change-of-support; RF ≫ GLM/GAM; expect climate/terrain to dominate | Drewry |
| **Estimate indicators from ML + remote sensing** | four input blocks (MDS · NIR/Red-Edge indices · climate · management); ANN/RF | Diaz-Gonzalez |
| **Interpretable rule-based assessment** | W-FARs: Gaussian fuzzification → mine rules → prune → **learn** rule weights | Xue |
| **What indicators do people actually use?** | SOM/SOC 610 · pH 467 · N 453 · K 399 · P 366 · texture 303 · MBC 119 | Fan |

---

## 8. ⚠️ The trap that will cost you most: chaining predictions

Chaudhry 2024, same spectra, same index:

| Route | R² |
|---|---|
| Predict 7 properties → score → weight → sum (`SQI_p`) | **0.23** |
| Predict the **index directly** (`SQI_dp`) | **0.90** |

Individual property models were fine (Cubist R² 0.35–0.93). The index destroyed the signal.

**This is the naive route every spatial SQI takes** — map each property with DSM, then compute
the index per pixel. That *is* `SQI_p`.

**What to do:**
1. If you have measured indices to train on, **test the direct route**. One extra model fit.
2. If you must chain, treat the index as **substantially less reliable than its component
   maps** and say so.
3. **Propagate, don't point-estimate** — monte-carlo-uncertainty-propagation via
   spup: draw each property from its predictive distribution *with spatial and
   cross-property correlation*, recompute the index per draw, map index **and uncertainty**.

⚠️ **The direct route's cost:** `SQI_dp` is trained against lab-measured `SQI_m`, so it is a
data-efficiency win, not a free lunch — and it makes the index a black box, losing the
indicator-level diagnosis that made an SQI actionable. State the trade-off.
→ composite-index-error-propagation

---

## 9. Why a composite at all — the SOC-alone failure

SOC/SOM is the field's most-used indicator by a wide margin (n=610 of 876 papers). Two
independent papers show it fails alone:

- Huera-Lucero — cacao monoculture had the
  **highest SOM (19.7%)** and the **lowest SQI**. Judged on organic matter, the worst land use
  ranks first.
- Sarapatka — on eroding Chernozems SOC differed
  ~7% between eroded and depositional positions while humic quality (HA/FA) differed ~70%.
  SOC monitoring would have reported almost no degradation.

**Two mechanisms, same conclusion: SOC alone is not a soil quality index.**

---

## 10. Runnable — what exists in R

### The three packages (function indexes verified 2026-08-09)

| Package | Covers | Use it for |
|---|---|---|
| **`SQIpro`** (CRAN) | six index methods — linear, regression, PCA, **fuzzy logic**, **entropy weighting**, **TOPSIS**; scoring (`score_more/less/optimum(bell)/trapezoid/custom`); `select_mds` (PCA + VIF); `sqi_anova`; `sqi_sensitivity` (leave-one-out); six `plot_*` incl. `plot_radar` | the **conventional routes**, with the widest method menu |
| **`SQI`** (CRAN) | linear · regression · PCA | a lighter subset of the same ground |
| **soilquality ≥ 2.3.0** (Carbajal, MIT, GitHub) | the **corpus methods CRAN lacks** — area/ratio aggregation, reference-soil standardisation, network-analysis MDS, functional (EMDS) grouping, distribution-based validation, circularity checking, inherent-property adjustment — plus **AHP weighting with a Consistency Ratio** | almost everything §2–§6 recommends that CRAN cannot run |

⚠️ **Check the version.** As of **v2.3.0** `soilquality` implements nearly every method this
section previously listed as having no packaged implementation. Below 1.1.0 it is the PCA-MDS →
AHP → linear → weighted-additive route only.

### The pipeline (`soilquality` ≥ 2.3.0)

```r
compute_sqi_df(
  df,
  inherent     = ~ soil_type * land_use_history,  # §6  adjust BEFORE selecting and scoring
  select       = c("pca", "network", "none"),     # §2  "none" builds the TDS index
  network_args = list(seed = 1, component = "all"),
  method       = c("weighted", "area"),           # §4
  reference    = NULL                             # §4  supply one -> Kuzyakov RATIO
)
```

Every step is also usable on its own:

```r
# §2  minimum data set
pca_select_mds(data, var_threshold = 0.05, loading_threshold = 0.5,
               within = NULL,          # <- set 0.10 for the published rule; see below
               groups = NULL, selector = c("loading", "norm"),
               adequacy = c("report", "warn", "ignore"))
na_select_mds(data, r_min = 0.60, p_max = 0.01, centrality_min = 0.6, within = 0.10,
              screen = TRUE, component = c("largest", "all"), groups = NULL, seed = 1L)
mds_consensus(data)                 # the intersection of both routes
assign_function_groups(properties)  # onto soil_function_groups (the five functions)
pca_adequacy(data)                  # KMO + Bartlett

# §3  scoring
score_higher_better() / score_lower_better() / score_optimum() / score_threshold()
score_sigmoid(x, direction = c("higher","lower"), x0 = NULL, b = 2.5)   # 1/(1+(x/x0)^b)
standardize_to_reference(x, reference, direction = c("higher","lower","optimum"))
# rule constructors for compute_sqi_*(): higher_better(), lower_better(), optimum_range(),
# threshold_scoring(), sigmoid_scoring(), reference_scoring()

# §4  weight and aggregate
ratio_to_saaty() -> create_ahp_matrix() -> ahp_weights()   # AHP weights + CR < 0.10
sqi_area(s, reference = NULL)                              # 0.5*sum(s^2)*sin(2*pi/n)

# §5  validation
sqi_validate(x, tds = NULL, external = NULL,
             middle_band_threshold = 0.8, external_r_max = 0.9)
sqi_stability(index_a, index_b, ...)   # does the RANKING survive a change of recipe?
plot_sqi_validation()

# §6  guards
check_circularity(index, predictors, data = NULL, allow_components = FALSE, r_max = 0.9)
adjust_inherent(data, indicators, inherent = ~ soil_type * land_use_history)
sensitivity_resistance(degraded, reference, carbon = "SOC")   # Kuzyakov's second method
```

**Fixtures, and which is for what.** `soil_data` (50 samples) has almost no covariance
structure — fine for scoring, weighting and aggregation, **useless** for any method that reads
the structure *between* indicators. `soil_structured` (120 samples, 40 pairs at |ρ| ≥ 0.6) is
the one for `na_select_mds()`, `mds_consensus()` and grouping. `soil_inherent` (180 samples)
carries soil type, land-use history, management and a plot id, with **ICC 0.81–0.99** — the
non-independence Maaz warned about, made visible.

### ⚠️ Three defaults that are not the published rule

1. **`pca_select_mds(within = NULL)`** — the default keeps only the **single highest-loading**
   indicator per component. That is the package's historical behaviour, **not** the literature's
   rule. Pass **`within = 0.10`** for "every indicator within 10% of the maximum loading" (§2
   step 4). `loading_threshold` is an absolute floor and `within` a relative band — different
   mechanisms, combinable.
2. **`na_select_mds()` is not deterministic.** Louvain is randomised; six runs over identical
   input returned two different data sets during the package's development. `seed = 1` makes a
   run reproducible — it does **not** make a selection robust. Vary the seed and find out. On a
   disconnected network pass **`component = "all"`**, or eigenvector centrality goes to ~0
   outside the dominant component and a genuine correlated clique is discarded whole.
3. **`adjust_inherent()` defaults to `method = "residual"`** — calling it *is* the deliberate
   act. The pipeline never adjusts unless you pass `inherent =` to `compute_sqi_df()`. And do
   not adjust by reflex: if your question is *which soil is inherently better* (siting,
   valuation, capability), adjusting destroys the answer you came for.

Two more worth knowing. `igraph` is in **`Suggests`**, not `Imports` — the package is MIT and a
hard dependency on GPL-2+ `igraph` would pull the combined work into GPL on distribution — so
the network route degrades gracefully when it is absent. And the **biodiversity** slot in
`soil_function_groups` ships **empty on purpose**: nothing in the indicator vocabulary measures
it, so an index built from these groups covers **four** functions, not five. Report it that way.

### ⚠️ What still has no packaged implementation

The list is now short. Everything else this skill recommends is runnable — see the pipeline above.

| Method | Why it matters | Section |
|---|---|---|
| **CFA loadings as index weights** (`weights_from_cfa()`) | the one route that derives weights from a measurement model instead of from assertion. `lavaan` gives the loadings; nothing carries them into an index | §6a |
| **Uncertainty on the index** | every SQI in this corpus is a point value. The method exists (monte-carlo-uncertainty-propagation via spup); a worked example does not | §8 |
| **SQI-aware path modelling** beyond the circularity guard | `lavaan` / `piecewiseSEM` / `plspm` estimate perfectly well, but none knows what an SQI is. Treat the route as documentation to follow, not a function to call | §6b |
| **W-FARs with learned rule weights** | `SQIpro::sqi_fuzzy()` is fuzzy scoring, not mined-and-weighted association rules | §7 |

**Sigmoidal scoring is no longer a gap anywhere.** `soilquality::score_sigmoid()` implements
`1/(1+(x/x₀)^b)` with `b` exposed as a parameter, and `SQIpro` covers the same space via
`score_optimum` (bell curve), `score_trapezoid` and `score_custom`.

⚠️ And the observation that used to sit here — that `SQIpro::plot_radar()` *draws* the radar
polygon while nothing *measures* it — no longer holds: `soilquality::sqi_area()` measures it,
with the reference-soil ratio.

---

## 11. Checklist

**Design**
- [ ] Function stated: fertility / environment / health / comprehensive
- [ ] Scale and **support** stated (point / plot / field / catchment) and matched to the framework
- [ ] Indicators assigned to **ecosystem functions** before selection

**Build**
- [ ] MDS route stated; adequacy tested (KMO/Bartlett) if PCA
- [ ] "Within 10% of max loading" implemented — **not** "< 10%"
- [ ] Scoring direction set per indicator (more / less / optimum)
- [ ] Scoring function stated; `b` value stated if sigmoidal
- [ ] Critical limits stated — **sample extremes or external?**
- [ ] **Weights published in full**
- [ ] Aggregation formula stated

**Validate**
- [ ] Sensitivity index reported
- [ ] **Quantile distribution** of scores reported, not just mean/range
- [ ] MDS-vs-TDS fidelity R² reported
- [ ] At least one **external** criterion (yield, known contrast)
- [ ] Recomputed under ≥ 2 method combinations; stability reported
- [ ] Inherent-property adjustment considered
- [ ] If built from predicted properties: direct-prediction route tested, or reliability caveated

**Report**
- [ ] Recipe published alongside every value
- [ ] No cross-study SQI comparison unless limits are external and shared

---

## 12. Open questions (do not paper over these)
- linear-vs-nonlinear-scoring — the corpus contradicts itself.
- sqi-weighting-objectivity — four weighting families, no head-to-head comparison exists.
- composite-index-error-propagation — why the index collapses and when to expect it.
- **Uncertainty on the index** — nobody in this corpus does it. Method exists
  (monte-carlo-uncertainty-propagation); a worked example does not.
- **Weights from a measurement model** — `weights_from_cfa()` is still unbuilt, so the CFA route
  of §6a ends at the loadings and has to be wired into the index by hand. See §10.
- **The old limit is gone.** Area/ratio aggregation, reference-soil standardisation,
  network-analysis MDS, functional grouping, distribution-based validation, circularity checking
  and inherent-property adjustment all became runnable in `soilquality` ≥ 2.3.0. This skill no
  longer recommends methods the ecosystem cannot execute — verify the version before assuming
  otherwise.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
