library(testthat)
library(parTsForecastR)

context("Test fc generating functions")

test_that("generate_fc_par_works", {
  data <- seq(1:144)
  model_names <- c("arima", "ets", "snaive", "bsts", "nnetar", "stl")

  ts_data <- stats::ts(data, frequency = 12, start = c(1, 1))
  fc <- generate_fc_par(ts_data, model_names = model_names)
  expect_equal(class(fc)[1], "tsForecastR")
  expect_equal(names(fc), "time_series_1")

  mts_data <- base::cbind(ts_data, 2*ts_data)
  colnames(mts_data) <- NULL
  fc <- generate_fc_par(mts_data, model_names = model_names)
  expect_equal(class(fc)[1], "tsForecastR")
  expect_equal(names(fc), c("time_series_1", "time_series_2"))

  xts_data <- xts::as.xts(mts_data)
  fc <- generate_fc_par(xts_data, model_names = model_names)
  expect_equal(class(fc)[1], "tsForecastR")
  expect_equal(names(fc), c("time_series_1", "time_series_2"))

  xts_na_data <-
    c(data, rep(NA, 2), data) %>%
    stats::ts(., frequency = 12, start = c(1, 1)) %>%
    xts::as.xts()
  expect_equal(class(generate_fc_par(xts_na_data,
                                     model_names = model_names)),
               "tsForecastR")
  expect_equal(class(generate_fc_par(xts_na_data,
                                     model_names = model_names,
                                     preprocess_fct = timeSeries::na.contiguous)),
               "tsForecastR")
})

