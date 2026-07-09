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
- Future prices are forecast to a user-selected prediction date.
- Prediction intervals are generated to quantify uncertainty.

Forecast prices are converted into projected holding values based on the original investment amount.


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


### 3. Portfolio Aggregation

Individual holding forecasts are combined into a portfolio forecast.

Instead of assuming every asset moves independently, the historical correlation between stock returns is used to estimate portfolio variance through a covariance matrix.

This produces confidence intervals that account for diversification, resulting in a more realistic estimate of portfolio risk.


### 4. Benchmark Analysis

To evaluate portfolio performance objectively, each investment is compared against investing the same amount into the SPY ETF on the same purchase date.

The project calculates:

- Portfolio return
- Benchmark return
- Portfolio profit
- Benchmark value
- Excess return

This provides a direct measure of whether active stock selection is expected to outperform passive market investing.


## Results

### Portfolio Summary

| Metric | Value |
|---------|-------:|
| Initial Investment | **$12,500** |
| Forecast Portfolio Value | **$21,269.86** |
| Forecast Profit | **$8,769.86** |
| Forecast Portfolio Return | **70.16%** |
| Benchmark Return | **103.43%** |
| Benchmark Value | **$25,429.15** |
| Relative Return vs Benchmark | **-33.27%** |


### Individual Holdings

| Stock | Return | Profit |
|--------|-------:|-------:|
| AAPL | 78.54% | $3,927.22 |
| JNJ | 38.96% | $779.28 |
| JPM | 176.53% | $2,647.90 |
| KO | 31.40% | $941.96 |
| MSFT | 47.35% | $473.49 |


## Visualisations

### Portfolio Historical Performance and Forecast

Displays:

- Historical portfolio value
- Forecast portfolio value
- Confidence intervals
- Final predicted portfolio value

<img width="602" height="341" alt="portfolio_history_forcast" src="https://github.com/user-attachments/assets/63b1461d-662d-4cd3-8b16-64c608e30b84" />


### Portfolio vs Benchmark

Compares historical and forecast portfolio performance against the SPY benchmark.

<img width="602" height="327" alt="portfolio_history_with_benchmark" src="https://github.com/user-attachments/assets/d9ba5a3b-29e6-4e02-8d6d-d8ad5a9a88a4" />


### Individual Holding Forecasts

Displays the historical value and future forecast for every holding.

Each graph includes:

- Historical performance
- Forecast
- Prediction interval
- Initial investment reference line
- Predicted final value

<img width="602" height="333" alt="portfolio_history_forcast_facet" src="https://github.com/user-attachments/assets/f7075742-982c-4fb3-b7de-28d7d80bbc5f" />


### Individual Holdings vs Benchmark

Compares each investment with investing the same amount into SPY over the same holding period.

<img width="602" height="331" alt="portfolio_history_with_benchmark_facet" src="https://github.com/user-attachments/assets/a4ccbd63-a9ff-453d-93be-bacdba40f33e" />


### Stock Price Range and Volatility Analysis

Shows the historical price movement of each holding, highlighting minimum and maximum observed prices and purchase price of each stock.

This provides additional insight into:
- Historical volatility
- Price range variation
- Relative movement between portfolio holdings

<img width="602" height="342" alt="stock_minmax_purchase" src="https://github.com/user-attachments/assets/548b1ed7-57d0-4d28-9d84-9f065d5598e5" />


## Key Findings

- The portfolio is forecast to increase from **$12,500** to approximately **$21,270**, representing a **70.16%** return.
- JPM is projected to deliver the highest percentage return (176.53%).
- Apple generates the largest monetary profit due to its higher allocation.
- Although every holding produces a positive expected return, the overall portfolio underperforms the SPY benchmark by approximately **33 percentage points**.
- Confidence intervals widen further into the forecast horizon, illustrating increasing uncertainty in long-term price predictions.


## Technologies Used

- R
- dplyr
- tidyr
- ggplot2
- forecast
- readxl
- Time Series Analysis (ARIMA)
- Portfolio Analytics
- Financial Modelling
- Statistical Forecasting


## Skills Demonstrated

- Data Cleaning
- Data Transformation
- Time Series Forecasting
- Statistical Analysis
- Financial Analytics
- Portfolio Performance Analysis
- Benchmark Analysis
- Data Visualisation
- Modular Programming
- Reproducible Analytical Workflows


## Future Improvements

Potential extensions include:

- Portfolio optimisation using Modern Portfolio Theory (MPT)
- Risk metrics including Sharpe Ratio, Sortino Ratio and Maximum Drawdown
- Forecast model comparison (ARIMA vs Prophet vs LSTM)
- Rolling backtesting for forecast validation
- Dividend-adjusted returns
- Interactive dashboard using Shiny or Power BI


## Repository Structure

```
Portfolio-Forecasting/
│
├── README.md
├── portfolio_forecasting.R
├── data/
├── images/
│   ├── portfolio_forecast.png
│   ├── portfolio_vs_benchmark.png
│   ├── individual_holdings.png
│   └── individual_vs_benchmark.png
└── LICENSE
```


## Running the Project

1. Clone the repository.
2. Install the required R packages.
3. Load the historical stock price dataset.
4. Update the portfolio data frame with your investments.
5. Choose a prediction date.
6. Run the forecasting functions to generate tables and visualisations.


## Author

Renzo Del Grosso

Bachelor of Science (Mathematics & Statistics with Financial Orientation)

This project was created to demonstrate practical applications of statistical modelling, financial analytics, and data visualisation using R.

