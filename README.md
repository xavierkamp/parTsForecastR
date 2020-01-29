[![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![Travis build status](https://travis-ci.com/xavierkamp/parTsForecastR.svg?branch=master)](https://travis-ci.com/xavierkamp/parTsForecastR)
[![AppVeyor build status](https://ci.appveyor.com/api/projects/status/github/xavierkamp/parTsForecastR?branch=master&svg=true)](https://ci.appveyor.com/project/xavierkamp/parTsForecastR)
[![Codecov test coverage](https://codecov.io/gh/xavierkamp/parTsForecastR/branch/master/graph/badge.svg)](https://codecov.io/gh/xavierkamp/parTsForecastR?branch=master)

# __Time Series Forecasting with Parallel Processing__
This package is an extension of the [tsForecastR](https://github.com/xavierkamp/tsForecastR) package. It uses a parallel processing framework to speed up forecast generation when multiple independent time series are present. To see the more details on the forecasting procedure, please inspect the [tsForecastR](https://github.com/xavierkamp/tsForecastR) package.

All codes are written in R.

## __Getting Started__

### __Prerequisites__

Install R: https://cloud.r-project.org/

Install RStudio: https://rstudio.com/products/rstudio/download/

For Windows, also install Rtools: https://cran.r-project.org/bin/windows/Rtools/

### __Install__

``` r
install.packages("devtools")
library("devtools")
devtools::install_github("xavierkamp/parTsForecastR")
```
### __Dependency__

This package requires the R package 'tsForecastR'.

## __Function__

__generate_fc_par__ : Function which enables the user to select different forecasting algorithms ranging from
traditional time series models (i.e. ARIMA, ETS, STL) to machine learning methods (i.e. LSTM, AutoML).

Example:
``` r
library(datasets)

ts_data <- stats::ts(seq(1:144), start = c(1, 1), frequency = 1)
mts_data <- cbind(ts_data, AirPassengers)

library(parTsForecastR)
# Generate forecasts on twelve periods
fc <- generate_fc_par(mts_data,
                      fc_horizon = 12)
df <- save_as_df(fc)
print(df)

# Generate forecasts on past data with a rolling window and six iterations
fc <- generate_fc_par(mts_data,
                      model_names = "arima",
                      fc_horizon = 12,
                      backtesting_opt = list(use_bt = TRUE,
                                             nb_iters = 6))
df <- save_as_df(fc)
print(df)
```
