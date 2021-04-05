# AINET-GNN-Trade-2021
Artificial Intelligence Network Explanation of Trade (AINET)

## Data Preparation
Due to license restrictions, the raw data cannot be shared directly. Rather we provide scripts in order to download and process the data from [UN Comtrade website](https://comtrade.un.org/data/). The node data was comprised of 53 countries across 70 time periods from October 2014 to July 2020. The countries and time period was selected based cross sectional data availability for soybeans. Belarus was excluded from the dataset based on the lack of trading partner information, the model performance increased after its removal.

Files
* data_prep/uncomtrade_data_pull.py
* data_prep/uncomtrade_data_process.py

## Data Statistics

Node data summary of 5,568 observations:

Variable|Trade Value | Net Weight | TUV (lead 1 month) | Edge Connections
----------------|---------------| ---------- | ---------- | --------
Min | 4.6e1 | 5.0e1 | 0.00 | 1
Mean | 6.9e7 | 1.6e8 | 0.62 | 8.2
Median | 4.2e6 | 9.4e6 | 0.50 | 5
Max | 4.4e9 | 1.2e10 | 20.51 | 36

Edge data summary of 40,162 observations:

Variable| Trade Value | Net Weight
----------------|---------------| ----------
Min | 1.0e0 | 5.0e1
Mean | 8.4e6 | 1.9e7
Median | 3.2e4 | 3.7e4
Max | 4.0e9 | 1.2e10


## Alternative Modeling
ARIMA and OLS models are created using the UN comtrade data. Individual ARIMA(0,1,1) models are ran for each country, forecasting soybean trade-unit-value forward 1, 6, and 24 months forward. A preliminary parametric OLS model is created using all node and edge features. RMSE is calculated to measure performance.

ARIMA(0,1,1) models were selected to standardize the model across countries. We began with creating cutomized models for each country, optimizing the predictability for each time series. However, this made interpretation difficult to assess even with increased performance for soybean TUV. ARIMA(0,1,1) models were the most common models across country series and therefore was selected to be the model for all countries to create a model for the entire dataset. The struggle with the ARIMA preparation for a comparative comparison to the GNN was how to incorporate the same variables of interest. Taking the performance average across all the country ARIMA(0,1,1) ultimately had better predictability performance compared to the OLS and GNN. Performance for both ARIMA and OLS were measured by the RMSE of the train and test dataset.

The OLS parametric equation is below. It is a fixed effects regression controlling for time, country, and trading partner information. It also includes interaction terms of trading value and trade weight to account for their relationship with the TUV dependent variable. The final parametric equation was selected after some robust checks. The core equation was comprised of a model showing the relationship between TUV and trade. To improve the model, trade partner information was added to account for top trading partner's and their influence on TUV. This final OLS model that includes time, country, and trading partner information had the best performance and also better predictability compared to the GNN framework for both the train and test dataset.

The RMSE performance for ARIMA and OLS
| Train | OLS      | ARIMA    |   | Test | OLS      | ARIMA    |
|-------|----------|----------|---|------|----------|----------|
| 6     | 0.186964 | 0.149483 |   | 6    | 0.225325 | 0.149483 |
| 12    | 0.181466 | 0.202305 |   | 12   | 0.240856 | 0.250507 |
| 24    | 0.160303 | 0.23752  |   | 24   | 0.259472 | 0.443633 |

Files
* alt_modeling/alt_ols_arima.R

## Graphing
The papers graphics are produced using [ggplot2](https://ggplot2.tidyverse.org/) and [ggraph](https://www.data-imaginist.com/2017/ggraph-introduction-layouts/). The training data from gnn_modeling produces the model epoch graph, the prediction data from gnn_modeling produces the prediction graph, and the processed data from the data_prep script produces the network graphs.

Files
* graphing/model_epoch.Rmd
* graphing/prediction.Rmd
* graphing/networks.Rmd

## GNN Modeling
Both the stateless graph convolutional long short term memory model (S-GC-LSTM) and the graph convolutionl long short term memory model (GC-LSTM) training and prediction are provided in jupyter notebooks. The S-GC-LSTM model is the model selected as the method of choice, and the metrics based on this model are provided in the csvs for the prediction and training performance. Based on standard practice, hyperparameters of learning rate, weight decay, filter size (K), dropout rate, and activation function are tuned using grid search to identify the best performing model.

Files
* gnn_modeling/temporal-gc-lstm.ipynb
* gnn_modeling/temporal-s-gc-lstm.ipynb
* gnn_modeling/model_prediction.csv
* gnn_modeling/model_train_performance.csv
