---
name: spatial-statistics-areal
description: >-
  Analyse spatial association and spatial dependence on areal (lattice/polygon) data for ANY
  variable — global and local Moran's I, LISA hot/cold spots and spatial outliers, bivariate Moran
  and BiLISA, Lee's L, spatial weights matrices and their robustness, Rao's-score (ex-Lagrange
  multiplier) diagnostics, and spatial regression (SLX, SAR, SEM, SDM, SDEM) with LeSage-Pace
  direct/indirect/total impact decomposition. Use when the question is about association,
  explanation or spillover across zones rather than prediction of a surface — for example relating
  cumulative forest loss to SOC stocks across the zones of a forest region. Triggers: "spatial
  autocorrelation", "Moran's I", "LISA", "hot spot analysis", "bivariate Moran", "BiLISA",
  "spatial weights matrix", "queen contiguity", "Lagrange multiplier test", "LM test spatial",
  "SAR model", "SEM model", "spatial lag", "spatial error", "SDM", "SDEM", "spatial econometrics",
  "spillover", "direct indirect effects", "impacts", "spdep", "spatialreg", "GeoDa", "areal data",
  "deforestation and soil carbon", "zone-level analysis", "district-level analysis", "PySAL",
  "libpysal", "esda", "spreg", "splot", "Moran_Local", "queen contiguity Python".
---

# Spatial Statistics on Areal Data

Forged from the DSM knowledge wiki. The wiki is the source of truth. Key pages:
spatial-autocorrelation, lisa, bivariate-spatial-association,
spatial-spillover, areal-data-support,
exploratory-spatial-data-analysis, spatial-weights-matrices,
spatial-regression-models, zonal-statistics, spdep,
spatialreg, pysal.

**Toolchain-agnostic.** The statistics are the same in **R** (`spdep`/`spatialreg`) and **Python**
(`libpysal`/`esda`/`spreg`). Both pipelines below were **verified by execution**, and cross-checked
against each other on the same data: given an identically-built W they agree to 4 decimal places
(see *Cross-implementation check*).

**Scope boundary.** This skill works on **polygons with one value each** — districts, municipalities,
fields — where the goal is **association, explanation and spillover**. It is *not* the DSM prediction
stack. If the goal is a continuous map of a soil property from covariates, use
digital-soil-mapping-workflow; for map accuracy
use soil-map-validation; for per-pixel uncertainty use
spatial-prediction-uncertainty. Different
support, different objective, different validation logic.

## The one idea to internalize first

**Every number this skill produces is conditional on two choices you make, not on the data: the
zones (support) and the neighbour definition (W).** Change the zones, or swap queen contiguity
for KNN-8, and Moran's I, the cluster map, the model selection and the spillover estimates all move.
So the method is not "compute the statistic" — it is **compute it across a family of specifications
and report what survives.** A result that appears under queen but not under KNN-8 is a property of
the boundary file, not of the world.

Two corollaries that decide whether your analysis is credible:
- **ESDA generates hypotheses; regression adjudicates them.** A bivariate Moran between forest loss
  and SOC is equally consistent with deforestation degrading the carbon sink and with both variables
  tracking elevation and rainfall. Only a model with covariates can separate them — and even then,
  not causally.
- **Aggregation manufactures autocorrelation.** Averaging pixels into zones removes within-zone
  variance, so the aggregated variable is smoother and more autocorrelated than the underlying field.
  Part of the Moran's I you measure was created by your own zonal statistics.

## Workflow

```
0. Support & projection  →  1. W family  →  2. Global (uni + bivariate)  →  3. Local (LISA/BiLISA)
                                                                                      │
6. Report what survives  ←  5. Impacts & residuals  ←  4. Model family (RS → SLX/SAR/SEM/SDM/SDEM)
```

### 0 — Fix the support, then the projection
Choose the analysis unit and **defend it** (areal-data-support):

| Question is about… | Analyse at… |
|---|---|
| governance, policy, tenure, subsidies | administrative units — the intervention happens there |
| a biophysical process (erosion, hydrology) | watershed / landform units, not administrative zones |
| the soil property field itself | stay at pixel support — use DSM, not areal econometrics |

