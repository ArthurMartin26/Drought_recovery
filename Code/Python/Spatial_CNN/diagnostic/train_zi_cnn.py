# ======================================================
# train_zi_cnn.py
# Train convolutional autoencoder for Zi representation
# ======================================================

# ------------------
# Imports
# ------------------
import torch
import torch.nn as nn
from torch.utils.data import DataLoader

from prepare_zi_data import build_zi_dataset


# ------------------
# Load Zi dataset
# ------------------
dataset, centres, meta, stats, X = build_zi_dataset()

# Number of input channels inferred from dataset
C = dataset[0].shape[0]


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
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

loader = DataLoader(
    dataset,
    batch_size=64,
    shuffle=True,
    drop_last=True
)

model = SpatialAutoencoder(
    in_channels=C,
    latent_dim=4
).to(device)

criterion = nn.MSELoss()
optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)


# ------------------
# Training loop
# ------------------
n_epochs = 10

for epoch in range(n_epochs):
    model.train()
    running_loss = 0.0

    for X_batch in loader:
        X_batch = X_batch.to(device)

        X_hat, z = model(X_batch)
        loss = criterion(X_hat, X_batch)

        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        running_loss += loss.item() * X_batch.size(0)

    epoch_loss = running_loss / len(loader.dataset)
    print(
        f"Epoch {epoch + 1:02d} | Reconstruction loss: {epoch_loss:.5f}"
    )

torch.save(model.state_dict(), "trained_zi_cnn.pt")
