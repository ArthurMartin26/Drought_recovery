# ======================================================
# extract_zi_embeddings_fullgrid_06.py
# Apply trained Zi CNN encoder to ALL valid grid cells
# and write z_0..z_7 per cell to CSV.
# ======================================================

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from pathlib import Path
import rasterio
from rasterio.warp import reproject, Resampling



# ------------------
# Paths (match your repo convention)
# ------------------
PROJECT_ROOT = Path(__file__).resolve().parents[3]
ZI_DIR = PROJECT_ROOT / "Data" / "Data_Output" / "Zi"


# ------------------
# Model definition (MUST match training)
# ------------------
class SpatialAutoencoder(nn.Module):
    def __init__(self, in_channels, latent_dim=8):
        super().__init__()

        self.encoder = nn.Sequential(
            nn.Conv2d(in_channels, 32, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.AvgPool2d(2),

            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.AvgPool2d(2)
        )

        self.fc_enc = nn.Linear(64 * 3 * 3, latent_dim)

        # Decoder kept for completeness (not used in extraction)
        self.fc_dec = nn.Linear(latent_dim, 64 * 3 * 3)
        self.decoder = nn.Sequential(
            nn.Upsample(scale_factor=2),
            nn.Conv2d(64, 32, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.Upsample(scale_factor=2),
            nn.Conv2d(32, in_channels, kernel_size=3, padding=1)
        )

    def encode(self, x):
        h = self.encoder(x)
        h = h.flatten(start_dim=1)
        z = self.fc_enc(h)
        return z


# ------------------
# Raster loading & alignment
# ------------------
def _read_and_align(src_path, ref_meta):
    """Read a raster and reproject/resample onto the reference grid."""
    with rasterio.open(src_path) as src:
        src_data = src.read(1).astype("float32")

        # Allocate destination on ref grid
        dst = np.empty((ref_meta["height"], ref_meta["width"]), dtype="float32")

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
    Load all zi_*.tif, align to first raster grid, stack to X (H, W, C).
    Returns: X, zi_files, ref_meta
    """
    zi_files = sorted(zi_dir.glob("zi_*.tif"))
    if len(zi_files) == 0:
        raise FileNotFoundError(f"No zi_*.tif found in: {zi_dir}")

    with rasterio.open(zi_files[0]) as ref:
        ref_meta = {
            "height": ref.height,
            "width": ref.width,
            "transform": ref.transform,
            "crs": ref.crs
        }
        X0 = ref.read(1).astype("float32")

    layers = [X0]
    for fp in zi_files[1:]:
        layers.append(_read_and_align(fp, ref_meta))

    # Stack as (H, W, C)
    X = np.stack(layers, axis=-1).astype("float32")
    return X, zi_files, ref_meta


# ------------------
# Masking & standardisation
# ------------------
def get_valid_mask(X, min_channels_frac=0.5):
    """
    Cell valid if >= min_channels_frac of channels are finite.
    """
    C = X.shape[-1]
    finite_counts = np.sum(np.isfinite(X), axis=-1)
    return finite_counts >= (min_channels_frac * C)


def standardise_channels(X, valid_mask, eps=1e-6):
    """
    Standardise each channel using mean/std over valid cells only.
    Fill non-finite with 0 after standardisation.
    Returns X_std, stats (list of dicts with mean/std)
    """
    H, W, C = X.shape
    X_std = X.copy().astype("float32")
    stats = []

    for c in range(C):
        chan = X[:, :, c]
        vals = chan[valid_mask & np.isfinite(chan)]
        if vals.size == 0:
            # Degenerate channel; keep zeros
            mu, sd = 0.0, 1.0
        else:
            mu = float(np.mean(vals))
            sd = float(np.std(vals))
            if sd < eps:
                sd = 1.0

        X_std[:, :, c] = (chan - mu) / sd
        stats.append({"mean": mu, "std": sd})

    # Fill any non-finite with 0.0
    X_std[~np.isfinite(X_std)] = 0.0
    return X_std, stats


# ------------------
# Full-grid patch extraction + embedding
# ------------------
def extract_fullgrid_embeddings(
    model_path,
    output_path=None,
    zi_dir=ZI_DIR,
    latent_dim=8,
    patch_size=12,
    batch_size=256,
    min_channels_frac=0.5,
    min_valid_frac=0.4,
    pad_edges=True,
    write_xy=True
):
    """
    Apply trained encoder to all valid cells and save CSV.

    pad_edges=True pads X with zeros so every cell can be centred;
    min_valid_frac still applies (fraction of valid cells in the patch).
    Set min_valid_frac=0.0 if you truly want EVERY valid centre regardless.
    """
    print("Loading & aligning rasters...")
    X, zi_files, ref_meta = load_zi_stack(Path(zi_dir))
    H, W, C = X.shape
    print(f"  Grid: {H} x {W}, channels: {C}, rasters: {len(zi_files)}")

    print("Building valid mask...")
    valid_mask = get_valid_mask(X, min_channels_frac=min_channels_frac)
    n_valid = int(valid_mask.sum())
    print(f"  Valid cells (mask): {n_valid}")

    print("Standardising channels (global, over valid cells only)...")
    X_std, stats = standardise_channels(X, valid_mask)

    half = patch_size // 2
    if pad_edges:
        X_pad = np.pad(X_std, ((half, half), (half, half), (0, 0)), mode="constant", constant_values=0.0)
        M_pad = np.pad(valid_mask.astype(np.uint8), ((half, half), (half, half)), mode="constant", constant_values=0)
        offset = half
    else:
        X_pad = X_std
        M_pad = valid_mask.astype(np.uint8)
        offset = 0

    centres = np.argwhere(valid_mask)  # (N, 2) -> (i, j)
    # Optional: filter out centres too close to borders if no padding
    if not pad_edges:
        keep = (
            (centres[:, 0] - half >= 0) &
            (centres[:, 0] + (patch_size - half) <= H) &
            (centres[:, 1] - half >= 0) &
            (centres[:, 1] + (patch_size - half) <= W)
        )
        centres = centres[keep]

    print(f"  Centres to embed: {len(centres)}")

    # Load model
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Loading model on {device} from: {model_path}")

    model = SpatialAutoencoder(in_channels=C, latent_dim=latent_dim).to(device)

    state = torch.load(model_path, map_location=device)
    # Handle common checkpoint wrappers
    if isinstance(state, dict) and any(k in state for k in ["state_dict", "model_state_dict"]):
        state = state.get("state_dict", state.get("model_state_dict"))

    model.load_state_dict(state)
    model.eval()

    # Affine for x,y coordinates (if requested)
    transform = ref_meta.get("transform", None)

    rows = []
    z_cols = [f"z_{k}" for k in range(latent_dim)]

    print("Embedding full grid in batches...")
    with torch.no_grad():
        for start in range(0, len(centres), batch_size):
            batch = centres[start:start + batch_size]
            n_b = batch.shape[0]

            patches = np.zeros((n_b, patch_size, patch_size, C), dtype="float32")
            keep_flags = np.ones(n_b, dtype=bool)

            for t in range(n_b):
                i, j = int(batch[t, 0]), int(batch[t, 1])
                ip = i + offset
                jp = j + offset

                si = ip - half
                sj = jp - half

                patch = X_pad[si:si + patch_size, sj:sj + patch_size, :]
                mpatch = M_pad[si:si + patch_size, sj:sj + patch_size]

                # Valid fraction criterion
                vfrac = float(mpatch.mean())
                if vfrac < min_valid_frac:
                    keep_flags[t] = False
                    continue

                # Set invalid pixels (where mask==0) to 0.0 across all channels
                if mpatch.dtype != np.bool_:
                    mbool = (mpatch != 0)
                else:
                    mbool = mpatch
                patch = patch.copy()
                patch[~mbool, :] = 0.0

                patches[t] = patch

            if not np.any(keep_flags):
                continue

            patches_kept = patches[keep_flags]
            batch_kept = batch[keep_flags]

            # To torch: (N, C, H, W)
            x = torch.from_numpy(patches_kept).permute(0, 3, 1, 2).to(device)

            z = model.encode(x).cpu().numpy()

            # Write rows
            for idx in range(z.shape[0]):
                i = int(batch_kept[idx, 0])
                j = int(batch_kept[idx, 1])
                rec = {z_cols[k]: float(z[idx, k]) for k in range(latent_dim)}
                rec["cell_i"] = i
                rec["cell_j"] = j

                if write_xy and transform is not None:
                    # Pixel centre coords
                    x_c, y_c = transform * (j + 0.5, i + 0.5)
                    rec["x"] = float(x_c)
                    rec["y"] = float(y_c)

                rows.append(rec)

            if (start // batch_size) % 10 == 0:
                print(f"  Processed {min(start + batch_size, len(centres))} / {len(centres)} centres...")

    df = pd.DataFrame(rows)

    # Default output path
    if output_path is None:
        output_path = PROJECT_ROOT / "Data" / "Data_Output" / "Zi" / f"zi_embeddings_fullgrid_{latent_dim}.csv"

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)

    print(f"Done. Wrote {len(df)} rows to: {output_path}")
    return df


if __name__ == "__main__":
    # Adjust if you store your .pt elsewhere
    MODEL_PATH = PROJECT_ROOT / "Data" / "Data_Output" / "Zi" / "trained_zi_cnn.pt"
    extract_fullgrid_embeddings(
        model_path=str(MODEL_PATH),
        latent_dim=8,
        patch_size=12,
        batch_size=256,
        min_channels_frac=0.5,
        min_valid_frac=0.4,
        pad_edges=True,
        write_xy=True
    )
