# Dissertation Proposal
## Learning Regional Adjustment to Drought Shocks Using Satellite Data

---

## Project Overview

This dissertation studies why regions exposed to similar drought shocks exhibit very different post-shock adjustment paths. Rather than treating drought impacts as uniform or focusing solely on average effects, the project examines **heterogeneity in post-drought adjustment**, using high-resolution satellite data and modern machine learning methods.

The core idea is to separate:
- **pre-shock regional structure** (how land use, vegetation, settlements, and water are spatially organised),
from
- **post-shock outcomes** (how vegetation evolves after a drought).

The project focuses on Nigeria, a country with substantial climatic variation, frequent drought exposure, and strong satellite data coverage.

---

## Research Question

Why do similar drought shocks lead to different post-shock adjustment paths across regions, and how can this heterogeneity be predicted from pre-shock spatial structure and regional characteristics?

The analysis does not ask whether regions simply “recover” or not. Instead, it asks **which type of adjustment path** a region follows after a drought shock.

---

## Conceptual Framework

Each region is characterised by three components:

1. **Pre-shock spatial structure**  
   Captures land use patterns, vegetation seasonality, settlement density, and water availability within a region.

2. **Drought exposure**  
   Measures the severity of rainfall deficits at the time a drought occurs.

3. **Post-shock adjustment path**  
   Describes how vegetation evolves following a drought, allowing for recovery, slow adjustment, persistent loss, or structural change.

The central goal is to understand how pre-shock structure and regional characteristics interact with drought intensity to shape post-shock outcomes.

---

## Spatial Unit and Scope

- Country: Nigeria  
- Spatial unit: Regular grid cells (e.g. 10km × 10km)  
- Temporal coverage: Early 2000s to early 2020s  
- Time resolution: Monthly  

Each grid cell can experience multiple drought events over time.

---

## Data Sources (High-Level)

The project relies exclusively on widely used, freely available satellite and geospatial datasets, including:
- Satellite-derived vegetation indices
- Satellite-based rainfall estimates
- Land cover and cropland maps
- Built-up area and settlement layers
- Surface water presence
- Population and accessibility layers

All datasets are harmonised to a common spatial grid.

---

## Methodology Overview

The analysis proceeds in six main stages.

---

### 1. Drought Event Identification

Drought events are identified at the **cell × month** level using rainfall anomalies relative to a historical baseline.

A drought event occurs when rainfall in a grid cell falls substantially below its long-run seasonal norm. To avoid noise and overlapping recovery periods:
- Events must persist for multiple months.
- A minimum spacing rule is imposed between events within the same cell.

This step establishes the number, timing, and spatial distribution of drought events and ensures sufficient data for downstream analysis.

---

### 2. Pre-Shock Baseline Construction

A fixed pre-shock baseline period is defined prior to drought identification. This baseline is used to compute:
- vegetation climatology,
- rainfall climatology,
- and other long-run regional characteristics.

The baseline is not re-estimated for each event.

---

### 3. Learning Pre-Shock Spatial Structure

A convolutional autoencoder is used to learn a low-dimensional representation of pre-shock spatial structure for each grid cell.

Inputs to the model include stacked raster layers summarising:
- vegetation levels and seasonality,
- land cover composition,
- settlement density,
- and water presence.

The model is trained in an unsupervised manner and does not observe droughts or outcomes. The resulting representation serves as a compact “spatial fingerprint” of each region.

---

### 4. Constructing Post-Shock Outcomes

For each drought event, vegetation trajectories are extracted over a fixed post-shock horizon.

These trajectories are summarised using features such as:
- magnitude of vegetation loss,
- speed of adjustment,
- long-run deviation from baseline,
- and post-shock variability.

Events are then grouped into a small number of **latent adjustment regimes**, representing qualitatively different post-shock paths.

This step avoids imposing a binary notion of recovery and allows for adaptation and structural change.

---

### 5. Supervised Learning: Predicting Adjustment Regimes

The probability that a drought event leads to a particular adjustment regime is modelled using **gradient-boosted decision trees**.

Inputs include:
- the learned spatial representation,
- interpretable regional covariates,
- and drought intensity at the time of the shock.

Gradient-boosted trees are chosen because they:
- capture nonlinear effects and interactions automatically,
- perform well on structured, tabular data,
- and support transparent interpretation.

The model is explicitly predictive rather than causal.

---

### 6. Interpretation and Validation

Model outputs are decomposed to understand:
- which regional characteristics are associated with different adjustment regimes,
- how spatial structure amplifies or buffers drought impacts.

Validation uses spatially aware cross-validation to assess generalisation to unseen regions.

---

## Contributions

This project contributes by:
- shifting focus from drought exposure to post-shock adjustment paths,
- combining spatial representation learning with interpretable ensemble methods,
- providing a scalable framework for analysing regional resilience using satellite data.

The approach balances methodological ambition with transparency and feasibility.

---

## Scope and Limitations

The analysis focuses on vegetation and land-use adjustment observable from space. It does not directly measure household welfare, sectoral employment, or income changes.

Extensions incorporating additional economic outcomes are left for future work.

---

## Repository Structure (Planned)

- `data_raw/`  
  Original downloaded datasets

- `data_processed/`  
  Harmonised grids, anomalies, and event tables

- `scripts/`  
  Data processing and analysis scripts

- `models/`  
  CNN and supervised learning code

- `outputs/`  
  Tables, figures, and maps

- `docs/`  
  Notes and write-up drafts

---

## Status

This repository currently documents the dissertation design and data strategy. Initial work focuses on drought event detection and exploratory analysis.

---

