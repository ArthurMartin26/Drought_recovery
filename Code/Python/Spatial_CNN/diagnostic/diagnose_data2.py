import numpy as np
from prepare_zi_data import load_zi_stack, get_valid_mask, standardise_channels, ZI_DIR

# Step 1: Load raw data
X, zi_files, meta = load_zi_stack(ZI_DIR)
print('Raw X shape:', X.shape)
print('Raw X min/max:', X.min(), X.max())
print('Raw X has NaN:', np.isnan(X).any())
print('Raw X has Inf:', np.isinf(X).any())

# Step 2: Get valid mask
mask = get_valid_mask(X)
print('\nValid mask:')
print('  Shape:', mask.shape)
print('  True count:', mask.sum())
print('  False count:', (~mask).sum())

# Step 3: Standardize
X_std, stats = standardise_channels(X, mask)
print('\nStandardized X:')
print('  Min/Max:', X_std.min(), X_std.max())
print('  Has NaN:', np.isnan(X_std).any())
print('  Has Inf:', np.isinf(X_std).any())
print('  Non-zero count:', (X_std != 0).sum())

# Check per-channel
print('\nPer-channel after standardization:')
for c in range(X_std.shape[-1]):
    ch = X_std[..., c]
    print(f'  Channel {c}: min={ch.min():.4f}, max={ch.max():.4f}, mean={ch.mean():.4f}, non-zero={ (ch != 0).sum()}')