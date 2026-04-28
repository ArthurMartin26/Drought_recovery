## updated 

# Spatial CNN (Zi) — README

This folder contains the code to learn a compact “baseline place signature” (Zi) from stacked spatial rasters. The workflow is:

1) build many local neighbourhood **patches** from aligned raster layers  
2) train a model to **compress each patch into a small vector** (Zi) while still being able to roughly reconstruct the patch  
3) apply the trained encoder to extract Zi vectors and save them with grid coordinates  
4) plot Zi dimensions as maps and compare different model settings (e.g., Zi size 4 vs 8)

The important mental model is:

- The model learns to reconstruct the **patch**, not an individual cell.
- Each centre cell (cell_i, cell_j) is assigned the Zi vector produced from the patch centred on that cell.
- If latent_dim = K, you get **K separate Zi maps** (z_0 … z_(K-1)), one per dimension.

---

## What “patch”, “batch”, “gradient descent”, and “backprop” mean (in this project)

### Patch (spatial concept)
A **patch** is a small square cut-out of the raster grid around a location.  
In this project the default is 12×12 grid cells. If your grid cells are ~10 km, a 12×12 patch represents roughly a 120 km × 120 km neighbourhood.

Why patches exist: geography is spatial; a single cell is not enough context. A patch gives the model the “neighbourhood look” of a place.

### Batch (computation concept)
A **batch** is a group of patches processed together before updating the model (e.g., 64 patches at a time).  
Batches exist for speed and stability: updating after one patch would be slow and noisy.

### Backpropagation (where it happens)
Backprop is triggered by:
- `loss.backward()`

This tells PyTorch to work out how each internal parameter contributed to the error.

### Gradient descent (where it happens)
Gradient descent happens when:
- `optimizer.step()`

This applies a small update to model parameters to reduce the loss next time.

---

## Repository / folder conventions

Typical outputs created by this pipeline:

- Trained model weights: `trained_zi_cnn.pt`  
  (large binary artefact; should not be committed to git)
- Embeddings: `zi_embeddings.csv` (or separate `zi_embeddings_4.csv`, `zi_embeddings_8.csv`)
- Figures: `Outputs/Figures/CNN_4/`, `Outputs/Figures/CNN_8/`, and optional comparison folders




=================================================================


Spatial CNN – Learning Fixed Geographic Heterogeneity (Zi)
Overview
This folder contains the Python components of the dissertation codebase related to spatial representation learning. The purpose of this stage is to construct a low‑dimensional, spatially structured representation of time‑invariant geographic heterogeneity (Zi) using convolutional neural networks (CNNs).
All code in this folder operates exclusively on fixed geographic covariates (e.g. elevation, slope, surface water, market accessibility). It is intentionally separated from:

drought shock identification,
NDVI outcome construction,
and downstream econometric modelling.

The output of this stage is a learned representation of geography, which is later treated as fixed pre‑treatment heterogeneity in the empirical drought‑recovery analysis.

Conceptual role of Zi
Zi is intended to summarise persistent geographic structure that may shape how locations respond to drought shocks. It is:

time‑invariant,
defined at the 10 km × 10 km grid‑cell level,
learned independently of drought shocks and outcomes,
treated as fixed heterogeneity in the econometric framework.

Rather than manually aggregating or selecting spatial covariates (e.g. averaging elevation, distance to market, water coverage), representation learning is used to compress high‑dimensional spatial data into a small number of latent geographic factors, while preserving local spatial structure.
The CNN is used purely as a feature extractor, not to predict outcomes directly.

Inputs
The Python pipeline consumes raster layers produced upstream in R and stored in:
Data/Data_Output/Zi/

These raster layers:

represent fixed geographic features only,
share a common equal‑area projection,
are resampled to a 10 km × 10 km grid,
are masked to Nigeria.

Final raster alignment, consistency checks, and global standardisation are enforced in Python before any learning takes place.

Spatial representation strategy
Geographic heterogeneity is represented using local spatial neighbourhoods (“patches”) rather than individual grid cells.

