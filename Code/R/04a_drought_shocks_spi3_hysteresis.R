# ============================================================
# 05_define_drought_shocks_spi3_hysteresis.R
#
# Drought = finite SHOCK based on 3-month accumulated rainfall
# Event logic:
#   - Compute 3-month rolling sum rainfall (P3)
#   - Standardise relative to baseline by cell and calendar month (z3)
#   - Enter drought when z3 <= enter_thresh
#   - Exit drought when z3 >= exit_thresh  (hysteresis)
#   - Events = contiguous runs of drought_state TRUE
#   - Enforce min_duration and spacing between events
#
# Input:  Data/Data_Output/nigeria_rainfall_10km_panel.csv
# Output: Data/Data_Output/drought_month_flags_spi3.csv
#         Data/Data_Output/drought_events_spi3.csv
#         Data/Data_Output/drought_summary_by_cell_spi3.csv
#         Data/Data_Output/drought_area_share_timeseries_spi3.png
#         Data/Data_Output/drought_events_per_cell_map_spi3.png
# ============================================================

suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
  library(ggplot2)
})

# ----------------------------
# Paths
# ----------------------------
panel_path <- "Data/Data_Output/nigeria_rainfall_10km_panel.csv"

out_months <- "Data/Data_Output/drought_month_flags_spi3.csv"
out_events <- "Data/Data_Output/drought_events_spi3.csv"
out_cell   <- "Data/Data_Output/drought_summary_by_cell_spi3.csv"
out_ts_png <- "Data/Data_Output/drought_area_share_timeseries_spi3.png"
out_map_png<- "Data/Data_Output/drought_events_per_cell_map_spi3.png"

stopifnot(file.exists(panel_path))

# ----------------------------
# Parameters (tune later)
# ----------------------------

# Baseline years used to define "normal"
baseline_start <- 2000
baseline_end   <- 2010

# 3-month accumulation window
k_months <- 3

# Hysteresis thresholds (shock definition)
# Enter drought when z3 <= -1.0, exit when z3 >= -0.5
enter_thresh <- -1.0
exit_thresh  <- -0.5

# Event filters
min_duration_months <- 2    # minimum months in drought_state to count as an event
spacing_months      <- 12   # minimum gap after event end before next event starts (same cell)

# ----------------------------
# Load data
# ----------------------------
dt <- fread(panel_path)

needed <- c("cell_id", "year", "month", "rain_mm")
stopifnot(all(needed %in% names(dt)))

# Make date and order
dt[, date := as.Date(sprintf("%04d-%02d-01", year, month))]
setorder(dt, cell_id, date)

# ----------------------------
# Step 1: 3-month accumulated rainfall P3
# (rolling sum within each cell, aligned to current month)
# ----------------------------
dt[, rain3 := frollsum(rain_mm, n = k_months, align = "right", na.rm = FALSE), by = cell_id]

# First (k_months-1) months per cell will be NA; that's expected.

# ----------------------------
# Step 2: Baseline climatology for rain3 by cell & calendar month
# We standardise by month-of-year to respect seasonality.
# ----------------------------
dt[, in_baseline := year >= baseline_start & year <= baseline_end]

base3 <- dt[in_baseline == TRUE & !is.na(rain3),
            .(
              base3_mean = mean(rain3),
              base3_sd   = sd(rain3),
              base3_med  = median(rain3)
            ),
            by = .(cell_id, month)
]

dt <- merge(dt, base3, by = c("cell_id", "month"), all.x = TRUE)

# z-score of 3-month rainfall
dt[, z3 := (rain3 - base3_mean) / base3_sd]

# ----------------------------
# Step 3: Convert z3 into a drought STATE using hysteresis
# This is the critical "shock not persistence" step:
#   - You only ENTER when it gets bad enough (enter_thresh)
#   - You only EXIT when it recovers enough (exit_thresh)
# This prevents noisy in/out flipping and forces finite events.
# ----------------------------

hysteresis_state <- function(z, enter = -1, exit = -0.5) {
  n <- length(z)
  state <- logical(n)
  in_drought <- FALSE
  
  for (t in seq_len(n)) {
    zi <- z[t]
    
    # If z is missing, we treat as "no info" and keep state FALSE
    # (you can change this, but it's a clean conservative default)
    if (is.na(zi)) {
      state[t] <- FALSE
      next
    }
    
    if (!in_drought) {
      # Enter drought only if we cross the entry threshold
      if (zi <= enter) in_drought <- TRUE
    } else {
      # Exit drought only if we recover past exit threshold
      if (zi >= exit) in_drought <- FALSE
    }
    
    state[t] <- in_drought
  }
  
  state
}

