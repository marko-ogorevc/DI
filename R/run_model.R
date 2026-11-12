# UNICEF BiH DI - minimal synthetic demonstration (base R only)
# Run from the repository root: Rscript R/run_model.R
# DISCLAIMER: ALL simulated inputs are synthetic. Published anchors are in data/evidence.csv.
# The model is a small hypothetical service system, NOT an estimate for Bosnia and Herzegovina.

required <- c("data/baseline.csv", "data/flows.csv", "data/scenarios.csv", "data/settings.csv")
if (!all(file.exists(required))) stop("Run from repository root; missing: ", paste(required[!file.exists(required)], collapse=", "))
baseline <- read.csv("data/baseline.csv", stringsAsFactors=FALSE)
flows <- read.csv("data/flows.csv", stringsAsFactors=FALSE)
scenarios <- read.csv("data/scenarios.csv", stringsAsFactors=FALSE)
settings <- read.csv("data/settings.csv", stringsAsFactors=FALSE)[1, ]
cares <- c("I","F","K","G")
stopifnot(identical(as.character(baseline$care_type), cares))
stopifnot(all(flows$from_care %in% c(cares,"HOME")))
stopifnot(all(flows$to_care %in% c(cares,"HOME","EXIT")))
stopifnot(all(baseline$children_start >= 0), all(baseline$capacity_start >= baseline$children_start))
stopifnot(all(flows$annual_count >= 0))

simulate_one <- function(scenario, base, flow_rules, config) {
  start_pop <- setNames(as.numeric(base$children_start), base$care_type)
  stocks <- start_pop
  caps <- setNames(as.numeric(base$capacity_start), base$care_type)
  variable_cost <- setNames(as.numeric(base$variable_cost_bam_per_child_year), base$care_type)
  fixed_cost <- setNames(as.numeric(base$fixed_cost_bam_per_year), base$care_type)
  stock_rows <- list(); cost_rows <- list(); flow_rows <- list()
  families <- as.numeric(config$prevention_families_start)

  for (step in seq_len(as.integer(config$horizon_years))) {
    year <- as.integer(config$base_year) + step - 1L
    opening <- stocks
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
    # Approximate child-years using mean opening and closing stocks (flows assumed spread over the year).
    child_years <- (opening + closing) / 2
    care_cost <- sum(child_years * variable_cost + fixed_cost)
    prevention_cost <- families * as.numeric(config$prevention_cost_bam_per_family_year)
    transition_cost <- as.numeric(scenario$annual_transition_investment_bam)
    total <- care_cost + prevention_cost + transition_cost + as.numeric(config$system_fixed_cost_bam_per_year)
    for (c in cares) {
      stock_rows[[length(stock_rows)+1L]] <- data.frame(
        scenario_id=scenario$scenario_id, year=year, care_type=c,
        children_start=as.numeric(opening[c]), children_end=as.numeric(closing[c]),
        capacity=as.numeric(caps[c]), child_years=as.numeric(child_years[c])
      )
    }
    for (j in seq_len(nrow(flow_rules))) {
      flow_rows[[length(flow_rows)+1L]] <- data.frame(
        scenario_id=scenario$scenario_id, year=year,
        from_care=flow_rules$from_care[j], to_care=flow_rules$to_care[j],
        expected_events=realised[j]
      )
    }
    cost_rows[[length(cost_rows)+1L]] <- data.frame(
      scenario_id=scenario$scenario_id, year=year, year_index=step-1L,
      institution_children_end=as.numeric(closing["I"]),
      institution_cost_bam=as.numeric(child_years["I"]*variable_cost["I"]+fixed_cost["I"]),
      prevention_families=families, care_cost_bam=care_cost,
      prevention_cost_bam=prevention_cost, transition_cost_bam=transition_cost,
      total_cost_bam=total
    )
    stocks <- closing
  }
  list(stocks=do.call(rbind,stock_rows), costs=do.call(rbind,cost_rows), flows=do.call(rbind,flow_rows))
}

simulations <- lapply(seq_len(nrow(scenarios)), function(i) simulate_one(scenarios[i, ], baseline, flows, settings))
stocks <- do.call(rbind, lapply(simulations, function(x) x$stocks))
annual <- do.call(rbind, lapply(simulations, function(x) x$costs))
flow_results <- do.call(rbind, lapply(simulations, function(x) x$flows))

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
write.csv(annual, "outputs/annual_results.csv", row.names=FALSE)
summary <- aggregate(discounted_incremental_bam ~ scenario_id, annual, sum)
names(summary)[2] <- "npv_incremental_cost_bam"
write.csv(summary, "outputs/scenario_summary.csv", row.names=FALSE)
print(summary)
cat("Synthetic illustrative results only. All values in constant 2025 BAM.\n")
