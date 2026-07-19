---
name: rothc-temporal-modelling
description: >-
  Set up, initialize, calibrate, validate, and interpret the RothC (Rothamsted Carbon)
  model — and CENTURY-family process models — for simulating soil organic carbon stock
  and its change over time. Use when modelling SOC dynamics under management or climate
  scenarios, initializing RothC pools (spin-up), calibrating decay constants, choosing
  carbon inputs, adapting RothC to a region/practice, or judging whether a RothC result
  is trustworthy. Triggers: "RothC", "CENTURY / CenW", "soil carbon model", "carbon
  pools DPM/RPM/BIO/HUM/IOM", "spin-up / initialize SOC pools", "calibrate RothC",
  "SOC under climate change", "carbon input estimation", "first-order decay".
---

# RothC Temporal SOC Modelling

Forged from the DSM knowledge wiki (6 RothC/process sources, 2019–2026). The wiki remains
the source of truth. Key pages: rothc, carbon-pools,
first-order-decay, carbon-inputs, rothc-initialization,
rothc-calibration, first-order-decay-vs-carbon-saturation.

## What RothC is (and is not)

RothC simulates SOC turnover with **five conceptual pools** (DPM, RPM, BIO, HUM, IOM),
monthly steps, and **first-order decay** scaled by temperature, moisture, and plant cover.
It models **the soil only** — you supply the carbon inputs (there is no plant-growth
sub-model). The pools are **not measurable**; they are a device to fit four decay curves
to SOC. It has **no carbon-saturation ceiling**, **no N cycle**, no explicit tillage/pH.

| Pool | Default k (yr⁻¹) | Meaning |
|------|-----------------|---------|
| DPM | 10 | fast, fresh decomposable plant material |
| RPM | 0.30 | resistant plant material |
| BIO | 0.66 | microbial biomass |
| HUM | 0.02 | humified, slow (usually the largest pool) |
| IOM | inert | ancient C; estimated, not simulated |

## Workflow

1. **Gather inputs.** Monthly temperature, precipitation, evapotranspiration; clay %;
   plant cover; and — the hardest part — **carbon inputs** (crop/root residues + manure).
   Estimate inputs from yield via humification coefficients and a DPM/RPM ratio; roots
   stabilize more efficiently than shoots. See carbon-inputs.
2. **Estimate IOM** from the initial stock: `CIOM = 0.049 × CTOT(0)^1.139` (Falloon).
3. **Initialize the pools (spin-up).** Find the steady state matching the known starting
   SOC. Prefer the **analytical solution** `C = −(1/ξ)·A⁻¹·Q` over a centuries-long run —
   far cheaper at high resolution. Watch: equilibrium may be unrealistic (some pixels
   demand implausibly high inputs → artefactual early-simulation change). See
   rothc-initialization.
4. **Adapt RothC to the region/practice if needed.** The base model is a starting point:
   RothC20_N for Mediterranean summer drought; RothC_MM for mulching's indirect
   temperature/water effects. If a practice changes soil T or water, model that, not just
   the C input.
5. **Calibrate — multi-objective, not SOC-only.** Calibrating on slow SOC needs ~10 yr and
   suffers equifinality. Instead constrain with several time series in priority order:
   **SOC → heterotrophic respiration (Rh) → soil water (TSMD) → temperature**. Rh (from
   automated gas chambers) is fast, low-uncertainty, and equals the sum of pool losses —
   the key extra target. Partition Rh from total respiration first (remove root/autotrophic
   Ra). Use GLUE for uncertainty. See rothc-calibration.
6. **Validate honestly** (defer to the soil-map-validation skill):
   - Report **absolute-stock skill and temporal-change skill separately** — RothC often
     validates on stock (MEC ~0.3) yet fails on change (MEC ≈ 0).
   - Validate against **independent** data at a **matching spatial support** (point vs
     grid mismatch inflates error). Metrics: RMSE, ME, MEC/NSE/EF.
   - Same-data fit ≠ predictive skill.
7. **Interpret at the right scale.** Trust **aggregated** (regional/national) trends more
   than pixel-level temporal change — local errors cancel on aggregation. High spatial
   resolution ≠ high accuracy.

## Two modes of use
- **Back-casting / monitoring** — reconstruct SOC over a past period (e.g. national 25 m).
- **Forward projection** — scenarios of climate or management. Consistent result: warming
  → faster decomposition → **SOC loss**; residue/manure/FYM retention is the main
  counter-lever.

## Pitfalls & structural limits (state these when reporting RothC results)
- **No carbon saturation** → overestimates SOC under sustained high inputs. This is the
  headline structural gap; flag it. → first-order-decay-vs-carbon-saturation
- **Pools aren't measurable** → don't over-interpret pool-specific numbers.
- **No priming, no pH, no N cycle** → biological processes are crude.
- **Binary cover, coarse input data** → soil-water/temperature modifiers are approximate.
- **Carbon inputs dominate uncertainty** → most error enters through what you feed it.
- **Not robust to changing conditions** — the field consensus is that first-order-decay
  models don't truly capture the governing processes; treat scenario projections as
  indicative, not precise.

## The forward direction: hybrid
RothC captures **temporal dynamics**; ML captures **spatial variability**. The wiki's
thesis is to **fuse them** — ML to impute inputs and map spatial fields, RothC/inverse
modelling for temporal trends and parameters, possibly with a saturation constraint. See
process-vs-empirical-models.

## Provenance
Distilled from: Lai 2026 (national 25 m RothC, pools, analytical init, temporal MEC≈0),
Ma 2026 (CenW/CENTURY, NSE, residue lever), Balugani 2023 (RothC20_N, multi-objective
respiration calibration, equifinality), Pesce 2023 (RothC_MM mulching), Afzali 2019 &
Kaushal 2022 (climate-change projection, warming→loss, FYM). Full citations in the wiki
`sources/`.


---
_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.ps1._
