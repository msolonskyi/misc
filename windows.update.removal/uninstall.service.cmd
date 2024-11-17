rem Windows Update Service
sc.exe delete wuauserv
rem Update Orchestrator Service
sc.exe delete UsoSvc
rem Windows Update Medic Service
rem do not have access to remove it even under admin account
sc.exe delete WaaSMedicSvc
