# Author: Anderson Monken
# Date: 1-18-2021
# Program: Download UNCOMTRADE data

#################
#%% Libraries
###########
import random
import string
import time
import glob
import pandas as pd
import numpy as np
import uncomtrader #https://github.com/cicdw/un_comtrader
from uncomtrader import ComtradeRequest
from uncomtrader import utils

###############
#%% Settings for downloading data
###############

# exclude partner codes that are not useful for project
partner_codes = {k : v for k, v in utils._get_partner_codes().items() if v not in \
                 ['all',0,841,535,74,80,86,581,876,849,850,92, \
                  471,129,136,162,166,838,584,500,574, \
                  886,278,866,720,230,280,582,590,592, \
                  868,717,736,835,810,890,836,260]}
# get list of codes to query data
partner_codes_list = [v for v in partner_codes.values()]
reporting_codes = [v for v in utils._get_reporting_codes().values() \
                   if v not in ['all',0,841]]

# where to save data
save_dir = '~/uncomtrade'

# the commodity code to download
hs_code = 1201 # TOTAL, 120110

# the years of data to download, monthly frequency is being pulled
min_year = 2015
max_year = 2020

###############
#%% Getting time and code fields broken up to satisfy 5 items per pull
###############

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

year_list = [year for year in range(min_year, max_year + 1)]
partner_chunk_list = list(chunks(partner_codes_list,5))

###############
#%% Executing data pull
###############

for partners in partner_chunk_list: # loop through partners 5 at a time
    
    for time_period in year_list: # loop through years one at a time
        
        # prepare the request in url encoded format
        req = ComtradeRequest(freq = "M", time_period = time_period,
                     reporting_area = 'all', partner_area = partners,
                     hs = hs_code, fmt='json')
        
        # make string version of partner list
        partners_str = ','.join([str(x) for x in partners])
        
        # skip entries that have already been created
        # since number of requests per hour is limited, only pull data
        # that we don't have yet
        if len(glob.glob(f'{save_dir}/{time_period}-{hs_code}-{partners_str}*')) > 0:
            print(f'found {time_period}-{hs_code}-{partners_str} already present, skipping...')
            continue
        
        
        # while loop to catch when the site rate limits the pulls
        # wait 10 minutes and then try again
        # free API limits to 100 requests per hour
        error = True
        while error == True:
            try:
                df = req.pull_data()
                error = False
            except OSError as err:
                error = True
                print(err)
                print("Sleeping for 10 minutes")
                time.sleep(600)
        
        # saving the data
        if df.shape == (0,0): # empty data save so we don't pull again
            df.to_pickle(f'{save_dir}/{time_period}-{hs_code}-{partners_str}-EMPTY.pkl')
        else: # save dataset and include random string in case we want to re-download for updates in future
            random_string = ''.join(random.sample(string.ascii_lowercase+string.digits,20))
            df.to_pickle(f'{save_dir}/{time_period}-{hs_code}-{partners_str}-{random_string}.pkl')
        
        # print about progress and sleep so we don't hit the rate limit
        print(f'Done! --- Time period: {time_period}, HS: {hs_code}, Partners: {partners_str}, Shape: {df.shape}')
        time.sleep(30) # if you need data quickly adjust this sleep period down
