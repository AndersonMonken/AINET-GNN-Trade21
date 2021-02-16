#-------- AINET: ARIMA -------------------#
#----- submission for FLAIRS 2021 --------#
#----- written by: Flora Haberkorn -------#

#rm(list=ls()) #clear workspace

#Set Working Directory
#setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

library(zoo)
library(xts)
library(ggplot2)
library(tidyverse)
library(parallel)
library(Hmisc)
library(lme4)
library(svMisc)
library(pbmcapply)
library(forecast) #arima
library(urca) #arima, diff stuff
library(e1071) #skewness
library(TSA) #keenan

#rt: reporter, importer, the perspective we are looking at
#pt: partner, exporter
#check that it is 53 countries with 70 entries/periods
#70 time periods 201410 to 202007
#node data all countries, edged only top 10 countries

#functions for analysis
'%!in%' <- function(x,y)!('%in%'(x,y))
RMSE = function(m, o){
  sqrt(mean((m - o)^2))
}

Mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

#----------------------------------------------------#
#------------------ data load -----------------------#
#----------------------------------------------------#


node_data = read.csv("full_node_data.csv", stringsAsFactors = F) #soybeanprice
edge_data = read.csv("full_edge_data.csv", stringsAsFactors = F) #info from unconmtrade

node_data = node_data %>%
  filter(between(date,  as.Date("2014-10-01"), as.Date("2020-07-01")))

edge_data = edge_data %>%
  filter(between(date,  as.Date("2014-10-01"), as.Date("2020-07-01")))


#----------------------------------------------------------------#
#------------------ data top trade with edges -------------------#
#----------------------------------------------------------------#

node_edge_trade = node_data %>%
  select(-c(matches('Leaf|yr|aggr|Code|X|soybeanPricePerkg'))) %>%#removing messed up cols
  left_join(edge_data, by = c('rtTitle','period','date')) 


#fix merge so that each row is 1 period per importer
top_trade = node_edge_trade %>% 
  group_by(rtTitle, period) %>% 
  arrange(desc(TradeValue.y)) %>% 
  slice(1:10) %>% #max 7 trading partners
  mutate(trade_no = row_number()) %>%
  pivot_wider(names_prefix = 'trade',
              names_from = 'trade_no',
              values_from = c('ptTitle','TradeValue.y','NetWeight.y')) %>%
  summarise_all(funs(unique(.[!is.na(.)])[1])) %>%
  mutate(period = as.factor(period)) %>% ungroup() %>%
  select(c(matches('trade|title|period$|weight|date|soy'))) %>%
  select(-c(matches('ptTitle'))) #excluding this to minimize iterations


# fixing colnames a little bit
names(top_trade) = gsub(x = names(top_trade), pattern = "\\.x|\\.y", replacement = "") 
#replaceing all NA with 0
top_trade[is.na(top_trade)] <- 0
print('top_trade ready')

#----------------------------------------------------------------#
#------------------ regression loops ----------------------------#
#----------------------------------------------------------------#

#collecting interested columns
col_covs = top_trade %>%
  select(c(matches('trade|title|period$|weight'))) %>% 
  colnames(.)


inter_covs = c('TradeValue:NetWeight',
  "TradeValue_trade1:NetWeight_trade1",
  "TradeValue_trade2:NetWeight_trade2",
  "TradeValue_trade3:NetWeight_trade3",
  "TradeValue_trade4:NetWeight_trade4",
  "TradeValue_trade5:NetWeight_trade5",
  "TradeValue_trade6:NetWeight_trade6",
  "TradeValue_trade7:NetWeight_trade7",
  "TradeValue_trade8:NetWeight_trade8",
  "TradeValue_trade9:NetWeight_trade9",
  "TradeValue_trade10:NetWeight_trade10"

)
col_covs = c(col_covs, inter_covs)

#--------------------------------- OLS regression and prediction -----------------------#
#create_lm(mtcars, "mpg", c("wt", "cyl"))
create_lm = function(train, test, dep, indep){
  #dependent variable
  form_base = paste(dep, "~")
  #string concat indep vector with a "+"
  form_vars = paste(indep, collapse = " + ")
  #two parts together
  formula = paste(form_base, form_vars)
  
  fit = lm(formula, data = train)
  #RMSE
  rmse_train =sqrt(mean(fit$residuals^2))
  info_ls = list(rmse_train, fit)
  return(info_ls)
}



