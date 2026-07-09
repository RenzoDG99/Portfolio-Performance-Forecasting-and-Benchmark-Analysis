# -----------------------------------------------------------
# Portfolio Performance Forecasting and Benchmark Analysis
# Author: Renzo Del Grosso
#
# Purpose:
# Forecast portfolio performance using ARIMA models,
# compare against SPY benchmark, and visualize results.



# -----------------------load packages-----------------------
library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(forecast)

# -----------------------read data-----------------------

df <- read_excel("data/StockAnalysisData.xlsx")

df <- df %>%
  mutate(Date = as.Date(Date, origin = "1899-12-30"))

# -----------------------PORTFOLIO-----------------------

portfolio <- data.frame(
  stock = c("AAPL", "JNJ", "JPM", "KO", "MSFT"),
  purchase_date = as.Date(c(
    "2022-01-30",
    "2023-02-10",
    "2022-12-01",
    "2024-03-18",
    "2023-05-01"
  )),
  value = c(5000, 2000, 1500, 3000, 1000)
)


# -----------------------predict values-----------------------

predict_price <- function(stock_data, future_date){

  stock_data <- stock_data %>%
    arrange(Date)

  last_date  <- max(stock_data$Date)
  last_price <- tail(stock_data$price, 1)

  # nothing to forecast if the target date is not in the future
  if(as.Date(future_date) <= last_date){
    return(data.frame(Date = last_date, price = last_price,
                      lo = last_price, hi = last_price))
  }

  # future trading days (Mon-Fri) between the last data point and the target
  future_dates <- seq(last_date + 1, as.Date(future_date), by = "day")
  wd <- as.POSIXlt(future_dates)$wday          # 0 = Sunday, 6 = Saturday
  future_dates <- future_dates[wd != 0 & wd != 6]

  h <- length(future_dates)

  fit <- auto.arima(ts(stock_data$price))
  fc  <- forecast(fit, h = h, level = 95)      # 95% prediction interval

  data.frame(
    Date  = future_dates,
    price = as.numeric(fc$mean),
    lo    = as.numeric(fc$lower[, 1]),
    hi    = as.numeric(fc$upper[, 1])
  )
}


