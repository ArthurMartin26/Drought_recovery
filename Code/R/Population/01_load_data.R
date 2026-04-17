# Load required package
library(terra)

# Read a GeoTIFF raster
r_count <- rast("Data/Data_Raw/Population/Pop_count/nga_ppp_2000_1km_Aggregated.tif")

r_density <- rast("Data/Data_Raw/Population/Pop_density/nga_pd_2003_1km.tif")

# Quick checks
r_count
crs(r_count)
res(r_count)
ext(r_count)

# Plot to sanity check
plot(r_count)
plot(r_density)
# Extract raster values as a vector
vals <- values(r)

# Inspect vals 
summary(vals)
