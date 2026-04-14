library(terra)
library(sf)
library(rnaturalearth)

# ----------------------------
# Paths
# ----------------------------
africa_dir  <- "Data/Data_Raw/CHIRPS/Africa_monthly"
nigeria_dir <- "Data/Data_Raw/CHIRPS/Nigeria_rainfall"

files <- list.files(
  africa_dir,
  pattern = "^chirps-v2.0\\.(200[0-9]|201[0-9]|202[0-4])\\.[0-9]{2}\\.tif$",
  full.names = TRUE
)
length(files)  # sanity check (should be 15 * 12 = 180)


for (f in files) {
  
  message("Processing: ", basename(f))
  
  # load raster
  r <- rast(f)
  
  # CHIRPS no-data handling
  NAflag(r) <- -9999
  
  # reproject Nigeria boundary if needed
  nga_proj <- project(nga, crs(r))
  
  # crop and mask
  r_nga <- crop(r, nga_proj)
  r_nga <- mask(r_nga, nga_proj)
  
  # construct output filename
  out_name <- file.path(
    nigeria_dir,
    paste0("nigeria_", basename(f))
  )
  
  # write Nigeria-only raster
  writeRaster(
    r_nga,
    out_name,
    overwrite = TRUE
  )
}
test <- rast("Data/Data_Raw/CHIRPS/Nigeria_rainfall/nigeria_chirps-v2.0.2015.05.tif")
plot(test, main = "Nigeria Rainfall – May 2015")