Surface Water (JRC Global Surface Water)
Purpose
This script constructs a fixed spatial measure of long‑run surface water availability for Nigeria, to be included as part of the latent geographic feature vector (Zi). Surface water represents a key structural characteristic that conditions how locations are able to cope with and recover from drought shocks, for example through irrigation potential, livestock access, floodplain agriculture, or ecosystem buffering. As such, it is treated as time‑invariant and predetermined with respect to individual drought events.

Data source
JRC Global Surface Water (GSW), v1.4
Produced by the European Commission’s Joint Research Centre under the Copernicus programme, the JRC Global Surface Water dataset is derived from Landsat imagery at 30 m spatial resolution. It tracks surface water presence globally over the period 1984–2021.
From the available GSW products, this script uses the surface water occurrence layer. For each pixel, this layer records the percentage of months over the full sample period in which surface water was detected. This measure captures persistent hydrological features such as rivers, lakes, reservoirs, wetlands, and floodplains, rather than short‑term flooding or year‑specific variation.

Data acquisition
The data were downloaded using the official JRC bulk download script, which retrieves surface water tiles globally organised into 10° × 10° geographic tiles. Only the occurrence product was downloaded; the change, transition, and seasonality layers were intentionally excluded to avoid introducing time‑varying dynamics into a variable intended to represent fixed geographic structure.
In total, the download produced 504 GeoTIFF tiles at 30 m resolution, covering the global land surface. These raw tiles are stored locally in:
Data/Data_Raw/Surface_Water_JRC/occurrence/

The raw files are treated as archival inputs and are not tracked in Git.

Processing in R
All processing is carried out in R using the terra package, following the same spatial harmonisation principles used for other raster datasets in the project.
The global surface water tiles are first combined using a virtual raster (VRT), allowing the full dataset to be accessed as a single raster without loading all files into memory. Nigeria’s administrative boundaries are dissolved to a single national polygon and used to crop and mask the global raster, ensuring that only pixels within Nigeria are retained.
The Nigeria‑only surface water raster is then reprojected to an equal‑area Africa Albers coordinate reference system (ESRI:102022). This projection is used consistently across the project to ensure that all spatial inputs are defined on a common metric grid with equal‑area cells.
Finally, the reprojected surface water occurrence raster is resampled to the project’s 10 km × 10 km analysis grid, matching the resolution and alignment used for CHIRPS rainfall and other Zi inputs. Values within each grid cell are aggregated using the mean, producing a measure of the share of each 10 km cell that exhibits persistent surface water over the 1984–2021 period. The resulting values (originally in the 0–100 range) are scaled to the [0, 1] interval for use as a CNN input channel.

Outputs


Surface water occurrence (percentage)
A 10 km raster giving the mean long‑run surface water occurrence percentage for each grid cell.


Surface water Zi channel (scaled)
A logistically scaled raster in the [0, 1] range, aligned exactly with other Zi inputs and suitable for inclusion as an input channel to the CNN autoencoder.



Interpretation and role in the analysis
The resulting raster encodes long‑run hydrological structure rather than short‑run climatic variation. Most grid cells exhibit low surface water occurrence, reflecting the predominantly semi‑arid nature of large parts of Nigeria, with higher values concentrated along major river systems (notably the Niger and Benue rivers), floodplains, coastal lagoons, and reservoir areas.
Surface water occurrence is interpreted as a baseline hydrological buffer that shapes feasible drought response and recovery strategies. It is not treated as an outcome of drought events themselves, but rather as a persistent spatial characteristic that conditions adaptation pathways. Accordingly, it enters the analysis as part of the fixed latent spatial feature set (Zi) learned by the CNN autoencoder.
