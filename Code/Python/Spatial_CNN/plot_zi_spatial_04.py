# ======================================================
# plot_zi_spatial_04.py
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
    / "zi_embeddings.csv"
)

FIG_DIR = (
    PROJECT_ROOT
    / "Outputs"
    / "Figures"
    / "CNN_8"
)

# ensure output folder exists
FIG_DIR.mkdir(parents=True, exist_ok=True)

# ------------------
# Load Zi embeddings
# ------------------
df = pd.read_csv(ZI_PATH)

z_cols = [c for c in df.columns if c.startswith("z_")]

H = int(df["cell_i"].max() + 1)
W = int(df["cell_j"].max() + 1)

print(f"Grid size: {H} x {W}")
print(f"Zi dimensions: {z_cols}")
print(f"Saving figures to: {FIG_DIR}")

# ------------------
# Plot + save Zi maps
# ------------------
for z in z_cols:
    grid = np.full((H, W), np.nan)

    for _, row in df.iterrows():
        grid[int(row["cell_i"]), int(row["cell_j"])] = row[z]

    plt.figure(figsize=(6, 5))
    im = plt.imshow(grid, cmap="viridis", origin="upper")
    plt.colorbar(im, label=z)

    plt.title(f"Spatial map of {z}")
    plt.xlabel("cell_j")
    plt.ylabel("cell_i")
    plt.tight_layout()

    # ---- SAVE ----
    out_path = FIG_DIR / f"{z}_spatial.png"
    plt.savefig(out_path, dpi=300)

    plt.close()   # important: prevents memory buildup
    print(f"Saved: {out_path}")