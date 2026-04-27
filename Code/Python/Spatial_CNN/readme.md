Overview
This folder contains the Python components of the dissertation codebase related to spatial representation learning. The purpose of this stage is to construct a low‑dimensional, spatially structured representation of time‑invariant geographic heterogeneity (Zi) using convolutional neural networks (CNNs).
All code in this folder operates exclusively on fixed geographic covariates (e.g. elevation, slope, long‑run climate means, surface water, market accessibility). It is intentionally separated from:

drought shock identification,
NDVI outcome construction,
and downstream econometric modelling.

The output of this stage is a learned representation of geography that is later treated as fixed pre‑treatment heterogeneity in the empirical analysis.

Conceptual role of Zi
Zi is intended to summarise persistent geographic structure that may shape how locations respond to drought shocks. It is:

time‑invariant,
defined at the 10 km × 10 km grid‑cell level,
learned independently of drought shocks and outcomes,
treated as fixed heterogeneity in the econometric framework.

Rather than manually aggregating or selecting spatial covariates, representation learning is used to reduce high‑dimensional spatial data into a small number of latent geographic factors while preserving local spatial structure. The CNN is used purely as a feature extractor, not to predict outcomes directly.

Inputs
The Python pipeline consumes raster layers produced upstream in R and stored in:
Data/Data_Output/Zi/

These raster layers:

represent fixed geographic features only,
share a common equal‑area projection,
are resampled to a 10 km × 10 km grid,
are masked to Nigeria.

Final raster alignment, consistency checks, and standardisation are enforced in Python before any learning takes place.

Spatial representation strategy
Geographic heterogeneity is represented using local spatial neighbourhoods (“patches”) rather than individual grid cells.
Each Zi patch corresponds to a 12 × 12 block of neighbouring grid cells, equivalent to a 120 km × 120 km spatial window. This allows the CNN to learn internal spatial structure (e.g. gradients, heterogeneity, clustering) rather than relying on single‑cell values or country‑level averages.
To avoid artefacts caused by coastlines, borders, and irregular country geometry, patches are sampled around valid grid‑cell centres rather than extracted on a rigid spatial lattice. Missing pixels within patches are permitted and explicitly handled, ensuring national coverage while preserving meaningful spatial variation.

What the current code does
At a high level, the scripts in this folder carry out the following steps:
1. Load and align Zi raster layers
All Zi rasters are read and explicitly resampled onto a common reference grid to ensure identical spatial support across channels.
2. Construct a valid‑cell spatial mask
Grid cells outside Nigeria or with missing covariates are identified and excluded from influencing model estimation.
3. Global standardisation of Zi channels
Each channel is normalised using statistics computed over valid cells only, ensuring comparability across space while avoiding contamination from missing or masked areas.
4. Extraction of spatial patches
The stacked Zi tensor is decomposed into local spatial neighbourhoods centred on valid grid cells.
Patches are sampled across the country, allowing for partial missingness within each patch. This ensures the CNN learns internal geographic structure rather than boundary artefacts or coast effects.
5. Preparation for PyTorch models
Extracted patches are converted into custom PyTorch datasets, ready for use in convolutional autoencoders or related CNN architectures.

Output
The output of this stage is a set of thousands of spatial Zi patches, each representing a local geographic environment. These patches are later passed through a CNN to produce low‑dimensional geographic embeddings, which are then merged back to grid cells and used as fixed heterogeneity in downstream drought‑recovery analysis.
Importantly, no outcome information or drought shock data are used at this stage, ensuring Zi remains strictly pre‑treatment.
