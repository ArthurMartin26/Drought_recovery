import rasterio
import numpy as np
from pathlib import Path
from rasterio.warp import reproject, Resampling

ZI_DIR = Path(r'c:\Users\Arthur.Martin\OneDrive - Department of Health and Social Care\Documents\LSE\DV495_DISSERTATION\Drought_recovery\Data\Data_Output\Zi')
zi_files = sorted(ZI_DIR.glob('zi_*.tif'))

# Load reference
with rasterio.open(zi_files[0]) as ref:
    ref_meta = ref.meta.copy()
    arrays = [ref.read(1).astype("float32")]

# Align remaining
for f in zi_files[1:]:
    with rasterio.open(f) as src:
        src_data = src.read(1).astype("float32")
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
        arrays.append(dst)

X = np.stack(arrays, axis=-1)
print('X shape:', X.shape)
print('X has NaN:', np.isnan(X).any())

# Check get_valid_mask logic
C = X.shape[-1]
finite_counts = np.sum(np.isfinite(X), axis=-1)
print('finite_counts shape:', finite_counts.shape)
print('finite_counts unique values:', np.unique(finite_counts))

min_channels_frac = 0.5
mask = finite_counts >= (min_channels_frac * C)
print('mask True count:', mask.sum())

# Now check standardise_channels
X_std = X.copy()
stats = {}
for c in range(C):
    vals = X[..., c][mask]
    print(f'Channel {c}: mask True={mask.sum()}, vals shape={vals.shape}, finite={np.isfinite(vals).sum()}')
    mu = vals.mean()
    sd = vals.std()
    stats[c] = {"mean": mu, "std": sd}
    print(f'  mu={mu}, sd={sd}')

# Check if vals has any finite values
print('\nDebug: what does X[..., 0][mask] contain?')
ch0_vals = X[..., 0][mask]
print('  Shape:', ch0_vals.shape)
print('  Finite count:', np.isfinite(ch0_vals).sum())
print('  Sample:', ch0_vals[:10])