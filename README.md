# Portfolio-Performance-Forecasting-and-Benchmark-Analysis

## Overview
This project was developed to analyse the historical performance of an investment portfolio, forecast future portfolio values, and compare expected performance against the S&P 500 (SPY) benchmark.

Using historical stock price data and ARIMA time-series forecasting, the project estimates future prices for each holding before aggregating them into an overall portfolio forecast. Historical return correlations between holdings are incorporated to estimate portfolio uncertainty, producing confidence intervals that better reflect diversification effects.

The project demonstrates an end-to-end financial analytics workflow including data preparation, statistical modelling, portfolio analysis, benchmarking, and data visualisation in R.

## Example Output
<img width="644" height="309" alt="portfolio_history_with_benchmark" src="https://github.com/user-attachments/assets/22f24465-513e-4e6a-9351-360c604f3356" />

## Objectives

The project aims to:

- Analyse historical portfolio performance.
- Forecast future stock prices using ARIMA models.
- Estimate future portfolio value.
- Compare portfolio performance against the SPY benchmark.
- Calculate expected portfolio profit and return.
- Quantify forecast uncertainty using confidence intervals.
- Visualise both portfolio-level and individual holding performance.


## Dataset

The analysis uses historical daily stock prices imported into R.

### Portfolio

| Stock | Investment |
|--------|-----------:|
| AAPL | $5,000 |
| JNJ | $2,000 |
| JPM | $1,500 |
| KO | $3,000 |
| MSFT | $1,000 |

**Total Investment:** $12,500

Benchmark:

- SPY ETF (S&P 500)


## Methodology

### 1. Data Preparation

Historical stock price data was imported using **readxl** before being cleaned and transformed using **dplyr** and **tidyr**.

Each investment was matched to its purchase date, allowing returns to be calculated from the correct investment period rather than from a common start date.

### 2. Time Series Forecasting

Each stock is modelled independently using the **forecast** package.

For every holding:

- Historical prices are extracted.
- The optimal ARIMA model is automatically selected using `auto.arima()`.
- Future prices are forecast to a user-selected prediction date.
- Prediction intervals are generated to quantify uncertainty.

Forecast prices are converted into projected holding values based on the original investment amount.
