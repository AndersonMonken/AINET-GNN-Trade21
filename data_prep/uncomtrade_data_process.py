# Author: Anderson Monken
# Date: 2-16-2021
# Program: process UNCOMTRADE data

import os
import pickle
import pandas as pd
import plotly.express as px
import networkx as nx
import matplotlib.pyplot as plt

# collect raw data from pickle files and make into dataframe
save_dir = 'data_prep/raw_data'
list_dfs = [pd.read_pickle(f'{save_dir}/{file_i}') for file_i in os.listdir(save_dir)]
list_dfs = [x for x in list_dfs if x.shape != (0,0)]
df_uncomtrade = pd.concat(list_dfs)

# removing EU composite as individual countries are present
df_uncomtrade = df_uncomtrade[(df_uncomtrade['rtTitle'] != 'EU-28') & (df_uncomtrade['ptTitle'] != 'EU-28')]
# too much missing data here
df_uncomtrade = df_uncomtrade[(~df_uncomtrade['rtTitle'].isin(['Other Asia, nes','Estonia','Hungary','Belarus','Egypt'])) & 
                              (~df_uncomtrade['ptTitle'].isin(['Other Asia, nes','Estonia','Hungary','Belarus','Egypt']))]


# update names of countries
df_uncomtrade = df_uncomtrade.replace('Viet Nam', 'Vietnam')
df_uncomtrade = df_uncomtrade.replace('United Kingdom', 'UK')
df_uncomtrade = df_uncomtrade.replace('United States of America', 'USA')
df_uncomtrade = df_uncomtrade.replace('Russian Federation', 'Russia')
df_uncomtrade = df_uncomtrade.replace('China, Hong Kong SAR', 'Hong Kong')
df_uncomtrade = df_uncomtrade.replace('Rep. of Korea', 'South Korea')
df_uncomtrade = df_uncomtrade.replace('United Arab Emirates', 'UAE')

# remove total commodity code
df_trade_tot = df_uncomtrade[df_uncomtrade['cmdCode'] == "TOTAL"]

# filter to only soybeans (1201) and minimum net weight and trade value
df_uncomtrade = df_uncomtrade[df_uncomtrade['cmdCode'] == 1201]
df_uncomtrade = df_uncomtrade[df_uncomtrade['NetWeight'] >= 50]
df_uncomtrade = df_uncomtrade[df_uncomtrade['TradeValue'] >= 1000]

# no cyclic edges for trade
df_uncomtrade = df_uncomtrade[df_uncomtrade['rtTitle'] != df_uncomtrade['ptTitle']]


# exports and imports have slightly different prices. I'm taking the imported price as that better
# reflects consumer prices in the market (cost of bringing good to the importing country)
# scratch that, due to data availability issues. I will take the average of imports and exports so we have more data
# https://unstats.un.org/unsd/tradekb/Knowledgebase/Trade-valuation
df_uncom_imports = df_uncomtrade[df_uncomtrade['rgDesc'].isin(['Imports'])].reset_index(drop=True)
df_uncom_exports = df_uncomtrade[df_uncomtrade['rgDesc'].isin(['Exports'])].reset_index(drop=True)

# column flipping so that partner info becomes reporter info and vice versa
new_cols = []
for col_i in df_uncom_exports.columns:
    if col_i == 'rtTitle':
        new_cols.append('ptTitle')
    elif col_i == 'ptTitle':
        new_cols.append('rtTitle')
    elif col_i == 'ptCode':
        new_cols.append('rtCode')
    elif col_i == 'rtCode':
        new_cols.append('ptCode')
    else:
        new_cols.append(col_i)
        
df_uncom_exports.columns = new_cols
df_uncom_exports['rgDesc'] = 'Imports'

# averaging import and export values
df_uncomtrade = (pd.concat([df_uncom_exports, df_uncom_imports])
                     .groupby(['rtTitle','rtCode','ptCode','ptTitle','period','periodDesc'])
                     .mean(['TradeValue','NetWeight'])
                     .reset_index()
                 )

# create date variable
df_uncomtrade['date'] = pd.to_datetime(df_uncomtrade['periodDesc'])

# create country dataset for tracking data availability
df_countries = df_uncomtrade.groupby('rtTitle').sum(['TradeValue','NetWeight']).reset_index()
df_countries.TradeValue.describe()
df_countries = df_countries[df_countries['TradeValue'] >= 70000]

# filter edges to only countries that will have nodes
df_uncomtrade = df_uncomtrade[(df_uncomtrade['rtTitle'].isin(df_countries['rtTitle'])) & 
                              df_uncomtrade['ptTitle'].isin(df_countries['rtTitle'])]

