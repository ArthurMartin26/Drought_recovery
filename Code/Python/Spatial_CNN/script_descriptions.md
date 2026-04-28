Rationale: `.pt` files are large binaries, not diffable, and are reproducible from code + data. Keep code + configs in git; store artefacts elsewhere (OneDrive / releases / Zenodo) if needed.

---

## Script 01 — `01_prepare_zi_data.py` (data preparation)

### Purpose
Loads multiple raster layers (zi_*.tif), aligns them onto a common grid, standardises the values, and samples thousands of neighbourhood patches for training.

This script does **not** train anything.

### What it does, step-by-step

1) **Find Zi raster layers**
- Looks for `zi_*.tif` in `Data/Data_Output/Zi`

2) **Align everything to a common grid**
- Uses the first raster as the reference grid
- Reprojects/resamples the remaining rasters onto that grid
- Stacks into one array: `X` with shape (H, W, C)
  - H/W = grid height/width
  - C = number of Zi layers/channels

3) **Create a “valid cell” mask**
- A cell is considered usable if enough channels are finite (default: at least 50% of layers are finite)

Important: “valid” does not mean perfect coverage; it means “enough information to use”.

4) **Standardise each channel**
- For each layer/channel:
  - compute mean and standard deviation using only valid cells
  - standardise layer: (value - mean) / std
- After standardisation, any non-finite values are filled with 0.0

Important: Filling missing with 0.0 is a placeholder choice; it affects how masking works later (see below).

5) **Sample patches**
- Randomly samples centres from valid cells
- For each sampled centre:
  - checks the patch fits within boundaries
  - checks at least `min_valid_frac` of the patch is valid (default 0.4 → 40%)
  - extracts patch (12×12×C by default)
  - sets invalid pixels in the patch to 0.0
  - stores the patch plus its centre `(i, j)`

Important: Patches are allowed to have missing regions inside them. Only a minimum fraction needs to be valid.

6) **Wrap patches as a Dataset**
- Converts patches into PyTorch tensor format: (N, C, H, W)

7) **Optionally save patches**
- Saves `zi_patches.npz` containing patches, centres, and standardisation stats.

### Key outputs
- `dataset`: patches in tensor form
- `centres`: list of (cell_i, cell_j) centre coordinates, one per patch
- `stats`: per-channel mean/std used for standardisation
- `X_std`: full standardised grid (H, W, C)

---

## Script 02 — `02_train_zi_cnn.py` (training / the main script)

### Purpose
Learns a compact representation Zi by training a model that:
- compresses each patch into a small vector (latent_dim)
- then tries to reconstruct the original patch from that vector

Zi is the compressed vector.

### The model architecture (high-level)

Encoder:
- takes (C × 12 × 12) patch
- extracts patterns and downsamples:
  - 12×12 → 6×6 → 3×3
- flattens and compresses to latent_dim (e.g. 4 or 8)

Decoder:
- takes latent vector
- expands back to (C × 12 × 12)

### Denoising
During training only, small random noise is added to inputs:
- `x = x + 0.01 * randn_like(x)`

This forces the encoder to focus on stable structure rather than memorising exact pixel values.

### Training loop (what happens every batch)

For each batch of patches:

1) Move batch to device (CPU/GPU)
2) Run model forward:
   - produce reconstructed patch `X_hat`
   - produce latent vector `z`
3) Compute the loss:
   a) **Masked reconstruction loss**
   - builds a mask where input is non-zero
   - only scores reconstruction error where mask == 1
   - this prevents zero-filled (missing/padding) pixels dominating the score

   b) **Latent variance regularisation**
   - measures how much the latent vectors vary across the batch
   - encourages embeddings not to collapse to the same values everywhere

   Total loss:
   - `loss = recon_loss + lambda_var * z_var`

4) Update the model:
   - `loss.backward()` (backprop)
   - `optimizer.step()` (gradient descent step)

### Important: “True zero” vs “missing”
Current masking logic treats **zero values** as “ignore” in the loss:
- `mask = (X_batch != 0)`

This is fine if zeros only occur because of missing/padding.
But if a channel can genuinely be zero (e.g., slope = 0, or a real anomaly of 0), then those real zeros would be ignored as if they were missing.

This is a conceptual limitation of the current approach.

If this becomes important:
- better approach is to separate “missingness” from “value” (e.g., add an explicit missingness channel or use a sentinel missing value and mask on finite values instead of `!= 0`).

### Reading the recon loss numbers
Recon loss is not a percentage; its absolute value depends on:
- how channels were standardised
- how much of each patch is masked out
- how small latent_dim is
- how noisy/complex the spatial patterns are

A lower recon loss can simply mean you allowed the model to store more information (e.g., latent_dim 8 vs 4). Lower is not automatically “better Zi”; it just means better reconstruction.

### What you save
- `trained_zi_cnn.pt` = model weights (parameters)
This is the learned “rulebook” for producing Zi from patches.

---

## Script 03 — `03_extract_zi_embeddings.py` (extract Zi vectors)

### Purpose
Loads the trained model and applies the encoder to every patch in the dataset to get embeddings.

What it does:

1) Loads the same dataset (patches + centres) via `prepare_zi_data()`
2) Rebuilds the same model architecture
3) Loads trained weights from `trained_zi_cnn.pt`
4) Runs `model.encode()` to produce Zi vectors
5) Writes a CSV with:
   - `z_0 … z_(K-1)`
   - `cell_i`, `cell_j`

