years  <- 2000:2024
months <- sprintf("%02d", 1:12)

base_url <- "https://data.chc.ucsb.edu/products/CHIRPS-2.0/africa_monthly/tifs/"
out_dir  <- "Data/Data_Raw/CHIRPS/Africa_monthly"

for (y in years) {
  for (m in months) {
    fname <- sprintf("chirps-v2.0.%d.%s.tif.gz", y, m)
    url   <- paste0(base_url, fname)
    dest  <- file.path(out_dir, fname)
    
    if (!file.exists(dest)) {
      download.file(url, dest, mode = "wb", quiet = TRUE)
    }
  }
}

gz_files <- list.files("Data/Data_Raw/CHIRPS/Africa_monthly",
                       pattern = "\\.gz$",
                       full.names = TRUE)

for (f in gz_files) {
  R.utils::gunzip(f, remove = TRUE)
}