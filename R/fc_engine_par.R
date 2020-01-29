#' Forecasting Engine API (parallel processing)
#' @description Function which enables the user to select different forecasting algorithms from
#' traditional time series models (i.e. ARIMA, ETS, STL) to machine learning methods (i.e. LSTM, AutoML).
#' @param mts_data A univariate or multivariate 'ts', 'mts' or 'xts' object
#' @param fc_horizon An integer, the forecasting horizon (i.e. the number of periods to forecast)
#' @param xreg_data A univariate or multivariate 'ts', 'mts' or 'xts' object, optional external regressors
#' @param backtesting_opt A list, options which define the backtesting approach:
#'
#'  use_bt - A boolean, to determine whether forecasts should be generated on future dates (default) or on past values. Generating
#'  forecasts on past dates allows to measure past forecast accuracy and to monitor a statistical model's ability to learn
#'  signals from the data.
#'
#'  nb_iters - An integer, to determine the number of forecasting operations to apply (When no backtesting is selected, then only
#'  one forecasting exercise is performed)
#'
#'  method - A string, to determine whether to apply a 'rolling' (default) or a 'moving' forecasting window. When 'rolling' is selected,
#'  after each forecasting exercise, the forecasting interval increments by one period and drops the last period to include it in
#'  the new training sample. When 'moving' is selected, the forecasting interval increments by its size rather than one period.
#'
#'  sample_size - A string, to determine whether the training set size should be 'expanding' (default) or 'fixed'.
#'  When 'expanding' is selected, then after each forecasting operation, the periods dropped from the forecasting interval will
#'  be added to the training set. When 'fixed' is selected, then adding new periods to the training set will require dropping as
#'  many last periods to keep the set's size constant.
#'
#' @param model_names A list or vector of strings representing the model names to be used
#' @param models_args A list, optional arguments to passed to the models
#' @param prepro_fct A function, a preprocessing function which handles missing values in the data.
#' The default preprocessing function selects the largest interval of non-missing values and then attributes the
#' most recent dates to those values. Other data handling functions can be applied (e.g. timeSeries::na.contiguous,
#' imputeTS::na.mean, custom-developped...).
#'
#' @param data_dir A string, directory to which results can be saved as text files
#' @param time_id A POSIXct, timestamp created with \code{\link[base]{Sys.time}} which is then appended to the results
#' @param nb_cores An integer, the number of CPU cores to use for parallel processing
#' @param ... Additional arguments to be passed to the function
#' @examples
#' \dontrun{
#' library(datasets)
#'
#' # Generate forecasts on future dates
#' fc <- generate_fc_par(AirPassengers,
#'                       fc_horizon = 12)
#'
#' fc <- generate_fc_par(AirPassengers,
#'                       fc_horizon = 6,
#'                       model_names = c("arima", "ets",
#'                                       "lstm_keras",
#'                                       "automl_h2o"))
#' fc <- generate_fc_par(AirPassengers,
#'                       fc_horizon = 6,
#'                       model_names = c("ets", "snaive",
#'                                       "stl", "nnetar"),
#'                       model_args = list(ets_arg = list(model = "ZZA",
#'                                                        opt.crit = "amse",
#'                                                        upper = c(0.3, 0.2,
#'                                                                  0.2, 0.98),
#'                                         stl_arg = list(s.window = "periodic")))
#'                       nb_cores = 2)
#'
#' # Generate forecasts on past dates to analyze performance
#' fc <- generate_fc_par(AirPassengers,
#'                       model_names = "arima",
#'                       fc_horizon = 12,
#'                       backtesting_opt = list(use_bt = TRUE))
#'
#' # Generate forecasts on past dates with multiple iterations and a rolling window
#' fc <- generate_fc_par(AirPassengers,
#'                       model_names = "tbats",
#'                       fc_horizon = 6,
#'                       backtesting_opt = list(use_bt = TRUE,
#'                                              nb_iters = 6))
#' }
#' @return A tsForecastR object
#' @export
generate_fc_par <- function(mts_data, fc_horizon = 12,
                            xreg_data = NULL,
                            backtesting_opt = list(use_bt = FALSE,
                                                   nb_iters = 1,
                                                   method = c("rolling",
                                                              "moving"),
                                                   sample_size = c("expanding",
                                                                   "fixed")),
                            model_names = c("arima", "ets", "tbats", "bsts",
                                            "snaive", "nnetar", "stl",
                                            "lstm_keras", "automl_h2o"),
                            prepro_fct = NULL,
                            models_args = NULL,
                            data_dir = NULL,
                            time_id = base::Sys.time(),
                            nb_cores = 1,
                            ...) {
  `%>%` <- magrittr::`%>%`
  `%do%` <- foreach::`%do%`
  `%dopar%` <- foreach::`%dopar%`
  model_output <- model_output_ls <- base::list()
  mts_data_xts <- tsForecastR::check_data_sv_as_xts(mts_data, default_colname = "time_series")
  xreg_data_xts <- tsForecastR::check_data_sv_as_xts(xreg_data, default_colname = "feature")
  if (!base::is.null(xreg_data_xts)) {
    keys_in_col <- base::colnames(xreg_data_xts) %>% stringr::str_detect("__")
    print(base::paste("Info about specified regressors: \n",
                      "Number of total features: ",
                      base::ncol(xreg_data_xts), "\n",
                      "Number of shared features (colnames w/o '__'): ",
                      base::sum(!keys_in_col), "\n",
                      "Number of ts specific features (ts_name + '__' + feature_name): ",
                      base::sum(keys_in_col),
                      sep = ""))
  }
  fc_horizon <- tsForecastR::check_fc_horizon(fc_horizon)
  model_names <- tsForecastR::check_model_names(model_names)
  models_args <- tsForecastR::check_models_args(models_args, model_names)
  backtesting_opt <- tsForecastR::check_backtesting_opt(backtesting_opt)
  data_dir <- tsForecastR::check_data_dir(data_dir)
  prepro_fct <- tsForecastR::check_preprocess_fct(prepro_fct)
  nb_cores <- tsForecastR::check_nb_cores(nb_cores)
  time_id <- tsForecastR::check_time_id(time_id)
  ind_seq <- base::seq(base::ncol(mts_data_xts))
  cl <- parallel::makeCluster(nb_cores)
  doParallel::registerDoParallel(cl)
  model_output_ls <-
    foreach::foreach(ind = ind_seq,
                     .export = c("mts_data_xts",
                                 "xreg_data_xts",
                                 "fc_horizon",
                                 "backtesting_opt",
                                 "data_dir",
                                 "prepro_fct",
                                 "time_id",
                                 "models_args"),
                     .packages = "tsForecastR") %dopar% {
     model_names_parall_proc <- model_names[model_names != "automl_h2o"]
     ts_data_xts <- tsForecastR::univariate_xts(mts_data_xts, ind)
     ts_colname <- base::colnames(ts_data_xts)
     model_output_cores <- base::list()
     for (model_name in model_names_parall_proc) {
       base::eval(base::parse(text = base::paste("model_output_cores$",
                                                 model_name, " <- ",
                                                 "tsForecastR::generate_fc_", model_name, "(",
                                                 "ts_data = ts_data_xts, ",
                                                 "xreg_data = xreg_data_xts, ",
                                                 "fc_horizon = fc_horizon, ",
                                                 "backtesting_opt = backtesting_opt, ",
                                                 "data_dir = data_dir, ",
                                                 "prepro_fct = prepro_fct, ",
                                                 "time_id = time_id, ",
                                                 model_name, "_arg = models_args$",
                                                 model_name, "_arg)",
                                                 sep = "")))
     }
     return(model_output_cores)
     }
  base::names(model_output_ls) <- base::colnames(mts_data_xts)
  model_output <- model_output_ls
  parallel::stopCluster(cl)
  foreach::foreach(ind = ind_seq) %do% {
    model_names_parall_proc <- model_names[model_names == "automl_h2o"]
    ts_data_xts <- tsForecastR::univariate_xts(mts_data_xts, ind)
    ts_colname <- base::colnames(ts_data_xts)
    for (model_name in model_names_parall_proc) {
      base::eval(base::parse(text = base::paste("model_output$", ts_colname, "$",
                                                model_name, " <- ",
                                                "tsForecastR::generate_fc_", model_name, "(",
                                                "ts_data = ts_data_xts, ",
                                                "xreg_data = xreg_data_xts, ",
                                                "fc_horizon = fc_horizon, ",
                                                "backtesting_opt = backtesting_opt, ",
                                                "data_dir = data_dir, ",
                                                "prepro_fct = prepro_fct, ",
                                                "time_id = time_id, ",
                                                "nb_threads = nb_cores, ",
                                                model_name, "_arg = models_args$",
                                                model_name, "_arg)",
                                                sep = "")))
    }
  }
  return(base::structure(model_output, class = "tsForecastR"))
}
