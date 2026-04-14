library(terra)

modis_dir <- "Data/MOD_NDVI/"
nigeria_path <- "Data/Nigerian_border/geoBoundaries-NGA-ADM0_simplified.geojson"
out_dir <- "Data/NDVI_Nigeria/"
dir.create(out_dir, showWarnings = FALSE)

# Load Nigeria polygon
nigeria <- vect(nigeria_path)

# List all HDF files
files <- list.files(modis_dir, pattern = "\\.hdf$", full.names = TRUE)

# Test date
d <- "A2000183"

message("Processing date: ", d)

# Select only the files for this date
f_date <- files[grepl(d, files)]

# Load NDVI from each tile
rasters <- list()
for (f in f_date) {
  s <- sds(f)
  r <- rast(s)[[1]]   # NDVI layer
  rasters <- c(rasters, r)
}

# Mosaic tiles
if (length(rasters) == 1) {
  ndvi_mosaic <- rasters[[1]]
} else {
  ndvi_mosaic <- do.call(mosaic, rasters)
}

# Reproject Nigeria polygon
nigeria_sinu <- project(nigeria, ndvi_mosaic)

# Crop + mask
ndvi_ng <- crop(ndvi_mosaic, nigeria_sinu)
ndvi_ng <- mask(ndvi_ng, nigeria_sinu)

# Rescale NDVI to 0–1
ndvi_ng <- ndvi_ng / 10000

# Save output
out_file <- file.path(out_dir, paste0("NDVI_Nigeria_", d, ".tif"))
writeRaster(ndvi_ng, out_file, overwrite = TRUE)

message("Saved: ", out_file)


plot(ndvi_ng)


