# Basil Harvest Forecast

An R Shiny application that forecasts a greenhouse-wide reported basil head-weight index for production planning. The public demonstration uses entirely synthetic data.

## Hosted demonstration

[Open the Basil Harvest Forecast app](https://jc9rx0-maxfield-raynolds.shinyapps.io/basil_forecast_demo/)

Choose a synthetic dataset and click **Generate forecast**:

- **Original demo:** issue date September 29, 2026; target weeks October 5–December 28.
- **Updated demo:** issue date October 6, 2026; target weeks October 12–January 4.

The public app does not accept uploaded company data. Its forecasts demonstrate software functionality, not operational accuracy.

## Run locally

Install the required packages:

```r
install.packages(c("shiny", "fpp3", "tidyverse"))
```

Open the repository directory in RStudio and run `app.R` using **Run App**, or run:

```r
shiny::runApp()
```

To render the synthetic report, open `basil_demo.qmd` and click **Render**. Rendering requires Quarto.

## What it predicts

The target is a weekly index based on sampled marketable basil heads weighed at harvest before trimming. It is not total production, packed sales weight, or average weight across every planted site.

Repeated identical weights within each line/date/product group are counted once. Distinct reported weights are averaged within those groups, then across products within each line/day, across observed lines within each day, and across observed days within each week.

This is an approximation: the source records do not reliably identify individual sampling events or record sample sizes. A sample repeated across products may receive additional influence.

## Data preparation and refresh

The reusable pipeline expects data already filtered to one greenhouse and basil, with these required columns:

| Column | Expected content |
|---|---|
| `HarvestDate` | Date in YYYY-MM-DD format |
| `LineNumber` | Numeric line identifier; lines 1–5 are retained |
| `ProductID` | Numeric product identifier |
| `AvgHeadweight` | Reported sample-average weight in grams; blanks allowed |

Weights ≤10 g or ≥130 g are flagged and replaced with missing values in the cleaned weight column. Original values are retained. These bounds are project-specific operational assumptions, not universal basil limits.

A separate private local workflow was tested with replacement CSVs. The public app instead selects between two bundled synthetic files to demonstrate a weekly update. Adding new bundled data to the hosted app requires redeployment; unattended refresh is not implemented.

## Forecast timing

The workflow is designed for Tuesday planning. It uses completed weeks through the preceding Sunday and displays 13 weekly targets beginning the Monday after the issue week.

For example, a September 29 issue date uses data through September 27 and first targets the week beginning October 5.

These are weekly periods, not calendar-month totals. The model generates 14 steps and omits the intervening week from the display.

## Model and evaluation

The selected model is naive: each point forecast equals the latest observed weekly index.

Development analysis on private operational data compared naive, simple exponential smoothing, damped-trend ETS, and seasonal naive with a 52-week lag. Evaluation used 13 expanding historical training cutoffs and forecast horizons 2–14.

ETS provided no meaningful improvement over naive in that validation period. Seasonal naive performed worse. The simpler naive model was retained.

Overlapping forecast windows are not independent observations. This period was used for model selection, not as an untouched final test. The private evaluation dataset is not included, so the operational comparison cannot be reproduced from the public synthetic demo.

The app displays 80% and 95% model-based prediction intervals. Long-horizon intervals can be too broad for precise sales commitments.

## Limitations and privacy

Changes in product mix, contributing lines, sampling practices, and growing conditions can affect the index. Variety changes and planned days to harvest are not modeled. Validation under the recent five-line operating setup is limited.

Historical evaluation assumes recorded measurements were available by the forecast cutoff; record-entry timing has not been verified.

Synthetic files contain invented measurements and demonstrate software operation only. They do not establish operational forecast accuracy.

Original company data and private analysis outputs are excluded from the public project. The hosted demonstration uses synthetic data only.