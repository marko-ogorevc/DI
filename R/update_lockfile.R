# Regenerate a genuine renv.lock for Posit Connect Cloud.
# Run in the DI repository root from RStudio:
#   source("R/update_lockfile.R")
#
# This uses your actual installed R/package versions. It does not bootstrap
# or activate a project-local renv library (.Rprofile is unchanged).

if (!file.exists("app.R") || !file.exists("R/run_model.R")) {
  stop("Run this script from the DI repository root (the folder with app.R).")
}

min_renv <- package_version("1.1.0")
if (!requireNamespace("renv", quietly = TRUE) ||
    packageVersion("renv") < min_renv) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}
if (packageVersion("renv") < min_renv) {
  stop("renv >= 1.1.0 is required by Posit Connect Cloud.")
}
if (!requireNamespace("shiny", quietly = TRUE)) {
  install.packages("shiny", repos = "https://cloud.r-project.org")
}

# Explicitly capture the app's one non-base runtime package, plus renv,
# and all recursive dependencies; do not pin irrelevant RStudio packages.
renv::snapshot(
  project = getwd(),
  packages = c("shiny", "renv"),
  prompt = FALSE,
  update = FALSE
)
if (!file.exists("renv.lock")) stop("renv.lock was not created.")

# Fail early if the new lockfile missed either required package.
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("jsonlite is required to check renv.lock; install.packages('jsonlite').")
}
lock <- jsonlite::fromJSON("renv.lock", simplifyVector = FALSE)
if (!all(c("shiny", "renv") %in% names(lock$Packages))) {
  stop("Snapshot incomplete: lockfile does not contain both shiny and renv.")
}
if (package_version(lock$Packages$renv$Version) < min_renv) {
  stop("Snapshot incomplete: renv version in lockfile is too old.")
}
cat("Regenerated renv.lock using renv ", as.character(packageVersion("renv")),
    " and R ", as.character(getRversion()), ".\n",
    "Commit and push the changed renv.lock to GitHub, then republish.\n", sep = "")
