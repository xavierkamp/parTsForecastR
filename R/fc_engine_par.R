#' Forecasting Engine API
#' @description Function which enables the user to select different forecasting algorithms ranging from
#' traditional time series models (i.e. ARIMA, ETS, STL) to machine learning methods (i.e. LSTM, AutoML).
#' @param mts_data A univariate or multivariate ts, mts or xts object
#' @param fc_horizon An integer, the forcasting horizon
#' @param xreg_xts A univariate or multivariate ts, mts or xts object, optional external regressors
#' @param backtesting_opt A list, options for the backtesting program:
#'
#'  use_bt - A boolean, to determine whether to apply backtesting or to generate forcasts on future dates
#'
#'  nb_iters - An integer, to determine the number of backtesting operations to apply
#'
#'  method - A string, to determine whether to use a rolling or a moving forecasting window
#'
#'  sample_size - A string, to determine whether the training set size should expand or
#'  remain fixed across backtesting operations
#'
#' @param model_names A list or character, names of models to apply
#' @param model_args A list, optional arguments to pass to the models
#' @param save_fc_to_file A string, directory to which results can be saved as text files
#' @param time_id A POSIXct, created with \code{\link[base]{Sys.time}} and appended to results
#' @param use_parallel A boolean, apply parallel processing
#' @examples
#' ## Not run:
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
#'                       use_parallel = TRUE)
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
#' ## End (Not run)
#' @return A list
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
                            preprocess_fct = NULL,
                            models_args = NULL,
                            save_fc_to_file = NULL,
                            time_id = base::Sys.time(),
                            nb_cores = 1,
                            ...) {
  `%>%` <- magrittr::`%>%`
  `%do%` <- foreach::`%do%`
  `%dopar%` <- foreach::`%dopar%`
  if (!require(tsForecastR)) {
    devtools::install_github("xavierkamp/tsForecastR",
                             auth_token = "bdea47dff495e7faaca2839db3942d18fed75a25")
    library(tsForecastR)
  }
  library(tsForecastR)
  model_output <- base::list()
  mts_data_xts <- check_data_sv_as_xts(mts_data, default_colname = "time_series")
  xreg_data_xts <- check_data_sv_as_xts(xreg_data, default_colname = "feature")
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
  fc_horizon <- check_fc_horizon(fc_horizon)
  model_names <- check_model_names(model_names)
  models_args <- check_models_args(models_args, model_names)
  backtesting_opt <- check_backtesting_opt(backtesting_opt)
  save_fc_to_file <- check_save_fc_to_file(save_fc_to_file)
  nb_cores <- check_nb_cores(nb_cores)
  time_id <- check_time_id(time_id)
  ind_seq <- base::seq(base::ncol(mts_data_xts))
  cl <- parallel::makeCluster(nb_cores)
  doParallel::registerDoParallel(cl)
  model_output_ls <-
    foreach::foreach(ind = ind_seq,
                     .export = c("mts_data_xts",
                                 "xreg_data_xts",
                                 "fc_horizon",
                                 "backtesting_opt",
                                 "save_fc_to_file",
                                 "preprocess_fct",
                                 "time_id",
                                 "models_args")) %dopar% {
                                   library(tsForecastR)
                                   model_names_parall_proc <- model_names[model_names != "automl_h2o"]
                                   ts_data_xts <- univariate_xts(mts_data_xts, ind)
                                   ts_colname <- base::colnames(ts_data_xts)
                                   model_output_cores <- base::list()
                                   for (model_name in model_names_parall_proc) {
                                     base::eval(base::parse(text = base::paste("model_output_cores$", ts_colname, "$",
                                                                               model_name, " <- ",
                                                                               "generate_fc_", model_name, "(",
                                                                               "ts_data_xts = ts_data_xts, ",
                                                                               "xreg_xts = xreg_data_xts, ",
                                                                               "fc_horizon = fc_horizon, ",
                                                                               "backtesting_opt = backtesting_opt, ",
                                                                               "save_fc_to_file = save_fc_to_file, ",
                                                                               "preprocess_fct = preprocess_fct, ",
                                                                               "time_id = time_id, ",
                                                                               model_name, "_arg = models_args$",
                                                                               model_name, "_arg)",
                                                                               sep = "")))
                                   }
                                   return(model_output_cores)
                                 }
  model_output <- model_output_ls[[1]]
  parallel::stopCluster(cl)
  foreach::foreach(ind = ind_seq) %do% {
    model_names_parall_proc <- model_names[model_names == "automl_h2o"]
    ts_data_xts <- univariate_xts(mts_data_xts, ind)
    ts_colname <- base::colnames(ts_data_xts)
    for (model_name in model_names_parall_proc) {
      base::eval(base::parse(text = base::paste("model_output$", ts_colname, "$",
                                                model_name, " <- ",
                                                "generate_fc_", model_name, "(",
                                                "ts_data_xts = ts_data_xts, ",
                                                "xreg_xts = xreg_data_xts, ",
                                                "fc_horizon = fc_horizon, ",
                                                "backtesting_opt = backtesting_opt, ",
                                                "save_fc_to_file = save_fc_to_file, ",
                                                "preprocess_fct = preprocess_fct, ",
                                                "time_id = time_id, ",
                                                "nb_cores = nb_cores, ",
                                                model_name, "_arg = models_args$",
                                                model_name, "_arg)",
                                                sep = "")))
    }
  }
  return(model_output)
}