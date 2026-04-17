Night‑time lights (VIIRS) — work in progress
Night‑time lights are being used as a time‑varying state variable (Xi) to proxy local economic activity and infrastructure conditions around the time droughts occur. Conceptually, this captures differences in baseline development that may influence how regions are able to cope with and recover from drought shocks.
Data source
I use VIIRS Day/Night Band (DNB) annual night‑light composites produced by the Earth Observation Group (EOG) at the Payne Institute, Colorado School of Mines. These data are derived from NOAA’s VIIRS sensor and are widely used in economics and development research as a proxy for economic activity.
Specifically, I use the annual masked average radiance product (average_masked), which removes background noise and ephemeral light sources (such as fires, gas flares, and transient events), leaving only persistent, stable night‑time lighting.
VIIRS night‑lights are available from 2012 onwards, which defines the period over which this variable can be included.

Downloading and raw data handling
Annual VIIRS night‑light files are downloaded as compressed GeoTIFFs (.tif.gz). Once extracted, each global raster is large (≈10 GB), which is expected given the global coverage and ~500 m resolution.
Raw files are stored locally and treated as archival inputs:
Data/Data_Raw/VIIRS/

These raw global rasters are not tracked in version control.

Processing in R (current stage)
Processing is carried out in R using the terra package, following the same general workflow as other raster datasets used in the project.
So far, the following steps have been completed for the 2012 VIIRS annual masked average:


Load global raster
The global VIIRS GeoTIFF is loaded using terra::rast(). The file is accessed lazily from disk (it is not loaded fully into memory).


Spatial alignment
Nigeria’s national boundary (previously dissolved from ADM2 units) is reprojected to match the VIIRS raster’s CRS (WGS84).


Crop and mask to Nigeria
The global night‑lights raster is cropped to Nigeria’s bounding box and masked to the national boundary, producing a Nigeria‑only raster at ~500 m resolution.


Visual diagnostics
Initial plots using raw radiance values appear very dark due to the highly skewed distribution of night‑lights. For diagnostics, a log1p() transformation is used, which clearly reveals major urban centres (e.g. Lagos, Abuja, Port Harcourt) and expected spatial gradients across the country.


The processed raster for 2012 is saved as:
Data/Data_Processed/Night_Lights/viirs_nightlights_nigeria_2012.tif

Diagnostic figures are saved to:
Outputs/Figures/


Interpretation
The VIIRS masked annual product records stable night‑time radiance, with values near zero indicating little or no persistent lighting and high values corresponding to dense urban or industrial activity. Negative values occasionally appear due to background subtraction during processing and are treated as effectively zero in later analysis.
Night‑lights are not interpreted pixel‑by‑pixel. Instead, these rasters will be aggregated to the analysis grid (10 km cells) and averaged over a 3–5 year pre‑drought window to construct a smooth, predetermined measure of local economic activity at the time each drought occurs.

Next steps
Planned next steps for night‑lights are:

Process additional VIIRS annual masked rasters (2013 onward) using the same crop‑and‑mask workflow
Aggregate annual night‑lights to the 10 km analysis grid
Construct 3–5 year pre‑shock averages of night‑lights for use as Xi
Integrate night‑lights into the event‑level dataset for drought recovery analysis, noting that this variable is only available for VIIRS‑era droughts (post‑2012)
