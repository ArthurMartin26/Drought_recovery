import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from prepare_zi_data import build_zi_dataset

# Load data
dataset, centres, meta, stats, X = build_zi_dataset()
C = dataset[0].shape[0]

# Model (same architecture)
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

    def forward(self, x):
        if self.training:
            x = x + 0.01 * torch.randn_like(x)
        h = self.encoder(x).flatten(1)
        z = self.fc_enc(h)
        h_dec = self.fc_dec(z).view(-1, 64, 3, 3)
        return self.decoder(h_dec), z

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
loader = DataLoader(dataset, batch_size=64, shuffle=True, drop_last=True)
model = SpatialAutoencoder(C, latent_dim=4).to(device)
optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)

n_epochs = 20
lambda_var = 0.1

for epoch in range(n_epochs):
    model.train()
    running_loss = 0.0
    for X_batch in loader:
        X_batch = X_batch.to(device)
        X_hat, z = model(X_batch)
        mask = (X_batch != 0).float()
        recon_loss = ((X_hat - X_batch) ** 2 * mask).sum() / (mask.sum() + 1e-8)
        z_var = z.var(dim=0).mean()
        loss = recon_loss - lambda_var * z_var
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        running_loss += recon_loss.item() * X_batch.size(0)
    epoch_loss = running_loss / len(loader.dataset)
    z_var_val = z_var.item()
    print(f'Epoch {epoch+1:02d} | Recon: {epoch_loss:.4f} | Var: {z_var_val:.4f}')

torch.save(model.state_dict(), 'trained_zi_cnn.pt')
print('Model saved to trained_zi_cnn.pt')