Reproject to a **metric planar CRS** appropriate to your study area (the relevant UTM zone, or a
national projected system) before anything spatial. Aggregate rasters with
zonal-statistics and **keep the pixel count per zone** — it is your evidence weight.

### 1 — Build a family of W, never one W
spatial-weights-matrices. Minimum: **Queen, Rook, KNN-4, KNN-8**, row-standardised
(`style="W"`). Add a distance-band sweep if the mechanism has a plausible physical range —
Guo et al. (2013) found an association only beyond
6,000 m that contiguity would have missed entirely. **Count no-neighbour units and report the count.**

### 2 — Global association
Univariate `moran.test()` / `moran.mc()` per variable, across every W. Then bivariate
(bivariate-spatial-association):
- **`moran_bv(x, y, listw, nsim=999)`** — directional: X here vs Y **next door**. Asymmetric —
  `I_xy ≠ I_yx`. State which variable you lagged and why.
- **`lee.test(x, y, listw)`** — Lee's L, symmetric, and it *factorises* into each variable's spatial
  smoothing × the correlation of their lags. Report **both**: `I_xy` alone cannot tell a genuine
  co-pattern from two independently clustered maps.

⚠️ **Do not read Moran's I as a strength parameter.** It is the score/LM test at ρ = 0 and is optimal
only near ρ = 0 (Li, Calder & Cressie 2007). Its magnitude
depends on W and n, so cross-study comparison is meaningless. To *measure* dependence use **APLE**
(`spatialreg::aple`). **Test with I, measure with APLE.**

### 3 — Local association (LISA / BiLISA)
lisa. Quadrants: HH hot spot, LL cold spot, HL and LH spatial outliers.
- Use **permutation** inference (`localmoran_perm`, `localmoran_bv`) or exact/saddlepoint
  (`localmoran.exact`, `localmoran.sad`) when neighbourhoods are small.
- ⚠️ **Never the normal approximation.** The local null is leptokurtic — kurtosis ≈ 8 vs 3
  (Anselin 1995) — and it **over-rejects**
  (Bivand et al. 2009).
- ⚠️ **Adjust for multiple comparisons and say how** (`p.adjust`, FDR or Bonferroni). *n* correlated
  tests; raw p < 0.05 across several hundred zones is not a finding.
- ⚠️ **Under significant global autocorrelation, call them "where the pattern concentrates", not
  "anomalies".** Anselin's simulation: the local null's mean shifts to 1.078 at ρ = 0.9, so
  "significant" locals can be ordinary features of the process.
  → lisa-significance-under-global-autocorrelation
- **Leverage check:** recompute the global statistic without the top LISA outliers. Anselin's African
  case fell from I = 0.417 to 0.254 and stayed significant (p < 0.006) — that robustness *is* a
  result.

### 4 — Model family
spatial-regression-models. Fit OLS, run `lm.RStests()` (⚠️ **`lm.LMtests` is deprecated**;
names changed `LMlag`→`RSlag`, `RLMerror`→`adjRSerr`). Then fit the family:

| Model | Equation | Dependence in | Spillovers |
|---|---|---|---|
| SLX | `y = Xβ + WXθ + ε` | neighbours' covariates | local, = θ |
| SAR | `y = ρWy + Xβ + ε` | outcome (contagion) | global |
| SEM | `y = Xβ + u`, `u = λWu + ε` | error (omitted spatial vars) | none in mean |
| **SDM** | `y = ρWy + Xβ + WXθ + ε` | both | **global** |
| **SDEM** | `y = Xβ + WXθ + u`, `u = λWu + ε` | both | **local** |

