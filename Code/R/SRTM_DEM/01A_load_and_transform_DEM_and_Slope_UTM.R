############################################################
# DEM processing: Nigeria elevation & slope (gradient)
# Purpose: Construct time-invariant Zi covariates
# Author: Arthur Martin
############################################################

library(terra)

#-----------------------------------------------------------
# 1. Read DEM
#-----------------------------------------------------------

dem <- rast("Data/Data_Raw/SRTM_DEM/appRasterSelectAPIService1776420803887353486985.tif")

# Inspect DEM metadata
dem
crs(dem)
ext(dem)
res(dem)

plot(dem, main = "Raw SRTM DEM")

#-----------------------------------------------------------
# 2. Load Nigeria administrative boundaries
#-----------------------------------------------------------

nga_adm2 <- vect("Data/Data_Raw/Nigeria Vectors/geoBoundaries-NGA-ADM2.geojson")

# Dissolve ADM2 to country boundary
nga_country <- aggregate(nga_adm2)

# Check CRS
crs(nga_country)

#-----------------------------------------------------------
# 3. Reproject Nigeria boundary to DEM CRS (if needed)
#-----------------------------------------------------------

nga_country <- project(nga_country, dem)

#-----------------------------------------------------------
# 4. Crop and mask DEM to Nigeria
#-----------------------------------------------------------

dem_crop <- crop(dem, nga_country)
dem_nga  <- mask(dem_crop, nga_country)

plot(dem_nga, main = "SRTM DEM (Nigeria)")
plot(nga_country, add = TRUE, border = "black", lwd = 2)

#-----------------------------------------------------------
# 5. Reproject DEM to metric CRS (UTM)
# IMPORTANT: derivatives require metres, not lat/long
#-----------------------------------------------------------

#-----------------------------------------------------------
# Reproject Nigeria boundary to match UTM DEM
#-----------------------------------------------------------

nga_country_utm <- project(nga_country, dem_nga_utm)

#-----------------------------------------------------------
# Compute slope (gradient magnitude)
#-----------------------------------------------------------

slope_deg <- terrain(
  dem_nga_utm,
  v = "slope",
  unit = "degrees"
)

# Mask with correctly projected boundary
slope_nga <- mask(slope_deg, nga_country_utm)

#-----------------------------------------------------------
# Diagnostics
#-----------------------------------------------------------

summary(values(slope_nga))
plot(slope_nga, main = "Slope (degrees) – Nigeria")
plot(
  slope_nga,
  main = "Slope (degrees) – Nigeria",
  col = terrain.colors(50)
)

plot(nga_country, add = TRUE, border = "black", lwd = 1)

#-----------------------------------------------------------
# 8. Save outputs
#-----------------------------------------------------------

writeRaster(
  slope_nga,
  "Data/Data_Output/Zi/slope_deg_nga_utm.tif",
  overwrite = TRUE
)

# Optional: save projected DEM for reuse
writeRaster(
  dem_nga_utm,
  "Data/Data_Output/Zi/dem_nga_utm.tif",
  overwrite = TRUE
)

plot(slope_nga)
############################################################
# End of script
############################################################