### What `cell_i` and `cell_j` represent
They are grid indices (row, column) of the centre cell of each patch:
- `cell_i` = north–south index (row)
- `cell_j` = east–west index (column)

They are **not** lat/long; they are index positions on the raster grid.

### Why there are many NaNs when mapping Zi back to the full grid
Because embeddings are produced only for sampled patch centres (e.g., 3000 samples), not for every grid cell. If you plot a full grid, most cells were never sampled and therefore have no Zi value.

This is expected unless you explicitly extract embeddings for every valid cell.

---

## Plotting Zi “spatially” (what it means)

“Plot Zi spatially” means:
- take each embedding dimension `z_k`
- put it back into a (H × W) grid at the correct (cell_i, cell_j) locations
- colour the grid by the values

If latent_dim = 4 → you plot 4 maps  
If latent_dim = 8 → you plot 8 maps

Important: Zi dimensions have no physical unit. You interpret them by:
- spatial coherence (smooth regions vs noise)
- whether different dimensions capture different patterns
- usefulness downstream (e.g., in regressions)

### Saving figures
The plotting script creates PNGs per dimension and saves them to:
- `Outputs/Figures/CNN_4/` (latent_dim = 4)
- `Outputs/Figures/CNN_8/` (latent_dim = 8)

---

## Comparing CNN_4 vs CNN_8 (how to do it properly)

You now have two folders of PNGs. Comparing them by eye can be misleading because each image may autoscale colours differently.

### What “better” means here
Lower recon loss (0.36 → 0.25 when going 4 → 8) is expected because you allowed more memory. The real question is whether Zi becomes more useful.

Use these checks:

1) **Spatial coherence**
- Are maps smooth and geographically structured, or speckled/noisy?
- Do z_0–z_3 show stable structure in both models?

2) **Do the extra dimensions (z_4–z_7) add real structure?**
- If they show coherent regions/gradients: useful added information.
- If they look like random speckle: likely not helpful.

3) **Redundancy**
- If z_4–z_7 are basically duplicates of z_0–z_3, you gained little.

4) **Downstream usefulness (best test)**
- Run your downstream analysis with Zi=4 vs Zi=8.
- Prefer the smallest Zi that produces stable, interpretable results.

### Fair visual comparison recommendation
For a fair visual comparison, regenerate plots from the CSVs using the same colour limits for both models (shared vmin/vmax per dimension). Otherwise, the PNGs can mislead.

Practical tip: save separate embeddings files:
- `zi_embeddings_4.csv`
- `zi_embeddings_8.csv`
so you can regenerate fair comparison figures.

---

## Common gotchas / troubleshooting

### 1) “Red underline” when importing `01_prepare_...`
Python cannot import modules whose names start with a number:
- `from 01_prepare_zi_data import ...` is invalid

Fix:
- rename to `prepare_zi_data_01.py` (or similar) and import from that.

### 2) `zipfile.BadZipFile` related to `Path(...)`
If you see errors pointing to `zipfile.py` when using `Path(__file__)`, it means `Path` was shadowed (you ended up using `zipfile.Path` instead of `pathlib.Path`).

Fix:
- use `import pathlib` and call `pathlib.Path(...)` explicitly everywhere.

### 3) NaNs in spatial plots
Expected if you only extracted embeddings for a sample of centres (e.g. 3000). Most cells will remain undefined.

---

## Suggested experimentation strategy (simple and defensible)

To improve the model, focus on the two big design levers:

1) Patch size (spatial scale)
- smaller patch → more local context, potentially noisier
- larger patch → more regional context, potentially smoother but may blur heterogeneity

2) latent_dim (Zi size)
- smaller Zi → stronger compression, simpler, more interpretable
- larger Zi → better reconstruction, potentially more detail but risk of capturing noise

A clean minimal plan:
- baseline: patch 12×12, Zi=4
- variant A: patch 12×12, Zi=8
- variant B: patch 8×8, Zi=4

Compare:
- spatial maps (coherence, new structure)
- redundancy across dims
- downstream usefulness

---

## How to run (typical order)

1) Prepare patches (optional to run standalone; training calls this internally)
- `python 01_prepare_zi_data.py`

2) Train model
- `python 02_train_zi_cnn.py`
This creates `trained_zi_cnn.pt`

3) Extract embeddings
- `python 03_extract_zi_embeddings.py`
This creates `zi_embeddings.csv` (rename to zi_embeddings_4.csv / zi_embeddings_8.csv as needed)

4) Plot embeddings
- `python plot_zi_spatial_04.py`
This saves PNG maps to Outputs/Figures/CNN_* folders

---

## What to write in the dissertation (short conceptual description)

We learn a low-dimensional place representation Zi from multiple baseline raster layers by training a patch-based autoencoding model. Each training example is a local spatial neighbourhood (patch) centred on a grid cell. The model compresses each patch into a latent vector Zi and is trained to reconstruct the original patch while ignoring missing/padded cells via masking. Zi vectors are then extracted for sampled centre cells and used as baseline covariates/representations in downstream analysis.

---

## Notes / limitations to be aware of

- The current masking approach treats zeros as missing, which can ignore real zeros in some channels. If channels include meaningful zeros (e.g., slope), consider a missingness mask channel or a sentinel missing value.
- Zi values have no direct interpretation by units; interpretation is via spatial structure and downstream usefulness.
- Embeddings are currently produced only for sampled centres, so spatial maps will have gaps unless you extract for every valid cell.
