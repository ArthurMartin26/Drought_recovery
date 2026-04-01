# Drought Shock Construction (SPI‑3 style, hysteresis, contiguous events)

## recent changes 
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
