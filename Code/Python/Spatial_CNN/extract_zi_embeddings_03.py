# ======================================================
# 03_extract_zi_embeddings.py
# Extract learned Zi embeddings from trained CNN encoder
# ======================================================

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
import pandas as pd
from pathlib import Path

# Import from prepare script
from prep_zi_data import prepare_zi_data


# ------------------
# Model definition (must match training architecture)
# ------------------
class SpatialAutoencoder(nn.Module):
    def __init__(self, in_channels, latent_dim=4):
        super().__init__()

        # ----- Encoder -----
        self.encoder = nn.Sequential(
            nn.Conv2d(in_channels, 32, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.AvgPool2d(2),

            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.AvgPool2d(2)
        )

        self.fc_enc = nn.Linear(64 * 3 * 3, latent_dim)

        # ----- Decoder (not needed for extraction, but kept for completeness) -----
        self.fc_dec = nn.Linear(latent_dim, 64 * 3 * 3)
        self.decoder = nn.Sequential(
            nn.Upsample(scale_factor=2),
            nn.Conv2d(64, 32, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.Upsample(scale_factor=2),
            nn.Conv2d(32, in_channels, kernel_size=3, padding=1)
        )

    def encode(self, x):
        """Extract latent embeddings."""
        h = self.encoder(x)
        h = h.flatten(start_dim=1)
        z = self.fc_enc(h)
        return z


# ------------------
# Extraction function
# ------------------
def extract_embeddings(
    model_path="trained_zi_cnn.pt",
    output_path=None,
    batch_size=64
):
    """
    Extract latent embeddings from trained model.
    
    Args:
        model_path: path to trained model weights
        output_path: path to save embeddings CSV (optional)
        batch_size: batch size for DataLoader
    
    Returns:
        embeddings: numpy array of shape (N, latent_dim)
        centres: list of (i, j) coordinates
    """
    # Load dataset
    print("Loading dataset...")
    dataset, centres, meta, stats, X = prepare_zi_data()
    C = dataset[0].shape[0]
    latent_dim = 4

    print(f"  Input channels: {C}")
    print(f"  Number of samples: {len(dataset)}")

    # DataLoader
    loader = DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=False
    )

    # Load trained model
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"  Device: {device}")

    model = SpatialAutoencoder(
        in_channels=C,
        latent_dim=latent_dim
    ).to(device)

    print(f"Loading model from {model_path}...")
    model.load_state_dict(torch.load(model_path, map_location=device))
    model.eval()

    # Extract embeddings
    print("Extracting embeddings...")
    Z_list = []

    with torch.no_grad():
        for X_batch in loader:
            X_batch = X_batch.to(device)
            z = model.encode(X_batch)
            Z_list.append(z.cpu().numpy())

    embeddings = np.vstack(Z_list)
    print(f"  Embeddings shape: {embeddings.shape}")

    # Save to CSV
    if output_path is None:
        output_path = Path(__file__).resolve().parents[3] / "Data" / "Data_Output" / "Zi" / "zi_embeddings.csv"

    df = pd.DataFrame(
        embeddings,
        columns=[f"z_{i}" for i in range(latent_dim)]
    )
    df["cell_i"] = [c[0] for c in centres]
    df["cell_j"] = [c[1] for c in centres]

    df.to_csv(output_path, index=False)
    print(f"Embeddings saved to {output_path}")

    return embeddings, centres


# ------------------
# Entry point
# ------------------
if __name__ == "__main__":
    extract_embeddings()