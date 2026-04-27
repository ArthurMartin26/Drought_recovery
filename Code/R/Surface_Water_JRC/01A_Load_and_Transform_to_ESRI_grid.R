# ============================================================
# Surface Water (Land–Water) Zi Channel
# JRC Global Surface Water – Occurrence
# Grid: 10km equal-area (ESRI:102022)
# ============================================================

library(terra)
library(sf)

# ----------------------------
# CRS and grid parameters (MUST match Zi)
# ----------------------------
crs_equal_area <- "ESRI:102022"
grid_res_m     <- 10000

# ----------------------------
# Paths
# ----------------------------
sw_dir <- "Data/Data_Raw/Surface_Water_JRC/occurrence"

# ----------------------------
# Nigeria boundary (dissolved)
# ----------------------------
nga_adm2 <- vect("Data/Data_Raw/Nigeria Vectors/geoBoundaries-NGA-ADM2.geojson")
nga      <- aggregate(nga_adm2)
nga      <- project(nga, crs_equal_area)

# ----------------------------
# Rebuild 10km Nigeria grid
# ----------------------------
grid_10km <- rast(
  ext(nga),
  resolution = grid_res_m,
  crs = crs_equal_area
)

values(grid_10km) <- 1
grid_nga <- mask(crop(grid_10km, nga), nga)

# ----------------------------
# Load JRC surface water tiles
# ----------------------------
sw_files <- list.files(
  sw_dir,
  pattern = "\\.tif$",
  full.names = TRUE
)

stopifnot(length(sw_files) > 0)

# Virtual raster (mosaic)
sw_vrt <- vrt(sw_files)

# ----------------------------
# Project JRC raster to equal-area CRS 
# ----------------------------
# Project Nigeria boundary to JRC CRS
nga_native <- project(nga, crs(sw_vrt))

# Crop & mask FIRST (cheap)
sw_crop <- crop(sw_vrt, nga_native)
sw_nga  <- mask(sw_crop, nga_native)

#!!!!!!!!!!! HUGE CPU step ~ 15  mins so do not run unless have to !!!!!!!!!
# NOW reproject Nigeria-only raster 
sw_ea <- project(
  sw_nga,
  crs_equal_area,
  method = "bilinear"
)


# ----------------------------
# Crop + mask to Nigeria (cheap)
# ----------------------------
sw_nga <- mask(crop(sw_ea, nga), nga)

# ----------------------------
# Aggregate directly to 10km Zi grid
# JRC occurrence = 0–100 (% time water observed)
# Mean = share of each 10km cell covered by surface water
# ----------------------------
sw_10km <- resample(
  sw_nga,
  grid_nga,
  method = "bilinear"
)

names(sw_10km) <- "surface_water_pct"

# ----------------------------
# CNN-friendly scaling
# Convert 0–100 (%) → [0,1]
# ----------------------------
sw_scaled <- sw_10km / 100
names(sw_scaled) <- "surface_water"

# ----------------------------
# Save outputs
# ----------------------------
writeRaster(
  sw_10km,
  "Data/Data_Output/Zi/zi_surface_water_pct.tif",
  overwrite = TRUE
)

writeRaster(
  sw_scaled,
  "Data/Data_Output/Zi/zi_surface_water_scaled.tif",
  overwrite = TRUE
)

# ----------------------------
# Diagnostics
# ----------------------------
plot(
  sw_10km,
  main = "Surface10km2 (Zi channel, scaled)"
)

plot(
  sw_scaled,
  main = "Surface Water Share (Zi channel, scaled)"
)
