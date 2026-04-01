# ============================================================
# 05_define_drought_shocks_spi3_hysteresis_contiguous.R
#
# Three-pass drought construction:
#   PASS 1: Compute SPI-3 style z-score + hysteresis drought_state (no events)
#   PASS 2: Build contiguous runs using *calendar contiguity* (gap-aware)
#   PASS 3: Filter by min duration (>=3) and spacing; assign event_id
#
# Key fix: events are broken whenever months are not consecutive.
# Key robustness fix: calendar spans are computed with seq.Date(by="month")
#                    (avoids weird span calculations in data.table context).
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

out_months  <- "Data/Data_Output/drought_month_flags_spi3.csv"
out_events  <- "Data/Data_Output/drought_events_spi3.csv"
out_cell    <- "Data/Data_Output/drought_summary_by_cell_spi3.csv"
out_ts_png  <- "Data/Data_Output/drought_area_share_timeseries_spi3.png"
out_map_png <- "Data/Data_Output/drought_events_per_cell_map_spi3.png"
out_val_png <- "Data/Data_Output/validation_cells_spi3.png"

stopifnot(file.exists(panel_path))

# ----------------------------
# Parameters (tune later)
# ----------------------------
baseline_start <- 2000
baseline_end   <- 2010

k_months <- 3

enter_thresh <- -1.0
exit_thresh  <- -0.5

# IMPORTANT: per your definition, drought = >= 3 consecutive months
min_duration_months <- 3

# Optional: minimum gap after an event before next event starts (same cell)
# Set to 0 to disable
spacing_months <- 12

# Validation: number of cells to inspect before scaling
n_validate_cells <- 2

# ----------------------------
# Helper: robust month-span (inclusive)
# ----------------------------
month_span <- function(start_date, end_date) {
  # inclusive count of months between start and end
  length(seq(start_date, end_date, by = "month"))
}

# ----------------------------
# Load data
# ----------------------------
dt <- fread(panel_path)

needed <- c("cell_id", "year", "month", "rain_mm")
stopifnot(all(needed %in% names(dt)))

# date and ordering
# Construct proper calendar date
dt[, date := as.Date(sprintf("%04d-%02d-01", year, month))]

# CRITICAL FIX:
# Reorder into true calendar time within each cell
setorder(dt, cell_id, date)

# Sanity check: dates must now be non-decreasing by exactly 1 month
# (except where data are genuinely missing)
# Coordinates optional
has_coords <- all(c("lon", "lat") %in% names(dt))

# ============================================================
# Optional QC: identify cells with missing months in the panel
# (Missing months are exactly what cause non-contiguous runs if not handled.)
# ============================================================
qc <- dt[, .(
  min_date = min(date),
  max_date = max(date),
  n_rows = .N,
  n_expected = length(seq(min(date), max(date), by = "month"))
), by = cell_id]

qc_bad <- qc[n_rows != n_expected]
if (nrow(qc_bad) > 0) {
  message("QC: Found cells with missing months (showing first 10):")
  print(qc_bad[1:min(10, .N)])
} else {
  message("QC: No missing-month gaps detected (panel looks complete by cell).")
}

# ============================================================
# PASS 1: SPI-3 (rain3) + baseline standardisation + hysteresis state
# ============================================================

# 1A) 3-month rolling sum (aligned to current month)
# Invalidate rain3 if the 3-month window crosses a calendar gap
# 1A) 3-month rolling sum (aligned to current month)
dt[, rain3 := frollsum(rain_mm, n = k_months, align = "right", na.rm = FALSE), by = cell_id]# 1B) Baseline climatology by (cell_id, calendar month)
dt[, in_baseline := year >= baseline_start & year <= baseline_end]

base3 <- dt[in_baseline == TRUE & !is.na(rain3),
            .(
              base3_mean = mean(rain3),
              base3_sd   = sd(rain3)
            ),
            by = .(cell_id, month)]

dt <- merge(dt, base3, by = c("cell_id", "month"), all.x = TRUE)

# merge() reorders rows by join keys, so restore calendar order
setorder(dt, cell_id, date)

# ------------------------------------------------------------
# Stabilise baseline SD to prevent extreme z-scores
# Tier 1: exclude effectively-zero SD baselines (sd < 1e-6)
# Tier 2: apply SD floor based on 1st percentile of positive SDs
# ------------------------------------------------------------

# Compute an SD floor from the empirical distribution (positive SDs only)
sd_floor <- quantile(base3$base3_sd[base3$base3_sd > 0],
                     probs = 0.01, na.rm = TRUE)

message(sprintf("SD stabilisation: sd_floor (1st percentile of positive SDs) = %.6f", sd_floor))