# create node dataset
df_nodes = df_uncomtrade.groupby(['period','date','rtCode','rtTitle']).sum(['TradeValue','NetWeight']).reset_index()
df_nodes['soybeanPricePerkg'] = df_nodes['TradeValue'] / df_nodes['NetWeight']
df_nodes['soybeanPricePerkg'].describe()
temp = df_nodes.set_index('date')[['rtTitle','soybeanPricePerkg']]
temp['rtTitle2'] = temp['rtTitle']
# make the lead term for forecasting
test = temp.groupby('rtTitle2').shift(periods=-1).reset_index().rename(columns = {'soybeanPricePerkg' : 'L1_soybean'})
df_nodes = df_nodes.merge(test, on = ['date','rtTitle'])

# get a list of all the potential periods
# we know to restrict some months from trial and error
period_list = sorted(list(df_nodes.period.unique()))[33:-3]

# set up dictionary to count data availability
country_dict = {k : 0 for k in df_nodes.rtTitle.unique()}

# find out how many time periods countries are in
for period in period_list:
    df_period_edges = df_uncomtrade[df_uncomtrade['period'] == period]
    df_period_nodes = df_nodes[df_nodes['period'] == period]
    for k in df_period_nodes.rtTitle.unique():
        country_dict[k] += 1
    print(period,df_period_nodes.shape)

# keep countries with 70 entries
cutoff = 70

# restrict dataset to only include those countries with 70 entries
keep_countries = sorted([k for k,v in country_dict.items() if v >= cutoff])
df_uncomtrade = (df_uncomtrade[(df_uncomtrade['rtTitle'].isin(keep_countries)) & 
                               (df_uncomtrade['ptTitle'].isin(keep_countries))])
df_nodes = df_nodes[df_nodes['rtTitle'].isin(keep_countries)]
df_nodes = df_nodes[df_nodes['period'].isin(period_list)]


df_uncomtrade.to_csv('alt_modeling/full_edge_data.csv')
df_nodes.to_csv('alt_modeling/full_node_data.csv')

def make_graph_data(period_list, edge_dataset, node_dataset, num_edges, country_list = None):
    """ Make graph dataset for GNN modeling. """

    def make_one_period(period, edge_dataset, node_dataset, country_dict = None):
        df_period_edges = edge_dataset[edge_dataset['period'] == period].reset_index(drop = True)
        
        date = df_period_edges['date'][0]
        
        # make edge dataset for single time period
        df_period_edges = (df_period_edges
                               .groupby(['rtTitle'])
                               .apply(lambda x: x.nlargest(num_edges, ['TradeValue']))
                               .reset_index(drop = True)
                           )
        # make node dataset for single time period
        df_period_nodes = (node_dataset[node_dataset['period'] == period]
                                                .sort_values('rtTitle')
                                                .reset_index(drop = True)
                                                )
        

        if country_list is None:
            country_dict = df_period_nodes['rtTitle'].to_dict()

        countryRdict = {v:k for k,v in country_dict.items()}

        df_period_nodes = (pd.Series(country_dict)
                                    .reset_index()
                                    .rename(columns = {0 : 'rtTitle'})
                                    .merge(df_period_nodes, how = 'right')
                                    .set_index('index')
                            )
        # make node info
        node_dict = df_period_nodes[['NetWeight','soybeanPricePerkg','L1_soybean']].to_dict(orient='index')
        
        # make edge info
        directed_edges = []
        for i, row_i in df_period_edges.iterrows():
            im_country = countryRdict[row_i['rtTitle']]
            ex_country = countryRdict[row_i['ptTitle']]
            trade_val = row_i['TradeValue']
            directed_edges.append((ex_country, im_country, trade_val))
        
        return {'period' : period, 
                'date' : date, 
                'nodes' : node_dict, 
                'country_dict' : country_dict, 
                'edges' : directed_edges,
                'node_df' : df_period_nodes,
                'edge_df' : df_period_edges}

    if country_list is not None:
        country_dict = {i : x for i, x in enumerate(sorted(country_list))}
    
    dict_data = {}
    for i, period in enumerate(period_list):
        dict_data[i] = make_one_period(period, edge_dataset, node_dataset, country_dict)
            
    return dict_data

# execute function, creating graph dataset
# only keep top 10 trading partners
graph_data = make_graph_data(period_list, df_uncomtrade, df_nodes, 10, keep_countries)

# save results for graphing and modeling
pickle.dump(graph_data, open(f'gnn_modeling/graph_data.pkl', 'wb'))
pickle.dump(graph_data, open(f'graphing/graph_data.pkl', 'wb'))