# -----------------------value function-----------------------
portfolio_forecast <- function(df, portfolio, benchmark="SPY", prediction_date, conf_level = 0.80){

  portfolio <- portfolio %>%
    mutate(weight=value/sum(value))

  df_long <- df %>%
    pivot_longer(-Date,
                 names_to="stock",
                 values_to="price")

  price_list <- split(df_long, df_long$stock)

  benchmark_data <- price_list[[benchmark]]

  results <- lapply(seq_len(nrow(portfolio)), function(i){

    stock_name <- portfolio$stock[i]
    buy_date <- portfolio$purchase_date[i]
    invested <- portfolio$value[i]
    weight <- portfolio$weight[i]

    stock_data <- price_list[[stock_name]]

    if(is.null(stock_data)){
      return(NULL)
    }

    stock_sub <- stock_data %>%
      filter(Date>=buy_date) %>%
      arrange(Date)

    bench_sub <- benchmark_data %>%
      filter(Date>=buy_date) %>%
      arrange(Date)

    if(nrow(stock_sub)<20 || nrow(bench_sub)<20){
      return(NULL)
    }

    buy_price <- first(stock_sub$price)

    # full forecast paths (one row per future trading day)
    pred_stock <- predict_price(stock_sub, prediction_date)
    pred_bench <- predict_price(bench_sub, prediction_date)

    future_stock <- tail(pred_stock$price, 1)
    future_spy   <- tail(pred_bench$price, 1)

    stock_return <- future_stock/buy_price-1
    spy_return <- future_spy/first(bench_sub$price)-1

    final_value <- invested*(1+stock_return)

    # per-date forecast VALUE of this holding, plus the standard deviation
    # of that value (recovered from the 95% price interval)
    z <- qnorm(0.975)
    value_path <- data.frame(
      Date     = pred_stock$Date,
      stock    = stock_name,
      value    = invested * pred_stock$price / buy_price,
      value_sd = invested * (pred_stock$hi - pred_stock$lo) / buy_price / (2 * z)
    )

    summary <- data.frame(
      stock=stock_name,
      invested_value=invested,
      weight=weight,
      predicted_price=future_stock,
      predicted_return_pct=100*stock_return,
      benchmark_return_pct=100*spy_return,
      final_value=final_value,
      profit=final_value-invested
    )

    list(summary = summary, path = value_path)
  })

  results <- results[!vapply(results, is.null, logical(1))]

  holdings <- bind_rows(lapply(results, `[[`, "summary"))

  # ---- per-date portfolio forecast band via a covariance model ----
  paths <- bind_rows(lapply(results, `[[`, "path"))

  port_stocks <- unique(paths$stock)

  # correlation matrix of daily log returns for the held stocks
  prices   <- df %>% arrange(Date) %>% select(all_of(port_stocks))
  rets     <- as.data.frame(lapply(prices, function(p) c(NA, diff(log(p)))))
  corr_mat <- cor(rets, use = "pairwise.complete.obs")

  # SDs above were extracted at 95%; the DISPLAYED band uses conf_level so the
  # ribbon can be tightened without changing the underlying risk estimate.
  z <- qnorm(1 - (1 - conf_level) / 2)

  # Portfolio value = sum of holding values.
  # Var(portfolio) = s' R s, where s = vector of per-stock value SDs at that
  # date and R = return correlation matrix. This shrinks the band when stocks
  # are less than perfectly correlated (diversification).
  forecast_path <- paths %>%
    group_by(Date) %>%
    summarise(
      portfolio_value = sum(value),
      portfolio_sd = {
        s <- setNames(value_sd, stock)[port_stocks]
        s[is.na(s)] <- 0
        sqrt(as.numeric(t(s) %*% corr_mat %*% s))
      },
      .groups = "drop"
    ) %>%
    mutate(
      portfolio_lo = portfolio_value - z * portfolio_sd,
      portfolio_hi = portfolio_value + z * portfolio_sd
    )

  total_invested <- sum(holdings$invested_value)
  total_final <- sum(holdings$final_value)

  portfolio_return <- (total_final/total_invested-1)*100
  benchmark_return <- sum(holdings$benchmark_return_pct*holdings$weight)

  list(
    prediction_date=as.Date(prediction_date),
    holdings=holdings,
    forecast_path=forecast_path,
    total_invested=total_invested,
    total_final_value=total_final,
    portfolio_return_pct=portfolio_return,
    portfolio_profit=total_final-total_invested,
    benchmark_return_pct=benchmark_return,
    excess_return_pct=portfolio_return-benchmark_return,
    benchmark_value=total_invested*(1+benchmark_return/100)
  )
}



# -----------------------graph function-----------------------
portfolio_history <- function(df, portfolio, prediction_date, conf_level = 0.8){

  df_long <- df %>%
    pivot_longer(-Date,
                 names_to="stock",
                 values_to="price")

  history <- lapply(seq_len(nrow(portfolio)), function(i){

    this_stock <- portfolio$stock[i]
    buy_date <- portfolio$purchase_date[i]
    investment <- portfolio$value[i]

    stock_data <- df_long %>%
      filter(stock == this_stock,
             Date >= buy_date) %>%
      arrange(Date)

    initial_price <- first(stock_data$price)

    stock_data %>%
      mutate(value = investment * price / initial_price) %>%
      select(Date, value)

  })

  history <- bind_rows(history) %>%
    group_by(Date) %>%
    summarise(portfolio_value = sum(value),
              .groups = "drop") %>%
    arrange(Date)

  # per-date forecast path from the forecast function
  forecast_path <- portfolio_forecast(
    df,
    portfolio,
    prediction_date = prediction_date,
    conf_level = conf_level
  )$forecast_path

  # start the dashed forecast line at the last historical point
  # (band width is zero here, then widens with the forecast)
  connector <- tail(history, 1) %>%
    mutate(portfolio_lo = portfolio_value,
           portfolio_hi = portfolio_value)
  forecast_path <- bind_rows(connector, forecast_path)

  ggplot() +

    geom_ribbon(data = forecast_path,
                aes(Date, ymin = portfolio_lo, ymax = portfolio_hi),
                fill = "red", alpha = 0.15) +

    geom_line(data = history,
              aes(Date, portfolio_value),
              linewidth = 1.2, colour = "steelblue") +

    geom_line(data = forecast_path,
              aes(Date, portfolio_value),
              linetype = "dashed", colour = "red", linewidth = 1) +

    geom_point(data = tail(forecast_path, 1),
               aes(Date, portfolio_value),
               colour = "red", size = 4) +

    labs(
      title = "Portfolio Value: Historical and Forecast",
      x = "Date",
      y = "Portfolio Value ($)"
    ) +

    theme_minimal()

}



