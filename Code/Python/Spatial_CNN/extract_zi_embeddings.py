# ======================================================
# extract_zi_embeddings.py
# Extract learned Zi embeddings from trained CNN encoder
# ======================================================

# ------------------
# Imports
# ------------------
import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
import pandas as pd

from prepare_zi_data import build_zi_dataset


# ------------------
# Model definition
# (must match training architecture exactly)
# ------------------
class SpatialAutoencoder(nn.Module):
    def __init__(self, in_channels, latent_dim=4):
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
# Load dataset
# ------------------
dataset, centres, meta, stats, X = build_zi_dataset()

C = dataset[0].shape[0]
latent_dim = 4

loader = DataLoader(
    dataset,
    batch_size=64,
    shuffle=False
)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# ------------------
# Load trained model
# ------------------
model = SpatialAutoencoder(
    in_channels=C,
    latent_dim=latent_dim
).to(device)

# If you SAVED the model after training, load it here:
# model.load_state_dict(torch.load("trained_zi_cnn.pt", map_location=device))

model.eval()


# ------------------
# Extract Zi embeddings
# ------------------
Z_list = []

with torch.no_grad():
    for X_batch in loader:
        X_batch = X_batch.to(device)
        z = model.encode(X_batch)
        Z_list.append(z.cpu().numpy())

Z = np.vstack(Z_list)   # shape: (n_cells, latent_dim)


# ------------------
# Build output DataFrame
# ------------------
df_zi = pd.DataFrame(
    Z,
    columns=[f"zi_{k+1}" for k in range(latent_dim)]
)

df_zi["row"] = [c[0] for c in centres]
df_zi["col"] = [c[1] for c in centres]

# Optional: add unique cell ID
df_zi["cell_id"] = np.arange(len(df_zi))


# ------------------
# Save to disk
# ------------------
out_path = "Data/Data_Output/Zi/zi_embeddings.csv"
df_zi.to_csv(out_path, index=False)

print("Zi embeddings saved to:", out_path)
print("Shape:", df_zi.shape)