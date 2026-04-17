library(terra)

##these are monster files ~10gb so do not try to plot! 
nl_global <- rast(
  "Data/Data_Raw/VIIRS/VNL_v2_npp_201204-201212_global_vcmcfg_c202101211500.average_masked.tif/VNL_v2_npp_201204-201212_global_vcmcfg_c202101211500.average_masked.tif"
)

nl_global
crs(nl_global)
res(nl_global)

nga_adm2 <- vect("Data/Data_Raw/Nigeria Vectors/geoBoundaries-NGA-ADM2.geojson")

nga <- aggregate(nga_adm2)

nga
crs(nga)

nl_crop <- crop(nl_global, nga)

nl_nga_2012 <- mask(nl_crop, nga)

plot(
  nl_nga_2012,
  main = "VIIRS Night-Time Lights (Masked Annual Average, 2012)"
)
plot(
  aggregate(nl_nga_2012, fact = 4),
  main = "VIIRS Night-Time Lights (Nigeria, 2012 – coarse view)"
)

plot(nga, add = TRUE, border = "black", lwd = 1)

png(
  "Outputs/Figures/viirs_nightlights_nigeria_2012.png",
  width = 2000,
  height = 1600,
  res = 300
)

plot(nl_nga_2012,
     main = "VIIRS Night-Time Lights (Annual Masked Average, 2012)")

dev.off()
plot(nga, add = TRUE, border = "black", lwd = 1)


#########################################

#######################

png(
  filename = "Outputs/Figures/viirs_nightlights_nigeria_2012_log.png",
  width = 2000,
  height = 1600,
  res = 300
)

plot(
  log1p(nl_nga_2012),
  main = "VIIRS Night-Time Lights (Nigeria, 2012; log scale)"
)

plot(nga, add = TRUE, border = "black", lwd = 1)

dev.off()