⚠️ **The classic RS-test route (→ SAR or SEM) has a live rival.**
LeSage (2014): "one need only be concerned with two
specifications, one being the global spillover **SDM** and the other a local spillover **SDEM**." His
objection is that the RS menu **already excludes `WX`** — and neighbours' rainfall, elevation and
road access plausibly do affect your SOC. **Fit both routes, report the AIC table, and choose on
substance:** global diffusion (frontier displacement propagating through the zone network) or
local neighbour effects (shared geomorphology and climate)?
→ lm-tests-vs-sdm-sdem-specification

### 5 — Impacts and residuals
⚠️ **Never interpret β from a lag-type model.** The reduced form carries `(I − ρW)⁻¹`, so effects
feed back. Only the **LeSage–Pace decomposition** is interpretable
(spatial-spillover). Then verify residual Moran's I ≈ 0 — with a power caveat.

### 6 — Report what survives
The deliverable is the **robustness table** (statistic × W specification) plus the model comparison
table, not a single headline number.

## Runnable pipeline (R, verified)

Requires `sf`, `spdep` (≥ 1.3), `spatialreg`. **Verified end-to-end against R 4.5.3 / spdep 1.4.2 /
spatialreg 1.4.3.**

```r
library(sf); library(spdep); library(spatialreg)

# ---- 1. Weights family ------------------------------------------------------
ctr <- st_coordinates(st_centroid(st_geometry(gdf)))
mk  <- function(nb) nb2listw(nb, style = "W", zero.policy = TRUE)
lwl <- list(
  Queen   = mk(poly2nb(gdf, queen = TRUE)),
  Rook    = mk(poly2nb(gdf, queen = FALSE)),
  `KNN-4` = mk(knn2nb(knearneigh(ctr, k = 4))),
  `KNN-8` = mk(knn2nb(knearneigh(ctr, k = 8)))
)
w <- lwl$Queen
cat("no-neighbour units:", sum(card(poly2nb(gdf, queen = TRUE)) == 0), "\n")

# ---- 2. Global bivariate Moran across W -------------------------------------
x <- as.numeric(gdfvar_x); y <- as.numeric(gdfvar_y)
for (nm in names(lwl)) {
  mb <- moran_bv(x, y, lwlnm, nsim = 999)          # NOT moran.bi()
  p  <- (sum(abs(mb$t) >= abs(mb$t0)) + 1) / (length(mb$t) + 1)
  cat(sprintf("%-6s I_xy = %+.4f   pseudo-p = %.4f\n", nm, mb$t0, p))
}
lt <- lee.test(x, y, w, zero.policy = TRUE, alternative = "two.sided")   # symmetric
cat(sprintf("Lee's L = %+.4f  p = %.4f\n", lt$estimate[1], lt$p.value))

# ---- 3. BiLISA with the CORRECT simulated p-value ---------------------------
lm_bv <- localmoran_bv(x, y, w, nsim = 999)
p_sim <- lm_bv[, "Pr(z != E(Ibvi)) Sim"]        # col 6 — col 5 is ANALYTICAL
p_adj <- p.adjust(p_sim, method = "fdr")        # state your adjustment
z_x     <- as.numeric(scale(x))
lag_z_y <- lag.listw(w, as.numeric(scale(y)), zero.policy = TRUE)
quad <- ifelse(z_x > 0 & lag_z_y > 0, "High-High",
        ifelse(z_x < 0 & lag_z_y < 0, "Low-Low",
        ifelse(z_x > 0 & lag_z_y < 0, "High-Low", "Low-High")))
gdf$bilisa <- factor(ifelse(p_adj < 0.05, quad, "Not significant"))

# ---- 4. Diagnostics and model family ----------------------------------------
f   <- as.formula(paste(var_y, "~", var_x, "+", paste(covars, collapse = " + ")))
ols <- lm(f, data = gdf)
print(summary(lm.RStests(ols, w, test = "all")))          # NOT lm.LMtests()

fits <- list(
  SLX  = lmSLX(f,      data = gdf, listw = w),
  SAR  = lagsarlm(f,   data = gdf, listw = w),
  SEM  = errorsarlm(f, data = gdf, listw = w),
  SDM  = lagsarlm(f,   data = gdf, listw = w, Durbin = TRUE),
  SDEM = errorsarlm(f, data = gdf, listw = w, Durbin = TRUE)
)
print(data.frame(model  = names(fits),
                 logLik = sapply(fits, function(m) as.numeric(logLik(m))),
                 AIC    = sapply(fits, AIC), row.names = NULL))

# ---- 5. Impacts (R=, not nsim=) and residual check --------------------------
imp <- impacts(fits$SDM, listw = w, R = 999)
print(summary(imp, zstats = TRUE, short = TRUE))

print(data.frame(
  model = c("OLS", "SAR", "SDM"),
  I = c(lm.morantest(ols, w)$estimate[1],
        moran.test(residuals(fits$SAR), w)$estimate[1],
        moran.test(residuals(fits$SDM), w)$estimate[1]),
  p = c(lm.morantest(ols, w)$p.value,
        moran.test(residuals(fits$SAR), w)$p.value,
        moran.test(residuals(fits$SDM), w)$p.value), row.names = NULL))

cat("APLE =", round(aple(as.vector(scale(y)), w), 4), "\n")   # measure strength
```

