# UNICEF BiH DI | Shiny dashboard v0.2
# Run from the repository root:
#   install.packages("shiny")   # once
#   shiny::runApp(".")
#
# The visualization layer supports session-only custom scenarios by calling
# the already validated simulate_one() function directly. No CSVs are changed,
# and S0_BAU always remains the original fixed reference scenario.
# All inputs and results are SYNTHETIC; not observations or forecasts for BiH.

if (!requireNamespace("shiny", quietly = TRUE)) {
  stop("The 'shiny' package is required. Run install.packages('shiny').")
}
library(shiny)

if (!file.exists("R/run_model.R")) {
  stop("Start Shiny from the DI repository root (where app.R is located).")
}

# Run the validated base-R model once when the app starts. Keep its objects in
# a separate environment so Shiny does not overwrite the model's variables.
model_env <- new.env(parent = globalenv())
invisible(capture.output(sys.source("R/run_model.R", envir = model_env)))

annual_data <- model_env$annual
stock_data <- model_env$stocks
flow_data <- model_env$flow_results
institution_data <- model_env$institution_results
scenario_summary <- model_env$summary
scenario_inputs <- model_env$scenarios
institution_inputs <- model_env$institution
settings <- model_env$settings

scenario_names <- c(
  S0_BAU = "S0 · Business as usual",
  S1_PHASED = "S1 · Phased reform, no closure",
  S1_PHASED_RESTRUCT = "S1 · Phased reform + restructuring",
  S1_RESTRUCT_MATCH75 = "S1 · Restructuring, 75% matching"
)
scenario_colors <- c(
  S0_BAU = "#72869B",
  S1_PHASED = "#3185A9",
  S1_PHASED_RESTRUCT = "#22896F",
  S1_RESTRUCT_MATCH75 = "#CE8544"
)
care_names <- c(I = "Institutional", F = "Foster",
                K = "Kinship", G = "Community / group")
care_colors <- c(I = "#234D78", F = "#408CB3",
                 K = "#66A79C", G = "#D39A50")
scenario_ids <- names(scenario_names)
stopifnot(setequal(scenario_ids, unique(annual_data$scenario_id)))
stopifnot(setequal(scenario_ids, unique(stock_data$scenario_id)))
stopifnot(setequal(scenario_ids, unique(institution_data$scenario_id)))
stopifnot(setequal(scenario_ids, scenario_summary$scenario_id))

annual_for <- function(id) {
  d <- annual_data[annual_data$scenario_id == id, , drop = FALSE]
  d[order(d$year), , drop = FALSE]
}
stocks_for <- function(id) {
  d <- stock_data[stock_data$scenario_id == id, , drop = FALSE]
  d[order(d$year, match(d$care_type, names(care_names))), , drop = FALSE]
}
institution_for <- function(id) {
  d <- institution_data[institution_data$scenario_id == id, , drop = FALSE]
  d[order(d$year), , drop = FALSE]
}
format_bam <- function(x) {
  paste0(format(round(as.numeric(x)), big.mark = ",",
                scientific = FALSE, trim = TRUE), " BAM")
}