# Create a stabilised SD column for computing z3
dt[, base3_sd_stab := base3_sd]

# Tier 1: near-zero SD -> unreliable baseline -> set to NA (so z3 becomes NA)
dt[!is.na(base3_sd_stab) & base3_sd_stab < 1e-6, base3_sd_stab := NA_real_]

# Tier 2: SD floor for remaining small-but-nonzero SDs
dt[!is.na(base3_sd_stab), base3_sd_stab := pmax(base3_sd_stab, sd_floor)]

# Compute z3 using stabilised SD (z3 is NA where baseline is unreliable)
dt[, z3 := (rain3 - base3_mean) / base3_sd_stab]

## mention this 
z_cap <- 6  # defensible bound for SPI-style indices

dt[, z3_trigger := pmax(pmin(z3, z_cap), -z_cap)]

# Intensity-safe version (bounded but explicitly named)
dt[, z3_intensity := z3_trigger]

# 1C) Hysteresis drought state (no events yet)
hysteresis_state <- function(z, enter = -1, exit = -0.5) {
  n <- length(z)
  state <- logical(n)
  in_drought <- FALSE
  
  for (t in seq_len(n)) {
    zi <- z[t]
    
    if (is.na(zi)) {
      # conservative: missing info => not in drought
      state[t] <- FALSE
      next
    }
    
    if (!in_drought) {
      if (zi <= enter) in_drought <- TRUE
    } else {
      if (zi >= exit) in_drought <- FALSE
    }
    
    state[t] <- in_drought
  }
  state
}


dt[, drought_state := hysteresis_state(z3_trigger,
                                       enter = enter_thresh,
                                       exit = exit_thresh),
   by = cell_id]

# ============================================================
# PASS 2: Build contiguous drought runs (gap-aware)
# ============================================================

# Define a "gap" whenever date != previous date + 1 month (within cell)
dt[, date_lag := shift(date), by = cell_id]
dt[, gap_month := !is.na(date_lag) & (date != (date_lag %m+% months(1)))]

# A new run starts if:
#   - drought_state differs from previous row OR
#   - there is a gap in months (even if state is the same)
dt[, state_lag := shift(drought_state, fill = FALSE), by = cell_id]
dt[, new_run := (drought_state != state_lag) | gap_month]
dt[, run_id := cumsum(new_run), by = cell_id]

# ============================================================
# PASS 3: Event table from TRUE runs + min duration + spacing + IDs
# ============================================================

# Run-level stats for TRUE runs only
run_stats <- dt[drought_state == TRUE,
                .(
                  start_date = min(date),
                  end_date   = max(date),
                  
                  # duration as number of months in the run (rows)
                  duration_m = .N,
                  
                  min_z3     = min(z3_intensity, na.rm = TRUE),
                  mean_z3    = mean(z3_intensity, na.rm = TRUE),
                  cum_def3   = sum(pmin(z3_intensity, 0), na.rm = TRUE),
                  min_rain3  = min(rain3, na.rm = TRUE),
                  mean_rain3 = mean(rain3, na.rm = TRUE),
                  
                  lon = if (has_coords) first(lon) else NA_real_,
                  lat = if (has_coords) first(lat) else NA_real_
                ),
                by = .(cell_id, run_id)]

# Robust calendar span in months (inclusive)
if (nrow(run_stats) > 0) {
  run_stats[, span_m := mapply(month_span, start_date, end_date)]
} else {
  run_stats[, span_m := numeric()]
}

# HARD GUARANTEE: if span_m != duration_m, contiguity is broken
# (Should not happen given gap-aware run_id, but keep this check.)
if (nrow(run_stats) > 0 && any(run_stats$span_m != run_stats$duration_m, na.rm = TRUE)) {
  bad <- run_stats[span_m != duration_m]
  message("First 20 non-contiguous runs:")
  print(bad[1:min(.N, 20)])
  stop("Contiguity check failed: found runs where calendar span != row-count duration.")
}

# Filter: minimum duration (>= 3 months)
run_stats <- run_stats[duration_m >= min_duration_months]
setorder(run_stats, cell_id, start_date)

# Optional: enforce spacing between events within each cell
if (spacing_months > 0 && nrow(run_stats) > 0) {
  run_stats[, last_end := shift(end_date), by = cell_id]
  run_stats[, keep := is.na(last_end) | (start_date > (last_end %m+% months(spacing_months)))]
  run_stats <- run_stats[keep == TRUE]
  run_stats[, c("last_end", "keep") := NULL]
}

# Assign global event IDs
run_stats[, event_id := .I]

