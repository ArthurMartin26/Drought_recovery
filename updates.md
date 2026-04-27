# April 27th - Spatial harmonisation and Zi construction.
All spatial covariates used to construct the fixed geographic feature set (Zi) were harmonised to a common equal‑area representation prior to modelling. Specifically, all raster and vector inputs (including rainfall aggregation grids, market accessibility, surface water occurrence, elevation, and slope) were projected to the Africa Albers equal‑area coordinate reference system (ESRI:102022) and mapped onto a shared 10 km × 10 km grid covering Nigeria. This ensures that each grid cell represents an identical land area and that all Zi channels share the same spatial extent, resolution, and alignment. Variable‑specific transformations (e.g. distance transforms for market access, long‑run means for surface water, and terrain derivatives for slope) are first computed at native resolution where appropriate and subsequently aggregated or resampled to the common grid. Values are then scaled to be suitable for input into a convolutional neural network. This harmonisation step is critical to ensure that the CNN learns meaningful latent spatial structure reflecting persistent geographic heterogeneity, rather than artefacts arising from inconsistent projections, resolutions, or spatial supports.

# April 2026 – Design update:
I now have monthly CHIRPS rainfall (2000–2024) and MODIS NDVI data aggregated to 10 km × 10 km grid cells for Nigeria, and have identified thousands of local, multi‑month drought events at the cell level. The empirical design is now event‑based, with each drought in each cell forming one observation. I distinguish between Zi, a fixed structural spatial fingerprint for each cell (e.g. geography, terrain, long‑run water presence, remoteness, land‑use structure), learned via a CNN from stacked raster layers, and Xi, event‑specific pre‑shock state variables (e.g. population, night‑time lights, cropland and irrigation shares, conflict exposure), constructed using rolling pre‑event averages to avoid post‑shock contamination. Post‑drought vegetation dynamics are classified into four adjustment regimes based on NDVI trajectories: rapid stabilisation (≤12 months), gradual stabilisation (≤24 months), delayed stabilisation (>24 months), and persistent structural shift (no return within the observation window). A gradient‑boosted decision tree model is used to predict these regimes from Zi, Xi, and drought severity, allowing the analysis to learn how structural spatial characteristics and evolving regional conditions interact to generate heterogeneous post‑drought adjustment paths.



# Drought Shock Construction (SPI‑3 style, hysteresis, contiguous events)

## recent changes 
## update (01/apr) : 06 nigeria drought shock 

This script aggregates the cell-level drought events constructed in Script 05 into Nigeria-wide drought episodes for descriptive analysis. Rather than treating droughts as grid-cell–specific phenomena, Script 06 links together all cell-level events that share the same start date and end date, which implies the same duration and the same set of calendar months. Each unique (start_date, end_date) window is treated as a single national drought episode, regardless of how many grid cells are affected. The script assigns a Nigeria-wide event identifier (ng_event_id), computes descriptive statistics on the spatial extent (number and share of grid cells affected) and severity (national minima and averages of SPI-based intensity), and produces summary tables and figures showing the frequency of drought episodes over time and their typical spatial coverage. This approach yields an interpretable count of seasonally defined, Nigeria-wide drought episodes, suitable for descriptive statistics and contextual analysis, while preserving the underlying cell-level information for traceability.

### Update (March 2026): Finalising drought event construction and stabilisation

The drought construction pipeline has now been stabilised and validated. Monthly rainfall is aggregated into a 3‑month window (SPI‑3 style) and standardised relative to a 2000–2010 baseline by grid cell and calendar month. To ensure numerical stability and avoid artefacts from near‑zero baseline variance, the standardised anomaly is treated as a **bounded latent trigger index** rather than a literal Gaussian z‑score. Specifically, the index is capped at ±6 and used exclusively for drought entry/exit via hysteresis thresholds (enter = −1.0, exit = −0.5). This preserves the ordering and persistence of dry versus wet periods while preventing implausible tail values from driving event definitions.

Calendar contiguity is enforced explicitly: drought runs are broken whenever months are not consecutive, and events are defined as contiguous drought regimes lasting at least three months. Event severity measures used downstream (e.g. minimum intensity and cumulative deficit) are computed from the bounded index to ensure robustness, while physical magnitudes (e.g. rainfall totals) are retained separately. Validation plots for sample grid cells confirm sensible temporal behaviour, stable hysteresis, and the absence of pathological spikes. At this point, drought events are considered final and suitable for downstream modelling of post‑shock adjustment and resilience.
 


This folder constructs **finite drought shock events** from gridded monthly rainfall data using a **SPI‑3–style standardisation**, **hysteresis entry/exit rules**, and **calendar‑contiguous event definition**.

The goal is to produce **credible, temporally finite rainfall shocks** suitable for downstream analysis of **post‑shock dynamics and recovery**, rather than raw climate anomalies.

---

## Overview of the Approach

Drought events are constructed in three passes:

1. **PASS 1 — Rainfall anomalies and drought state**
   - Construct 3‑month accumulated rainfall (`rain3`)
   - Standardise relative to a historical baseline (SPI‑3 style)
   - Classify monthly drought state using hysteresis thresholds

2. **PASS 2 — Calendar‑contiguous drought runs**
   - Enforce strict calendar contiguity (no missing months)
   - Break runs whenever months are not consecutive

3. **PASS 3 — Drought events**
   - Collapse contiguous drought runs into events
   - Enforce minimum duration
   - Assign event IDs and compute summary statistics

All logic is implemented in  
`05_define_drought_shocks_spi3_hysteresis_contiguous.R`.

---

## Data Requirements

Input panel (`nigeria_rainfall_10km_panel.csv`) must contain:

- `cell_id` — spatial grid identifier  
- `year`, `month` — calendar time  
- `rain_mm` — monthly rainfall  
- Optional: `lon`, `lat` for mapping

---

## Critical Panel Invariant (Important)

**All time‑series logic assumes rows are ordered in true calendar time.**

The input panel is initially month‑stacked (e.g. all Januaries, then all Februaries).  
We therefore explicitly construct a `date` variable and **re‑order the data**:

```r
dt[, date := as.Date(sprintf("%04d-%02d-01", year, month))]
setorder(dt, cell_id, date)
