# AINET-GNN-Trade-2021
Artificial Intelligence Network Explanation of Trade (AINET)


## Alternative Modeling
ARIMA and OLS models were created using the UN comtrade data. Individual ARIMA(0,1,1) models are ran for each country, forecasting soybean trade-unit-value forward 1, 6, 24 months forward. A preliminary parametric OLS model was created using all node and edge features. RMSE is calculated to measure performance.

Files
* alt_ols_arima.R
