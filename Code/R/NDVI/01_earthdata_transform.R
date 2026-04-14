# ------------------------------------------------------------
# Load libraries
# ------------------------------------------------------------
library(terra)

# ------------------------------------------------------------
# 1. Load MODIS NDVI (MOD13A3)
# ------------------------------------------------------------
f <- "Data/MOD_NDVI/MOD13A3.A2000092.h19v08.061.2020042090746.hdf"

# Read all subdatasets
s <- sds(f)

# Convert to SpatRaster
r <- rast(s)

# NDVI is always layer 1 for MOD13A3
ndvi <- r[[1]]

# ------------------------------------------------------------
# 2. Load Nigeria polygon (WGS84)
# ------------------------------------------------------------
nigeria <- vect("Data/Nigerian_border/geoBoundaries-NGA-ADM0_simplified.geojson")

# Optional: check polygon looks correct
#plot(nigeria)

# ------------------------------------------------------------
# 3. Reproject Nigeria polygon to MODIS Sinusoidal CRS
# ------------------------------------------------------------
# IMPORTANT: project to the raster object, not just its CRS string
nigeria_sinu <- project(nigeria, ndvi)

# Optional: check alignment
# plot(ndvi)
# plot(nigeria_sinu, add = TRUE, border = "red", lwd = 2)

# ------------------------------------------------------------
# 4. Crop and mask NDVI to Nigeria
# ------------------------------------------------------------
ndvi_ng <- crop(ndvi, nigeria_sinu)
ndvi_ng <- mask(ndvi_ng, nigeria_sinu)

# ------------------------------------------------------------
# 5. Plot final result
# ------------------------------------------------------------
plot(ndvi_ng, main = "NDVI over Nigeria (MOD13A3)")
