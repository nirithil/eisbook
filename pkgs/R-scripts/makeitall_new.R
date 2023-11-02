# Extremely machine dependent section. I need to learn more about R...
setwd("~/shared_data/R-scripts")

outputdir=paste(getwd(),"output/",sep="/") # Directory for the output files

############

library(ISgeometry)

# Extra site locations
SKI <- c(69.34, 20.31) # Correct coordinates for Skibotn
AND <- c(69.13, 15.87) # More realistic for And�ya
BRF <- c(68.16, 19.77) # Bergfors
INA <- SAY             # "Inari" is the same as old "S�ytsj�rvi"
JOK <- PAR             # "Jokkmokk" is the old "Parivierra"
KAR <- KRS             # Easier to remember


# The coordiates for the actual sites
SKI <-c(69.34,20.31)    # Skibotn
KAR <-c(68.48,22.52)    # Karesuvanto
KAI <-c(68.27,19.45)    # Kaiseniemi 



# Radar parameters
f0      <- 233e6              # Transmitter frequency [Hz]
dtc     <- 0.25               # Duty cycle
Tnoise  <- 200                # Noise temperature [K]
powfull <- 10e6               # Full transmitter power [W]
powlow <- 5e6                 # Example with low transmitter power [W]
powinit <- 3.6e6              # Example with initial transmitter power [W]
bwdthfull <- 1.0              # Beam-width for full array [deg]
bwdthlow <- bwdthfull*sqrt(2) # Beam-width for array with half number of elements [deg]
bwdthbig <- bwdthfull/sqrt(2) # Beam-width for array with double number of elements [deg]
bwdthinit <- bwdthfull/sqrt(3) # Initial beamwidth (transmitter)
fwhmRange <- 0.2              # Length of pulse [km]
maxangT <- 70                 # Maximum angle from zenith for transmitter [deg]
maxangR <- 70                 # Maximum angle from zenith for receiver [deg]

# Plot parameters
xGrid <- seq(-300,300,by=5) # x-coordinates
yGrid <- seq(-300,300,by=5) # y-coordinates
centrepoint <- SKI          # Centre-point of the map

# Contour levels for integration times
IsoLevels <- c(0.001,0.00316,0.01,0.0316,0.1,0.316,1,3.16,10,31.6,100,316,1000,3160,10000)  # Isotropic parameters
VecLevels <- c(0.01,0.0316,0.1,0.316,1,3.16,10,31.6,100,316,1000,3160,10000) # Wind parameters

# The ionosphere
ne_E <- 2e11 # Electron density E-layer [m^(-3)]
fwhmIonSlab_E <- 10    # Thickness of E-layer
tau0_E <- 500 # Correlation time [�s] E-layer (at 233 MHz)
ne_F <- 2e11 # Electron density F-layer [m^(-3)]
fwhmIonSlab_F <- 100   # Thickness of F-layer
tau0_F <- 200 # Correlation time [�s] F-layer (at 233 MHz)

# The target noise level
target_sigma <- 0.05 # Target noise level

#####################################

## Scenario 1 (Skibotn (low power), Bergfors, And�ya)

scname <- c("Final") # Scenario name
Tloc <- list(SKI) # Location of the transmitter
Rloc <- list(SKI,KAR,KAI) # Locations of receivers
BeamWTx <- bwdthinit  # Transmitter beam-width [deg]
BeamWRx <- bwdthfull  # Receiver beam-width [deg]
pTrx <- powinit   # Transmitter power [W]

#cH <- c(90,110)  # Altitudes of interest [km]
#fwhmIonSlab <- fwhmIonSlab_E
#ne <- ne_E
#tau0 <- tau0_E
#source("dotheplots.R")

cH <- c(300)  # Altitudes of interest [km]
fwhmIonSlab <- fwhmIonSlab_F
ne <- ne_F
tau0 <- tau0_F
source("dotheplots.R")

