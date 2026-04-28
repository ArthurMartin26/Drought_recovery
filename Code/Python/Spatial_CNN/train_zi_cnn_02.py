# ======================================================
# 02_train_zi_cnn.py
# Train convolutional autoencoder for Zi representation
# ======================================================

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from pathlib import Path

# Import from prepare script
from prepare_zi_data_01 import prepare_zi_data


# ------------------
# Model definition
# ------------------
class SpatialAutoencoder(nn.Module):
    def __init__(self, in_channels, latent_dim=4):
        super().__init__()

        # ----- Encoder -----
        self.encoder = nn.Sequential(
            nn.Conv2d(in_channels, 32, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.AvgPool2d(2),          # 12x12 → 6x6

            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.AvgPool2d(2)           # 6x6 → 3x3
        )

        self.fc_enc = nn.Linear(64 * 3 * 3, latent_dim)

        # ----- Decoder -----
        self.fc_dec = nn.Linear(latent_dim, 64 * 3 * 3)

        self.decoder = nn.Sequential(
            nn.Upsample(scale_factor=2),  # 3x3 → 6x6
            nn.Conv2d(64, 32, kernel_size=3, padding=1),
            nn.ReLU(),

            nn.Upsample(scale_factor=2),  # 6x6 → 12x12
            nn.Conv2d(32, in_channels, kernel_size=3, padding=1)
        )

    def forward(self, x):
        # ---- denoising ----
        if self.training:
            x = x + 0.01 * torch.randn_like(x)

        h = self.encoder(x)
        h = h.flatten(start_dim=1)
        z = self.fc_enc(h)

        h_dec = self.fc_dec(z)
        h_dec = h_dec.view(-1, 64, 3, 3)
        x_hat = self.decoder(h_dec)

        return x_hat, z


# ------------------
# Training setup
# ------------------
def train_cnn(
    n_epochs=30,
    batch_size=64,
    latent_dim=8,
    learning_rate=1e-3,
    lambda_var=1e-5,
    save_path="trained_zi_cnn.pt"
):
    """
    Train the autoencoder on Zi patches.
    
    Args:
        n_epochs: number of training epochs
        batch_size: batch size for DataLoader
        latent_dim: dimension of latent embedding
        learning_rate: Adam learning rate
        lambda_var: variance regularization coefficient
        save_path: where to save trained model
    """
    # Load dataset
    print("Preparing dataset...")
    dataset, centres, meta, stats, X = prepare_zi_data()
    C = dataset[0].shape[0]
    print(f"  Input channels: {C}")
    print(f"  Patch size: {dataset[0].shape[1]}")
    print(f"  Number of samples: {len(dataset)}")

    # DataLoader
    loader = DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=True,
        drop_last=True
    )

    # Model
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"  Device: {device}")

    model = SpatialAutoencoder(
        in_channels=C,
        latent_dim=latent_dim
    ).to(device)

    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)

    # Training loop
    print(f"\nTraining for {n_epochs} epochs...")
    for epoch in range(n_epochs):
        model.train()
        running_loss = 0.0

        for X_batch in loader:
            X_batch = X_batch.to(device)

            X_hat, z = model(X_batch)

            # ---- masked reconstruction loss ----
            # mask out zero-filled pixels so they don't dominate MSE
            mask = (X_batch != 0).float()
            recon_loss = ((X_hat - X_batch) ** 2 * mask).sum() / (mask.sum() + 1e-8)

            # ---- latent variance regularisation (encourages diverse embeddings) ----
            z_var = z.var(dim=0).mean()

            # Add variance (not subtract) to prevent collapse
            loss = recon_loss + lambda_var * z_var

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            running_loss += recon_loss.item() * X_batch.size(0)

        epoch_loss = running_loss / len(loader.dataset)
        print(f"Epoch {epoch + 1:02d} | Recon loss: {epoch_loss:.6f}")

    # Save model
    torch.save(model.state_dict(), save_path)
    print(f"\nModel saved to {save_path}")

    return model


# ------------------
# Entry point
# ------------------
if __name__ == "__main__":
    train_cnn()