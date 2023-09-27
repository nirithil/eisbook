#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Feb  3 14:47:41 2023

@author: nina

Script to plot a general EISCAT summaryplot from EISCAT_*.hdf5-file

"""

import datetime
import numpy as np
import pandas as pd
import matplotlib as mpl
# Set figure style to LaTex style
mpl.rcParams.update({
    'font.family': 'Serif',
    'text.usetex': False,
    'pgf.rcfonts': False})
import matplotlib.pyplot as plt
from matplotlib import colors
import matplotlib.dates as mdates
import h5py
import warnings
warnings.filterwarnings("ignore")
from matplotlib.ticker import MaxNLocator
from numba import jit



#%% Functions
# This is an alternative version for reading eiscat data from hdf5-files
# (from files named EISCAT_*.hdf5 vs MAD_*.hdf5)
# 
#def alt_version(file, include_nans=True):

def alt_version(file, include_nans=True):
    """
    This function reads EISCAT data from a hdf5-file 
    and returns a dictionary with the data

    Parameters
    ----------
    file : str
        File path for the hdf5 file

    include_nans: boolean
        Include NaNs at datagaps to have a non-continious pcolormesh grid
        This adds additional rows into the original data.

    Returns
    -------
    data : Dict
        Dictionary containing selected data from input file

    """    
    
    @jit(nopython = True)
    def reshape(arr, indexarr, m_max = 37):
        n = len(indexarr)
        returnarr = np.empty((n, m_max))
        m, mprev = 0, 0
        for i in range(n):
            m = mprev + int(indexarr[i])
            returnarr[i, :int(indexarr[i])] = arr[mprev:m]
            returnarr[i, int(indexarr[i]):m_max] = np.nan
            mprev = m
        return returnarr
    
    # Load data from file
    f = h5py.File(file)
    utime = f['data']['utime'][()]   
    
    # read in times and convert to datetime from unix timestamps
    start_time = [datetime.datetime(1970,1,1) + datetime.timedelta(seconds=ts) for ts in utime[0,:]]
    end_time = [datetime.datetime(1970,1,1) + datetime.timedelta(seconds=ts) for ts in utime[1,:]]
    
    
    # Read parameters names
    par0d_names = [item[0].decode("ASCII").strip() for item in f['metadata']['par0d'][:]]
    par1d_names = [item[0].decode("ASCII").strip() for item in f['metadata']['par1d'][:]]
    par2d_names = [item[0].decode("ASCII").strip() for item in f['metadata']['par2d'][:]]
    
    # Create dictionary
    data = dict()
    
    # Add start and stop time (Should this really be average time or?)
    data['start time'] = np.array(start_time)
    data['end time'] = np.array(end_time)
    
    # Add radar info
    antenna = file.split('@')[1].split('m*.hdf5')[0].split('m')[0]
    data['antenna'] = antenna
    site = f['metadata']['names'][1][1].decode("ASCII").strip()
    if site == "L":
        site = "EISCAT Svalbard Longyearbyen Radar"
    
    data['site'] = site
    # Add 0d parameters: experiment parameters
    for i, par in enumerate(par0d_names):
        #print(par)
        try:
            data[f'{par}'] = f['data']['par0d'][i][0]
        except ValueError:
            print("No parameter in par0d named that name")
            
            continue
    # Add 1D parameters aka parameters that only vary with time 
    for i, par in enumerate(par1d_names):
        #print(par)
        try:
            data[f'{par}'] = f['data']['par1d'][i]
        except ValueError:
            print("No parameter in par1d named that name")
            
            continue
    # Add 2D parameters aka parameters that are varying with height    
    for i, par in enumerate(par2d_names):
        #print(par)
        try:
            #if f['data']['par2d'][i].all() == 0:
            #    print(f"No value in {par}, skipping this parameters")
            #else:
            
            if type(data['nrec']) == np.ndarray:
                fpardata = np.empty((len(data['start time']),
                                         int(np.max(data['nrec']))))
                # for i in range(f['data']['par2d'].shape[0]):
                #     prevind = 0
                #     for j in range(len(data['nrec'])):
                #         nextind = prevind + int(data['nrec'][j])
                #         fpardata[i, j, :int(data['nrec'][j])] = f['data']['par2d'][i][prevind:nextind] 
                #         fpardata[i, j, int(data['nrec'][j]):37] = np.nan
                #         prevind = nextind
               
                fpardata[:, :] = reshape(f['data']['par2d'][i], 
                                                data['nrec'])
                data[f'{par}'] = fpardata
            else:
                data[f'{par}'] = np.array(f['data']['par2d'][i]).reshape(
                      len(data['start time']), int(data['nrec']))
        except ValueError:
            print("No parameter in par2d named that name")
            
            continue
    
    # add electron temperature from ratio    
    data['Te'] = data['Tr']*data['Ti']
    include_nans = True
    
    # Inlude NaN-values for plotting white space at datagaps
    if include_nans == True:
        tmp = pd.DataFrame()
        tmp['start time'] = data['start time']
        tmp['delta'] = tmp['start time'].diff()
    
        
        
        i = tmp[tmp['delta'] > (1.1*tmp['delta'].median())].index
        
        idx=[]
        for item in i:
            idx.append(item-1)
            idx.append(item)
        
        
        tmp1 = pd.DataFrame(tmp['start time'][idx])
        tmp1['start time'] = tmp1['start time']+1.1*tmp['delta'].median()
    
        #idx = tmp1.index
        tmp = pd.concat([tmp,tmp1]).sort_values(by='start time').reset_index(drop=True)
    
        data['start time'] = np.array([time.to_pydatetime() for time in tmp['start time']])
    
    
        for par in par2d_names:
            if par == 'h':
                test = data[par].copy()
                data[par] = np.insert(test, idx, test[idx], axis=0)
            else: 
                try:
                    test = data[par].copy()
                    data[par] = np.insert(test, idx, np.nan, axis=0)
                except KeyError:
                    continue
        
        for par in par1d_names:
            try:
                test = data[par].copy()
                data[par] = np.insert(test, idx, np.nan, axis=0)
            except KeyError:
                continue
            
        data['Te'] = data['Tr']*data['Ti']
    
    
    return data
    
    
