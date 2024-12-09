# Microsoft Edge Elevation Service (MicrosoftEdgeElevationService)
sc.exe config "MicrosoftEdgeElevationService" start=disabled
# Microsoft Edge update services
sc.exe config "edgeupdate" start=disabled
sc.exe config "edgeupdatem" start=disabled
