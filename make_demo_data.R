library(tidyverse)

set.seed(1234)

demo_dates <- seq.Date(
  as.Date('2021-07-28'),
  as.Date('2026-09-30'),
  by = 'week'
)

demo_table <- tidyr::expand_grid(
  HarvestDate = demo_dates,
  LineNumber = 1:5
  ) |> 
  mutate(
    ProductID = 9001,
    AvgHeadweight = rnorm(n(), mean = 55, sd = 5)
  )

write_csv(demo_table, 'basil_synthetic_demo_updated.csv')
