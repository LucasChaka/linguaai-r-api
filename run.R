if (!requireNamespace("plumber", quietly = TRUE)) {
  install.packages("plumber", repos = "https://cloud.r-project.org")
}

library(plumber)

port <- as.integer(Sys.getenv("PORT", 8000))

pr <- plumb("plumber.R")
pr$run(host = "0.0.0.0", port = port)