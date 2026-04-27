Python Code: Spatial Representation Learning (Zi)
Overview
This folder contains the Python components of the dissertation codebase related to spatial representation learning. The primary purpose of this code is to construct a low‑dimensional, spatially structured representation of time‑invariant geographic heterogeneity (Zi) using convolutional neural networks (CNNs).
All Python code in this folder operates exclusively on fixed spatial covariates (e.g. elevation, slope, surface water, market accessibility). It is intentionally separated from:

drought shock identification,
NDVI outcome construction,
econometric modelling.

The output of this stage is a learned representation of geography that is later used as fixed heterogeneity in downstream empirical analysis.

Conceptual role of Zi
Zi is intended to summarise persistent geographic structure that may shape how locations respond to drought shocks. It is:

time‑invariant,
defined at the grid‑cell level,
learned independently of outcomes and weather shocks,
treated as pre‑treatment heterogeneity in the empirical framework.

Representation learning is used to reduce high‑dimensional spatial data into a small number of latent geographic factors while preserving spatial structure.

Inputs
The Python pipeline consumes raster layers produced upstream in R and stored in:
Data/Data_Output/Zi/

These rasters:

share a common equal‑area projection,
are resampled to a 10 km × 10 km grid,
are masked to Nigeria,
represent fixed geographic features only.

Python enforces final raster alignment and consistency before any learning takes place.

What the current code does
At a high level, the existing notebooks and scripts in this folder:


Load and align Zi raster layers
All Zi channels are explicitly resampled onto a common reference grid to ensure identical spatial support.


Construct a valid‑cell spatial mask
Cells outside Nigeria or with missing covariates are excluded from further processing.


Globally standardise Zi channels
Each channel is normalised using statistics computed over valid cells only, preserving spatial comparability.


Extract overlapping spatial patches
The Zi tensor is decomposed into local spatial neighbourhoods for CNN training, ensuring that the model learns internal geographic structure rather than boundary artefacts.


Prepare data for PyTorch models
Extracted patches are wrapped in custom PyTorch datasets for use in convolutional autoencoders.
