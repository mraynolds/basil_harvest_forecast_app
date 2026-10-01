
last_complete_week_start <- function(issue_date) {
  monday <- lubridate::floor_date(
    issue_date, 
    unit = 'week',
    week_start = 1)
  return(monday - 7)
}

find_invalid_weights <- function(data) {
  data |>
    dplyr::filter(AvgHeadweight >= 130 | AvgHeadweight <= 10) |>
    dplyr::distinct(AvgHeadweight) |>
    dplyr::pull(AvgHeadweight)
}

clean_basil_weights <- function(data, invalid_weights) {
  cleaned_data <- data |>
    mutate(
      hw_invalid = AvgHeadweight %in% invalid_weights,
      AvgHeadweight_clean = if_else(
        hw_invalid,
        NA_real_,
        AvgHeadweight
      )
    )
  
  return(cleaned_data)
}

prepare_basil_weekly <- function(data, issue_date) {
  last_week_start <- last_complete_week_start(issue_date)
  cutoff_date <- last_week_start + 6
  eligible_data <- data |> 
    filter(
      HarvestDate <= cutoff_date,
      LineNumber %in% 1:5
    )
  
  product_day <- eligible_data |> 
    group_by(LineNumber, HarvestDate, ProductID) |> 
    summarise(hw_count = n_distinct(AvgHeadweight_clean, na.rm =TRUE),
              product_day_weight = if (hw_count == 0) {
                NA_real_ 
              } else {
                mean(unique(AvgHeadweight_clean), na.rm = TRUE)
              },
              ambiguous_sample = hw_count > 1,
              .groups = 'drop'
    )
  
  product_day_observed <- product_day |> 
    filter(!is.na(product_day_weight))
  
  daily_weights <- product_day_observed |> 
    group_by(LineNumber, HarvestDate) |> 
    summarise(
      daily_weight = mean(product_day_weight),
      n_products = n(),
      any_ambiguity = any(ambiguous_sample == TRUE),
      .groups = 'drop'
    ) |>
    arrange(HarvestDate, LineNumber)
  
  greenhouse_daily <- daily_weights |> 
    group_by(HarvestDate) |> 
    summarise(
      greenhouse_daily_weight = mean(daily_weight),
      n_lines_observed = n_distinct(LineNumber),
      any_ambiguity = any(any_ambiguity),
      .groups = "drop"
    ) |> 
    arrange(HarvestDate)
  
  greenhouse_weekly <- greenhouse_daily |> 
    mutate(week_start = lubridate::floor_date(HarvestDate, unit = 'week', week_start = 1)) |> 
    group_by(week_start) |> 
    summarise(
      weekly_weight = mean(greenhouse_daily_weight),
      n_harvest_days = n(),
      mean_lines_observed = mean(n_lines_observed),
      any_ambiguity = any(any_ambiguity),
      .groups = "drop"
    ) |> 
    arrange(week_start) |> 
    tidyr::complete(
      week_start = seq(min(week_start), max(week_start), by = "week"))
  
  return(greenhouse_weekly)
}


forecast_basil <- function(weekly_data, issue_date, model_start) {
  
  expected_last_week <- last_complete_week_start(issue_date)
  
  model_data <- weekly_data |> 
    filter(
      week_start >= model_start & week_start <= expected_last_week
    )
  
  if (nrow(model_data) == 0) {
    stop("No weekly data are available for the selected modeling period.")
  }
  
  if (max(model_data$week_start) != expected_last_week) {
    stop("The input does not include the last completed week. Update the data.")
  }
  
  if (any(is.na(model_data$weekly_weight))) {
    stop("The modeling period contains missing weekly weights. Review the data.")
  }
  
  model_data <- model_data |> 
    mutate(week = yearweek(week_start)) |> 
    as_tsibble(index = week)
  
  gap_check <- has_gaps(model_data)
  
  if (any(gap_check$.gaps)) {
    stop("The modeling period has gaps. Weeks are missing")
  }
  
  model_fit <- model(model_data, naive = NAIVE(weekly_weight))
  
  model_forecast <- model_fit |> 
    forecast(h = 14) |> 
    hilo(level = c(80, 95))
  
  return(model_forecast)

}

make_forecast_display <- function(forecast_data) {
  display_data <- forecast_data |> 
    as_tibble() |> 
    arrange(week) |> 
    mutate(
      horizon = row_number(),
      lower80 = `80%`$lower,
      upper80 = `80%`$upper,
      lower95 = `95%`$lower,
      upper95 = `95%`$upper
    ) |> 
    filter(horizon >= 2, horizon <= 14) |> 
    select(
      week, horizon, .mean, lower80, upper80, lower95, upper95
    )
  
  return(display_data)
}