dt[, drought_state := hysteresis_state(z3, enter = enter_thresh, exit = exit_thresh), by = cell_id]

# ----------------------------
# Step 4: Turn drought STATE into drought EVENTS (runs)
# Events are contiguous TRUE segments in drought_state.
# ----------------------------

# Identify contiguous runs per cell
dt[, run_id := rleid(drought_state), by = cell_id]

# Run-level stats (only runs where state is TRUE)
run_stats <- dt[drought_state == TRUE,
                .(
                  start_date = min(date),
                  end_date   = max(date),
                  duration_m = .N,
                  min_z3     = min(z3, na.rm = TRUE),
                  mean_z3    = mean(z3, na.rm = TRUE),
                  cum_def3   = sum(pmin(z3, 0), na.rm = TRUE),
                  min_rain3  = min(rain3, na.rm = TRUE),
                  mean_rain3 = mean(rain3, na.rm = TRUE),
                  lon        = first(lon),
                  lat        = first(lat)
                ),
                by = .(cell_id, run_id)
]

# Filter: minimum event duration
run_stats <- run_stats[duration_m >= min_duration_months]
setorder(run_stats, cell_id, start_date)

# Enforce spacing between events within each cell
run_stats[, last_end := shift(end_date), by = cell_id]
run_stats[, keep := is.na(last_end) | start_date > (last_end %m+% months(spacing_months))]
run_stats <- run_stats[keep == TRUE]

# Assign event IDs (global)
run_stats[, event_id := .I]

# Join event_id back to month-level dt ONLY where drought_state is TRUE and run matches
dt <- merge(
  dt,
  run_stats[, .(cell_id, run_id, event_id)],
  by = c("cell_id", "run_id"),
  all.x = TRUE
)

# IMPORTANT: event_id should only exist on drought_state==TRUE rows
dt[drought_state == FALSE, event_id := NA_integer_]

# ----------------------------
# Step 5: Create final outputs
# ----------------------------

# Month-level output: keeps both raw rain and drought state
months_out <- dt[, .(
  cell_id, year, month, date, lon, lat,
  rain_mm, rain3, z3,
  drought_state, event_id
)]

fwrite(months_out, out_months)

# Event-level output
events_dt <- run_stats[, .(
  event_id, cell_id, start_date, end_date, duration_m,
  min_z3, mean_z3, cum_def3,
  min_rain3, mean_rain3,
  lon, lat
)]

fwrite(events_dt, out_events)

# Summary per cell
cell_summary <- events_dt[, .(
  n_events = .N,
  avg_duration = mean(duration_m, na.rm = TRUE),
  avg_min_z3 = mean(min_z3, na.rm = TRUE),
  lon = lon[1],
  lat = lat[1]
), by = cell_id]

fwrite(cell_summary, out_cell)

# ----------------------------
# Step 6: Highlight outputs (plots)
# ----------------------------

# Share of cells in drought state each month
ts <- months_out[, .(share_cells_drought = mean(drought_state, na.rm = TRUE)), by = date]

p1 <- ggplot(ts, aes(x = date, y = share_cells_drought)) +
  geom_line(linewidth = 0.4) +
  labs(
    title = "Share of 10km grid cells in drought (SPI-3 style, hysteresis)",
    x = NULL, y = "Share of cells"
  ) +
  theme_minimal()

ggsave(out_ts_png, p1, width = 9, height = 4, dpi = 150)

# Map: number of events per cell
p2 <- ggplot(cell_summary, aes(x = lon, y = lat, color = n_events)) +
  geom_point(size = 0.7, alpha = 0.9) +
  scale_color_viridis_c() +
  labs(
    title = "Number of drought events per 10km cell (SPI-3 style, hysteresis)",
    x = "Longitude", y = "Latitude", color = "Events"
  ) +
  theme_minimal()

ggsave(out_map_png, p2, width = 7, height = 6, dpi = 150)

# ----------------------------
# Sanity checks (fail loudly if logic breaks)
# ----------------------------


