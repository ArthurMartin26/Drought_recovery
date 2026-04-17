Purpose
This script prepares spatial data on urban settlements for use in constructing a fixed market‑access feature (Zi). The aim is to capture baseline economic connectivity and remoteness by measuring proximity to large urban centres, which shape the set of feasible post‑drought adjustment paths for each grid cell.
Data sources

Natural Earth – Populated Places (v5.1.2)
Vector shapefile containing point locations of cities and towns worldwide, with associated attributes including metropolitan population estimates (POP_MAX). The full version of the dataset is used in order to retain population variables required for filtering settlements by size.

Key processing steps

Imports the Natural Earth populated places shapefile using the terra package.
Filters settlements to Nigeria only.
Restricts the dataset to economically significant market centres using metropolitan population thresholds (e.g. POP_MAX ≥ 100,000), excluding small towns that are unlikely to function as major markets.
Ensures coordinate reference systems are harmonised with other spatial datasets used in the project (WGS84 / EPSG:4326).
Prepares the settlement layer for raster‑based distance calculations by treating settlements as fixed spatial features.

Conceptual notes
Urban settlements are represented as points in the source data, even though cities are spatially extended. To avoid misclassifying grid cells located within large urban agglomerations as remote, the market‑access construction accounts for city extent by treating areas within a fixed radius of major settlements as belonging to the same market area. This ensures that “distance to market” reflects proximity to an urban agglomeration rather than distance to a single centroid.
Outputs

A cleaned and filtered point layer of large urban settlements in Nigeria, suitable for constructing distance‑based accessibility rasters.
Intermediate objects used downstream to compute distance‑to‑market measures that enter the fixed spatial feature set (Zi).

Role in the overall workflow
This script is part of the data acquisition and preparation phase. It produces inputs for later transformations (point‑to‑raster distance surfaces and aggregation to 10 km grid cells) but does not perform modelling or event‑level analysis.
