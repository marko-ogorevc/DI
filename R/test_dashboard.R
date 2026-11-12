# UNICEF BiH DI | Shiny v0.1 data-contract smoke test (base R only)
# Checks app syntax and that model objects/columns used by the dashboard exist.
# Run from repository root: Rscript R/test_dashboard.R
# This does NOT open a Shiny session or replace a visual runtime check.

stopifnot(file.exists("app.R"), file.exists("R/run_model.R"))
invisible(parse("app.R"))

m <- new.env(parent = globalenv())
invisible(capture.output(sys.source("R/run_model.R", envir = m)))

ids <- c("S0_BAU", "S1_PHASED", "S1_PHASED_RESTRUCT", "S1_RESTRUCT_MATCH75")
stopifnot(setequal(unique(m$annual$scenario_id), ids))
stopifnot(setequal(unique(m$stocks$scenario_id), ids))
stopifnot(setequal(unique(m$institution_results$scenario_id), ids))
stopifnot(setequal(unique(m$flow_results$scenario_id), ids))
stopifnot(setequal(m$summary$scenario_id, ids))

required_columns <- list(
  annual = c("scenario_id", "year", "institution_children_end",
             "total_cost_bam", "institution_cost_bam",
             "care_cost_bam", "prevention_cost_bam",
             "transition_cost_bam", "institution_restructuring_cost_bam",
             "incremental_cost_bam", "discounted_incremental_bam",
             "institution_units_end"),
  stocks = c("scenario_id", "year", "care_type", "children_end"),
  flow_results = c("scenario_id", "year", "from_care", "to_care",
                   "expected_events", "deferred_suitability_events"),
  institution_results = c("scenario_id", "year", "units_start", "units_end",
                          "units_closed", "capacity_end", "staff_fte_end",
                          "staff_redeployed_fte", "one_off_closure_cost_bam"),
  scenarios = c("scenario_id", "enable_unit_closure",
                "alternative_suitability_fraction",
                "annual_transition_investment_bam",
                "annual_foster_capacity_add"),
  institution = c("units_start", "central_fixed_cost_bam_per_year",
                  "unit_fixed_cost_bam_per_year", "avoidable_unit_fixed_cost_share",
                  "staff_fte_per_unit", "staff_adjustment_lag_years",
                  "one_off_cost_bam_per_unit_closed")
)

for (object_name in names(required_columns)) {
  missing <- setdiff(required_columns[[object_name]], names(m[[object_name]]))
  if (length(missing)) stop(object_name, " missing: ", paste(missing, collapse = ", "))
}

horizon <- as.integer(m$settings$horizon_years)
for (id in ids) {
  a <- m$annual[m$annual$scenario_id == id, ]
  st <- m$stocks[m$stocks$scenario_id == id, ]
  ins <- m$institution_results[m$institution_results$scenario_id == id, ]
  stopifnot(nrow(a) == horizon, nrow(ins) == horizon,
            nrow(st) == horizon * 4L)
  stopifnot(all(is.finite(a$total_cost_bam)),
            all(is.finite(a$institution_children_end)),
            all(is.finite(ins$units_end)))
}
stopifnot(all(is.finite(m$summary$npv_incremental_cost_bam)))
cat("Shiny v0.1 syntax and data-contract checks passed.\n")


# Runtime smoke test of the user-editable scenario contract. The model is
# evaluated in memory, without modifying reference inputs or BAU results.
custom <- m$scenarios[m$scenarios$scenario_id == "S1_RESTRUCT_MATCH75", , drop = FALSE]
inst <- m$institution[1, , drop = FALSE]
custom$annual_cumulative_admission_reduction <- 0.08
custom$alternative_suitability_fraction <- 0.75
custom$annual_transition_investment_bam <- 125000
inst$avoidable_unit_fixed_cost_share <- 0.50
inst$staff_adjustment_lag_years <- 3L
custom_run <- m$simulate_one(custom, m$baseline, m$flows, m$settings, inst)
stopifnot(nrow(custom_run$costs) == horizon)
stopifnot(nrow(custom_run$institutions) == horizon)
stopifnot(all(is.finite(custom_run$costs$total_cost_bam)))
stopifnot(all(custom_run$stocks$children_end <=
              custom_run$stocks$capacity_end + 1e-8))
original <- m$annual[m$annual$scenario_id == custom$scenario_id, ]
original <- original[order(original$year), , drop = FALSE]
stopifnot(any(abs(custom_run$costs$total_cost_bam -
                  original$total_cost_bam) > 1e-4))
stopifnot(any(abs(custom_run$costs$institution_children_end -
                  original$institution_children_end) > 1e-4))
cat("Editable scenario smoke test passed.\n")
