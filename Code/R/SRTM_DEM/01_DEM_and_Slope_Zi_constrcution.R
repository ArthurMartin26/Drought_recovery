############################################################
# DEM & Slope processing (Zi channels)
# Grid: 10km equal-area (ESRI:102022)
# Purpose: Construct time-invariant Zi covariates
############################################################

library(terra)
library(sf)

# ----------------------------
# Global Zi parameters (MUST match others)
# ----------------------------
crs_equal_area <- "ESRI:102022"
grid_res_m     <- 10000

# ----------------------------
# 1. Read DEM (SRTM)
# ----------------------------
dem_raw <- rast(
  "Data/Data_Raw/SRTM_DEM/appRasterSelectAPIService1776420803887353486985.tif"
)

# Ensure CRS exists
if (is.na(crs(dem_raw))) {
  crs(dem_raw) <- "EPSG:4326"
}

plot(dem_raw, main = "Raw SRTM DEM")

# ----------------------------
# 2. Nigeria boundary (ADM2 → country)
# ----------------------------
nga_adm2 <- vect("Data/Data_Raw/Nigeria Vectors/geoBoundaries-NGA-ADM2.geojson")
nga      <- aggregate(nga_adm2)

# Project boundary to DEM CRS for cropping
nga_dem <- project(nga, dem_raw)

# ----------------------------
# 3. Crop & mask DEM to Nigeria (cheap)
# ----------------------------
dem_crop <- mask(crop(dem_raw, nga_dem), nga_dem)

plot(dem_crop, main = "DEM cropped to Nigeria")

# ----------------------------
# 4. Reproject DEM to equal-area CRS
# (This is the only expensive step)
# ----------------------------
dem_ea <- project(
  dem_crop,
  crs_equal_area,
  method = "bilinear"
)

# ----------------------------
# 5. Build 10km Zi grid
# ----------------------------
nga_ea <- project(nga, crs_equal_area)

grid_10km <- rast(
  ext(nga_ea),
  resolution = grid_res_m,
  crs = crs_equal_area
)

values(grid_10km) <- 1
grid_nga <- mask(crop(grid_10km, nga_ea), nga_ea)

# ----------------------------
# 6. Aggregate DEM to 10km grid
# (mean elevation per cell)
# ----------------------------
dem_10km <- resample(
  dem_ea,
  grid_nga,
  method = "bilinear"
)

names(dem_10km) <- "elevation_m"

# ----------------------------
# 7. Compute slope (degrees) on EA DEM
# ----------------------------
slope_deg <- terrain(
  dem_ea,
  v    = "slope",
  unit = "degrees"
)

# Aggregate slope to 10km grid
slope_10km <- resample(
  slope_deg,
  grid_nga,
  method = "bilinear"
)

names(slope_10km) <- "slope_deg"

# ----------------------------
# 8. Save Zi outputs
# ----------------------------
writeRaster(
  dem_10km,
  "Data/Data_Output/Zi/zi_dem_m.tif",
  overwrite = TRUE
)

writeRaster(
  slope_10km,
  "Data/Data_Output/Zi/zi_slope_deg.tif",
  overwrite = TRUE
)

# ----------------------------
# 9. Diagnostics
# ----------------------------
plot(dem_10km, main = "Elevation (Zi channel)")
plot(slope_10km,
     main = "Slope (degrees, Zi channel)",
     col  = terrain.colors(50))

############################################################
# End of script
############################################################