## Toolchain equivalence

| Stage | R — `spdep`/`spatialreg` | Python — `libpysal`/`esda`/`spreg` |
|---|---|---|
| Contiguity W | `poly2nb(gdf, queen=)` | `weights.contiguity.Queen/Rook.from_dataframe(gdf)` |
| KNN / distance W | `knn2nb(knearneigh())`, `dnearneigh()` | `weights.distance.KNN/DistanceBand.from_dataframe()` |
| Kernel W (adaptive) | `nb2listwdist()` | `weights.distance.Kernel(..., fixed=False, k=)` |
| Higher-order | `nblag()`, `nblag_cumul()` | `weights.util.higher_order()` |
| Row-standardise | `nb2listw(style = "W")` | `w.transform = "R"` |
| Connectivity | `sum(card(nb)==0)`, `n.comp.nb()` | `w.islands`, **`w.n_components`** |
| Global Moran | `moran.test()`, `moran.mc()` | `esda.Moran(y, w)` → `.I`, `.p_sim` |
| Geary / Getis–Ord | `geary.test()`, `localG()` | `esda.Geary`, `esda.G_Local(..., star=True)` |
| Local Moran | `localmoran_perm()` | `esda.Moran_Local(y, w)` → `.Is`, `.q`, `.p_sim` |
| Bivariate Moran / BiLISA | `moran_bv()` / `localmoran_bv()` | `esda.Moran_BV` / `esda.Moran_Local_BV` |
| Lee's L | `lee()`, `lee.test()` | `esda.Spatial_Pearson`, `Spatial_Pearson_Local` |
| Multivariate local Geary | `localC()`, `localC_perm()` | `esda.Geary_Local_MV` |
| Multiple comparisons | `p.adjust()` | `esda.fdr` |
| RS / LM diagnostics | `lm.RStests()` | `spreg` `LMtests`, `MoranRes`, `AKtest` |
| SAR / SEM | `lagsarlm()` / `errorsarlm()` | `spreg.ML_Lag` / `spreg.ML_Error` |
| SLX / SDM / SDEM | `lmSLX()`, `Durbin = TRUE` | `slx_lags=` / `slx_vars=` arguments |
| Impacts | `impacts(m, listw, R = 999)` | `spreg` spatial-multipliers module |
| Cluster map | `tmap` / `ggplot2` | `splot.esda.lisa_cluster()` |
| Dependence strength | **`spatialreg::aple()`** | — (no equivalent) |
| Exact / saddlepoint Moran | **`localmoran.exact/.sad()`** | — (no equivalent) |
| Regimes · SUR · spatial panel | — (limited) | **`spreg`** `*_Regimes`, `SUR*`, `Panel_*` |

**Neither is a superset.** R has APLE and the exact/saddlepoint distributions; Python has regimes, SUR
and spatial panels. Pick per project — the **methodological cautions transfer unchanged**.

## Python pipeline (`libpysal` / `esda` / `spreg`)

