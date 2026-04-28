import numpy as np
from prepare_zi_data import load_zi_stack, get_valid_mask, standardise_channels, sample_patches_from_centres, ZI_DIR

# Load and process
X, zi_files, meta = load_zi_stack(ZI_DIR)
mask = get_valid_mask(X)
X_std, stats = standardise_channels(X, mask)

print('Stats per channel:')
for c, s in stats.items():
    print(f'  Channel {c}: mean={s["mean"]:.4f}, std={s["std"]:.4f}')

# Check a single valid cell before patching
valid_centres = np.argwhere(mask)
print(f'\nTotal valid centres: {len(valid_centres)}')

# Sample some patches
patches, centres = sample_patches_from_centres(X_std, mask, patch_size=12, n_samples=10)

print(f'\nSampled {len(patches)} patches')
print('Patch shape:', patches.shape)
print('Patch min/max:', patches.min(), patches.max())
print('Patch mean:', patches.mean())

# Check first patch
print('\nFirst patch stats:')
p0 = patches[0]
print('  Shape:', p0.shape)
print('  Unique values:', np.unique(p0))
print('  Non-zero count:', (p0 != 0).sum())