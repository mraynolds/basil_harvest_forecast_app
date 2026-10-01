library(shiny)
library(fpp3)
library(tidyverse)

source('R/forecast_pipeline.R')

ui <- fluidPage(
  titlePanel('Basil Harvest Forecast'),
  
  helpText(
    "Forecasts the greenhouse-wide reported head-weight index,",
    "based on sampled marketable basil heads weighed before trimming.",
    "Observed products and lines receive equal weight within each day;",
    "observed days receive equal weight within each week.",
    "This is not total production or packed sales weight."
  ),
  
  helpText(
    "Uses data through the previous completed week.",
    "The first target is the following week, followed by 12 more weeks.",
    "Prediction intervals widen with the forecast horizon;",
    "long-range estimates may be too uncertain for firm sales commitments."
  ),
  
  helpText(
    "This public demonstration uses only bundled synthetic data.",
    "Forecasts do not represent company production or operational accuracy."
  ),
  
  dateInput(
    inputId = 'issue_date',
    label = 'Forecast issue date',
    value = as.Date('2026-09-29')
  ),
  
  selectInput(
    inputId = "demo_file",
    label = "Synthetic dataset",
    choices = c(
      "Original demo — issue date September 29" =
        "basil_synthetic_demo.csv",
      "Updated demo — issue date October 6" =
        "basil_synthetic_demo_updated.csv"
    )
  ),
  
  textOutput('file_message'),
  textOutput('cutoff_message'),
  actionButton('generate', 'Generate forecast'),
  textOutput('forecast_status'),
  plotOutput('forecast_plot'),
  tableOutput('forecast_table')
)

server <- function(input, output, session) {
  
  output$cutoff_message <- renderText({
    cutoff <- last_complete_week_start(input$issue_date) + 6
    
    paste('Use harvest data through', format(cutoff, '%B %d %Y'))
  })
  
  observeEvent(input$demo_file, {
    demo_date <- if (input$demo_file == "basil_synthetic_demo.csv") {
      as.Date("2026-09-29")
    } else {
      as.Date("2026-10-06")
    }
    
    updateDateInput(session, "issue_date", value = demo_date)
  })
  
  output$file_message <- renderText({
    data <- uploaded_data()
    paste('Loaded', nrow(data), 'rows from', input$demo_file)
  })
  
  uploaded_data <- reactive({
    req(input$demo_file)
    
    data <- readr::read_csv(
      input$demo_file,
      col_types = readr::cols(
        HarvestDate = readr::col_date(format = '%Y-%m-%d'),
        LineNumber = readr::col_double(),
        ProductID = readr::col_double(),
        AvgHeadweight = readr::col_double()
      )
    )
    
    required <- c(
      'HarvestDate', 'LineNumber', 'ProductID', 'AvgHeadweight'
    )
    
    validate(
      need(
        all(required %in% names(data)),
        'The CSV is missing one or more required columns.'
      ),
      need(
        nrow(readr::problems(data)) == 0,
        'Some values could not be read correctly. Check the CSV.'
      )
    )
    
    validate(
      need(
        nrow(data) > 0,
        'The CSV contains no data rows.'
      ),
      need(
        !anyNA(data$HarvestDate),
        'Some harvest dates are missing. Correct them before forecasting.'
      ),
      need(
        all(is.na(data$AvgHeadweight) |
              is.finite(data$AvgHeadweight)),
            'Head weights must be finite numbers or blank')
      )
    data
  })
  
  forecast_result <- eventReactive(input$generate, {
    data <- tryCatch(
      uploaded_data(),
      shiny.silent.error = function(e) NULL
    )
    
    req(!is.null(data))
    invalid_weights <- find_invalid_weights(data)
    
    display_data <-  tryCatch(
      {
        clean_basil_weights(data, invalid_weights) |>
          prepare_basil_weekly(issue_date = input$issue_date) |>
          forecast_basil(
            issue_date = input$issue_date,
            model_start = as.Date("2021-07-26")
          ) |>
          make_forecast_display()
      },
      error = function(e) e
    )
    
    failed <- inherits(display_data, "error")
    
    list(
      table = if (failed) NULL else display_data,
      error = if (failed) conditionMessage(display_data) else NULL,
      issue_date = input$issue_date,
      file_path = input$demo_file
    )
  })
  
  output$forecast_table <- renderTable({
    
    result <- forecast_result()
    req(is.null(result$error))
    
    result$table |>
      transmute(
        `Harvest week starting` = as.character(as.Date(week)),
        `Forecast (g)` = .mean,
        `80% lower` = lower80,
        `80% upper` = upper80,
        `95% lower` = lower95,
        `95% upper` = upper95
      )
    }, digits = 1)
  
  output$forecast_plot <- renderPlot({
    
    result <- forecast_result()
    req(is.null(result$error))
    
    plot_data <- forecast_result()$table |>
      mutate(week_start = as.Date(week))
    
    ggplot(data = plot_data, aes(x = week_start)) + 
      geom_ribbon(aes(ymin = lower95, ymax = upper95), fill = 'orange', alpha = 0.15) + 
      geom_ribbon(aes(ymin = lower80, ymax = upper80), fill = 'orange', alpha = 0.30) +
      geom_line(aes(y = .mean)) +
      labs(
        x = 'Harvest week starting',
        y = 'Reported head-weight index (g)',
        title = 'Weekly Basil Forecast',
        subtitle = 'Darker band: 80% prediction interval; lighter band: 95%'
        )
  })
  
  output$forecast_status <- renderText({
    req(input$demo_file)
    result <- forecast_result()
    
    changed <- !identical(result$issue_date, input$issue_date) ||
      !identical(result$file_path, input$demo_file)
    
    if (changed) {
      "Inputs changed. Click Generate forecast to update the displayed results."
    } else if (!is.null(result$error)) {
      paste("Forecast unavailable:", result$error)
    } else {
      paste(
        "Showing forecast for issue date",
        format(result$issue_date, "%B %d, %Y")
      )
    }
  })
}

shinyApp(ui = ui, server = server)