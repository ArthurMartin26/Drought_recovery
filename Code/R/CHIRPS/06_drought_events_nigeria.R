# ============================================================
# 06_drought_events_nigeria_wide_spi3.R
#
# Purpose:
#   Collapse cell-level drought events from Script 05 into
#   Nigeria-wide drought episodes for descriptive statistics.
#
# Definition of a Nigeria-wide drought episode:
#   All cell events sharing the SAME (start_date, end_date),
#   i.e. the same duration and the same set of months.
#
# Inputs (from Script 05):
#   - Data/Data_Output/drought_events_spi3.csv   (cell events)
#   - Data/Data_Output/drought_month_flags_spi3.csv (monthly panel w/state)
#
# Outputs:
#   - Data/Data_Output/drought_nigeria_events_spi3.csv
#   - Data/Data_Output/drought_nigeria_event_cell_map_spi3.csv
#   - Data/Data_Output/drought_nigeria_event_types_spi3.csv
#   - Data/Data_Output/drought_nigeria_events_by_year_spi3.png
#   - Data/Data_Output/drought_nigeria_event_extent_spi3.png
# ============================================================

suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
  library(ggplot2)
})

# ----------------------------
# Paths
# ----------------------------
in_events_cell  <- "Data/Data_Output/drought_events_spi3.csv"
in_months       <- "Data/Data_Output/drought_month_flags_spi3.csv"

out_ng_events   <- "Data/Data_Output/drought_nigeria_events_spi3.csv"
out_ng_map      <- "Data/Data_Output/drought_nigeria_event_cell_map_spi3.csv"
out_ng_types    <- "Data/Data_Output/drought_nigeria_event_types_spi3.csv"

out_png_year    <- "Data/Data_Output/drought_nigeria_events_by_year_spi3.png"
out_png_extent  <- "Data/Data_Output/drought_nigeria_event_extent_spi3.png"

stopifnot(file.exists(in_events_cell), file.exists(in_months))

# ----------------------------
# Load data
# ----------------------------
ev <- fread(in_events_cell)
mo <- fread(in_months)

needed_ev <- c("event_id","cell_id","start_date","end_date","duration_m",
               "min_z3","mean_z3","cum_def3","min_rain3","mean_rain3")
stopifnot(all(needed_ev %in% names(ev)))

needed_mo <- c("cell_id","date","drought_state","event_id")
stopifnot(all(needed_mo %in% names(mo)))

# Ensure date types
# fread() will typically bring these in as character; convert safely
ev[, start_date := as.IDate(start_date)]
ev[, end_date   := as.IDate(end_date)]
mo[, date := as.IDate(date)]

# Total cells (denominator for national shares)
n_cells_total <- uniqueN(mo$cell_id)
message(sprintf("Total unique grid cells in panel: %s", format(n_cells_total, big.mark=",")))

# ----------------------------
# Nigeria-wide event ID:
# group by same (start_date, end_date) window
# ----------------------------
setorder(ev, start_date, end_date, cell_id)

ev[, ng_key := paste0(start_date, "__", end_date)]
ev[, ng_event_id := as.integer(factor(ng_key))]

# ----------------------------
# Add month-set label (for interpretation)
# ----------------------------
# A helper to create a label like "Jun-Aug" or "Nov-Feb" robustly
month_set_label <- function(s, e) {
  mseq <- seq.Date(as.Date(s), as.Date(e), by = "month")
  paste0(month.abb[month(mseq)], collapse = "-")
}

ev[, month_set := mapply(month_set_label, start_date, end_date)]
ev[, start_year := year(as.Date(start_date))]
ev[, end_year   := year(as.Date(end_date))]

# Event "type" = (duration x month_set) ignoring year
ev[, ng_type := paste0("k", duration_m, "_", month_set)]

# ----------------------------
# Mapping: cell-event -> Nigeria event
# ----------------------------
ng_map <- ev[, .(event_id, cell_id, ng_event_id, start_date, end_date, duration_m, month_set, ng_type)]
fwrite(ng_map, out_ng_map)

# ----------------------------
# Nigeria-wide episode summary
# ----------------------------
# Aggregate across all cell-events that share the same ng_event_id window
ng_events <- ev[, .(
  start_date = first(start_date),
  end_date   = first(end_date),
  duration_m = first(duration_m),
  month_set  = first(month_set),
  start_year = first(start_year),
  
  # Extent
  n_cells_affected = uniqueN(cell_id),
  share_cells_affected = uniqueN(cell_id) / n_cells_total,
  
  # Severity across affected cells (cell-event stats already computed in 05)
  min_z3_national  = min(min_z3, na.rm = TRUE),
  mean_min_z3      = mean(min_z3, na.rm = TRUE),
  mean_mean_z3     = mean(mean_z3, na.rm = TRUE),
  sum_cum_def3     = sum(cum_def3, na.rm = TRUE),
  
  # Rainfall summary
  min_rain3_national = min(min_rain3, na.rm = TRUE),
  mean_rain3_cells   = mean(mean_rain3, na.rm = TRUE),
  
  # How many cell-events were merged into this national episode
  n_cell_events = .N
), by = ng_event_id]

setorder(ng_events, start_date, end_date)
fwrite(ng_events, out_ng_events)

message(sprintf("Nigeria-wide drought episodes created: %s",
                format(nrow(ng_events), big.mark=",")))

# ----------------------------
# Event type counts (duration x month_set)
# ----------------------------
ng_types <- ng_events[, .(
  n_events = .N,
  avg_extent_share = mean(share_cells_affected, na.rm = TRUE),
  avg_min_z3_national = mean(min_z3_national, na.rm = TRUE)
), by = .(duration_m, month_set)]

setorder(ng_types, duration_m, month_set)
fwrite(ng_types, out_ng_types)

# ----------------------------
# Plots
# ----------------------------

# 1) Count Nigeria-wide events by year
by_year <- ng_events[, .(n_events = .N), by = start_year]
setorder(by_year, start_year)

p_year <- ggplot(by_year, aes(x = start_year, y = n_events)) +
  geom_col(width = 0.8) +
  labs(
    title = "Nigeria-wide drought episodes per year (SPI-3 hysteresis; grouped by same month-window)",
    x = "Year (event start year)",
    y = "Number of Nigeria-wide episodes"
  ) +
  theme_minimal()

ggsave(out_png_year, p_year, width = 9, height = 4, dpi = 150)

# 2) Distribution of spatial extent (share of cells affected)
p_extent <- ggplot(ng_events, aes(x = share_cells_affected)) +
  geom_histogram(bins = 30) +
  labs(
    title = "Spatial extent of Nigeria-wide drought episodes",
    x = "Share of grid cells affected",
    y = "Number of episodes"
  ) +
  theme_minimal()


ggsave(out_png_extent, p_extent, width = 9, height = 4, dpi = 150)

# ----------------------------
# Sanity checks
# ----------------------------
# Each ng_event_id should correspond to a unique (start_date, end_date)
chk <- ng_events[, .N, by = .(ng_event_id, start_date, end_date)]
stopifnot(nrow(chk) == nrow(ng_events))

# Mapping should never assign NA ng_event_id
stopifnot(all(!is.na(ng_map$ng_event_id)))

message("DONE: Nigeria-wide drought episodes + event types written to Data/Data_Output/")