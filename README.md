# AINET-GNN-Trade-2021
Artificial Intelligence Network Explanation of Trade (AINET)

## Data Preparation
Pull data from [UN Comtrade website](https://comtrade.un.org/data/)

Files
* data_prep/uncomtrade_data_pull.py
* data_prep/uncomtrade_data_process.py

## Alternative Modeling
ARIMA and OLS models are created using the UN comtrade data. Individual ARIMA(0,1,1) models are ran for each country, forecasting soybean trade-unit-value forward 1, 6, and 24 months forward. A preliminary parametric OLS model is created using all node and edge features. RMSE is calculated to measure performance.

Files
* alt_modeling/alt_ols_arima.R

## Graphing

Files
* 

## Modeling

Files
* 
