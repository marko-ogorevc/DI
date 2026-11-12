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
  selected_annual <- reactive(annual_for(input$scenario))
  selected_stocks <- reactive(stocks_for(input$scenario))
  selected_institution <- reactive(institution_for(input$scenario))

  output$npv_value <- renderText({
    value <- scenario_summary$npv_incremental_cost_bam[
      scenario_summary$scenario_id == input$scenario]
    format_bam(value)
  })
  output$institution_children <- renderText({
    sprintf("%.1f", tail(selected_annual()$institution_children_end, 1))
  })
  output$active_units <- renderText({
    paste0(tail(selected_institution()$units_end, 1), " / ",
           institution_inputs$units_start[1])
  })

  output$cost_chart <- renderPlot({
    ids <- if (isTRUE(input$compare_all)) scenario_ids else unique(c("S0_BAU", input$scenario))
    d <- annual_data[annual_data$scenario_id %in% ids, , drop = FALSE]
    par(mar = c(4.2, 4.7, 2.1, 1.2))
    plot(range(d$year), range(d$total_cost_bam / 1e6), type = "n",
         xlab = "Year", ylab = "Million BAM (2025 prices)", xaxt = "n")
    axis(1, at = sort(unique(d$year)))
    grid(col = "#E5ECF2")
    for (id in ids) {
      x <- annual_for(id)
      lines(x$year, x$total_cost_bam / 1e6,
            col = scenario_colors[id], lwd = 2.7)
      points(x$year, x$total_cost_bam / 1e6,
             col = scenario_colors[id], pch = 16, cex = 0.7)
    }
    legend("topright", inset = 0.015, bty = "n", cex = 0.82,
           legend = unname(scenario_names[ids]),
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
    d <- flow_data[flow_data$scenario_id == input$scenario &
                     flow_data$from_care == "I" &
                     flow_data$to_care %in% c("F", "K", "G"), , drop = FALSE]
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
    x <- institution_inputs[1, ]
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
}

shinyApp(ui = ui, server = server)