# model for regs
reg_list = col_covs


# loop for time periods
res_ols = vector('list', length(reg_list))
print('starting ols')
for (lag_gnn in c(0,5,11,23)) {
  print(paste0('ols split ',lag_gnn+1))
  
  z = as.vector(unlist(reg_list))
  covars =  paste(z, collapse = ' + ')
  
  # splitting train data, -1, -6, -24
  train_df = top_trade %>% group_by(rtTitle) %>% 
    filter(as.Date(date, '%Y-%m-%d') < max(as.Date(date, '%Y-%m-%d')) - months(lag_gnn)) %>% ungroup()
  # #splitting testing data, factor levels matching reg for prediction
  test_df = top_trade %>% group_by(rtTitle) %>% 
    filter(as.Date(date, '%Y-%m-%d') %!in% as.Date(train_df$date, '%Y-%m-%d')) %>%
    ungroup() %>%
    mutate(period = droplevels(period))
  
  #regression
  results = create_lm(train = train_df,
                      test = test_df, #using fixed node-edge data
                      "L1_soybean", #soybean price still the same
                      as.vector(z))
  fit = results[[2]] #regression info
  
  #level reset for predict function, not generalized (specific column reset)
  for(vars in z){
    if (!is.null(fit$xlevels$period)) {{
      levels(test_df$period) = fit$xlevels$period
      #print('period factored')}
    } 
    }}
  
  p = predict(fit,test_df)
  rmse_test = RMSE(p,test_df$L1_soybean)
  
  rmse = list(results[[1]],rmse_test)
  
  #making dataframe to collect rmse (train and test)
  res_ols = data.frame(vars = covars,
                      ols_rmse_train = rmse[[1]][[1]],
                      ols_rmse_test = rmse[[2]][[1]])
  

  print(paste0('ols split ',lag_gnn+1,' done!'))
  
  
  colnames(res_ols) = c('full_model','rmse_train','rmse_test')
  
  print(paste0('dataframe done!',lag_gnn+1))
  assign(paste0('ols_',lag_gnn+1),res_ols)
  #print('data saved!')
}
print('Done!')

#exploing results
one = ols_1 %>% arrange(desc(rmse_train)) %>% 
  select(rmse_train,rmse_test) %>% tail(.,1)
six = ols_6 %>% arrange(desc(rmse_train)) %>% 
  select(rmse_train,rmse_test) %>% tail(.,1)
twelve = ols_12 %>% arrange(desc(rmse_train)) %>%
  select(rmse_train,rmse_test) %>% tail(.,1)
twentyfour = ols_24 %>% arrange(desc(rmse_train)) %>% 
  select(rmse_train,rmse_test) %>% tail(.,1)

one
six
twelve
twentyfour
#--------------------------------- VAR time series regression and prediction -----------------------#

# country split loop for arima
ff = function(w){
   lag_gnn = 23
  #w = 43
  message(paste0('this is w ',w))
soys_train_1 = soys_train_ls[w]

cc_name = as.data.frame(soys_train_1) %>% 
          summarise(first(.)) %>% select(rtTitle) %>%
          first()

soys_train_1 = as.data.frame(soys_train_1) %>% 
               select(c(-rtTitle))

soys_test_1 = soys_test_ls[w]

soys_test_1 = as.data.frame(soys_test_1) %>% 
              select(c(-rtTitle))

soys_train_1_ts = frmtdf(soys_train_1)
soys_test_1_ts = frmtdf(soys_test_1)

#ARIMA selection
fit = Arima(soys_train_1_ts, order=c(1,1,1))
  #auto.arima(soys_train_1_ts, stepwise=FALSE, approximation=FALSE) #more thorough selection
covars =  paste(arimaorder(fit), collapse = '-') # pdq order
#checkresiduals(fit)
rmse_train = sqrt(mean(fit$residuals^2)) #to compare with gnn

# forecast/prediction
p = forecast(fit, h = lag_gnn+1) #specifying how much to forcast forward
rmse_test = RMSE(as.vector(p$mean),as.vector(soys_test_1$L1_soybean))

rmse = list(rmse_train,rmse_test)
res_arima = data.frame(vars = covars,
                       arima_rmse_train = rmse[[1]][[1]],
                       arima_rmse_test = rmse[[2]][[1]],
                       arima_cc = cc_name)

cc_res[[w]] = res_arima

return(cc_res)
}


