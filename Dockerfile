
#####################################################################################
## Specify release of MATLAB to build. (use lowercase, default is r2021b)
ARG MATLAB_RELEASE=r2023a
## older MATLAB version for Daniel (because of license)
# ARG MATLAB_RELEASE=r2020b 
## Specify the list of products to install into MATLAB, 
ARG MATLAB_PRODUCT_LIST="MATLAB"
## Optional Network License Server information
ARG LICENSE_SERVER
## If LICENSE_SERVER is provided then SHOULD_USE_LICENSE_SERVER will be set to "_use_lm"
ARG SHOULD_USE_LICENSE_SERVER=${LICENSE_SERVER:+"_with_lm"}
##ARG SHOULD_USE_LICENSE_SERVER=${LICENSE_SERVER:+"_use_lm"}
## Default DDUX information
ARG MW_CONTEXT_TAGS=MATLAB_PROXY:JUPYTER:MPM:V1
#####################################################################################
## Base Jupyter image without LICENSE_SERVER
#FROM jupyter/base-notebook AS base_jupyter_image
FROM jupyter/base-notebook AS base_jupyter_image

## Base Jupyter image with LICENSE_SERVER
FROM jupyter/base-notebook AS base_jupyter_image_with_lm
ARG LICENSE_SERVER
# If license server information is available, then use it to set environment variable
#ENV MLM_LICENSE_FILE=${LICENSE_SERVER}
#ENV MLM_LICENSE_FILE=27000@hqserv

# Select base Jupyter image based on whether LICENSE_SERVER is provided
FROM base_jupyter_image${SHOULD_USE_LICENSE_SERVER}
ARG MW_CONTEXT_TAGS
ARG MATLAB_RELEASE
ARG MATLAB_PRODUCT_LIST

#####################################################################################
## Switch to root user
USER root
ENV DEBIAN_FRONTEND="noninteractive" TZ="Etc/UTC"

#####################################################################################
## Installing Dependencies for Ubuntu 20.04
# For MATLAB : Get base-dependencies.txt from matlab-deps repository on GitHub
# For mpm : wget, unzip, ca-certificates
# For MATLAB Integration for Jupyter : xvfb

## List of MATLAB Dependencies for Ubuntu 20.04 and specified MATLAB_RELEASE
ARG MATLAB_DEPS_REQUIREMENTS_FILE="https://raw.githubusercontent.com/mathworks-ref-arch/container-images/main/matlab-deps/${MATLAB_RELEASE}/ubuntu20.04/base-dependencies.txt"
ARG MATLAB_DEPS_REQUIREMENTS_FILE_NAME="matlab-deps-${MATLAB_RELEASE}-base-dependencies.txt"

