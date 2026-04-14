library(terra)

# ------------------------------------------------------------
# 0. Paths
# ------------------------------------------------------------
modis_dir <- "Data/MOD_NDVI/"
nigeria_path <- "Data/Nigerian_border/geoBoundaries-NGA-ADM0_simplified.geojson"
out_dir <- "Data/NDVI_Nigeria/"

dir.create(out_dir, showWarnings = FALSE)

# ------------------------------------------------------------
# 1. Load Nigeria polygon (WGS84)
# ------------------------------------------------------------
nigeria <- vect(nigeria_path)

# ------------------------------------------------------------
# 2. List all MODIS HDF files
# ------------------------------------------------------------
files <- list.files(modis_dir, pattern = "\\.hdf$", full.names = TRUE)

# ------------------------------------------------------------
# 3. Extract acquisition date from filename
#    Example: MOD13A3.A2000092.h18v07.061.2020042090746.hdf
#    We want: A2000092
# ------------------------------------------------------------
get_date <- function(f) {
  # Extract the AYYYYDDD part
  sub(".*(A[0-9]{7}).*", "\\1", basename(f))
}

dates <- sapply(files, get_date)
unique_dates <- unique(dates)

# ------------------------------------------------------------
# 4. Loop over each acquisition date
# ------------------------------------------------------------
for (d in unique_dates) {
  
  message("Processing date: ", d)
  
  # All tiles for this date
  f_date <- files[dates == d]
  
  # Load NDVI from each tile
  rasters <- list()
  for (f in f_date) {
    s <- sds(f)
    r <- rast(s)[[1]]   # NDVI is layer 1
    rasters <- c(rasters, r)
  }
  
  # ------------------------------------------------------------
  # 5. Mosaic all tiles for this date
  # ------------------------------------------------------------
  if (length(rasters) == 1) {
    ndvi_mosaic <- rasters[[1]]
  } else {
    ndvi_mosaic <- do.call(mosaic, rasters)
  }
  
  # ------------------------------------------------------------
  # 6. Reproject Nigeria polygon to MODIS CRS
  # ------------------------------------------------------------
  nigeria_sinu <- project(nigeria, ndvi_mosaic)
  
  # ------------------------------------------------------------
  # 7. Crop + mask
  # ------------------------------------------------------------
  ndvi_ng <- crop(ndvi_mosaic, nigeria_sinu)
  ndvi_ng <- mask(ndvi_ng, nigeria_sinu)
  ndvi_ng <- ndvi_ng / 10000
  
  
  # ------------------------------------------------------------
  # 8. Save output
  # ------------------------------------------------------------
  out_file <- file.path(out_dir, paste0("NDVI_Nigeria_", d, ".tif"))
  writeRaster(ndvi_ng, out_file, overwrite = TRUE)
  
  message("Saved: ", out_file)
}

message("All dates processed.")
