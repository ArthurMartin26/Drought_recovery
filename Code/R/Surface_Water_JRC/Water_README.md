Surface water (JRC Global Surface Water)
For surface water, I use the JRC Global Surface Water (GSW) dataset produced by the European Commission’s Joint Research Centre as part of the Copernicus programme. This dataset is derived from Landsat imagery at 30 m resolution and tracks where surface water has been detected globally over the period 1984–2021.
From the available layers, I focus on the surface water occurrence product. This records, for each pixel, the percentage of months in which surface water was observed over the full period. I chose this layer because it captures long‑run, structural water availability (rivers, lakes, floodplains, wetlands), rather than short‑term flooding or year‑specific changes. As such, it fits naturally into the set of fixed spatial characteristics (Zi) that shape how areas are able to respond to droughts.

Downloading the data
The data were downloaded using the official JRC bulk download script, which retrieves all surface‑water tiles globally, organised into 10° × 10° geographic tiles. Only the occurrence dataset was downloaded — not the change or transition layers — to avoid mixing time‑varying dynamics into a variable that is intended to be structurally fixed.
In total, the download produced 504 GeoTIFF tiles at 30 m resolution, covering the global land surface. These raw files are stored locally in:
Data/Data_Raw/Surface_Water_JRC/occurrence/

The raw tiles are treated as archival inputs and are not tracked in Git.

Processing in R
All processing was done in R using the terra package, following the same general workflow used for other raster datasets in the project.
First, the global tiles were combined using a virtual raster (VRT). This allows the full dataset to be treated as a single raster without loading all tiles into memory. Nigeria’s administrative boundaries (dissolved from ADM2 to a single national polygon) were then reprojected to match the raster’s coordinate reference system.
The global surface‑water raster was then cropped and masked to Nigeria, ensuring that only pixels within the national boundary are retained. This results in a Nigeria‑only surface‑water raster that clearly shows major hydrological features such as the Niger and Benue rivers, the Niger Delta, and the Lake Chad basin.
The processed raster is saved as:
Data/Data_Processed/Surface_Water/JRC_surface_water_occurrence_Nigeria.tif


Interpretation and role in the analysis
The resulting raster encodes long‑run surface water occurrence values between 0 and 100, where higher values indicate more persistent water presence over the 1984–2021 period. This variable captures baseline hydrological buffering capacity — whether an area has access to permanent or semi‑permanent water bodies that can mitigate the impacts of rainfall shocks.
Surface water occurrence is treated as a time‑invariant spatial feature (Zi). It is not interpreted as a direct outcome of individual drought events, but rather as a structural characteristic that conditions how regions are able to cope with and recover from droughts (for example, through irrigation potential, grazing fallback options, or ecosystem resilience).
