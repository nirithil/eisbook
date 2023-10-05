#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Dec 10 15:09:33 2021

@author: nina

Script to plot a general EISCAT summaryplot from hdf5-file

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

#%% Fumctions

def read_esr_data(file, include_nans=True):
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
    # Antenna information from filename. This works for ESR
    antenna = file.split('@')[1].split('m*.hdf5')[0].split('m')[0]
    
    # load data from file
    f = h5py.File(file,'r')
    data = f['Data']['Table Layout'][()]
    parameters=f['Metadata']['Data Parameters'][()]
    meta = f['Metadata']['Experiment Notes'][()]
    
    # Create dataframe for easier handling of the data
    df = pd.DataFrame(data)
        
    # loop over all record numbers in file
    empty_dict = []
    for i in range(max(df['recno'])+1): 
        #print(i)
        tmp = df[df['recno']==i].reset_index(drop=True) 
        
        # Create datetime object
        time = datetime.datetime(tmp['year'][0], tmp['month'][0], tmp['day'][0],
                                 tmp['hour'][0], tmp['min'][0], tmp['sec'][0])
        
        # load other parameters
        kindat = tmp['kindat'][0]
        azm = tmp['azm'][0]
        el = tmp['elm'][0]
        
        rnge = np.array(tmp['range'])
        alts = np.array(tmp['gdalt'])
        ne = np.array(tmp['ne'])
        ti = np.array(tmp['ti'])
        te = np.array(tmp['tr']*ti)
        vi = np.array(tmp['vo'])
        
        dne = np.array(tmp['dne'])
        dti = np.array(tmp['dti'])
        dte = np.array(tmp['dtr']*dti)
        dvi = np.array(tmp['dvo'])
        
        az = np.unique(tmp['azm'])
        el = np.unique(tmp['elm'])
        ptx = np.unique(tmp['power'])
        sys_t = np.unique(tmp['systmp'])
        
        
        tmp_dict = {'time': time, 'alt': alts, 'ne': ne, 'ti': ti, 'te': te, 'vi': vi,
                    'dne': dne, 'dti': dti, 'dte': dte, 'dvi': dvi,
                    'az': az, 'el': el, 'ptx': ptx, 'sys_t': sys_t}
        
        empty_dict.append(tmp_dict)
        
    tmp2 = pd.DataFrame(empty_dict)
    
    # Inlude NaN-values for plotting white space at datagaps
    if include_nans == True:
        tmp2['delta'] = tmp2['time'].diff()
        tmp2['delta'] = tmp2['delta'].shift(-1)
        
        #print(tmp2['delta'])
        
        tmp3 = tmp2[tmp2['delta']>(tmp2['delta'].median())]
        tmp3['time'] = tmp3['time'] + tmp2['delta'].median()
        
        #tmp3[tmp3.columns[1:]] = np.nan
        # Add NaN-arrays of same shape as original item
        for column in tmp3.columns[2:-1]:
            idx = tmp3[column].index
            idx = idx
            for i in idx:
                item = tmp3[column][i]
                item[:] = np.nan
                
        
        tmp2 = pd.concat([tmp2,tmp3]).sort_values(by='time').reset_index(drop=True)
        #del(tmp2['delta'])
        

    
    # Resave in a dict for easier reading/plotting
    data = dict()
    
    data['site'] = ('EISCAT' + meta[3][0].decode("ascii").split("EISCAT")[1]).strip()
    data['antenna'] = antenna+"m"
    data['time'] = list(tmp2['time'])
    data['alt'] = np.vstack(tmp2['alt'])
    data['az'] = np.vstack(tmp2['az'])
    data['el'] = np.vstack(tmp2['el'])
    data['ptx'] = np.vstack(tmp2['ptx'])
    data['sys_t'] = np.vstack(tmp2['sys_t'])
    
    data['ne'] = np.vstack(tmp2['ne'])
    data['te'] = np.vstack(tmp2['te']) 
    data['ti'] = np.vstack(tmp2['ti']) 
    data['vi'] = np.vstack(tmp2['vi']) 
    
    data['dne'] = np.vstack(tmp2['dne'])
    data['dte'] = np.vstack(tmp2['dte']) 
    data['dti'] = np.vstack(tmp2['dti']) 
    data['dvi'] = np.vstack(tmp2['dvi']) 
    
    
    
    
    return data, tmp2



#%% Load data


#file = '/home/nina/Downloads/MAD6400_2004-11-07_steffe_111@42m.hdf5'

file = '/home/nina/Downloads/MAD6400_2021-03-10_ipy_ant@32m.hdf5'


