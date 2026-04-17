library(terra)

# Read the Natural Earth populated places shapefile
cities <- vect("Data/Data_Raw/Settlements/ne_10m_populated_places/ne_10m_populated_places.shp")

# Inspect the object
cities
crs(cities)

# Look at attribute names
names(cities)

# Quick plot (points only)
plot(cities, pch = 20, col = "blue")

# Filter to Nigeria only
cities_ng <- cities[cities$ADM0NAME == "Nigeria", ]

# Filter to large settlements (example: >=100k)
cities_big <- cities_ng[cities_ng$POP_MAX >= 100000, ]

# Reproject to match DEM
cities_big <- project(cities_big, dem_nga)

plot(cities_big)
plot(cities_ng)
