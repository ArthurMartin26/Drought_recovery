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

print('After loading ref:')
print('  Shape:', arrays[0].shape)
print('  Valid:', np.isfinite(arrays[0]).sum())

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
        print(f'After {f.name}:')
        print('  Shape:', dst.shape)
        print('  Valid:', np.isfinite(dst).sum())

# Stack
X = np.stack(arrays, axis=-1)
print('\nFinal X shape:', X.shape)
print('Final X valid count:', np.isfinite(X).sum(axis=(0,1)))

# Check per-channel
print('\nPer-channel valid counts:')
for c in range(X.shape[-1]):
    valid = np.isfinite(X[..., c]).sum()
    print(f'  Channel {c}: {valid} / {X.shape[0]*X.shape[1]}')