# -----------------------faceted per-stock graph function-----------------------
portfolio_facet_history <- function(df, portfolio, prediction_date,conf_level = 0.8) {

  z <- qnorm(1 - (1 - conf_level) / 2)

  df_long <- df %>%
    pivot_longer(-Date,
                 names_to  = "stock",
                 values_to = "price")

  price_list <- split(df_long, df_long$stock)

  # ---- build per-stock history + forecast ----
  stock_data_list <- lapply(seq_len(nrow(portfolio)), function(i) {

    this_stock  <- portfolio$stock[i]
    buy_date    <- portfolio$purchase_date[i]
    investment  <- portfolio$value[i]

    raw <- price_list[[this_stock]]
    if (is.null(raw)) return(NULL)

    stock_sub <- raw %>%
      filter(Date >= buy_date) %>%
      arrange(Date)

    if (nrow(stock_sub) < 20) return(NULL)

    buy_price <- first(stock_sub$price)

    # --- historical value path ---
    history <- stock_sub %>%
      mutate(
        stock          = this_stock,
        holding_value  = investment * price / buy_price,
        segment        = "historical"
      ) %>%
      select(Date, stock, holding_value, segment)

    # --- forecast price path ---
    pred <- predict_price(stock_sub, prediction_date)

    forecast_df <- data.frame(
      Date          = pred$Date,
      stock         = this_stock,
      holding_value = investment * pred$price    / buy_price,
      lo            = investment * pred$lo       / buy_price,
      hi            = investment * pred$hi       / buy_price,
      segment       = "forecast"
    )

    # tighten the interval to conf_level
    # (predict_price uses 95%; rescale SDs then re-apply conf_level z)
    z95 <- qnorm(0.975)
    sd_path <- (forecast_df$hi - forecast_df$lo) / (2 * z95)
    forecast_df$lo <- forecast_df$holding_value - z * sd_path
    forecast_df$hi <- forecast_df$holding_value + z * sd_path

    # connector: last historical point with zero-width band
    connector <- tail(history, 1) %>%
      mutate(lo = holding_value, hi = holding_value, segment = "forecast")

    forecast_df <- bind_rows(connector, forecast_df)

    # final predicted value label (last forecast row)
    label_row <- tail(forecast_df, 1) %>%
      mutate(
        label = paste0(
          "$", formatC(holding_value, format = "f", digits = 0, big.mark = ","),
          "\n(",
          ifelse(holding_value >= investment, "+", ""),
          formatC((holding_value / investment - 1) * 100, format = "f", digits = 1),
          "%)"
        )
      )

    list(
      history     = history,
      forecast_df = forecast_df,
      label_row   = label_row,
      investment  = investment,
      stock       = this_stock
    )
  })

  stock_data_list <- stock_data_list[!vapply(stock_data_list, is.null, logical(1))]

  # ---- combine into single data frames for ggplot ----
  all_history  <- bind_rows(lapply(stock_data_list, `[[`, "history"))
  all_forecast <- bind_rows(lapply(stock_data_list, `[[`, "forecast_df"))
  all_labels   <- bind_rows(lapply(stock_data_list, `[[`, "label_row"))

  # horizontal reference line per stock (invested value)
  invested_lines <- portfolio %>%
    filter(stock %in% unique(all_history$stock))

  # ---- plot ----
  ggplot() +

    # confidence ribbon
    geom_ribbon(
      data = all_forecast,
      aes(x = Date, ymin = lo, ymax = hi),
      fill  = "#e05c5c",
      alpha = 0.15
    ) +

    # invested-value reference line
    geom_hline(
      data    = invested_lines,
      aes(yintercept = value),
      colour  = "grey60",
      linetype = "dotted",
      linewidth = 0.6
    ) +

    # historical line
    geom_line(
      data      = all_history,
      aes(x = Date, y = holding_value),
      colour    = "steelblue",
      linewidth = 1.1
    ) +

    # forecast dashed line
    geom_line(
      data      = all_forecast,
      aes(x = Date, y = holding_value),
      colour    = "#e05c5c",
      linetype  = "dashed",
      linewidth = 0.95
    ) +

    # terminal forecast point
    geom_point(
      data   = all_labels,
      aes(x = Date, y = holding_value),
      colour = "#e05c5c",
      size   = 3.5
    ) +

    # predicted value label
    geom_text(
      data  = all_labels,
      aes(x = Date, y = holding_value, label = label),
      hjust  = 1.08,
      vjust  = 0.5,
      size   = 3,
      colour = "#e05c5c",
      lineheight = 0.9
    ) +

    facet_wrap(~ stock, scales = "free_y", ncol = 2) +

    scale_y_continuous(
      labels = scales::dollar_format(accuracy = 1)
    ) +

    labs(
      title    = "Individual Holding Value: Historical and Forecast",
      subtitle = paste0(
        "Forecast to ", format(as.Date(prediction_date), "%B %d, %Y"),
        "  |  ", round((1 - conf_level) * 100), "% outside shaded band"
      ),
      x = "Date",
      y = "Holding Value ($)"
    ) +

    theme_minimal(base_size = 12) +
    theme(
      strip.text       = element_text(face = "bold", size = 12),
      plot.title       = element_text(face = "bold", size = 14),
      plot.subtitle    = element_text(colour = "grey45", size = 10),
      panel.grid.minor = element_blank(),
      panel.spacing    = unit(1.2, "lines")
    )
}