#------ loop for time periods
res_ols = vector('list', 53)
print('starting arima')
for (lag_gnn in c(0,5,11,23)) {
 
  print(paste0('arima split ',lag_gnn+1))
  
  z = as.vector(unlist(reg_list))
  
  # splitting train data, -1, -6, -24
  train_df = top_trade %>% group_by(rtTitle) %>% 
             filter(as.Date(date, '%Y-%m-%d') < max(as.Date(date, '%Y-%m-%d')) - months(lag_gnn)) %>%
             ungroup() %>%
             select(c(rtTitle, date, L1_soybean))
  # #splitting testing data, factor levels matching reg for prediction
  test_df = top_trade %>% group_by(rtTitle) %>% 
            filter(as.Date(date, '%Y-%m-%d') %!in% as.Date(train_df$date, '%Y-%m-%d')) %>%
            ungroup() %>%
            select(c(rtTitle, date, L1_soybean))
  
  soys_train_ls = split(train_df, f = train_df$rtTitle)
  names(soys_train_ls) = NULL
  
  soys_test_ls = split(test_df, f = test_df$rtTitle)
  names(soys_test_ls) = NULL
  
  cc_res = vector('list', length(soys_train_ls))
  
  #important part, the actual ARIMA
  res_arima = pbmclapply(seq_along(soys_train_ls), ff, mc.cores = 35)
  
  print(paste0('arima split ',lag_gnn+1,' done!'))
  
  #making dataframe to collect rmse (train and test)
  res_arima = data.frame(matrix(unlist(res_arima), nrow=length(res_arima), byrow=T))
  colnames(res_arima)[1:4] = c('full_model','rmse_train','rmse_test','country')
  res_arima$time_lg = rep(lag_gnn+1, nrow(res_arima))
  
  print(paste0('dataframe done!',lag_gnn+1))
  assign(paste0('arima_',lag_gnn+1),res_arima)
  #print('data saved!')
}
print('Done!')


#exploring results
# one = arima_1 %>% arrange(desc(rmse_train)) %>% tail(.,1)
# six = arima_6 %>% arrange(desc(rmse_train)) %>% tail(.,1)
# twelve = arima_12 %>% arrange(desc(rmse_train)) %>% tail(.,1)
# twentyfour = arima_24 %>% arrange(desc(rmse_train)) %>% tail(.,1)
# 
# one
# six
# twelve
# twentyfour

one = arima_1 %>% mutate(rmse_train = as.numeric(rmse_train),
                         rmse_test = as.numeric(rmse_test)) %>% 
                        select(c(matches('rmse'))) %>% 
                        #group_by(country) %>% 
                        summarise_all(list(mean = mean, median =  median, mode = Mode))

six = arima_6 %>% mutate(rmse_train = as.numeric(rmse_train),
                         rmse_test = as.numeric(rmse_test)) %>% 
                          select(c(matches('rmse'))) %>% 
                          #group_by(country) %>% 
                          summarise_all(list(mean = mean, median =  median, mode = Mode))

twelve = arima_12 %>% mutate(rmse_train = as.numeric(rmse_train),
                         rmse_test = as.numeric(rmse_test)) %>% 
                  select(c(matches('rmse'))) %>% 
                  #group_by(country) %>% 
                  summarise_all(list(mean = mean, median =  median, mode = Mode))

twentyfour = arima_24 %>% mutate(rmse_train = as.numeric(rmse_train),
                                 rmse_test = as.numeric(rmse_test)) %>% 
                select(c(matches('rmse'))) %>% 
                #group_by(country) %>% 
                summarise_all(list(mean = mean, median =  median, mode = Mode))

one
six
twelve
twentyfour