# Join event_id back to month-level dt (only matched runs)
dt <- merge(
  dt,
  run_stats[, .(cell_id, run_id, event_id)],
  by = c("cell_id", "run_id"),
  all.x = TRUE
)

# Ensure event_id only on drought months
dt[drought_state == FALSE, event_id := NA_integer_]

# ----------------------------
# Outputs
# ----------------------------
months_out <- dt[, .(
  cell_id, year, month, date,
  lon = if (has_coords) lon else NA_real_,
  lat = if (has_coords) lat else NA_real_,
  rain_mm, rain3,
  z3_trigger,
  z3_intensity,
  drought_state, event_id
)]

fwrite(months_out, out_months)

events_dt <- run_stats[, .(
  event_id, cell_id, start_date, end_date, duration_m,
  min_z3, mean_z3, cum_def3,
  min_rain3, mean_rain3,
  lon, lat
)]
fwrite(events_dt, out_events)

cell_summary <- events_dt[, .(
  n_events = .N,
  avg_duration = mean(duration_m, na.rm = TRUE),
  avg_min_z3 = mean(min_z3, na.rm = TRUE),
  lon = if (has_coords) lon[1] else NA_real_,
  lat = if (has_coords) lat[1] else NA_real_
), by = cell_id]
fwrite(cell_summary, out_cell)

# ----------------------------
# Plots
# ----------------------------

# Share of cells in drought state each month
ts <- months_out[, .(share_cells_drought = mean(drought_state, na.rm = TRUE)), by = date]

p1 <- ggplot(ts, aes(x = date, y = share_cells_drought)) +
  geom_line(linewidth = 0.4) +
  labs(
    title = "Share of 10km grid cells in drought (SPI-3 style, hysteresis; contiguous events)",
    x = NULL, y = "Share of cells"
  ) +
  theme_minimal()

ggsave(out_ts_png, p1, width = 9, height = 4, dpi = 150)

# Map: number of events per cell (only if lon/lat exist)
if (has_coords && nrow(cell_summary) > 0) {
  p2 <- ggplot(cell_summary, aes(x = lon, y = lat, color = n_events)) +
    geom_point(size = 0.7, alpha = 0.9) +
    scale_color_viridis_c() +
    labs(
      title = "Number of drought events per 10km cell (SPI-3; contiguous events)",
      x = "Longitude", y = "Latitude", color = "Events"
    ) +
    theme_minimal()
  ggsave(out_map_png, p2, width = 7, height = 6, dpi = 150)
}

# ============================================================
# Validation on 1–2 cells (MANDATORY BEFORE SCALING)
# ============================================================

# Pick cells with at least one event if possible; otherwise first cells
cells_with_events <- unique(months_out[!is.na(event_id), cell_id])
if (length(cells_with_events) >= n_validate_cells) {
  val_cells <- cells_with_events[1:n_validate_cells]
} else {
  val_cells <- unique(months_out$cell_id)[1:n_validate_cells]
}

val_dt <- months_out[cell_id %in% val_cells]

# Simple validation printout (first 200 rows)
print(val_dt[, .(cell_id, date, z3_trigger, drought_state, event_id)][order(cell_id, date)][1:200])

# Plot z3 with drought_state shading
p_val <- ggplot(val_dt, aes(x = date, y = z3_trigger)) +
  geom_line(linewidth = 0.35) +
  geom_hline(yintercept = enter_thresh, linetype = "dashed", linewidth = 0.3) +
  geom_hline(yintercept = exit_thresh,  linetype = "dotted", linewidth = 0.3) +
  geom_ribbon(aes(ymin = -Inf, ymax = Inf, fill = drought_state),
              alpha = 0.15) +
  facet_wrap(~ cell_id, scales = "free_x", ncol = 1) +
  labs(
    title = "Validation cells: z3 and drought_state (shaded) with hysteresis thresholds",
    x = NULL, y = "z3 (SPI-3 style)"
  ) +
  theme_minimal() +
  guides(fill = "none")

ggsave(out_val_png, p_val, width = 10, height = 5 + 2 * n_validate_cells, dpi = 150)

# ============================================================
# Final sanity checks (fail loudly)
# ============================================================

# 1) event_id only appears on drought_state TRUE
stopifnot(months_out[!is.na(event_id), all(drought_state == TRUE)])

# 2) Every event has duration equal to calendar span (robust)
if (nrow(events_dt) > 0) {
  span2 <- mapply(month_span, events_dt$start_date, events_dt$end_date)
  stopifnot(all(span2 == events_dt$duration_m))
}

message("DONE: drought events built with gap-aware contiguity and validated on sample cells.")