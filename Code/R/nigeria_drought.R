# ============================================================
# 04_define_drought_events.R
# Define drought months and drought events from 10km rainfall panel
# Input:  Data/Data_Output/nigeria_rainfall_10km_panel.csv
# Output: Data/Data_Output/drought_month_flags.csv
#         Data/Data_Output/drought_events.csv
#         Data/Data_Output/drought_summary_by_cell.csv
#         Data/Data_Output/drought_area_share_timeseries.png
#         Data/Data_Output/drought_events_per_cell_map.png
# ============================================================

suppressPackageStartupMessages({
  library(data.table)   # fast for millions of rows
  library(lubridate)
  library(ggplot2)
})

# ----------------------------
# Paths
# ----------------------------
panel_path <- "Data/Data_Output/nigeria_rainfall_10km_panel.csv"
out_months <- "Data/Data_Output/drought_month_flags.csv"
out_events <- "Data/Data_Output/drought_events.csv"
out_cell   <- "Data/Data_Output/drought_summary_by_cell.csv"
out_ts_png <- "Data/Data_Output/drought_area_share_timeseries.png"
out_map_png<- "Data/Data_Output/drought_events_per_cell_map.png"

stopifnot(file.exists(panel_path))

# ----------------------------
# Parameters (edit these if desired)
# ----------------------------

# Baseline years for "normal" rainfall (used in z-scores + medians)
baseline_start <- 2000
baseline_end   <- 2010

# Two alternative drought definitions:
# A) z-score rule: rainfall z <= -1 for >= min_consecutive months
use_zscore_rule <- TRUE
z_thresh <- -1.0

# B) median rule: rainfall <= 0.5 * median(baseline month) for >= min_consecutive months
use_median50_rule <- FALSE
median_frac <- 0.50

# Event construction rules
min_consecutive <- 2      # minimum consecutive drought months to form an event
spacing_months  <- 12     # after an event ends, forbid a new event within next 12 months in same cell

# ----------------------------
# Load data
# ----------------------------
dt <- fread(panel_path)

# Expected columns: cell_id, year, month, rain_mm, lon, lat
needed <- c("cell_id", "year", "month", "rain_mm")
stopifnot(all(needed %in% names(dt)))

# Make a proper date (first of month)
dt[, date := as.Date(sprintf("%04d-%02d-01", year, month))]
setorder(dt, cell_id, date)

# ----------------------------
# Build baseline climatology by cell and calendar month
# ----------------------------
dt[, in_baseline := year >= baseline_start & year <= baseline_end]

# If baseline window is missing for some cells, the script still works,
# but those cells may get NA anomalies.
base_stats <- dt[in_baseline == TRUE & !is.na(rain_mm),
                 .(
                   base_mean  = mean(rain_mm),
                   base_sd    = sd(rain_mm),
                   base_median= median(rain_mm)
                 ),
                 by = .(cell_id, month)]

dt <- merge(dt, base_stats, by = c("cell_id", "month"), all.x = TRUE)

# z-score anomaly (seasonally adjusted)
dt[, rain_z := (rain_mm - base_mean) / base_sd]

# median threshold (seasonally adjusted)
dt[, rain_med_ratio := rain_mm / base_median]

# ----------------------------
# Define drought months (choose rule)
# ----------------------------
dt[, drought_month := FALSE]

if (use_zscore_rule) {
  dt[!is.na(rain_z) & rain_z <= z_thresh, drought_month := TRUE]
}

if (use_median50_rule) {
  dt[!is.na(rain_med_ratio) & rain_med_ratio <= median_frac, drought_month := TRUE]
}

# ----------------------------
# Turn drought months into drought events (per cell)
# Uses run-length encoding on the drought_month indicator
# Applies min_consecutive and spacing_months
# ----------------------------

# Helper: find runs inside a logical vector
make_runs <- function(x) {
  r <- rle(x)
  ends <- cumsum(r$lengths)
  starts <- ends - r$lengths + 1
  data.table(run_value = r$values, start_idx = starts, end_idx = ends, run_len = r$lengths)
}

# Build events per cell

event_rows <- list()
event_counter <- 0L   # FIX: clean counter
dt[, event_id := NA_integer_]

for (cid in unique(dt$cell_id)) {
  
  sub <- dt[cell_id == cid]
  if (nrow(sub) == 0) next
  
  runs <- make_runs(sub$drought_month)
  runs <- runs[run_value == TRUE & run_len >= min_consecutive]
  if (nrow(runs) == 0) next
  
  last_end_date <- as.Date("1900-01-01")
  
  for (j in 1:nrow(runs)) {
    
    s_idx <- runs$start_idx[j]
    e_idx <- runs$end_idx[j]
    
    start_date <- sub$date[s_idx]
    end_date   <- sub$date[e_idx]
    
    if (start_date > (last_end_date %m+% months(spacing_months))) {
      
      event_counter <- event_counter + 1
      eid <- event_counter
      
      dt[
        cell_id == cid &
          date >= start_date &
          date <= end_date,
        event_id := eid
      ]
      
      ev <- sub[s_idx:e_idx]
      
      event_rows[[eid]] <- data.table(
        event_id    = eid,
        cell_id     = cid,
        start_date  = min(ev$date),
        end_date    = max(ev$date),
        duration_m  = as.integer(max(ev$date) %/% months(1) - min(ev$date) %/% months(1) + 1),
        min_rain_mm = min(ev$rain_mm, na.rm = TRUE),
        mean_rain_mm= mean(ev$rain_mm, na.rm = TRUE),
        min_z       = if (all(is.na(ev$rain_z))) NA_real_ else min(ev$rain_z, na.rm = TRUE),
        mean_z      = if (all(is.na(ev$rain_z))) NA_real_ else mean(ev$rain_z, na.rm = TRUE),
        cum_deficit = if (all(is.na(ev$rain_z))) NA_real_
        else sum(pmin(ev$rain_z, 0), na.rm = TRUE),
        lon         = ev$lon[1],
        lat         = ev$lat[1]
      )
      
      last_end_date <- end_date
    }
  }
}

# This now works correctly
events_dt <- rbindlist(event_rows, fill = TRUE)

# ----------------------------
# Outputs
# ----------------------------
months_out <- dt[, .(
  cell_id, year, month, date, lon, lat,
  rain_mm, rain_z, drought_month, event_id
)]

fwrite(months_out, out_months)
fwrite(events_dt, out_events)

cell_summary <- events_dt[, .(
  n_events = .N,
  avg_duration = mean(duration_m, na.rm = TRUE),
  avg_min_z = mean(min_z, na.rm = TRUE),
  lon = lon[1],
  lat = lat[1]
), by = cell_id]

fwrite(cell_summary, out_cell)

# ----------------------------
# Plots
# ----------------------------
ts <- months_out[, .(
  share_cells_drought = mean(drought_month, na.rm = TRUE)
), by = date]

p1 <- ggplot(ts, aes(date, share_cells_drought)) +
  geom_line(linewidth = 0.4) +
  labs(title = "Share of 10km grid cells in drought", y = "Share") +
  theme_minimal()

ggsave(out_ts_png, p1, width = 9, height = 4, dpi = 150)

p2 <- ggplot(cell_summary, aes(lon, lat, color = n_events)) +
  geom_point(size = 0.7) +
  scale_color_viridis_c() +
  theme_minimal() +
  labs(title = "Number of drought events per 10km cell")

ggsave(out_map_png, p2, width = 7, height = 6, dpi = 150)
# 04_define_drought_events.R