Each Zi patch corresponds to a 12 × 12 block of neighbouring grid cells, equivalent to a 120 km × 120 km spatial window.
This allows the CNN to learn internal spatial structure (gradients, clustering, heterogeneity) rather than relying on single‑cell values or country‑level averages.
To avoid artefacts caused by coastlines, borders, and irregular country geometry, patches are sampled around valid grid‑cell centres rather than extracted on a rigid spatial lattice.
Missing pixels within patches are permitted and explicitly handled; patches must exceed a minimum valid‑pixel fraction.

This design ensures the CNN learns meaningful geographic structure rather than boundary artefacts or coast effects.

What the current code does
At a high level, the scripts in this folder implement the following pipeline.
1. Load and align Zi raster layers
All Zi rasters are read and explicitly reprojected / resampled onto a common reference grid to ensure identical spatial support across channels.
2. Construct a valid‑cell spatial mask
Grid cells outside Nigeria or with insufficient finite covariate information are identified and excluded from influencing model estimation.
3. Global standardisation of Zi channels
Each Zi channel is normalised using global statistics computed over valid cells only, ensuring:

comparability across space,
no contamination from masked or missing areas.

After standardisation, invalid pixels are safely filled with zeros.
4. Extraction of spatial patches (training sample)
The stacked Zi tensor is decomposed into local spatial neighbourhoods centred on valid grid cells.

A random sample of ~3,000 candidate centres is drawn from the valid grid.
Each candidate yields a 12 × 12 × C patch if it satisfies minimum validity criteria.
The final training sample consists of ~2,800 patches, depending on feasibility around borders and masked areas.

This sampling strategy is intentionally used to:

reduce computational burden,
avoid excessive spatial redundancy,
ensure national coverage during representation learning.

5. Preparation for PyTorch
Extracted patches are converted into a custom PyTorch Dataset with shape:
(batch, channels, height, width)

ready for CNN‑based models.

CNN architecture and training
A convolutional autoencoder is used for representation learning.

The encoder consists of two convolutional layers with average pooling.
The latent space has low dimensionality (currently 4).
The decoder mirrors the encoder and is used only during training.

The model is trained unsupervised, minimising mean‑squared reconstruction error.
To prevent trivial identity mappings and encourage learning of robust spatial features, the model is trained as a denoising autoencoder, with small amounts of random noise added to input patches during training.
Training converges rapidly; empirical experimentation shows that ~10 epochs are sufficient for stable convergence. Additional epochs do not materially change the learned representation.

What Zi is (and what it is not)
At this stage:

Zi is not a raster
Zi is not a neural network
Zi is a numeric latent embedding

Formally, Zi is the encoder output:
Zi = fθ(local spatial patch)

where fθ is the trained CNN encoder.
Each Zi observation is a vector of length K (latent dimension), summarising the local geographic environment around a grid cell.

Current output (checkpoint)
The script extract_zi_embeddings.py currently:

runs the trained encoder on the sampled patch centres only,
produces a tabular dataset with shape approximately:

(~2,800 rows × [zi_1 … zi_K + identifiers])

This output is primarily intended for:

debugging,
sanity checks,
visualisation of learned factors.


Important note: full‑grid Zi extraction (next step)
The Nigerian analysis grid contains ~14,000 cells (112 × 124), of which a slightly smaller subset are valid.
At present, Zi has been extracted only for the training patch centres, not for all grid cells.
The next step in this pipeline is therefore to:

apply the trained encoder to every valid grid cell,
extracting a local 12 × 12 patch around each cell,
producing a full‑coverage Zi matrix aligned to the drought–NDVI panel.

This distinction between:

training‑time patch sampling, and
inference‑time full‑grid application

is intentional and mirrors standard representation‑learning practice.

Output (intended final form)
The final output of this stage will be a dataset of the form:
(cell_id, row, col, zi_1, zi_2, …, zi_K)

with one row per 10 km × 10 km grid cell in Nigeria.
These Zi variables will then be merged into the downstream econometric analysis and treated as fixed pre‑treatment geographic heterogeneity.



