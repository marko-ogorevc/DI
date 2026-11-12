# UNICEF BiH DI - minimal synthetic M1-M3 demonstration (v0.2, base R only)
# Run from the repository root: Rscript R/run_model.R
# DISCLAIMER: ALL simulated inputs are synthetic. Published anchors are in data/evidence.csv.
# The model is a small hypothetical service system, NOT an estimate for Bosnia and Herzegovina.

required <- c("data/baseline.csv", "data/flows.csv", "data/scenarios.csv", "data/settings.csv", "data/institutions.csv")
if (!all(file.exists(required))) stop("Run from repository root; missing: ", paste(required[!file.exists(required)], collapse=", "))
baseline <- read.csv("data/baseline.csv", stringsAsFactors=FALSE)
flows <- read.csv("data/flows.csv", stringsAsFactors=FALSE)
scenarios <- read.csv("data/scenarios.csv", stringsAsFactors=FALSE)
settings <- read.csv("data/settings.csv", stringsAsFactors=FALSE)[1, ]
institution <- read.csv("data/institutions.csv", stringsAsFactors=FALSE)
cares <- c("I","F","K","G")
stopifnot(identical(as.character(baseline$care_type), cares))
stopifnot(all(flows$from_care %in% c(cares,"HOME")))
stopifnot(all(flows$to_care %in% c(cares,"HOME","EXIT")))
stopifnot(all(baseline$children_start >= 0), all(baseline$capacity_start >= baseline$children_start))
stopifnot(all(flows$annual_count >= 0))
# v0.2 has exactly one illustrative institution; the schema can later be expanded.
stopifnot(nrow(institution) == 1L, institution$care_type[1] == "I")
stopifnot(institution$units_start[1] >= 1, institution$places_per_unit[1] >= 1)
stopifnot(institution$min_units_operational[1] >= 1)
stopifnot(institution$min_units_operational[1] <= institution$units_start[1])
stopifnot(institution$closure_lag_years[1] >= 1)
stopifnot(all(scenarios$enable_unit_closure %in% c(0, 1)))
stopifnot(all(institution$central_fixed_cost_bam_per_year >= 0))
stopifnot(all(institution$unit_fixed_cost_bam_per_year >= 0))
stopifnot(all(institution$one_off_cost_bam_per_unit_closed >= 0))
stopifnot(abs(institution$units_start[1] * institution$places_per_unit[1] -
              baseline$capacity_start[baseline$care_type == "I"]) < 1e-8)
stopifnot(abs(institution$central_fixed_cost_bam_per_year[1] +
              institution$units_start[1] * institution$unit_fixed_cost_bam_per_year[1] -
              baseline$fixed_cost_bam_per_year[baseline$care_type == "I"]) < 1e-8)

