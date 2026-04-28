import numpy as np
from prepare_zi_data import build_zi_dataset

dataset, centres, meta, stats, X = build_zi_dataset()
print('Dataset shape:', dataset.X.shape)
print('Number of channels (C):', dataset[0].shape[0])
print('Unique values in first sample:', np.unique(dataset[0].numpy())[:10])
print('Any NaN?', np.isnan(dataset.X).any())
print('Any Inf?', np.isinf(dataset.X).any())
print('Min/Max:', dataset.X.min().item(), '/', dataset.X.max().item())
print('Mean:', dataset.X.mean().item())
print('Std:', dataset.X.std().item())
print('Number of valid centres:', len(centres))

# Check how many patches are all zeros
all_zero = (dataset.X == 0).all(dim=(1,2,3)).sum().item()
print(f'Patches that are all zeros: {all_zero} / {len(dataset)}')

# Check value distribution per channel
print('\nPer-channel stats:')
for c in range(dataset[0].shape[0]):
    ch_data = dataset.X[:, c, :, :]
    valid = ch_data[ch_data != 0]
    if len(valid) > 0:
        print(f'  Channel {c}: mean={valid.mean():.4f}, std={valid.std():.4f}, non-zero count={len(valid)}')
    else:
        print(f'  Channel {c}: ALL ZERO')