Verified by execution against `libpysal` 4.15.0 / `esda` 2.10.0 / `spreg` 1.9.1 / `geopandas` 1.1.4
(Python 3.13).

```python
import numpy as np, geopandas as gpd, esda, spreg
from libpysal import weights
from splot import esda as esdaplot

gdf = gpd.read_file(path).to_crs(epsg_metric)    # a local metric CRS, not lon/lat

# ---- 1. Weights family ------------------------------------------------------
wf = {
    "Queen":  weights.contiguity.Queen.from_dataframe(gdf),
    "Rook":   weights.contiguity.Rook.from_dataframe(gdf),
    "KNN-4":  weights.distance.KNN.from_dataframe(gdf, k=4),
    "KNN-8":  weights.distance.KNN.from_dataframe(gdf, k=8),
}
for w in wf.values():
    w.transform = "R"                            # row-standardise
w = wf["Queen"]
print("islands:", len(w.islands), "| components:", w.n_components)   # REPORT BOTH

# ---- 2. Global: bivariate Moran across W ------------------------------------
x, y = gdf[var_x].values, gdf[var_y].values
for name, wi in wf.items():
    mbv = esda.Moran_BV(x, y, wi, permutations=999)
    print(f"{name:6s} I_xy = {mbv.I:+.4f}   p_sim = {mbv.p_sim:.4f}")

# symmetric alternative (Lee's L)
lee = esda.Spatial_Pearson(connectivity=w.sparse).fit(x.reshape(-1, 1), y.reshape(-1, 1))

# ---- 3. BiLISA + multiple-comparison adjustment -----------------------------
lisa = esda.Moran_Local_BV(x, y, w, permutations=999)
sig  = lisa.p_sim < 0.05
# WARNING: q codes are 1=HH, 2=LH, 3=LL, 4=HL - index them, never assume the order
labels = {1: "High-High", 2: "Low-High", 3: "Low-Low", 4: "High-Low"}
gdf["bilisa"] = np.where(sig, [labels[q] for q in lisa.q], "Not significant")
esdaplot.lisa_cluster(lisa, gdf, p=0.05)

# ---- 4. Model family --------------------------------------------------------
Y = gdfvar_y.values
X = gdf[covars + [var_x]].values
ols  = spreg.OLS(Y, X, w=w, spat_diag=True, moran=True)   # RS/LM diagnostics
sar  = spreg.ML_Lag(Y, X, w=w)
sem  = spreg.ML_Error(Y, X, w=w)
slx  = spreg.OLS(Y, X, w=w, slx_lags=1)
sdm  = spreg.ML_Lag(Y, X, w=w, slx_lags=1)      # SDM  = lag   + WX
sdem = spreg.ML_Error(Y, X, w=w, slx_lags=1)    # SDEM = error + WX
print(ols.summary)
```

## Cross-implementation check — and what it proves about W

Run on the same 49-polygon test dataset, R and Python agree **only when W is built the same way**:

| Statistic | R (`spdep`) | Python (`esda`) |
|---|---|---|
| Moran's I (univariate) | 0.500189 | 0.5002 |
| Bivariate Moran `I_xy` | −0.451623 | −0.4516 |
| Lee's L | −0.470306 | −0.4703 |

Agreement to 4 decimals — the implementations are interchangeable.

**But swap one W for another "queen contiguity" matrix over the same polygons and the numbers move.**
A stored/canonical neighbour list for that dataset has **232 links**; rebuilding contiguity from the
polygon file gives **236**. Four links out of ~234 — under 2 % — and:

| | 232-link W | 236-link W |
|---|---|---|
| Moran's I | **0.510951** | **0.500189** |
| Bivariate `I_xy` | **−0.457613** | **−0.451623** |

Both are "queen contiguity". Both are defensible. They give different answers. **This is the whole
argument of this skill in one table:** if you report a single statistic under a single W, you have
reported a property of your boundary file. Report the family.

## ⚠️ Shortcut ("simple") impacts hide the feedback loop

Some implementations report a cheap approximation instead of the exact LeSage–Pace decomposition:

