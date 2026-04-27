library(terra)

# Raw JRC surface water occurrence tiles
sw_dir <- "Data/Data_Raw/Surface_Water_JRC/occurrence"

# Nigeria boundary (already dissolved earlier)
nga_adm2 <- vect("Data/Data_Raw/Nigeria Vectors/geoBoundaries-NGA-ADM2.geojson")

nga <- aggregate(nga_adm2)

nga
crs(nga)
plot(nga)

sw_files <- list.files(
  sw_dir,
  pattern = "\\.tif$",
  full.names = TRUE
)

length(sw_files)

#create a virtual raster file gloabl raster as we cannot just layer them as they are different tiles 
sw_vrt <- vrt(sw_files)

# reproejct to nigeria boundary. 
nga <- project(nga, sw_vrt)

## this just cuts down out raaster tiles 
sw_crop <- crop(sw_vrt, nga)

## now we crop to nigeria  - cpu heavy step 
sw_nga <- mask(sw_crop, nga)

plot(sw_nga)

png(
  filename = "Outputs/Figures/jrc_surface_water_occurrence_nigeria.png",
  width = 2000,
  height = 1600,
  res = 300
)

plot(
  sw_nga,
  main = "JRC Global Surface Water Occurrence (1984–2021): Nigeria"
)

dev.off()

