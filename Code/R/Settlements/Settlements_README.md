
# Purpose
This script constructs a fixed spatial measure of market access for each 10 km grid cell in Nigeria, to be included as part of the latent geographic feature set (Zi). Market access is proxied by distance to large urban centres, capturing persistent differences in economic connectivity and remoteness that shape feasible post‑drought adjustment paths but are predetermined with respect to drought shocks themselves.
Unlike time‑varying outcomes, this feature represents slow‑moving spatial structure and is treated as fixed over the analysis period.

# Data sources
Natural Earth – Populated Places (v5.1.2)
A global vector dataset of populated places with associated attributes, including estimated metropolitan population (POP_MAX). The full dataset is used to allow filtering settlements by size and economic significance.
Nigeria administrative boundary (Natural Earth)
Used to restrict both the settlement layer and the analysis grid to Nigeria only.

# Key processing steps


Load and filter urban settlements
The Natural Earth populated places shapefile is imported using terra. Settlements are filtered to Nigeria and restricted to large urban centres using a population threshold (baseline: POP_MAX ≥ 100,000), excluding small towns that are unlikely to function as major markets.


# Ensure spatial consistency
Settlement point locations are re‑projected to the same equal‑area coordinate reference system used throughout the project (Africa Albers, ESRI:102022). This ensures consistency with the 10 km grid used for CHIRPS rainfall and other spatial inputs.


# Rebuild the analysis grid
A 10 × 10 km equal‑area raster grid is constructed and masked to Nigeria. This grid matches the resolution, projection, and spatial support used in the rainfall and NDVI processing scripts, guaranteeing cell‑by‑cell alignment across all inputs.


# Rasterise urban centres
Large cities are rasterised onto the 10 km grid, producing a sparse binary raster indicating the presence of a major urban settlement within each grid cell.


# Compute distance to market
For every grid cell, Euclidean distance to the nearest large urban centre is calculated using a raster distance transform. Distances are computed in metres (as implied by the projected CRS) and converted to kilometres for interpretability.


# Transform for model input
The distance surface is log‑transformed (log(1 + distance)) to compress the right tail and reduce the influence of extreme remoteness. The transformed values are then min–max scaled to the [0, 1] interval, producing a CNN‑stable input channel.


# Export outputs
Both the raw distance‑to‑market raster (in kilometres) and the scaled Zi‑ready raster are saved to disk. An optional cell‑level table is also produced to facilitate merging with other spatial features using grid cell identifiers.



# Conceptual notes
Market access is defined in terms of proximity to economically significant urban agglomerations rather than small settlements or administrative centroids. Although cities are represented as points in the source data, distance is interpreted as proximity to an urban market area rather than a literal city centre. The grid‑based distance calculation ensures that cells containing large cities and their immediate surroundings are correctly classified as highly accessible.
Euclidean distance is used to capture broad, structural remoteness. While travel‑time‑based measures may better reflect infrastructure and terrain, Euclidean distance provides a transparent, time‑invariant proxy well suited to inclusion in a fixed geographic embedding (Zi). Additional spatial features (e.g. population density or night‑time lights) can complement this measure in later stages of the modelling pipeline.

# Outputs


# Distance to nearest large city (km)
A continuous raster defined on the 10 km Nigeria grid.


# Scaled distance‑to‑market Zi channel
Log‑transformed and normalised raster suitable for direct inclusion as an input channel to the CNN autoencoder.


Optional cell‑level table
Grid cell identifiers paired with scaled distance‑to‑market values, for merging with other fixed spatial features.
