library(terra)
library(sf)
library(rnaturalearth)
# paths (adjust only if needed)
chirps_path <- "Data/Data_Raw/CHIRPS/chirps-v2.0.2015.05.tif/chirps-v2.0.2015.05.tif"
nga_sf <- ne_countries(country = "Nigeria", returnclass = "sf")

# load raster
r <- rast(chirps_path)
NAflag(r) <- -9999


# load Nigeria boundary (Natural Earth)
nga_sf <- ne_countries(country = "Nigeria", returnclass = "sf")

# convert to terra vector
nga <- vect(nga_sf)

# reproject boundary to raster CRS
nga <- project(nga, crs(r))

# crop and mask
r_nga <- crop(r, nga)
r_nga <- mask(r_nga, nga)

# plot to verify
plot(r_nga, main = "CHIRPS Rainfall – Nigeria (May 2015)")

