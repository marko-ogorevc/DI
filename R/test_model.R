# UNICEF BiH DI v0.3 - deterministic accounting regression checks (base R).
# From repository root: Rscript R/test_model.R
source("R/run_model.R")

pick <- function(id) {
  x <- annual[annual$scenario_id == id, ]
  x[order(x$year), ]
}
bau <- pick("S0_BAU")
phased <- pick("S1_PHASED")
restructured <- pick("S1_PHASED_RESTRUCT")
limited <- pick("S1_RESTRUCT_MATCH75")
stopifnot(nrow(bau) == as.integer(settings$horizon_years))
stopifnot(nrow(phased) == nrow(bau), nrow(restructured) == nrow(bau),
          nrow(limited) == nrow(bau))

# Unit-cost restructuring must not change the children's projected pathways.
stopifnot(isTRUE(all.equal(phased$institution_children_end,
                           restructured$institution_children_end, tolerance=1e-9)))
a <- stocks[stocks$scenario_id == "S1_PHASED", ]
b <- stocks[stocks$scenario_id == "S1_PHASED_RESTRUCT", ]
a <- a[order(a$year, a$care_type), ]
b <- b[order(b$year, b$care_type), ]
stopifnot(isTRUE(all.equal(a$children_end, b$children_end, tolerance=1e-9)))
stopifnot(all(stocks$children_end >= -1e-8))
stopifnot(all(stocks$children_end <= stocks$capacity + 1e-8))
stopifnot(all(stocks$children_end <= stocks$capacity_end + 1e-8))
stopifnot(all(flow_results$expected_events >= 0))
stopifnot(all(flow_results$deferred_suitability_events >= -1e-9))
stopifnot(all(flow_results$planned_events >= flow_results$expected_events - 1e-8))
stopifnot(all(abs(flow_results$planned_events -
                  flow_results$expected_events -
                  flow_results$deferred_suitability_events -
                  flow_results$deferred_source_limit_events) < 1e-7))
stopifnot(sum(limited$deferred_suitability_events) > 0)
stopifnot(all(restructured$deferred_suitability_events == 0))
stopifnot(all(limited$institution_children_end >=
              restructured$institution_children_end - 1e-8))

# No-restructuring scenarios never close a unit; restructuring can.
stopifnot(all(phased$units_closed == 0L), all(bau$units_closed == 0L))
stopifnot(sum(restructured$units_closed) > 0L)
stopifnot(all(restructured$institution_units_end <= restructured$institution_units_start))
stopifnot(all(restructured$institution_units_end >= as.integer(institution$min_units_operational)))
stopifnot(all(institution_results$staff_redeployed_fte <=
              as.numeric(institution$max_annual_staff_redeployment_fte) + 1e-8))
stopifnot(all(abs(institution_results$staff_fte_end -
                  (as.numeric(institution$central_staff_fte) +
                   institution_results$units_end * as.numeric(institution$staff_fte_per_unit))) < 1e-8))
stopifnot(all(institution_results$capacity_end + 1e-8 >=
              annual$institution_children_end[match(
                paste(institution_results$scenario_id, institution_results$year),
                paste(annual$scenario_id, annual$year))]))
close_idx <- which(restructured$units_closed > 0)
stopifnot(length(close_idx) >= 1L, min(close_idx) >= as.integer(institution$staff_adjustment_lag_years))
first_close <- min(close_idx)
stopifnot(abs(restructured$institution_fixed_cost_bam[first_close] -
              phased$institution_fixed_cost_bam[first_close]) < 1e-8)
stopifnot(restructured$institution_fixed_cost_bam[first_close + 1L] <
          phased$institution_fixed_cost_bam[first_close + 1L])


# Fixed cost savings start only AFTER the year-end closure.
stopifnot(abs(phased$institution_cost_bam[1] -
              restructured$institution_cost_bam[1]) < 1e-6)
stopifnot(all(restructured$institution_fixed_cost_bam <=
              phased$institution_fixed_cost_bam + 1e-8))
stopifnot(abs(sum(restructured$institution_restructuring_cost_bam) -
              sum(restructured$units_closed) *
              as.numeric(institution$one_off_cost_bam_per_unit_closed)) < 1e-6)

# Cost categories must reconcile without counting closure expenses twice.
stopifnot(all(abs(annual$total_cost_bam - annual$care_cost_bam -
                  annual$prevention_cost_bam - annual$transition_cost_bam -
                  annual$institution_restructuring_cost_bam -
                  as.numeric(settings$system_fixed_cost_bam_per_year)) < 1e-6))
stopifnot(all(abs(annual$institution_cost_bam -
                  annual$institution_fixed_cost_bam -
                  annual$institution_variable_cost_bam) < 1e-6))

# Regression check against the previously executed v0.1 illustrative result.
npv <- setNames(summary$npv_incremental_cost_bam, summary$scenario_id)
stopifnot(abs(npv["S1_PHASED"] + 129778.3) < 2)
stopifnot(npv["S1_PHASED_RESTRUCT"] < npv["S1_PHASED"])
stopifnot(npv["S1_RESTRUCT_MATCH75"] > npv["S1_PHASED_RESTRUCT"])
# Independent Python accounting mirror reference (illustrative input set only).
stopifnot(abs(npv["S1_PHASED_RESTRUCT"] + 1309109.65) < 2)
stopifnot(abs(npv["S1_RESTRUCT_MATCH75"] + 908810.08) < 2)
cat("All v0.3 synthetic accounting and regression checks passed.\n")
