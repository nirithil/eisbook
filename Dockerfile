######################################################################################
# Select base Jupyter image (from the jupyter docker-stacks project)
# pushed to server 2023/10/07 before optimalisation experiments
FROM jupyter/base-notebook:latest as eisbase

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root
# COPY pkgs/sources.list /etc/apt/

ENV DEBIAN_FRONTEND="noninteractive" TZ="Etc/UTC"

# Install all OS dependencies for fully functional Server
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
    # Common useful utilities
    curl telnet git wget nano tzdata unzip vim scite \
    ca-certificates \
    # git-over-ssh
    openssh-client \
    # less is needed to run help in R
    # see: https://github.com/jupyter/docker-stacks/issues/1588
    less \
    # nbconvert dependencies
    # https://nbconvert.readthedocs.io/en/latest/install.html#installing-tex
    texlive-xetex texlive-fonts-recommended texlive-plain-generic \
    # Enable clipboard on Linux host systems
    xclip \
    # dependencies needed for guisdap and MATLAB
    bzip2 lbzip2 ffmpeg fonts-freefont-otf \
    gzip ghostscript libimage-exiftool-perl qpdfview \
    gcc libc6-dev libfftw3-3 libgfortran5 \
    dbus-x11 xfce4 xfce4-panel xfce4-session xfce4-settings xorg xvfb \
    firefox xubuntu-icon-theme xscreensaver \
    websockify \
    # octave install
    octave octave-doc gnuplot-qt \
        && apt-get remove --yes gnome-screensaver \
        && apt-get clean \
        && apt-get -y autoremove \
        && rm -rf /var/lib/apt/lists/*

# octave executable 
ARG OCTAVE_EXECUTABLE=/usr/bin/octave

# Install guisdap part 1  
# Install pithia tools online (devided in few layers originaly 7.5GB layer)
RUN cd /tmp && curl -qOJ https://cloud.eiscat.se/s/XGm8jnePJWCwP3A/download && \
    unzip pkg.zip && \
    for i in /tmp/pkg/*deb; do dpkg -i $i && rm $i; done && \
    rm -rf /tmp/pkg*

# # Install pithia tools from local storage
# COPY ./pkg/* /tmp/pkg/
# RUN for i in /tmp/pkg/*deb; do dpkg -i $i && rm $i; done && \
#     rm -rf /tmp/pkg*

# to test updated scripts in anal
# COPY g9/anal/* /opt/guisdap/anal/

# # to test changes in remtg
# COPY ./remtg/datasel.m /opt/remtg/lib/

# Switch back to jovyan to avoid accidental container runs as root
USER ${NB_UID}

#######################################################################################
# Install  the desktop feature, tiger/novnc stuff

FROM eisbase as eisnovnc

USER root

# Install tigervnc to /usr/local
# RUN curl -sSfL 'https://sourceforge.net/projects/tigervnc/files/stable/1.10.1/tigervnc-1.10.1.x86_64.tar.gz/download' \
RUN curl -sSfL 'https://sourceforge.net/projects/tigervnc/files/stable/1.13.1/tigervnc-1.13.1.x86_64.tar.gz/download' \
    | tar -zxf - -C /usr/local --strip=2

# noVNC provides VNC over browser capability
# Set default install location for noVNC
ARG NOVNC_PATH=/opt/noVNC

# Get noVNC
RUN mkdir -p ${NOVNC_PATH} \
    # && curl -sSfL 'https://github.com/novnc/noVNC/archive/v1.2.0.tar.gz' \
    && curl -sSfL 'https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz' \
    | tar -zxf - -C ${NOVNC_PATH} --strip=1 \
    && chown -R ${NB_USER}:users ${NOVNC_PATH}

# JOVYAN is the default user in jupyter/base-notebook.
# JOVYAN is being set to be passwordless. 
# This allows users to easily wake the desktop when it goes to sleep.
RUN passwd $NB_USER -d

# Get websockify
RUN conda install -y websockify=0.11.0

# Set environment variable for python package jupyter-matlab-vnc-proxy
ENV NOVNC_PATH=${NOVNC_PATH}

# Change user to jovyan from root as we do not want any changes to be made as root in the container
USER $NB_USER
WORKDIR /home/${NB_USER}

# Fixes occasional failure to start VNC desktop, which requires a reloading of the webpage to fix.
RUN touch ${HOME}/.Xauthority

# Install integration
RUN python -m pip install jupyter-remote-desktop-proxy jupyter-server-proxy

#######################################################################################
# Install matlab and matlab integration for jupyter

FROM eisnovnc as eismatlab
# Specify release of MATLAB to build. (use lowercase, default is r2023a) Taken from mathworks-ref-arch
# /matlab-integration-for-jupyter matlab/matlabVNC and adjusted
ENV MATLAB_RELEASE=r2023a

# Specify the list of products to install into MATLAB, 
ARG MATLAB_PRODUCT_LIST="MATLAB"

# Default DDUX information
ARG MW_CONTEXT_TAGS=MATLAB_PROXY:JUPYTER:MPM:V1

USER root

## Installing Dependencies for Ubuntu 22.04
# For MATLAB : Get base-dependencies.txt from matlab-deps repository on GitHub
# For mpm : wget, unzip, ca-certificates
# For MATLAB Integration for Jupyter (VNC): xvfb dbus-x11 firefox xfce4 xfce4-panel xfce4-session xfce4-settings xorg xubuntu-icon-theme curl xscreensaver

# List of MATLAB Dependencies for Ubuntu 22.04 and specified MATLAB_RELEASE
ARG MATLAB_DEPS_REQUIREMENTS="ca-certificates libasound2 libc6 libcairo-gobject2 libcairo2 libcap2 \
 libcrypt1 libcups2 libdrm2 libgbm1 libgdk-pixbuf-2.0-0 libgl1 libglib2.0-0 libgstreamer-plugins-base1.0-0 \
 libgstreamer1.0-0 libgtk-3-0 libice6 libnspr4 libnss3 libodbc2 libodbcinst2 libpam0g libpango-1.0-0 \
 libpangocairo-1.0-0 libpangoft2-1.0-0 libsndfile1 libuuid1 libwayland-client0 libxcomposite1 libxcursor1 \
 libxdamage1 libxfixes3 libxft2 libxinerama1 libxrandr2 libxt6 libxtst6 libxxf86vm1 locales locales-all \
 make net-tools procps sudo unzip zlib1g"
ARG MATLAB_DEPS_REQUIREMENTS_FILE_NAME="matlab-deps-${MATLAB_RELEASE}-base-dependencies.txt"

RUN echo ${MATLAB_DEPS_REQUIREMENTS} > ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME} \
    && apt-get update \
    && export isJammy=`cat /etc/lsb-release | grep DISTRIB_RELEASE=22.04 | wc -l` \
    && export needsPy39=`cat ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME} | grep libpython3.9 | wc -l` \
    && if [[ isJammy -eq 1 && needsPy39 -eq 1 ]] ; then apt-get install -y software-properties-common && add-apt-repository ppa:deadsnakes/ppa ; fi \
    && xargs -a ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME} -r apt-get install --no-install-recommends -y \
    && apt-get clean \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/* ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME}

# Run mpm to install MATLAB in the target location and delete the mpm installation afterwards
RUN wget -q https://www.mathworks.com/mpm/glnxa64/mpm && \
    chmod +x mpm && \
    ./mpm install \
    --release=${MATLAB_RELEASE} \
    --destination=/opt/matlab \
    --products ${MATLAB_PRODUCT_LIST} && \
    rm -f mpm /tmp/mathworks_root.log && \
    ln -s /opt/matlab/bin/matlab /usr/local/bin/matlab

# Note on glibc patch - See https://github.com/mathworks/build-glibc-bz-19329-patch
# Installation is skipped on Ubuntu 22.04 (Jammy) as it already contains the glibc fix

# Install patched glibc - See https://github.com/mathworks/build-glibc-bz-19329-patch
# WORKDIR /packages
# RUN export DEBIAN_FRONTEND=noninteractive && \
#     apt-get update && apt-get clean && apt-get -y autoremove && \
#     wget -q https://github.com/mathworks/build-glibc-bz-19329-patch/releases/download/ubuntu-focal/all-packages.tar.gz && \
#     tar -x -f all-packages.tar.gz \
#     --exclude glibc-*.deb \
#     --exclude libc6-dbg*.deb \
#         && apt-get install -y --no-install-recommends --allow-downgrades ./*.deb \
#         && rm -rf /packages
# WORKDIR /

# # Optional: Install MATLAB Engine for Python, if possible. 
# # Note: Failure to install does not stop the build.
# RUN export DEBIAN_FRONTEND=noninteractive && apt-get update \
#     && apt-get install --no-install-recommends -y  python3-distutils \
#     && apt-get clean \
#     && apt-get -y autoremove \
#     && rm -rf /var/lib/apt/lists/* \
#     && cd /opt/matlab/extern/engines/python \
#     && python setup.py install || true

# Change user to jovyan from root as we do not want any changes to be made as root in the container
USER $NB_USER
WORKDIR /home/${NB_USER}

# Install integration
RUN python -m pip install -U pip && \
    python -m pip install octave_kernel matplotlib numpy pandas \
    madrigalWeb jupyterlab_widgets "ipywidgets>=7,<8" plotly \
    jupyter-remote-desktop-proxy jupyter-server-proxy jupyter-matlab-proxy

# Make JupyterLab the default environment
ENV JUPYTER_ENABLE_LAB="yes"

ENV MW_CONTEXT_TAGS=${MW_CONTEXT_TAGS}

######################################################################################
# install julia # adjusted from jupyter docker-stack julia-notebook scripts r
FROM eismatlab as eisjulia

USER ${NB_UID}

# Add setup scripts that may be used by downstream images or inherited images 
COPY pkgs/setup-scripts/ /opt/setup-scripts/

USER root

# Julia dependencies
# install Julia packages in /opt/julia instead of ${HOME}
ENV JULIA_DEPOT_PATH=/opt/julia \
    JULIA_PKGDIR=/opt/julia

# Setup Julia
RUN /opt/setup-scripts/setup-julia.bash

USER ${NB_UID}

# Setup IJulia kernel & other packages
RUN /opt/setup-scripts/setup-julia-packages.bash
######################################################################################
# install R # taken from jupyter-docker stacks r-notebook
FROM eisjulia as eisr

USER ${NB_UID}
# Add R mimetype option to specify how the plot returns from R to the browser
COPY --chown=${NB_UID}:${NB_GID} /pkgs/Rprofile.site /opt/conda/lib/R/etc/

# Add setup scripts that may be used by downstream images or inherited images 
COPY pkgs/R-scripts/ISinstall.r /opt/setup-scripts/
COPY pkgs/R-scripts/ISgeometry_0.5.3_AT.tar.gz /opt/setup-scripts/

USER root

# R pre-requisites
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    fonts-dejavu \
    unixodbc \
    unixodbc-dev \
    r-cran-rodbc \
    gfortran \
    gcc && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

USER ${NB_UID}

# R packages including IRKernel which gets installed globally.
# r-e1071: dependency of the caret R package

# RUN mamba install -yn base -c conda-forge r-base r-tinytex perl
RUN mamba install --yes \
    'r-base' \
    'r-caret' \
    'r-crayon' \
    'r-devtools' \
    'r-e1071' \
    'r-forecast' \
    'r-hexbin' \
    'r-htmltools' \
    'r-htmlwidgets' \
    'r-irkernel' \
    'r-nycflights13' \
    'r-randomforest' \
    'r-rcurl' \
    'r-rmarkdown' \
    'r-rodbc' \
    'r-rsqlite' \
    'r-shiny' \
    'r-tidymodels' \
    'r-tidyverse' \
    'r-maps' \
    'r-mapdata' \
    'unixodbc' && \
    mamba clean --all -f -y

RUN R CMD BATCH /opt/setup-scripts/ISinstall.r && rm ISinstall.r.Rout 

USER root
RUN fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"
USER ${NB_UID}
#######################################################################################
# Install guisdap part 2 + final settings in the notebook to connect everything
FROM eisr as eisbook

USER root

# scripts to read in hdf5 into matlab and python from Lisa
RUN mkdir /opt/guisdap/user_scripts
COPY /pkgs/user_scripts /opt/guisdap/user_scripts

# add remtg to octave path and setup proper graphics_toolkit based on app
COPY pkgs/addto_octaverc /usr/share/octave/site/m/startup
RUN cd /usr/share/octave/site/m/startup && cat addto_octaverc >> octaverc \
    && rm addto_octaverc

# turn off automatic update check in matlab
COPY pkgs/guisdap.m /opt/matlab/toolbox/local/
COPY pkgs/addto_matlabrc /opt/matlab/toolbox/local
RUN cd /opt/matlab/toolbox/local && cat addto_matlabrc >> matlabrc.m \
    && rm addto_matlabrc
# COPY pkgs/gupquit.m /opt/guisdap/anal/

# To setup folders for guisdap and backup container homefolder for comparisement on run
COPY /pkgs/startup.sh /usr/local/bin/start-notebook.d/

# setup shared folder for eiscat server purposes...
RUN mkdir /shared_data && fix-permissions "/shared_data"

# environemental variable Hub is used in guisdap to determine that 
# it is running in notebook to prevent crashes
ENV EISCATSITE="Hub"

# path for guisdap to be added at start to MATLAB, this causes guisdap automatically load together with the matlab environment... why?
ENV MATLABPATH="/home/$NB_USER/gup/mygup:/home/$NB_USER/user_scripts/:/opt/remtg/lib"

## other attempts and experiments

# Switch back to notebook user
USER $NB_USER
WORKDIR /home/${NB_USER}



