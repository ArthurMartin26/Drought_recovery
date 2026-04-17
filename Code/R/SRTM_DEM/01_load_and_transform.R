library(terra)

# Read the raster
dem <- rast("Data/Data_Raw//SRTM_DEM/appRasterSelectAPIService1776420803887353486985.tif")

# Basic metadata
dem
crs(dem)
ext(dem)
res(dem)

plot(dem)

nga_adm2 <- vect("Data/Data_Raw/Nigeria Vectors/geoBoundaries-NGA-ADM2.geojson")

nga_country <- aggregate(nga_adm2)

nga
crs(nga)

# Reproject boundary to match DEM if needed
nga <- project(nga_country, dem)

dem_crop <- crop(dem, nga_country)
dem_nga  <- mask(dem_crop, nga_country)
plot(dem_nga)
plot(nga_country, add = TRUE, border = "black", lwd = 2)