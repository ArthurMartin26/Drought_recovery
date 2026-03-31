# Drought Shock Construction (SPI‑3 style, hysteresis, contiguous events)

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