ui <- fluidPage(
  tags$head(tags$style(HTML("
    body { background: #F5F8FB; color: #1A344C; }
    .container-fluid { max-width: 1500px; }
    .di-header { padding: 15px 0 11px; margin-bottom: 12px; }
    .di-header h2 { color: #183A5D; font-weight: 700; margin: 0 0 9px; }
    .di-header p { color: #51677D; font-size: 15px; margin-bottom: 5px; }
    .di-notice { background: #FFF7E9; border-left: 4px solid #C78B36;
                 padding: 10px 13px; margin-top: 14px; font-size: 13px; }
    .well, .metric-box, .tab-content { background: white; border: 1px solid #E0E8EF;
                                       border-radius: 8px; box-shadow: none; }
    .metric-box { padding: 17px 18px; margin-bottom: 15px; min-height: 115px; }
    .metric-label { color: #597087; font-size: 13px; margin-bottom: 9px; }
    .metric-value { font-size: 24px; font-weight: 700; color: #183A5D; }
    .tab-content { padding: 19px; }
    .nav-tabs { margin-bottom: 0; }
    .tab-content h4 { color: #183A5D; font-weight: 650; margin-top: 22px; }
    .help-text { color: #61758A; font-size: 13px; }
    .di-editor { margin-top: 18px; border-top: 1px solid #DFE8F0; padding-top: 9px; }
    .di-editor details { background: #F3F7FA; border: 1px solid #E0E8EF;
                         padding: 11px 13px; border-radius: 7px; margin: 12px 0; }
    .di-editor summary { cursor: pointer; font-weight: 650; margin-bottom: 4px; }
    .di-editor .form-group { margin-bottom: 15px; }
    .di-run-status { padding: 9px; border-left: 3px solid #6095B4;
                     color: #35556A; margin: 10px 0 3px; font-size: 13px; }
    .di-actions { display: flex; flex-wrap: wrap; gap: 7px; }
    .di-actions .btn { margin: 0; }
    .metric-value { overflow-wrap: anywhere; }
  "))),
  div(class = "di-header",
      h2("Child-centred DI | Economic simulation"),
      p("UNICEF BiH · Synthetic demonstration · Model v0.3 / Shiny v0.2"),
      p("Annual child pathways, institutional restructuring and fiscal scenario comparisons.")),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Scenario selection"),
      selectInput("scenario", "Policy scenario",
                  choices = stats::setNames(names(scenario_names),
                                            unname(scenario_names)),
                  selected = "S1_PHASED_RESTRUCT"),
      checkboxInput("compare_all", "Compare all scenarios in cost chart", TRUE),
      div(class = "di-editor",
        conditionalPanel(
          condition = "input.scenario != 'S0_BAU'",
          h4("Edit scenario assumptions"),
          p(class = "help-text",
            "Choose values, then click Run scenario. These inputs affect this browser session only."),
          sliderInput("adm_reduction", "Additional I admission reduction (per year)",
                      min = 0, max = 0.15, value = 0.05, step = 0.01),
          sliderInput("transition_growth", "I transition multiplier growth (per year)",
                      min = 0, max = 0.25, value = 0.07, step = 0.01),
          sliderInput("suitability", "Share of suitable I-to-alternative placements",
                      min = 0, max = 1, value = 1, step = 0.05),
          checkboxInput("closure_allowed", "Allow institutional unit closures", TRUE),
          tags$details(
            tags$summary("Capacity, finance & restructuring"),
            numericInput("foster_add", "New foster places / year",
                         value = 4, min = 0, max = 50, step = 1),
            numericInput("kinship_add", "New kinship places / year",
                         value = 2, min = 0, max = 50, step = 1),
            numericInput("group_add", "New group care places / year",
                         value = 1, min = 0, max = 30, step = 1),
            numericInput("prevention_add", "Additional families supported / year",
                         value = 10, min = 0, max = 100, step = 1),
            numericInput("transition_investment", "Annual transition investment (BAM)",
                         value = 100000, min = 0, max = 2000000, step = 25000),
            sliderInput("avoidable_share", "Avoidable fixed cost share per closed unit",
                        min = 0, max = 1, value = 0.65, step = 0.05),
            sliderInput("staff_lag", "Staff adjustment / closure lead time (years)",
                        min = 1, max = 5, value = 2, step = 1)
          ),
          div(class = "di-actions",
              actionButton("run_scenario", "Run scenario", class = "btn-primary"),
              actionButton("reset_scenario", "Reset defaults"))
        ),
        div(class = "di-run-status", textOutput("run_status"))
      ),
      tags$hr(),
      h4("Model settings"),
      p(class = "help-text",
        sprintf("Base year: %s · Horizon: %s years",
                settings$base_year, settings$horizon_years)),
      p(class = "help-text",
        sprintf("Discount rate: %.1f%% · Prices: %s BAM",
                100 * settings$discount_rate, settings$monetary_price_year)),
      p(class = "help-text",
        "The BAU comparator is fixed. Edited scenarios are recalculated in memory without changing the CSV inputs."),
      downloadButton("download_selected", "Download selected annual results",
                     class = "btn-default"),
      downloadButton("download_parameters", "Download applied assumptions",
                     class = "btn-default"),
      div(class = "di-notice",
          strong("Synthetic data only."),
          p("This represents one hypothetical local care system, not actual BiH children, facilities, budgets or forecasts. Negative incremental NPV means net fiscal savings relative to BAU."))
    ),
    mainPanel(
      width = 9,
      fluidRow(
        column(4, div(class = "metric-box",
                      div(class = "metric-label", "Discounted incremental costs"),
                      div(class = "metric-value", textOutput("npv_value")),
                      div(class = "help-text", "10-year NPV vs business as usual"))),
        column(4, div(class = "metric-box",
                      div(class = "metric-label", "Children in institutions"),
                      div(class = "metric-value", textOutput("institution_children")),
                      div(class = "help-text", "Expected count, final year"))),
        column(4, div(class = "metric-box",
                      div(class = "metric-label", "Active institutional units"),
                      div(class = "metric-value", textOutput("active_units")),
                      div(class = "help-text", "End of simulation horizon")))
      ),
      tabsetPanel(
        tabPanel("Financial results",
                 h4("Total annual system costs"),
                 plotOutput("cost_chart", height = "340px"),
                 h4("Cost decomposition — selected scenario"),
                 plotOutput("cost_components", height = "310px"),
                 h4("Annual fiscal outputs"),
                 tableOutput("annual_table")),
        tabPanel("Child pathways",
                 h4("Children by care type — selected scenario"),
                 plotOutput("child_chart", height = "350px"),
                 h4("Transitions from institutions to alternative care"),
                 plotOutput("flow_chart", height = "310px"),
                 p(class = "help-text",
                   "Expected values may be fractional. 'Deferred' transitions are not assumed to occur elsewhere.")),
        tabPanel("Institutional transformation",
                 h4("Active institutional units at year-end"),
                 plotOutput("unit_chart", height = "305px"),
                 h4("Institutional occupancy and operational places"),
                 plotOutput("capacity_chart", height = "305px"),
                 h4("Closures and workforce adjustment"),
                 tableOutput("institution_table")),
        tabPanel("Assumptions & limitations",
                 h4("Scenario assumptions"),
                 tableOutput("scenario_table"),
                 h4("Institution assumptions"),
                 tableOutput("institution_inputs_table"),
                 h4("Interpretation"),
                 p("Financial outputs are discounted incremental fiscal costs, not a complete societal cost-benefit analysis. There is no monetisation of long-term child outcomes."),
                 p("All baseline populations, costs, transition rates, workforce data, suitability shares and closure rules are synthetic. The suitability share is an aggregate stress-test assumption, not an individual child assessment."),
                 p("Capacity constraints and the two-year workforce-adjustment lag are simplified. They cannot establish that a particular placement or unit closure is legally or professionally feasible."),
                 p("Costs of closed units that cannot be avoided remain in system costs. Model parameters must be replaced with verified information before policy use."),
                 p("Custom scenario assumptions apply only while this app is running in the current session. Download applied assumptions if you want to save them. The published source CSVs and BAU comparator are unchanged."))
      )
    )
  )
)

server <- function(input, output, session) {
  # Each browser session owns its scenario override. No source CSVs are modified.
  override <- reactiveVal(NULL)

  restore_inputs <- function(id) {
    d <- scenario_inputs[scenario_inputs$scenario_id == id, , drop = FALSE]
    if (nrow(d) != 1L) return(invisible(NULL))
    updateSliderInput(session, "adm_reduction",
                      value = d$annual_cumulative_admission_reduction)
    updateSliderInput(session, "transition_growth",
                      value = d$annual_institution_transition_multiplier_growth)
    updateSliderInput(session, "suitability",
                      value = d$alternative_suitability_fraction)
    updateCheckboxInput(session, "closure_allowed",
                        value = as.logical(d$enable_unit_closure))
    updateNumericInput(session, "foster_add", value = d$annual_foster_capacity_add)
    updateNumericInput(session, "kinship_add", value = d$annual_kinship_capacity_add)
    updateNumericInput(session, "group_add", value = d$annual_group_capacity_add)
    updateNumericInput(session, "prevention_add",
                       value = d$annual_prevention_families_add)
    updateNumericInput(session, "transition_investment",
                       value = d$annual_transition_investment_bam)
    updateSliderInput(session, "avoidable_share",
                      value = institution_inputs$avoidable_unit_fixed_cost_share[1])
    updateSliderInput(session, "staff_lag",
                      value = institution_inputs$staff_adjustment_lag_years[1])
    invisible(NULL)
  }

  observeEvent(input$scenario, {
    override(NULL)
    restore_inputs(input$scenario)
  })
  observeEvent(input$reset_scenario, {
    override(NULL)
    restore_inputs(input$scenario)
    showNotification("Scenario defaults restored.", type = "message", duration = 4)
  })

  observeEvent(input$run_scenario, {
    req(input$scenario != "S0_BAU")
    id <- input$scenario
    x <- scenario_inputs[scenario_inputs$scenario_id == id, , drop = FALSE]
    inst <- institution_inputs[1, , drop = FALSE]
    values <- c(input$adm_reduction, input$transition_growth, input$suitability,
                input$foster_add, input$kinship_add, input$group_add,
                input$prevention_add, input$transition_investment,
                input$avoidable_share, input$staff_lag)
    if (length(values) != 10L || any(!is.finite(values)) || any(values < 0)) {
      showNotification("Enter valid non-negative numeric assumptions.",
                       type = "error", duration = 8)
      return(invisible(NULL))
    }
    x$annual_cumulative_admission_reduction <- input$adm_reduction
    x$annual_institution_transition_multiplier_growth <- input$transition_growth
    x$alternative_suitability_fraction <- input$suitability
    x$enable_unit_closure <- as.integer(isTRUE(input$closure_allowed))
    x$annual_foster_capacity_add <- as.integer(round(input$foster_add))
    x$annual_kinship_capacity_add <- as.integer(round(input$kinship_add))
    x$annual_group_capacity_add <- as.integer(round(input$group_add))
    x$annual_prevention_families_add <- as.integer(round(input$prevention_add))
    x$annual_transition_investment_bam <- input$transition_investment
    inst$avoidable_unit_fixed_cost_share <- input$avoidable_share
    inst$staff_adjustment_lag_years <- as.integer(round(input$staff_lag))

    outcome <- tryCatch({
      result <- model_env$simulate_one(x, model_env$baseline,
                                       model_env$flows, settings, inst)
      cost <- result$costs
      bau <- annual_for("S0_BAU")
      ix <- match(cost$year, bau$year)
      if (anyNA(ix)) stop("BAU reference years do not match the simulation.")
      cost$bau_cost_bam <- bau$total_cost_bam[ix]
      cost$incremental_cost_bam <- cost$total_cost_bam - cost$bau_cost_bam
      cost$discounted_incremental_bam <- cost$incremental_cost_bam /
        (1 + settings$discount_rate)^cost$year_index
      cost$cumulative_incremental_bam <- cumsum(cost$incremental_cost_bam)
      if (any(!is.finite(cost$total_cost_bam)) ||
          any(!is.finite(cost$discounted_incremental_bam))) {
        stop("The simulation returned non-finite costs.")
      }
      list(id = id, annual = cost, stocks = result$stocks,
           flows = result$flows, institutions = result$institutions,
           params = x, inst = inst)
    }, error = function(e) {
      showNotification(
        paste("Scenario not feasible:", conditionMessage(e)),
        type = "error", duration = 12
      )
      NULL
    })
    if (!is.null(outcome)) {
      override(outcome)
      showNotification("Scenario recalculated successfully.",
                       type = "message", duration = 5)
    }
  })

  active_data <- reactive({
    current <- override()
    if (!is.null(current) && identical(current$id, input$scenario))
      return(current)
    id <- input$scenario
    list(id = id, annual = annual_for(id), stocks = stocks_for(id),
         flows = flow_data[flow_data$scenario_id == id, , drop = FALSE],
         institutions = institution_for(id),
         params = scenario_inputs[scenario_inputs$scenario_id == id, , drop = FALSE],
         inst = institution_inputs[1, , drop = FALSE])
  })

  selected_annual <- reactive(active_data()$annual)
  selected_stocks <- reactive(active_data()$stocks)
  selected_institution <- reactive(active_data()$institutions)
  selected_flows <- reactive(active_data()$flows)
  applied_scenario <- reactive(active_data()$params)
  applied_institution <- reactive(active_data()$inst)

  output$run_status <- renderText({
    if (input$scenario == "S0_BAU")
      return("BAU is a fixed comparator; select a reform scenario to edit.")
    current <- override()
    if (!is.null(current) && identical(current$id, input$scenario))
      return("Custom scenario applied. Further edits require another Run scenario.")
    "Published synthetic defaults displayed. Edit and click Run scenario to recalculate."
  })

  output$npv_value <- renderText({
    format_bam(sum(selected_annual()$discounted_incremental_bam))
  })
  output$institution_children <- renderText({
    sprintf("%.1f", tail(selected_annual()$institution_children_end, 1))
  })
  output$active_units <- renderText({
    paste0(tail(selected_institution()$units_end, 1), " / ",
           institution_inputs$units_start[1])
  })

  output$cost_chart <- renderPlot({
    ids <- if (isTRUE(input$compare_all)) scenario_ids else
      unique(c("S0_BAU", input$scenario))
    get_cost <- function(id) {
      if (id == input$scenario) selected_annual()
      else annual_for(id)
    }
    d <- do.call(rbind, lapply(ids, get_cost))
    par(mar = c(4.2, 4.7, 2.1, 1.2))
    plot(range(d$year), range(d$total_cost_bam / 1e6), type = "n",
         xlab = "Year", ylab = "Million BAM (2025 prices)", xaxt = "n")
    axis(1, at = sort(unique(d$year)))
    grid(col = "#E5ECF2")
    for (id in ids) {
      x <- get_cost(id)
      lines(x$year, x$total_cost_bam / 1e6,
            col = scenario_colors[id], lwd = 2.7)
      points(x$year, x$total_cost_bam / 1e6,
             col = scenario_colors[id], pch = 16, cex = 0.7)
    }
    legend_labels <- unname(scenario_names[ids])
    current <- override()
    if (!is.null(current) && identical(current$id, input$scenario))
      legend_labels[ids == input$scenario] <-
        paste0(legend_labels[ids == input$scenario], " (edited)")
    legend("topright", inset = 0.015, bty = "n", cex = 0.82,
           legend = legend_labels,
           col = unname(scenario_colors[ids]), lwd = 2.7)
  })

  output$cost_components <- renderPlot({
    d <- selected_annual()
    mat <- rbind(
      Institutional = d$institution_cost_bam,
      `Other care` = d$care_cost_bam - d$institution_cost_bam,
      Prevention = d$prevention_cost_bam,
      `General transition` = d$transition_cost_bam,
      `Unit closures` = d$institution_restructuring_cost_bam
    ) / 1e6
    cols <- c("#234D78", "#66A6B4", "#88BFA0", "#E4B46D", "#C77B66")
    par(mar = c(4.1, 4.7, 1.7, 1))
    barplot(mat, names.arg = d$year, col = cols, border = NA,
            xlab = "Year", ylab = "Million BAM (2025 prices)",
            legend.text = rownames(mat),
            args.legend = list(x = "topright", bty = "n", cex = 0.77))
    box(bty = "l")
  })

  output$annual_table <- renderTable({
    d <- selected_annual()
    data.frame(
      Year = d$year,
      `Institutional children` = round(d$institution_children_end, 1),
      Units = d$institution_units_end,
      `Total costs (m BAM)` = round(d$total_cost_bam / 1e6, 3),
      `Incremental (m BAM)` = round(d$incremental_cost_bam / 1e6, 3),
      `Discounted incremental (m BAM)` =
        round(d$discounted_incremental_bam / 1e6, 3),
      check.names = FALSE
    )
  }, striped = TRUE, spacing = "xs", digits = 3)

  output$child_chart <- renderPlot({
    d <- selected_stocks()
    par(mar = c(4.3, 4.6, 1.5, 1))
    plot(range(d$year), range(c(0, d$children_end)), type = "n",
         xlab = "Year", ylab = "Expected children at year-end", xaxt = "n")
    axis(1, at = sort(unique(d$year)))
    grid(col = "#E5ECF2")
    for (care in names(care_names)) {
      z <- d[d$care_type == care, , drop = FALSE]
      lines(z$year, z$children_end, col = care_colors[care], lwd = 2.7)
      points(z$year, z$children_end,
             col = care_colors[care], pch = 16, cex = 0.6)
    }
    legend("topright", legend = unname(care_names),
           col = unname(care_colors), lwd = 2.7, bty = "n", cex = 0.88)
  })

  output$flow_chart <- renderPlot({
    d <- selected_flows()
    d <- d[d$from_care == "I" &
             d$to_care %in% c("F", "K", "G"), , drop = FALSE]
    years <- sort(unique(d$year))
    realised <- vapply(years, function(y)
      sum(d$expected_events[d$year == y]), numeric(1))
    deferred <- vapply(years, function(y)
      sum(d$deferred_suitability_events[d$year == y]), numeric(1))
    mat <- rbind(`Realised expected flows` = realised,
                 `Deferred by suitability proxy` = deferred)
    par(mar = c(4.2, 4.6, 1.5, 1))
    barplot(mat, beside = FALSE, names.arg = years,
            col = c("#3185A9", "#E6AC68"), border = NA,
            xlab = "Year", ylab = "Expected transitions",
            legend.text = rownames(mat),
            args.legend = list(x = "topright", bty = "n", cex = 0.82))
    box(bty = "l")
  })

  output$unit_chart <- renderPlot({
    d <- selected_institution()
    par(mar = c(4.3, 4.3, 1.5, 1))
    plot(d$year, d$units_end, type = "s", lwd = 3,
         col = "#22896F", xaxt = "n",
         ylim = c(0, max(institution_inputs$units_start, d$units_end)),
         xlab = "Year (year-end)", ylab = "Active units")
    axis(1, at = d$year)
    axis(2, at = 0:as.integer(institution_inputs$units_start[1]))
    points(d$year, d$units_end, pch = 16, col = "#22896F")
    grid(col = "#E8EEF2")
  })

  output$capacity_chart <- renderPlot({
    d <- selected_institution()
    a <- selected_annual()
    par(mar = c(4.3, 4.6, 1.5, 1))
    plot(d$year, d$capacity_end, type = "l", lwd = 2.8,
         col = "#3185A9", xaxt = "n",
         ylim = range(c(0, d$capacity_end, a$institution_children_end)),
         xlab = "Year", ylab = "Places / expected children")
    axis(1, at = d$year)
    grid(col = "#E8EEF2")
    lines(a$year, a$institution_children_end,
          col = "#D08A47", lwd = 2.8)
    legend("topright", c("Operational places", "Expected children"),
           col = c("#3185A9", "#D08A47"),
           lwd = 2.8, bty = "n")
  })

  output$institution_table <- renderTable({
    d <- selected_institution()
    data.frame(
      Year = d$year,
      `Units open` = d$units_start,
      `Units closed` = d$units_closed,
      `Units at year-end` = d$units_end,
      `FTE at year-end` = d$staff_fte_end,
      `FTE reassigned` = d$staff_redeployed_fte,
      `One-off closure cost (BAM)` = round(d$one_off_closure_cost_bam),
      check.names = FALSE
    )
  }, striped = TRUE, spacing = "xs")

  output$scenario_table <- renderTable({
    d <- scenario_inputs
    d[d$scenario_id == input$scenario, names(applied_scenario())] <-
      applied_scenario()[1, ]
    data.frame(
      Scenario = d$scenario_id,
      `Closure allowed` = as.logical(d$enable_unit_closure),
      `Suitability share` = d$alternative_suitability_fraction,
      `Annual transition investment (BAM)` =
        d$annual_transition_investment_bam,
      `Foster places added/year` = d$annual_foster_capacity_add,
      check.names = FALSE
    )
  }, striped = TRUE, spacing = "xs")

  output$institution_inputs_table <- renderTable({
    x <- applied_institution()[1, ]
    data.frame(
      `Central fixed cost (BAM/year)` = x$central_fixed_cost_bam_per_year,
      `Fixed cost/unit (BAM/year)` = x$unit_fixed_cost_bam_per_year,
      `Avoidable share` = x$avoidable_unit_fixed_cost_share,
      `Staff FTE/unit` = x$staff_fte_per_unit,
      `Staff adjustment lag (years)` = x$staff_adjustment_lag_years,
      `Closure cost (BAM/unit)` = x$one_off_cost_bam_per_unit_closed,
      check.names = FALSE
    )
  }, striped = TRUE, spacing = "xs")

  output$download_selected <- downloadHandler(
    filename = function() paste0("DI_", input$scenario, "_annual.csv"),
    content = function(file) write.csv(selected_annual(), file, row.names = FALSE)
  )

  output$download_parameters <- downloadHandler(
    filename = function() paste0("DI_", input$scenario, "_parameters.csv"),
    content = function(file) {
      param <- applied_scenario()
      inst <- applied_institution()
      dat <- data.frame(
        scenario_id = input$scenario,
        group = c(rep("scenario", ncol(param)), rep("institution", ncol(inst))),
        parameter = c(names(param), names(inst)),
        value = c(vapply(param, as.character, character(1)),
                  vapply(inst, as.character, character(1))),
        edited_in_session = !is.null(override()),
        stringsAsFactors = FALSE
      )
      write.csv(dat, file, row.names = FALSE)
    }
  )
}

shinyApp(ui = ui, server = server)
