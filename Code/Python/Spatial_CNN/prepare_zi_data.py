# ======================================================
# prepare_zi_data.py
# Build spatial Zi patches for CNN representation learning
# ======================================================

# ------------------
# Imports
# ------------------
from pathlib import Path
import numpy as np
import rasterio
from rasterio.warp import reproject, Resampling
import torch
from torch.utils.data import Dataset


# ------------------
# Paths
# ------------------
PROJECT_ROOT = Path(__file__).resolve().parents[3]
ZI_DIR = PROJECT_ROOT / "Data" / "Data_Output" / "Zi"


# ------------------
# Raster loading & alignment
# ------------------
def read_and_align(path, ref_meta):
    """Reproject a raster to the reference grid."""
    with rasterio.open(path) as src:
        src_data = src.read(1).astype("float32")

        dst = np.empty(
            (ref_meta["height"], ref_meta["width"]),
            dtype="float32"
        )

        reproject(
            source=src_data,
            destination=dst,
            src_transform=src.transform,
            src_crs=src.crs,
            dst_transform=ref_meta["transform"],
            dst_crs=ref_meta["crs"],
            resampling=Resampling.bilinear
        )

    return dst


def load_zi_stack(zi_dir):
    """
    Load and align all Zi rasters onto a common grid.
    """
    zi_files = sorted(zi_dir.glob("zi_*.tif"))

    if len(zi_files) == 0:
        raise FileNotFoundError("No zi_*.tif files found")

    arrays = []

    # --- reference grid ---
    with rasterio.open(zi_files[0]) as ref:
        ref_meta = ref.meta.copy()
        arrays.append(ref.read(1).astype("float32"))

    # --- align remaining rasters ---
    for f in zi_files[1:]:
        aligned = read_and_align(f, ref_meta)
        arrays.append(aligned)

    X = np.stack(arrays, axis=-1)
    return X, zi_files, ref_meta


# ------------------
# Masking & standardisation
# ------------------
def get_valid_mask(X, min_channels_frac=0.5):
    """
    Cell is valid if enough Zi channels are finite.
    """
    C = X.shape[-1]
    finite_counts = np.sum(np.isfinite(X), axis=-1)
    return finite_counts >= (min_channels_frac * C)


def standardise_channels(X, mask):
    """
    Global standardisation per channel,
    computed over valid cells only.
    """
    X_std = X.copy()
    C = X.shape[-1]
    stats = {}

    for c in range(C):
        vals = X[..., c][mask]
        mu = vals.mean()
        sd = vals.std()

        X_std[..., c] = (X[..., c] - mu) / sd
        stats[c] = {"mean": mu, "std": sd}

    # Safe fill after standardisation
    X_std[~np.isfinite(X_std)] = 0.0

    return X_std, stats


# ------------------
# Patch sampling
# ------------------
def sample_patches_from_centres(
    X,
    mask,
    patch_size=12,
    n_samples=3000,
    min_valid_frac=0.4,
    seed=42
):
    rng = np.random.default_rng(seed)

    H, W, C = X.shape
    ps = patch_size
    half = ps // 2

    valid_centres = np.argwhere(mask)

    patches = []
    centres = []

    min_valid = ps * ps * min_valid_frac

    for _ in range(n_samples):
        i, j = valid_centres[rng.integers(len(valid_centres))]

        # boundary check
        if i - half < 0 or j - half < 0:
            continue
        if i + half > H or j + half > W:
            continue

        patch_mask = mask[i-half:i+half, j-half:j+half]
        if patch_mask.sum() < min_valid:
            continue

        patch = X[i-half:i+half, j-half:j+half, :].copy()
        patch[~patch_mask] = 0.0

        patches.append(patch)
        centres.append((i, j))

    return np.stack(patches), centres


# ------------------
# PyTorch dataset
# ------------------
class ZiPatchDataset(Dataset):
    def __init__(self, patches):
        self.X = torch.from_numpy(patches).permute(0, 3, 1, 2)

    def __len__(self):
        return self.X.shape[0]

    def __getitem__(self, idx):
        return self.X[idx]


# ------------------
# Public builder function
# ------------------
def build_zi_dataset(
    patch_size=12,
    n_samples=3000,
    min_valid_frac=0.4
):
    X, zi_files, meta = load_zi_stack(ZI_DIR)
    mask = get_valid_mask(X)
    X_std, stats = standardise_channels(X, mask)

    patches, centres = sample_patches_from_centres(
        X_std,
        mask,
        patch_size=patch_size,
        n_samples=n_samples,
        min_valid_frac=min_valid_frac
    )

    dataset = ZiPatchDataset(patches)

    return dataset, centres, meta, stats, X


# ------------------
# Script entry point (optional)
# ------------------
if __name__ == "__main__":
    print("Project root:", PROJECT_ROOT)
    print("Zi directory:", ZI_DIR)
    print("Files found:")
    for f in ZI_DIR.glob("zi_*.tif"):
        print(" ", f.name)

    dataset, centres, meta, stats, X = build_zi_dataset()

    print("Zi shape:", X.shape)
    print("Patches:", len(dataset))
    print("Channels:", X.shape[-1])