simulate_one <- function(scenario, base, flow_rules, config, inst) {
  start_pop <- setNames(as.numeric(base$children_start), base$care_type)
  stocks <- start_pop
  caps <- setNames(as.numeric(base$capacity_start), base$care_type)
  variable_cost <- setNames(as.numeric(base$variable_cost_bam_per_child_year), base$care_type)
  fixed_cost <- setNames(as.numeric(base$fixed_cost_bam_per_year), base$care_type)
  stock_rows <- list(); cost_rows <- list(); flow_rows <- list(); institution_rows <- list()
  families <- as.numeric(config$prevention_families_start)
  units_active <- as.integer(inst$units_start)
  closure_wait <- 0L

  for (step in seq_len(as.integer(config$horizon_years))) {
    year <- as.integer(config$base_year) + step - 1L
    opening <- stocks
    # The active institution's capacity is determined by its open 25-place units.
    units_open <- units_active
    caps["I"] <- units_open * as.numeric(inst$places_per_unit)
    if (step > 1L) {
      caps["F"] <- caps["F"] + as.numeric(scenario$annual_foster_capacity_add)
      caps["K"] <- caps["K"] + as.numeric(scenario$annual_kinship_capacity_add)
      caps["G"] <- caps["G"] + as.numeric(scenario$annual_group_capacity_add)
      families <- families + as.numeric(scenario$annual_prevention_families_add)
    }
    realised <- numeric(nrow(flow_rules))
    for (j in seq_len(nrow(flow_rules))) {
      src <- flow_rules$from_care[j]; dst <- flow_rules$to_care[j]
      q <- as.numeric(flow_rules$annual_count[j])
      if (src != "HOME") q <- q * opening[src] / start_pop[src]
      if (src == "HOME" && dst == "I") {
        q <- q * max(0, 1 - as.numeric(scenario$annual_cumulative_admission_reduction) * step)
      }
      if (src == "I" && dst %in% c("F","K","G","HOME")) {
        q <- q * (1 + as.numeric(scenario$annual_institution_transition_multiplier_growth) * step)
      }
      realised[j] <- q
    }
    # A person cannot leave a care type more than once within a time step.
    for (src in cares) {
      ix <- which(flow_rules$from_care == src)
      if (length(ix) && sum(realised[ix]) > opening[src]) {
        realised[ix] <- realised[ix] * opening[src] / sum(realised[ix])
      }
    }
    # Capacity constraint. v0.1 stops if a scenario is infeasible; it never moves children into unsuitable care.
    closing <- opening
    for (c in cares) {
      closing[c] <- opening[c] + sum(realised[flow_rules$to_care == c]) - sum(realised[flow_rules$from_care == c])
    }
    if (any(closing < -1e-8)) stop("Negative stocks in ", scenario$scenario_id, " year ", year)
    if (any(closing > caps + 1e-8)) {
      bad <- cares[closing > caps + 1e-8]
      stop("Capacity exceeded in ", scenario$scenario_id, " year ", year, ": ", paste(bad, collapse=", "), ". Revise scenario/capacity.")
    }
    # Check whole-system stock-flow balance. HOME and EXIT are outside the four counted care stocks.
    home_entries <- sum(realised[flow_rules$from_care == "HOME" & flow_rules$to_care %in% cares])
    system_exits <- sum(realised[flow_rules$from_care %in% cares & flow_rules$to_care %in% c("HOME","EXIT")])
    if (abs(sum(closing) - (sum(opening) + home_entries - system_exits)) > 1e-7) {
      stop("Stock-flow accounting failed in year ", year)
    }
    # Care costs use average child-years. Institutional overhead is not proportional to occupancy.
    child_years <- (opening + closing) / 2
    institution_fixed <- as.numeric(inst$central_fixed_cost_bam_per_year) +
      units_open * as.numeric(inst$unit_fixed_cost_bam_per_year)
    institution_variable <- as.numeric(child_years["I"] * variable_cost["I"])
    institution_care <- institution_fixed + institution_variable
    other_care <- sum((child_years * variable_cost + fixed_cost)[cares != "I"])
    care_cost <- institution_care + other_care

    # Closure takes effect at year-end: one unit at most, and only if the
    # remaining units can accommodate closing-year institutional population.
    # A lag of 1 means one eligible year; the fixed-cost saving starts next year.
    units_needed <- max(as.integer(inst$min_units_operational),
                        ceiling(as.numeric(closing["I"]) / as.numeric(inst$places_per_unit) - 1e-8))
    closure_eligible <- (as.integer(scenario$enable_unit_closure) == 1L &&
                         units_needed < units_open)
    if (closure_eligible) closure_wait <- closure_wait + 1L else closure_wait <- 0L
    units_closed <- 0L
    if (closure_eligible && closure_wait >= as.integer(inst$closure_lag_years)) {
      units_active <- units_open - 1L
      units_closed <- 1L
      closure_wait <- 0L
    }
    institution_restructuring <- units_closed * as.numeric(inst$one_off_cost_bam_per_unit_closed)
    # General transition investment is separate from the unit-closure cost;
    # the input assumptions must avoid overlap when replaced with real data.
    prevention_cost <- families * as.numeric(config$prevention_cost_bam_per_family_year)
    transition_cost <- as.numeric(scenario$annual_transition_investment_bam)
    total <- care_cost + prevention_cost + transition_cost +
      institution_restructuring + as.numeric(config$system_fixed_cost_bam_per_year)
    caps_end <- caps
    caps_end["I"] <- units_active * as.numeric(inst$places_per_unit)
    for (c in cares) {
      stock_rows[[length(stock_rows)+1L]] <- data.frame(
        scenario_id=scenario$scenario_id, year=year, care_type=c,
        children_start=as.numeric(opening[c]), children_end=as.numeric(closing[c]),
        capacity=as.numeric(caps[c]), capacity_end=as.numeric(caps_end[c]),
        child_years=as.numeric(child_years[c])
      )
    }
    for (j in seq_len(nrow(flow_rules))) {
      flow_rows[[length(flow_rows)+1L]] <- data.frame(
        scenario_id=scenario$scenario_id, year=year,
        from_care=flow_rules$from_care[j], to_care=flow_rules$to_care[j],
        expected_events=realised[j]
      )
    }
    institution_rows[[length(institution_rows)+1L]] <- data.frame(
      scenario_id=scenario$scenario_id, year=year, institution_id=inst$institution_id,
      units_start=units_open, units_end=units_active,
      capacity_start=units_open * as.numeric(inst$places_per_unit),
      capacity_end=units_active * as.numeric(inst$places_per_unit),
      closure_eligible=closure_eligible, units_closed=units_closed,
      fixed_cost_bam=institution_fixed, variable_cost_bam=institution_variable,
      one_off_closure_cost_bam=institution_restructuring
    )
    cost_rows[[length(cost_rows)+1L]] <- data.frame(
      scenario_id=scenario$scenario_id, year=year, year_index=step-1L,
      institution_children_end=as.numeric(closing["I"]),
      institution_cost_bam=institution_care,
      institution_fixed_cost_bam=institution_fixed,
      institution_variable_cost_bam=institution_variable,
      institution_units_start=units_open, institution_units_end=units_active,
      units_closed=units_closed, institution_restructuring_cost_bam=institution_restructuring,
      prevention_families=families, care_cost_bam=care_cost,
      prevention_cost_bam=prevention_cost, transition_cost_bam=transition_cost,
      total_cost_bam=total
    )
    stocks <- closing
  }
  list(stocks=do.call(rbind,stock_rows), costs=do.call(rbind,cost_rows),
       flows=do.call(rbind,flow_rows), institutions=do.call(rbind,institution_rows))
}

