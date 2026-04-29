# ======================================================
# plot_zi_spatial_fullgrid_07.py
# Plot all Zi dimensions (full grid) in a single figure
# ======================================================

import pathlib
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# ------------------
# Paths
# ------------------
PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[3]

ZI_PATH = (
    PROJECT_ROOT
    / "Data"
    / "Data_Output"
    / "Zi"
    / "zi_embeddings_fullgrid_8.csv"   # adjust name if needed
)

FIG_DIR = (
    PROJECT_ROOT
    / "Outputs"
    / "Figures"
    / "CNN_8"
)

FIG_DIR.mkdir(parents=True, exist_ok=True)

# ------------------
# Load Zi embeddings
# ------------------
df = pd.read_csv(ZI_PATH)

z_cols = [c for c in df.columns if c.startswith("z_")]
z_cols = sorted(z_cols)   # ensure z_0 ... z_7 order

H = int(df["cell_i"].max() + 1)
W = int(df["cell_j"].max() + 1)

print(f"Grid size: {H} x {W}")
print(f"Zi dimensions: {z_cols}")
print(f"Saving figure to: {FIG_DIR}")

# ------------------
# Build grids for each Zi
# ------------------
zi_grids = {}

for z in z_cols:
    grid = np.full((H, W), np.nan)

    for _, row in df.iterrows():
        grid[int(row["cell_i"]), int(row["cell_j"])] = row[z]

    zi_grids[z] = grid

# ------------------
# Plot: 2 x 4 panel figure
# ------------------
fig, axes = plt.subplots(2, 4, figsize=(18, 9), constrained_layout=True)

axes = axes.flatten()

for ax, z in zip(axes, z_cols):
    im = ax.imshow(
        zi_grids[z],
        cmap="viridis",
        origin="upper"
    )

    ax.set_title(z)
    ax.set_xticks([])
    ax.set_yticks([])

    # colourbar per subplot (small, unobtrusive)
    cbar = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    cbar.ax.tick_params(labelsize=8)

# overall title
fig.suptitle(
    "Learned Geographic Heterogeneity (Zi)\nFull 10 km Grid, Nigeria",
    fontsize=16
)

# ---- SAVE ----
out_path = FIG_DIR / "zi_spatial_fullgrid_8panel.png"
plt.savefig(out_path, dpi=300)
plt.close()

print(f"Saved combined Zi figure to: {out_path}")