# -----------------------graph function (with benchmark)-----------------------
portfolio_history_with_benchmark <- function(df, portfolio, prediction_date,benchmark = "SPY", conf_level = 0.80){

  z   <- qnorm(1 - (1 - conf_level) / 2)
  z95 <- qnorm(0.975)

  df_long <- df %>%
    pivot_longer(-Date, names_to = "stock", values_to = "price")

  price_list <- split(df_long, df_long$stock)

  # ---------- PORTFOLIO history ----------
  history <- lapply(seq_len(nrow(portfolio)), function(i){
    stock_data <- price_list[[ portfolio$stock[i] ]] %>%
      filter(Date >= portfolio$purchase_date[i]) %>%
      arrange(Date)
    initial_price <- first(stock_data$price)
    stock_data %>%
      mutate(value = portfolio$value[i] * price / initial_price) %>%
      select(Date, value)
  })

  history <- bind_rows(history) %>%
    group_by(Date) %>%
    summarise(portfolio_value = sum(value), .groups = "drop") %>%
    arrange(Date)

  # portfolio forecast path (existing engine)
  forecast_path <- portfolio_forecast(
    df, portfolio, benchmark = benchmark,
    prediction_date = prediction_date, conf_level = conf_level
  )$forecast_path

  connector <- tail(history, 1) %>%
    mutate(portfolio_lo = portfolio_value, portfolio_hi = portfolio_value)
  forecast_path <- bind_rows(connector, forecast_path)

  # ---------- BENCHMARK history ----------
  bench_all <- price_list[[benchmark]] %>% arrange(Date)

  bench_history <- lapply(seq_len(nrow(portfolio)), function(i){
    sub <- bench_all %>% filter(Date >= portfolio$purchase_date[i]) %>% arrange(Date)
    bp  <- first(sub$price)
    sub %>% mutate(value = portfolio$value[i] * price / bp) %>% select(Date, value)
  })

  bench_history <- bind_rows(bench_history) %>%
    group_by(Date) %>%
    summarise(benchmark_value = sum(value), .groups = "drop") %>%
    arrange(Date)

  # future benchmark value = K * spy_price, where K = sum(value_i / bench_buy_price_i)
  K <- sum(vapply(seq_len(nrow(portfolio)), function(i){
    bp <- first((bench_all %>% filter(Date >= portfolio$purchase_date[i]))$price)
    portfolio$value[i] / bp
  }, numeric(1)))

  bench_fc <- predict_price(
    bench_all %>% filter(Date >= min(portfolio$purchase_date)),
    prediction_date
  )

  bench_forecast <- data.frame(
    Date            = bench_fc$Date,
    benchmark_value = K * bench_fc$price,
    benchmark_lo    = K * bench_fc$lo,
    benchmark_hi    = K * bench_fc$hi
  )
  bsd <- (bench_forecast$benchmark_hi - bench_forecast$benchmark_lo) / (2 * z95)
  bench_forecast$benchmark_lo <- bench_forecast$benchmark_value - z * bsd
  bench_forecast$benchmark_hi <- bench_forecast$benchmark_value + z * bsd

  bench_connector <- tail(bench_history, 1) %>%
    mutate(benchmark_lo = benchmark_value, benchmark_hi = benchmark_value)
  bench_forecast <- bind_rows(bench_connector, bench_forecast)

  # ---------- plot ----------
  ggplot() +
    geom_ribbon(data = forecast_path,
                aes(Date, ymin = portfolio_lo, ymax = portfolio_hi),
                fill = "purple", alpha = 0.2) +
    geom_ribbon(data = bench_forecast,
                aes(Date, ymin = benchmark_lo, ymax = benchmark_hi),
                fill = "grey30", alpha = 0.17) +

    geom_line(data = history,
              aes(Date, portfolio_value, colour = "Portfolio"), linewidth = 1.2) +
    geom_line(data = bench_history,
              aes(Date, benchmark_value, colour = "Benchmark"), linewidth = 1.0) +

    geom_line(data = forecast_path,
              aes(Date, portfolio_value, colour = "Portfolio"),
              linetype = "dashed", linewidth = 1) +
    geom_line(data = bench_forecast,
              aes(Date, benchmark_value, colour = "Benchmark"),
              linetype = "dashed", linewidth = 0.9) +

    geom_point(data = tail(forecast_path, 1),
               aes(Date, portfolio_value, colour = "Portfolio"), size = 4) +
    geom_point(data = tail(bench_forecast, 1),
               aes(Date, benchmark_value, colour = "Benchmark"), size = 4) +

    scale_colour_manual(
      name   = NULL,
      values = c("Portfolio" = "purple", "Benchmark" = "grey30")
    ) +
    labs(title = "Portfolio vs Benchmark: Historical and Forecast",
         x = "Date", y = "Value ($)") +
    theme_minimal()
}