## Install dependencies
## MATLAB versions older than 22b need libpython3.9 which is only present in the deadsnakes PPA on ubuntu:22.04
RUN wget ${MATLAB_DEPS_REQUIREMENTS_FILE} -O ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME} \
    && apt-get update \
    && export isJammy=`cat /etc/lsb-release | grep DISTRIB_RELEASE=22.04 | wc -l` \
    && export needsPy39=`cat ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME} | grep libpython3.9 | wc -l` \
    && if [[ isJammy -eq 1 && needsPy39 -eq 1 ]] ; then apt-get install -y software-properties-common && add-apt-repository ppa:deadsnakes/ppa ; fi \
    && xargs -a ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME} -r apt-get install --no-install-recommends -y \
    unzip \
    ca-certificates \
    xvfb \
    && apt-get clean \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/* ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME}

## Installing MATLAB Engine for Python
RUN apt-get update \
    && apt-get install --no-install-recommends -y  python3-distutils \
    && apt-get clean \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && cd /opt/matlab/extern/engines/python \
    && python setup.py install || true

## Run mpm to install MATLAB in the target location and delete the mpm installation afterwards
RUN wget -q https://www.mathworks.com/mpm/glnxa64/mpm && \ 
    chmod +x mpm && \
    ./mpm install \
    --release=${MATLAB_RELEASE} \
    --destination=/opt/matlab \
    --products ${MATLAB_PRODUCT_LIST} && \
    rm -f mpm /tmp/mathworks_root.log && \
    ln -s /opt/matlab/bin/matlab /usr/local/bin/matlab
#####################################################################################
## install needed apps
RUN export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get install --no-install-recommends -y \
 nano scite vim wget unzip openssh-client git telnet curl unzip \
 bzip2 lbzip2 octave ffmpeg gnuplot-qt fonts-freefont-otf \
 gzip ghostscript libimage-exiftool-perl qpdfview \
 gcc libc6-dev libfftw3-3 libgfortran5 \
 dbus-x11 xfce4 xfce4-panel xfce4-session xfce4-settings xorg xubuntu-icon-theme \
 websockify \
    && apt-get clean \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/*

#RUN cd /opt/matlab/bin/glnxa64 && rm -f libtiff.so.5 libcurl.so.4
#####################################################################################
## Install pithia tools
RUN cd /tmp && curl -qOJ https://cloud.eiscat.se/s/XGm8jnePJWCwP3A/download && \
    unzip pkg.zip && \
    for i in /tmp/pkg/*deb; do dpkg -i $i && rm $i; done && \
    rm -rf /tmp/pkg*
# COPY pkgs/*.m /opt/matlab/toolbox/local/ (this shouldn't be necessary anymore? not sure about the following lines)
COPY pkgs/mrc /tmp
RUN cd /tmp && cat mrc >> /opt/matlab/toolbox/local/matlabrc.m && rm mrc
COPY pkgs/RTG*.m /usr/share/octave/site/m/

############################################################################
# Update to newer guisdap scripts that do not require compiling 
# What else doesn't require compiling? this should be redone by nextcloud storage like the debian packages
# in the g9 folder there's a git sparse-checkout repository only for 
# 3 folders git pull master origin before running docker build

COPY g9/anal/* /opt/guisdap/anal/
# COPY g9/exps/* /opt/guisdap/exps/
# COPY g9/init/* /opt/guisdap/init/

# scripts to read in hdf5 into matlab and python from Lisa
RUN mkdir /opt/guisdap/Etools
COPY /pkgs/Etools/* /opt/guisdap/Etools
############################################################################

## Julia
ENV JULIA_VERSION=1.9.3
RUN mkdir /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C /opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

#####################################################################################
# Setup for home folder when starting up container
COPY ./startup.sh /usr/local/bin/start-notebook.d
COPY /home/jovyan/* /home/jovyan_new
#####################################################################################
# Switch back to notebook user
USER $NB_USER
WORKDIR /home/${NB_USER}

## Add packages and precompile
RUN julia -e 'import Pkg; Pkg.update()' && \
    julia -e 'import Pkg; Pkg.add("Plots"); using Plots' && \
    julia -e 'import Pkg; Pkg.add("Distributions"); using Distributions' && \
    julia -e 'import Pkg; Pkg.add("Optim"); using Optim' && \  
    julia -e 'import Pkg; Pkg.add("FFTW"); using FFTW' && \  
    julia -e 'import Pkg; Pkg.add("DSP"); using DSP' && \  
    julia -e 'import Pkg; Pkg.add("IJulia"); using IJulia' && \
    julia -e 'import Pkg; Pkg.build("IJulia"); using IJulia' && \
    # julia -e 'import Pkg; Pkg.add("StatsPlots"); using StatsPlots' && \  
    fix-permissions /home/$NB_USER

# Install integration
RUN python -m pip install jupyter-remote-desktop-proxy
RUN python -m pip install jupyter-matlab-proxy
RUN python -m pip install octave_kernel
RUN python -m pip install matplotlib numpy pandas
RUN python -m pip install madrigalWeb
RUN python -m pip install jupyterlab \
 jupyterlab_widgets "ipywidgets>=7,<8"
RUN python -m pip install plotly dash

# what is this variable needed for?
ARG OCTAVE_EXECUTABLE=/usr/bin/octave 

# Make JupyterLab the default environment
ENV JUPYTER_ENABLE_LAB="yes"

ENV MW_CONTEXT_TAGS=${MW_CONTEXT_TAGS}

#####################################################################################
# environemental variable Hub is used in guisdap to determine that 
# it is running in notebook to prevent crashes
ENV EISCATSITE="Hub"
#####################################################################################
# path for guisdap to be added at start to MATLAB, this causes guisdap automatically load together with the matlab environment... why?
ENV MATLABPATH="/home/$NB_USER/gup/mygup:/opt/guisdap/anal:/opt/guisdap/init:/home/$NB_USER/Etools/:/opt/remtg/lib"

#####################################################################################
## other attempts and experiments

##RUN echo "$NB_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$NB_USER \
##    && chmod 0440 /etc/sudoers.d/$NB_USER