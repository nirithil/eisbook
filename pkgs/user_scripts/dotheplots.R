graphics.off()
Scenario <- multistaticIntegrationTimes(refPoint         = SKI,
                                        locTrans         = Tloc,
                                        locRec           = Rloc,
                                        locxy            = FALSE,
                                        fwhmTrans        = BeamWTx,
                                        fwhmRec          = BeamWRx,
                                        fwhmRange        = fwhmRange,
                                        x                = xGrid,
                                        y                = yGrid,
                                        heights          = cH,
                                        Pt               = pTrx,
                                        Ne               = ne,
                                        fwhmIonSlab      = fwhmIonSlab,
                                        Tnoise           = Tnoise,
                                        fradar           = f0,
                                        tau0             = tau0,
                                        phArrTrans       = TRUE,
                                        phArrRec         = TRUE,
                                        targetNoiseLevel = target_sigma,
                                        dutyCycle        = dtc,
                                        zlim             = c(-2,3),
                                        zlimv            = c(0,5),
                                        iso.levels       = IsoLevels,
                                        vel.levels       = VecLevels,
                                        printInfo        = TRUE,
                                        plotResolution   = FALSE,
                                        verbose          = FALSE,
                                        mineleTrans      = 90-maxangT,
                                        mineleRec        = 90-maxangR)
for(j in cH)
{
	dev.set()
	filename=paste(scname,j,"iso",sep="_")
	text(x=0.5,y=0.0,filename)
	savepdf(dev.cur(),paste(outputdir,filename,".pdf",sep=""))
	dev.set()
	filename=paste(scname,j,"vel",sep="_")
	text(x=0.5,y=0.0,filename)
	savepdf(dev.cur(),paste(outputdir,filename,".pdf",sep=""))
}
