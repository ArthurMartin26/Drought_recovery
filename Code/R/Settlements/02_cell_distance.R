# ============================================================
# Distance to Markets (Large Cities) – Zi Channel
# Self-contained, but CONSISTENT with CHIRPS 10km grid
# ============================================================

library(terra)
library(sf)
library(rnaturalearth)

# ----------------------------
# Equal-area CRS (MUST match CHIRPS)
# ----------------------------
crs_equal_area <- "ESRI:102022"

# ----------------------------
# Nigeria boundary
# ----------------------------
nga_sf <- ne_countries(country = "Nigeria", returnclass = "sf")
nga_sf <- st_transform(nga_sf, crs_equal_area)
nga    <- vect(nga_sf)

# ----------------------------
# Rebuild the SAME 10km grid used for CHIRPS
# (This is safe because CRS + resolution are identical)
# ----------------------------
# Use Nigeria extent in equal-area CRS
grid_10km <- rast(
  ext(nga),
  resolution = 10000,        # 10 km
  crs = crs_equal_area
)

values(grid_10km) <- 1
grid_nga <- mask(crop(grid_10km, nga), nga)

# ----------------------------
# Load populated places
# ----------------------------
cities <- vect(
  "Data/Data_Raw/Settlements/ne_10m_populated_places/ne_10m_populated_places.shp"
)

# ----------------------------
# Filter to Nigeria + large cities
# ----------------------------
cities_ng  <- cities[cities$ADM0NAME == "Nigeria", ]
cities_big <- cities_ng[cities_ng$POP_MAX >= 100000, ]

# ----------------------------
# Project cities to equal-area CRS
# ----------------------------
cities_big <- project(cities_big, crs_equal_area)

# ----------------------------
# Rasterise cities onto 10km grid
# ----------------------------
cities_raster <- rasterize(
  cities_big,
  grid_nga,
  field = 1
)

# ----------------------------
# Euclidean distance to nearest city (metres)
# ----------------------------
dist_to_city_m <- distance(cities_raster)

# Convert to kilometres
dist_to_city_km <- dist_to_city_m / 1000

dist_to_city_km <- mask(dist_to_city_km, grid_nga)

# ----------------------------
# CNN-friendly transform
# ----------------------------
dist_log <- log1p(dist_to_city_km)

gmin <- global(dist_log, "min", na.rm = TRUE)[1,1]
gmax <- global(dist_log, "max", na.rm = TRUE)[1,1]

dist_market_scaled <- (dist_log - gmin) / (gmax - gmin)
names(dist_market_scaled) <- "dist_market"

# ----------------------------
# Save outputs
# ----------------------------
writeRaster(
  dist_to_city_km,
  "Data/Data_Output/Zi/zi_dist_market_km.tif",
  overwrite = TRUE
)

writeRaster(
  dist_market_scaled,
  "Data/Data_Output/Zi/zi_dist_market_scaled.tif",
  overwrite = TRUE
)

# ----------------------------
# Diagnostics plot
# ----------------------------
plot(dist_market_scaled,
     main = "Distance to Market (Zi channel, scaled)")