```
Direct   = β̂              Total = β̂ / (1 − ρ̂)          Indirect = Total − β̂
```

The **total is exact** — for row-standardised W the row sums of `(I − ρW)⁻¹` are `1/(1 − ρ)`. But
**`Direct = β` is not**: the diagonal of `(I − ρW)⁻¹` exceeds 1, because the effect leaves unit *i*,
travels through its neighbours and **comes back**. The shortcut assigns that feedback loop to the
*indirect* term — understating the direct effect and **inflating the reported spillover**.

Verified (`spatialreg` 1.4.3, SAR on the test dataset, ρ = 0.431):

| | β | exact Direct | exact Indirect | Total |
|---|---|---|---|---|
| x₁ | −1.0316 | **−1.0860** | −0.7271 | −1.8131 |
| x₂ | −0.2659 | **−0.2800** | −0.1874 | −0.4674 |

The shortcut would report Direct = −1.0316 and Indirect = −0.7815 — **≈ 5 % of the direct effect
misfiled as spillover at ρ = 0.43**, and the gap grows with ρ. If the spillover is your headline
number, this is not a rounding detail. `spatialreg::impacts()` computes the exact version by default;
**check what your tool actually reports before quoting an indirect effect.**

⚠️ **Restricted model menus.** Some point-and-click and automated implementations offer only
OLS / SAR / SEM / SAC and choose between them with the LM decision tree. **None of those four include
a `WX` term**, so SDM and SDEM cannot be reached at all — and the tool will still hand you a
confident "selected model". If your environment cannot fit SLX/SDM/SDEM, that is a **tool
constraint**, not a methodological finding. Fit them in R or Python before publishing a spillover.
→ lm-tests-vs-sdm-sdem-specification

## ⚠️ API traps that silently break scripts

Verified against **spdep 1.4.2 / spatialreg 1.4.3**. Every one of these appears in circulating
tutorials and LLM-generated code.

| Wrong | Right | Failure mode |
|---|---|---|
| `moran.bi()`, `localmoran.bi()` | **`moran_bv()`, `localmoran_bv()`** | function does not exist — these names were never in `spdep` |
| `res$statistic`, `res$p.value` from `moran_bv` | **`res$t0`**, pseudo-p from **`res$t`** | returns a **`boot`** object; both are `NULL`, so loops print blanks |
| `localmoran_bv(...)[, 5]` as the permutation p | **`[, "Pr(z != E(Ibvi)) Sim"]`** (col 6) | col 5 is the **analytical** p — you filter the map with the wrong test |
| `lm.LMtests()` | **`lm.RStests()`** | deprecated wrapper; messages "Please update scripts"; names changed `LMlag`→`RSlag`, `RLMerror`→`adjRSerr` |
| `impacts(m, listw = w, nsim = 999)` | **`impacts(m, listw = w, R = 999)`** | `nsim` **silently ignored**; `summary(imp, zstats=TRUE)` then errors *"summary method unavailable"* |
| `localmoran()` default p-values | **`localmoran_perm()`** or `.exact`/`.sad` | normal approximation over-rejects; local null has kurtosis ≈ 8 |
| `tm_scale_bar()`, `tm_polygons(palette=)` | **`tm_scalebar()`**, `fill.scale = tm_scale_categorical(values=)` | tmap v4 renamed these |
| assuming `Moran_Local.q` is HH/LL/HL/LH | **`1=HH, 2=LH, 3=LL, 4=HL`** | PySAL's coding — a hand-written mapping silently swaps **cold spots with outliers** |
| `nb2listw(style="W")` ported as `w.transform="W"` | **`w.transform = "R"`** | PySAL spells row-standardisation `"R"`; `"W"` is not it |
| checking only `w.islands` | also **`w.n_components`** | zero islands but a **disconnected graph** makes a global statistic an average over populations that never neighbour each other |
| distance weights on lon/lat degrees | reproject first, or pass `radius=` | unprojected distances are meaningless — the same trap in both languages |