# -----------------------faceted per-stock graph (with benchmark)-----------------------
portfolio_facet_history_with_benchmark <- function(df, portfolio, prediction_date, benchmark = "SPY", conf_level = 0.80) {

  z   <- qnorm(1 - (1 - conf_level) / 2)
  z95 <- qnorm(0.975)

  df_long <- df %>%
    pivot_longer(-Date, names_to = "stock", values_to = "price")

  price_list <- split(df_long, df_long$stock)

  stock_data_list <- lapply(seq_len(nrow(portfolio)), function(i) {

    this_stock <- portfolio$stock[i]
    buy_date   <- portfolio$purchase_date[i]
    investment <- portfolio$value[i]

    raw <- price_list[[this_stock]]
    if (is.null(raw)) return(NULL)

    stock_sub <- raw %>% filter(Date >= buy_date) %>% arrange(Date)
    if (nrow(stock_sub) < 20) return(NULL)

    buy_price <- first(stock_sub$price)

    ## ---- STOCK history + forecast ----
    history <- stock_sub %>%
      mutate(stock = this_stock,
             holding_value = investment * price / buy_price,
             series = "This stock") %>%
      select(Date, stock, holding_value, series)

    pred <- predict_price(stock_sub, prediction_date)
    forecast_df <- data.frame(
      Date = pred$Date, stock = this_stock,
      holding_value = investment * pred$price / buy_price,
      lo = investment * pred$lo / buy_price,
      hi = investment * pred$hi / buy_price,
      series = "This stock"
    )
    sd_path <- (forecast_df$hi - forecast_df$lo) / (2 * z95)
    forecast_df$lo <- forecast_df$holding_value - z * sd_path
    forecast_df$hi <- forecast_df$holding_value + z * sd_path

    connector <- tail(history, 1) %>%
      mutate(lo = holding_value, hi = holding_value, series = "This stock")
    forecast_df <- bind_rows(connector, forecast_df)

    ## ---- BENCHMARK history + forecast (same $, same date) ----
    bench_sub <- price_list[[benchmark]] %>% filter(Date >= buy_date) %>% arrange(Date)
    bench_bp  <- first(bench_sub$price)

    bench_history <- bench_sub %>%
      mutate(stock = this_stock,
             holding_value = investment * price / bench_bp,
             series = "Benchmark") %>%
      select(Date, stock, holding_value, series)

    bpred <- predict_price(bench_sub, prediction_date)
    bench_forecast <- data.frame(
      Date = bpred$Date, stock = this_stock,
      holding_value = investment * bpred$price / bench_bp,
      lo = investment * bpred$lo / bench_bp,
      hi = investment * bpred$hi / bench_bp,
      series = "Benchmark"
    )
    bsd <- (bench_forecast$hi - bench_forecast$lo) / (2 * z95)
    bench_forecast$lo <- bench_forecast$holding_value - z * bsd
    bench_forecast$hi <- bench_forecast$holding_value + z * bsd

    bench_connector <- tail(bench_history, 1) %>%
      mutate(lo = holding_value, hi = holding_value, series = "Benchmark")
    bench_forecast <- bind_rows(bench_connector, bench_forecast)

    ## ---- terminal labels ----
    mk_label <- function(fc, series){
      tail(fc, 1) %>% mutate(
        series = series,
        label  = paste0("$", formatC(holding_value, format = "f", digits = 0, big.mark = ","),
                        " (", ifelse(holding_value >= investment, "+", ""),
                        formatC((holding_value / investment - 1) * 100, format = "f", digits = 1), "%)")
      )
    }

    list(
      history      = bind_rows(history, bench_history),
      forecast_df  = bind_rows(forecast_df, bench_forecast),
      label_row    = bind_rows(mk_label(forecast_df, "This stock"),
                               mk_label(bench_forecast, "Benchmark")),
      stock        = this_stock
    )
  })

  stock_data_list <- stock_data_list[!vapply(stock_data_list, is.null, logical(1))]

  all_history  <- bind_rows(lapply(stock_data_list, `[[`, "history"))
  all_forecast <- bind_rows(lapply(stock_data_list, `[[`, "forecast_df"))
  all_labels   <- bind_rows(lapply(stock_data_list, `[[`, "label_row"))

  invested_lines <- portfolio %>% filter(stock %in% unique(all_history$stock))

  pal <- c("This stock" = "purple", "Benchmark" = "grey30")

  ggplot() +
    geom_ribbon(data = all_forecast,
                aes(Date, ymin = lo, ymax = hi, fill = series), alpha = 0.13) +

    geom_hline(data = invested_lines, aes(yintercept = value),
               colour = "grey60", linetype = "dotted", linewidth = 0.6) +

    geom_line(data = all_history,
              aes(Date, holding_value, colour = series), linewidth = 1.05) +
    geom_line(data = all_forecast,
              aes(Date, holding_value, colour = series),
              linetype = "dashed", linewidth = 0.9) +

    geom_point(data = all_labels,
               aes(Date, holding_value, colour = series), size = 3) +
    geom_text(data = all_labels,
              aes(Date, holding_value, label = label, colour = series,
                  vjust = ifelse(series == "This stock", -0.8, 1.8)),
              hjust = 1.05, size = 2.8, show.legend = FALSE) +

    facet_wrap(~ stock, scales = "free_y", ncol = 2) +
    scale_colour_manual(name = NULL, values = pal) +
    scale_fill_manual(name = NULL, values = pal) +
    scale_y_continuous(labels = scales::dollar_format(accuracy = 1)) +
    labs(
      title    = "Individual Holding vs Benchmark: Historical and Forecast",
      subtitle = paste0("Forecast to ", format(as.Date(prediction_date), "%B %d, %Y"),
                        "  |  benchmark = same $ invested on the same date"),
      x = "Date", y = "Holding Value ($)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      strip.text    = element_text(face = "bold", size = 12),
      plot.title    = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(colour = "grey45", size = 10),
      panel.grid.minor = element_blank(),
      panel.spacing = unit(1.2, "lines"),
      legend.position = "top"
    )
}









# -----------------------results-----------------------

results <- portfolio_forecast(df,portfolio,benchmark="SPY",prediction_date="2027-12-31")

results$holdings
results$total_invested
results$total_final_value
results$portfolio_return_pct
results$portfolio_profit
results$benchmark_return_pct
results$excess_return_pct
results$benchmark_value


portfolio_history(df,portfolio,prediction_date = "2027-12-31",conf_level = 0.95)

portfolio_facet_history(df, portfolio, prediction_date = "2027-12-31", conf_level = 0.95)

portfolio_history_with_benchmark(df,portfolio,benchmark="SPY",prediction_date = "2027-12-31",conf_level = 0.95)

portfolio_facet_history_with_benchmark(df,portfolio,benchmark="SPY",prediction_date = "2027-12-31",conf_level = 0.95)
