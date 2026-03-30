library(terra)
library(sf)
library(dplyr)
library(rnaturalearth)

# ----------------------------
# Paths
# ----------------------------
nigeria_rain_dir <- "Data/Data_Raw/CHIRPS/Nigeria_rainfall"
out_panel_path   <- "Data/Data_Output/nigeria_rainfall_10km_panel.csv"

# IMPORTANT: make sure output folder exists (you said you’ll create folders manually)

# ----------------------------
# Equal-area CRS (Africa Albers)
# Use ESRI code (your GDAL explicitly told you this)
# ----------------------------
crs_equal_area <- "ESRI:102022"

# ----------------------------
# Nigeria boundary (once)
# ----------------------------
nga_sf <- ne_countries(country = "Nigeria", returnclass = "sf")
nga_sf <- st_transform(nga_sf, crs_equal_area)
nga    <- vect(nga_sf)

# ----------------------------
# List Nigeria rainfall rasters
# ----------------------------
files <- list.files(
  nigeria_rain_dir,
  pattern = "^nigeria_chirps-v2.0\\.[0-9]{4}\\.[0-9]{2}\\.tif$",
  full.names = TRUE
)
stopifnot(length(files) > 0)

# ----------------------------
# Build a reference grid in equal-area CRS
# ----------------------------
r_ref <- rast(files[1])

# Convert CHIRPS nodata (-9999) to NA robustly
r_ref[r_ref <= -9990] <- NA

# Ensure source CRS exists (Nigeria rasters should be lon/lat)
if (is.na(crs(r_ref))) crs(r_ref) <- "EPSG:4326"

# Project reference to equal-area CRS
r_ref_ea <- project(r_ref, crs_equal_area, method = "bilinear")

# Create true 10km grid (metres)
grid_10km <- rast(ext(r_ref_ea), resolution = 10000, crs = crs_equal_area)

# Initialise values so mask() works
values(grid_10km) <- 1

# Clip grid to Nigeria
grid_nga <- crop(grid_10km, nga)
grid_nga <- mask(grid_nga, nga)

# Create zone IDs only where grid exists
grid_zones <- grid_nga
cells <- which(!is.na(values(grid_zones)))
values(grid_zones) <- NA
values(grid_zones)[cells] <- seq_along(cells)
names(grid_zones) <- "cell_id"


library(exactextractr)

# convert grid zones to polygons (one polygon per 10km cell)
grid_polys <- as.polygons(grid_zones, values = TRUE, na.rm = TRUE)
names(grid_polys) <- "cell_id"

# convert to sf for exactextractr
grid_sf <- st_as_sf(grid_polys)
# ----------------------------
# Centroids in WGS84 (for merging later)
# ----------------------------
grid_centroids <- as.points(grid_zones)                 # SpatVector
grid_centroids_wgs84 <- project(grid_centroids, "EPSG:4326")
centroids_df <- as.data.frame(grid_centroids_wgs84, geom = "XY")
names(centroids_df)[names(centroids_df) == "x"] <- "lon"
names(centroids_df)[names(centroids_df) == "y"] <- "lat"

# ----------------------------
# Loop over months and aggregate rainfall
# Robust approach:
#   1) set nodata -> NA
#   2) ensure CRS
#   3) project to equal-area CRS
#   4) resample to grid_zones (so ext/res align)
#   5) zonal mean
# ----------------------------
panel_list <- vector("list", length(files))

for (i in seq_along(files)) {
  
  f <- files[i]
  message("Processing: ", basename(f))
  
  year  <- as.integer(substr(basename(f), 21, 24))
  month <- as.integer(substr(basename(f), 26, 27))
  
  r <- rast(f)
  
  # robust nodata handling
  r[r <= -9990] <- NA
  
  # ensure CRS is set (CHIRPS Nigeria rasters should be lon/lat)
  if (is.na(crs(r))) crs(r) <- "EPSG:4326"
  
  # exactextractr expects sf polygons in same CRS as raster
  grid_sf_this <- st_transform(grid_sf, st_crs(crs(r)))
  
  # compute mean rainfall inside each 10km polygon
  rain_mean <- exact_extract(r, grid_sf_this, "mean")
  
  panel_list[[i]] <- data.frame(
    cell_id = grid_sf_this$cell_id,
    year    = year,
    month   = month,
    rain_mm = rain_mean
  )
}
# ----------------------------
# Combine + merge centroids + save
# ----------------------------

rain_panel <- bind_rows(panel_list) %>%
  left_join(centroids_df, by = "cell_id")

write.csv(rain_panel, out_panel_path, row.names = FALSE)
