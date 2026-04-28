import rasterio
import numpy as np
from pathlib import Path
from rasterio.warp import reproject, Resampling

ZI_DIR = Path(r'c:\Users\Arthur.Martin\OneDrive - Department of Health and Social Care\Documents\LSE\DV495_DISSERTATION\Drought_recovery\Data\Data_Output\Zi')
zi_files = sorted(ZI_DIR.glob('zi_*.tif'))

print('Loading reference file:', zi_files[0].name)
with rasterio.open(zi_files[0]) as ref:
    ref_meta = ref.meta.copy()
    ref_data = ref.read(1).astype("float32")
    print('  Ref shape:', ref_data.shape)
    print('  Ref meta:', ref_meta)

# Try reprojecting the second file
print('\nLoading second file:', zi_files[1].name)
with rasterio.open(zi_files[1]) as src:
    src_data = src.read(1).astype("float32")
    print('  Src shape:', src_data.shape)
    print('  Src valid:', np.isfinite(src_data).sum())
    
    dst = np.empty((ref_meta["height"], ref_meta["width"]), dtype="float32")
    print('  Dst shape:', dst.shape)
    
    reproject(
        source=src_data,
        destination=dst,
        src_transform=src.transform,
        src_crs=src.crs,
        dst_transform=ref_meta["transform"],
        dst_crs=ref_meta["crs"],
        resampling=Resampling.bilinear
    )
    
    print('  Reprojected valid:', np.isfinite(dst).sum())
    print('  Reprojected sample:', dst[50:55, 50:55])