esr, tmp = read_esr_data(file, include_nans=True)


#%% Remove data with large errors

lim = esr['dne'] > 0.5 * esr['ne']
    
ne = esr['ne'].copy()
te = esr['te'].copy()
ti = esr['te'].copy()
vi = esr['vi'].copy()

ne[lim] = np.nan
te[lim] = np.nan
ti[lim] = np.nan
vi[lim] = np.nan

# Note: if you want to plot the raw parameters change
#       ne, te, ti, vi to esr['ne'], esr['te'], etc..
#       in below figure

#%%  Plot summary plot
plt.close('all')

# Tile times for pcolormesh array-requirements
Time = np.tile(esr['time'], (np.shape(esr['ne'])[1],1)).T

# Get Date
date = esr['time'][0].date()


# Set colorbar limits to ne, te, ti, vi
clims = [1e10, 1e12,0,4000, 0, 3000 ,-800,800]

# Make figure
fig,ax = plt.subplots(5,1,figsize=(12,9), sharex=True, constrained_layout=True)
ax[0].set_title(f'{esr["site"]} {esr["antenna"]} on {date.strftime("%d %B %Y")}', fontsize = 15)

# Plot electron number density
pcm = ax[0].pcolormesh(Time,esr['alt'],ne, cmap='plasma',
                        norm=colors.LogNorm(vmin=clims[0], vmax=clims[1]))
fig.colorbar(pcm, ax=ax[0],
             pad=-0.1).set_label(label='Electron \n density [m$^{-3}$]', size=11)
ax[0].set_ylabel('Altitude [km]', fontsize=13)
ax[0].grid('on')
ax[0].xaxis_date()

# Plot electron temperature
pcm = ax[1].pcolormesh(Time,esr['alt'],te, cmap='plasma',
                        vmin=clims[2], vmax=clims[3])
fig.colorbar(pcm, ax=ax[1],
             pad=-0.1).set_label(label='Electron \n Temperature [K]', size=11)
ax[1].set_ylabel('Altitude [km]', fontsize=13)
ax[1].grid('on')

# Plot ion temperature
pcm = ax[2].pcolormesh(Time,esr['alt'],ti, cmap='plasma',
                        vmin=clims[4], vmax=clims[5])
fig.colorbar(pcm, ax=ax[2],
             pad=-0.1).set_label(label='Ion \n Temperature [K]', size=11)
ax[2].set_ylabel('Altitude [km]', fontsize=13)
ax[2].grid('on')


# Plot LOS velocity
pcm = ax[3].pcolormesh(Time,esr['alt'], vi, cmap='plasma',
                        vmin=clims[6], vmax=clims[7])
fig.colorbar(pcm, ax=ax[3],
             pad=-0.1).set_label(label='Ion Drift \n Velocity [ms$^{-1}$]',size=11)
ax[3].set_ylabel('Altitude [km]', fontsize=13)
ax[3].xaxis.set_major_formatter(mdates.DateFormatter('%d %H:%M'))
ax[3].grid('on')


# Add System information plot
ax[4].plot(esr['time'], esr['az'], color='blue', label='Az')
ax[4].plot(esr['time'], esr['el'], color='orange', label='El')
ax[4].set_ylabel('Degrees', fontsize=13)
ax[4].set_ylim([0,360])
ax[4].legend(loc='upper left', ncol=2, frameon=False,
             borderaxespad=0.2, fontsize=12)

# Create additional y-axis on right hand side
ax41 = ax[4].twinx()
ax41.plot(esr['time'],esr['ptx'], color='black')
ax41.set_ylabel('Power [kW]')
ax41.set_ylim([0,1500])

# Create additional y-axis on right hand side
ax42 = ax[4].twinx()
ax42.spines.right.set_position(("axes", 1.08))
ax42.plot(esr['time'],esr['sys_t'], color='red')
ax42.set_ylabel('T$^{sys}$ [K]', color='red')
ax42.tick_params(axis='y', colors='red')
ax42.set_ylim([0,200])

ax[4].grid('on')
ax[4].set_xlabel('Universal Time', fontsize=13)


# Chose which time to plot
#start = datetime.datetime.combine(date, datetime.time(0,0,0))
#stop = datetime.datetime.combine(date, datetime.time(11,0,0))
#ax[4].set_xlim(start, stop)


# Save file at wanted destination
#savename = f'/home/nina/pictures/esr{esr["antenna"]}_summary_{date.strftime("%Y%b%d")}.png'
#plt.savefig(savename, dpi=300)

