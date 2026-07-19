---
name: soil-sampling-design
description: >-
  Choose and design a soil sampling scheme for digital soil mapping — where (and when) to
  sample, how many, and by which method — matched to the objective (feature-space vs spatial
  coverage, representativeness, local heterogeneity, multiple properties, cost/accessibility,
  space-time) and to whether you are placing new samples or reusing legacy data. Use when
  planning a sampling campaign, sizing a sample, assessing/supplementing legacy points, or
  choosing between cLHS and its alternatives. Triggers: "sampling design", "how many samples",
  "where to sample", "cLHS", "sample size", "representative samples", "reference area",
  "supplemental sampling", "sampling for soil mapping", "legacy soil data reuse",
  "sample density".
---

# Soil Sampling Design

Forged from the DSM knowledge wiki. The wiki is the source of truth. Key pages:
sampling-design, sample-representativeness, spatiotemporal-sampling,
landscape-heterogeneity, scale-dependence, area-of-applicability,
spatial-cross-validation. Sampling is the **first step** of
digital-soil-mapping-workflow; hand map-accuracy
validation to soil-map-validation.

## The one idea to internalize first
**Sampling is upstream of every accuracy claim — and there is no one-size design.** Choose by *what you
are optimizing* and *what constrains you*, not by habit. The axes:
- **Feature space** (covariate coverage — for model calibration) vs **geographic space** (spatial spread —
  for interpolation). Optimizing one alone is fragile; joint coverage is robust when the model isn't fixed
  at design time.
- **Representativeness** (do the samples span the target's conditions?) — the training-side twin of the
  area of applicability.
- **Local heterogeneity** (sample denser where the landscape varies more).
- **Cost / accessibility** (the design that's actually executable).
- **Time** (space-time, if you need change).
And: **design-based (probability) sampling** is the only route to *design-based map-accuracy validation* —
decide early if you need it.

## Which design — decision guide
| Your objective / constraint | Reach for | Source |
|---|---|---|
| Efficient covariate-space coverage, few points | **cLHS** (condition on covariates only) | Minasny & McBratney |
| cLHS + spatial uniformity | **scLHS** | Gao 2016 |
| Add a **time** axis (or autocorrelation-aware) | **acLHS** / space-time | Le & Vargas; Brus |
| Beat cLHS on accuracy (fuzzy-cluster) | **IHS** | Yang 2016 |
| **Several target properties** at once | **MPRS** / Wang dual-space | Zhang 2022; Wang 2026 |
| **Density should track variability** | **heterogeneity-adaptive** (CV-of-DEM → subregions) | Wang 2026 |
| **Expensive access**; sample a small representative area | **Reference Area (autoRA / Gower)** | Rodrigues 2025 |
| Scale an existing sampling style cheaply from terrain | **DL segmentation (DualTrans)** | Pham 2025 |
| Certify **map accuracy** (MRV) | **probability sampling** (design-based) | Wadoux; de Gruijter |
| Tight logistics/budget | **cost- / accessibility-constrained cLHS** | Godinho Silva; Sena |
| You already have legacy points | assess **representativeness** → **supplement** | An; Zhang & Zhu; Liu |

## How many samples — size from a learning curve, not a guess
- Accuracy shows **diminishing returns with a plateau** (n ≈ **200–300**; density ≈ 1 obs/2 km²); biggest jump
  is 25→50; **floor ≈ 30** (nothing reliable below). Larger extents need more points for the same density.
- **Track per-property n** for multi-property builds — the under-sampled properties (often N, P) map worst
  (inherent-vs-management-properties); read each property's n against the plateau before trusting it.
- **cLHS vs SRS tie on the mean, differ on the *variance*** — cLHS halves the RMSE spread and kills catastrophic
  draws at small n. It's **insurance against an unlucky single draw**; at n ≥ 300 the design barely matters.

## Representativeness — assess legacy, and design for it
- **Assess before use** (sample-representativeness): fuzzy-cluster coverage per parent material,
  representativeness heuristics, trustworthiness indicators. Redundant samples add little; **coverage** is what counts.
- **Design *for* it a-priori:** the **Reference Area** — sample a
  sub-region whose **Gower dissimilarity spans the whole AOI**, extrapolate with a bounded error (~60% cost cut in
  the study). This is the design-side of the AOA.
- **Cover geographic *and* feature space jointly** (Wang) for
  robustness when the model isn't chosen yet.
- **Supplement** thin areas using the assessment (and, post-mapping, the LPD map)
  — active learning.

## Sample density follows heterogeneity
Don't sample uniformly. Compute local heterogeneity (landscape-heterogeneity: SDI, Moran's I,
distribution shape; or CV-of-DEM in a window) and **put more samples where the landscape varies more**, fewer where
it's uniform. A pre-modelling triage also sets honest accuracy expectations per area.

## Space-time (if you need change)
Record **date/season** on every point (many legacy points lack it). Design where *and when* to sample
(spatiotemporal-sampling: Brus space-time — design/model/hybrid), integrating static + dynamic
covariates and matching the process timescale (seasonal vs decadal).

## Cost & accessibility (make it executable)
Cost-constrained cLHS trades a little accuracy for big savings; accessibility-aware designs substitute reachable
alternatives for inaccessible points. Essential where terrain/logistics dominate (Andes, Amazon). The Reference
Area design is itself a major cost lever.

## Validate the right thing
- If you need **map-accuracy certification**, you need a **probability sample** up front — model-training designs
  (cLHS, RA, heterogeneity-adaptive) are *not* probability samples by themselves. → SKILL.
- Match the CV strategy to the design and sampling structure (clustered legacy → kNNDM/spatial CV).

## Pitfalls
- **Guessing sample size** instead of sizing from a learning curve (plateau ≈ 200; floor ≈ 30).
- **Conditioning cLHS on the target** (or bare coordinates) — inflates accuracy that won't reproduce; condition on covariates only.
- **Optimizing feature space alone (cLHS) or geography alone** — fragile; prefer joint coverage when the model is undecided.
- **Sampling uniformly** across a heterogeneous area — waste in uniform zones, under-coverage in variable ones.
- **Reusing legacy data without a representativeness check** — clustered bias silently corrupts the map.
- **Treating a model-training design as a probability sample** for MRV accuracy claims.
- **DL site-selection (DualTrans) treated as coverage-optimal** — it imitates labelled expert sites, inheriting their logic/bias.
- **Losing the sampling date** — kills any temporal use.
- **One design for many properties without checking per-property n** — the weak nutrients stay under-sampled.

## Provenance
Distilled from: Minasny & McBratney (cLHS), Bouasria 2023 (learning-curve sizing, cLHS-vs-SRS variance,
landscape-heterogeneity triage), Carbajal 2025 (cLHS in the Andes; small-n regime), Wadoux (probability/design-based),
Hengl & Abbruzzini (legacy per-property n, spatial de-clustering), Yang & Li 2026 (the design catalog: scLHS, acLHS,
IHS, MPRS, supplemental, representativeness assessment, space-time), Pham 2025 (DL segmentation site selection),
Rodrigues 2025 (Reference Area / autoRA-Gower), and Wang 2026 (heterogeneity-adaptive, dual-space, multi-property).
Full citations in the wiki `sources/`.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