Also: model fitting moved from `spdep` to **`spatialreg`** in 2019 — pre-2019 papers and scripts
(including Bivand & Piras 2015) say
`spdep` for everything.

## Worked case — cumulative forest loss vs SOC stocks

A recurring application, and a template for any two-variable areal question: does deforestation
relate to soil organic carbon across the administrative or landscape zones of a forest region?
Nothing below is region-specific — substitute your own zones, forest-loss product and CRS.

| Step | Concretely |
|---|---|
| Support | Administrative zones — justified because the question is about **territorial governance** (REDD+, protected areas, tenure), not the soil field itself. Reproject to a **local metric CRS** (the appropriate UTM zone, or a national projected system). |
| X | Cumulative forest loss over the study period, from an annual loss raster reclassified to binary and summed per zone, then converted to area with the correct cell factor (30 m cells → × 0.09 ha). |
| Y | Mean SOC stock 0–30 cm from a gridded soil product (soilgrids or a national map). **Keep the pixel count per zone.** |
| Covariates | Mean annual precipitation, mean elevation, accessibility — the obvious confounders that make a raw bivariate association uninterpretable. |
| Direction | Lag **Y**: "loss here vs SOC in neighbours" tests the spillover hypothesis. Report `I_yx` too. |
| BiLISA reading | **HH** = high loss among high-SOC neighbours → priority for protection/REDD+, because further clearing hits rich stocks. **HL** = consolidated degradation (mature cleared landscapes, historic road corridors) → candidates for agroforestry/silvopastoral transition. **LH** = low loss among high-SOC neighbours → effective barriers to land-use change, worth identifying and explaining. |
| Model reading | **SEM/SDEM favoured** → the pattern is driven by geomorphology and climate that the zone borders cut across. **SAR/SDM favoured** → cross-border propagation, i.e. agricultural-frontier displacement or edge microclimate effects. |
| Honest limit | ⚠️ Cross-sectional, so **no causal claim**. SoilGrids SOC is itself a *model prediction*, not a measurement — its own error is spatially correlated, which the areal model does not account for. |

That last row matters and is easy to skip: when Y comes from a digital soil map rather than from
observations, you are regressing on a prediction. Say so, and prefer measured SOC where it exists.

## Reporting checklist

- [ ] Analysis unit named and **justified**; CRS stated (metric, planar).
- [ ] Zonal aggregation described; **pixel count per zone** reported (min/median/max).
- [ ] W family listed; **no-neighbour units counted**; **`n_components` reported**; row-standardisation stated.
- [ ] Global statistics reported **per W specification** — the robustness table.
- [ ] Bivariate: **which variable was lagged**, plus Lee's L alongside `I_xy`.
- [ ] Local inference: **permutation or exact**, `nsim` stated, **multiple-comparison adjustment named**.
- [ ] LISA described as "where the pattern concentrates" if the global statistic is significant.
- [ ] Leverage check: global statistic recomputed without top local outliers.
- [ ] RS diagnostics **and** the SLX/SAR/SEM/SDM/SDEM AIC table — not just the winner.
- [ ] Impacts as **direct / indirect / total** with simulated p-values (`R = 999`); β never reported
      as a marginal effect for lag-type models.
- [ ] Residual Moran's I ≈ 0 in the chosen model, **with a power statement**.
- [ ] State whether reported impacts are the **exact** decomposition or a **shortcut** — never quote a
      shortcut indirect as a spillover estimate without saying so.
- [ ] Explicit statement that association ≠ causation, and that results are conditional on zones and W.

## When NOT to use this skill
- **You want a map of a soil property** → SKILL.
- **You want per-pixel uncertainty or an applicability mask** →
  SKILL.
- **You want map accuracy** → SKILL.
- **You have point observations and want to interpolate** → geostatistics / regression kriging
  (regression-kriging), not lattice statistics.
- **The relationship itself varies across space and that is the question** →
  geographically-weighted-regression and spatial-non-stationarity.
- **You need SOC change over time** → SKILL or
  SKILL.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
