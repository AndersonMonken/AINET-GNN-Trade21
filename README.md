# AINET-GNN-Trade-2021
Artificial Intelligence Network Explanation of Trade (AINET)

## Data Preparation
Due to license restrictions, the raw data cannot be shared directly. Rather we provide scripts in order to download and process the data from [UN Comtrade website](https://comtrade.un.org/data/).

Files
* data_prep/uncomtrade_data_pull.py
* data_prep/uncomtrade_data_process.py

## Alternative Modeling
ARIMA and OLS models are created using the UN comtrade data. Individual ARIMA(0,1,1) models are ran for each country, forecasting soybean trade-unit-value forward 1, 6, and 24 months forward. A preliminary parametric OLS model is created using all node and edge features. RMSE is calculated to measure performance.

Files
* alt_modeling/alt_ols_arima.R

## Graphing
The papers graphics are produced using [ggplot2](https://ggplot2.tidyverse.org/) and [ggraph](https://www.data-imaginist.com/2017/ggraph-introduction-layouts/). The training data from gnn_modeling produces the model epoch graph, the prediction data from gnn_modeling produces the prediction graph, and the processed data from the data_prep script produces the network graphs.

Files
* graphing/model_epoch.Rmd
* graphing/prediction.Rmd
* graphing/networks.Rmd

## GNN Modeling
Both the stateless graph convolutional long short term memory model (S-GC-LSTM) and the graph convolutionl long short term memory model (GC-LSTM) training and prediction are provided in the jupyter notebooks. The S-GC-LSTM model is the model selected as the method of choice, and the metrics based on this model are provided in the csvs for the prediction and training performance.

Files
* gnn_modeling/temporal-gc-lstm.ipynb
* gnn_modeling/temporal-s-gc-lstm.ipynb
* gnn_modeling/model_prediction.csv
* gnn_modeling/model_train_performance.csv