simulations <- lapply(seq_len(nrow(scenarios)), function(i) simulate_one(scenarios[i, ], baseline, flows, settings, institution[1, ]))
stocks <- do.call(rbind, lapply(simulations, function(x) x$stocks))
annual <- do.call(rbind, lapply(simulations, function(x) x$costs))
flow_results <- do.call(rbind, lapply(simulations, function(x) x$flows))
institution_results <- do.call(rbind, lapply(simulations, function(x) x$institutions))

bau <- annual[annual$scenario_id == "S0_BAU", c("year","total_cost_bam")]
names(bau)[2] <- "bau_cost_bam"
annual <- merge(annual, bau, by="year", all.x=TRUE, sort=FALSE)
annual <- annual[order(annual$scenario_id, annual$year), ]
annual$incremental_cost_bam <- annual$total_cost_bam - annual$bau_cost_bam
annual$discounted_incremental_bam <- annual$incremental_cost_bam / ((1+settings$discount_rate)^annual$year_index)
annual$cumulative_incremental_bam <- ave(annual$incremental_cost_bam, annual$scenario_id, FUN=cumsum)

if (!dir.exists("outputs")) dir.create("outputs")
write.csv(stocks, "outputs/stocks.csv", row.names=FALSE)
write.csv(flow_results, "outputs/realised_flows.csv", row.names=FALSE)
write.csv(institution_results, "outputs/institution_units.csv", row.names=FALSE)
stopifnot(all(abs(annual$total_cost_bam - annual$care_cost_bam -
                  annual$prevention_cost_bam - annual$transition_cost_bam -
                  annual$institution_restructuring_cost_bam -
                  as.numeric(settings$system_fixed_cost_bam_per_year)) < 1e-6))
write.csv(annual, "outputs/annual_results.csv", row.names=FALSE)
summary <- aggregate(discounted_incremental_bam ~ scenario_id, annual, sum)
names(summary)[2] <- "npv_incremental_cost_bam"
write.csv(summary, "outputs/scenario_summary.csv", row.names=FALSE)
print(summary)
cat("Synthetic illustrative results only. All values in constant 2025 BAM.\n")
