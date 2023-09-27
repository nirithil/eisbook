# Script written by Nina to plot out EISCAT data from an EISCAT_*.hdf5 file which was made using GUISDAP

# Load the functions needed
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

from read_esr_eiscat_hdf5_files__2 import *

#%% Load data

# Read in your EISCAT_*.hdf5 file
#file = 'W:\COURSE MTR & DATA StudentsReadOnly\AGF\AGF304_data\test_data\EISCAT\EISCAT_2019-11-20_folke_64@42mb.hdf5'

esr = alt_version(file)

#%% Read in the variance 

var_ne = esr['var_Ne']
var_ti = esr['var_Ti']
var_te = esr['var_Tr']*var_ti
var_vi = esr['var_Vi']


#%%  Plot summary plot
#
#   Note: If pcolorplot gives smeared out data in data gaps, despite using
#         insert_nan in data reading function, use scatter plot instead of
#         pcolormesh.
#
#
plt.close('all')

# Tile times for pcolormesh array-requirements
Time = np.tile(esr['start time'], (np.shape(esr['Ne'])[1],1)).T

# Get Date
date = esr['start time'][0].date()


# Set colorbar limits to ne, te, ti, vi
clims = [1e10, 1e12,0,4000, 0, 3000 ,-800,800]

# Make figure
fig,ax = plt.subplots(5,1,figsize=(12,9), sharex=True, constrained_layout=True)
ax[0].set_title(f'{esr["site"]} {esr["antenna"]} on {date.strftime("%d %B %Y")}', fontsize = 15)

# Plot electron number density
pcm = ax[0].pcolor(Time,esr['h']/1000, esr['Ne'], cmap='plasma',
                        norm=colors.LogNorm(vmin=clims[0], vmax=clims[1]))
fig.colorbar(pcm, ax=ax[0],
             pad=-0.1).set_label(label='Electron \n density [m$^{-3}$]', size=11)
ax[0].set_ylabel('Altitude [km]', fontsize=13)
ax[0].grid('on')
ax[0].xaxis_date()

# Plot electron temperature
pcm = ax[1].pcolormesh(Time,esr['h']/1000,esr['Te'], cmap='plasma',
                        vmin=clims[2], vmax=clims[3])
fig.colorbar(pcm, ax=ax[1],
             pad=-0.1).set_label(label='Electron \n Temperature [K]', size=11)
ax[1].set_ylabel('Altitude [km]', fontsize=13)
ax[1].grid('on')

# Plot ion temperature
pcm = ax[2].pcolormesh(Time,esr['h']/1000,esr['Ti'], cmap='plasma',
                        vmin=clims[4], vmax=clims[5])
fig.colorbar(pcm, ax=ax[2],
             pad=-0.1).set_label(label='Ion \n Temperature [K]', size=11)
ax[2].set_ylabel('Altitude [km]', fontsize=13)
ax[2].grid('on')


# Plot LOS velocity
pcm = ax[3].pcolormesh(Time,esr['h']/1000, esr['Vi'], cmap='plasma',
                        vmin=clims[6], vmax=clims[7])
fig.colorbar(pcm, ax=ax[3],
             pad=-0.1).set_label(label='Ion Drift \n Velocity [ms$^{-1}$]',size=11)
ax[3].set_ylabel('Altitude [km]', fontsize=13)
ax[3].xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
ax[3].grid('on')


# Add System information plot
ax[4].plot(esr['start time'], esr['az'], color='blue', label='Az')

# use below plotting if elevation is a float in the dictionary and not an array 
ax[4].plot(esr['start time'], [esr['el']]*len(esr['start time']), color='orange', label='El')
# if elevation is an array use:
#ax[4].plot(esr['start time'], esr['el'], color='orange', label='El')

ax[4].set_ylabel('Degrees', fontsize=13)
# Create y-limits in plot depending on if az is given in the -180,180 or 0,360 range
if esr['az'].min() < 0:
    ylim = [-180, 180]
else:
    ylim = [0,360]

ax[4].set_ylim(ylim)
ax[4].legend(loc='upper left', ncol=2, frameon=False,
             borderaxespad=0.2, fontsize=12)

# Create additional y-axis on right hand side
ax41 = ax[4].twinx()
ax41.plot(esr['start time'],esr['Pt'], color='black')
ax41.set_ylabel('Power [kW]')
ax41.set_ylim([0,1500])

# Create additional y-axis on right hand side
ax42 = ax[4].twinx()
ax42.spines.right.set_position(("axes", 1.08))
ax42.plot(esr['start time'],esr['Tsys1'], color='red')
ax42.set_ylabel('T$^{sys}$ [K]', color='red')
ax42.tick_params(axis='y', colors='red')
ax42.set_ylim([0,200])

ax[4].grid('on')
ax[4].set_xlabel('Universal Time', fontsize=13)


# Chose which time to plot
start = datetime.datetime.combine(date, datetime.time(0,0,0))
stop = datetime.datetime.combine(date, datetime.time(23,59,59))
ax[4].set_xlim(start, stop)


# Save file at wanted destination
#savename = f'/home/nina/pictures/esr{esr["antenna"]}_summary_{date.strftime("%Y%b%d")}.png'
#plt.savefig(savename, dpi=300)
