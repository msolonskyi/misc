# Windows Mobile Hotspot Service
sc.exe config "icssvc" start=disabled
# Windows Remote Management (WS-Management)
sc.exe config "WinRM" start=disabled
# Windows Biometric Service
sc.exe config "WbioSrvc" start=disabled
# Retail Demo Service
sc.exe config "RetailDemo" start=disabled
# Radio Management Service
sc.exe config "RmSvc" start=disabled
# Fax
sc.exe config "Fax" start=disabled
# Parental Controls
sc.exe config "WpcMonSvc" start=disabled
# Pen Service
sc.exe config "PenService" start=disabled
# Phone Service
sc.exe config "PhoneSvc" start=disabled
# Remote Desktop Configuration
sc.exe config "SessionEnv" start=disabled
# Remote Desktop Services
sc.exe config "TermService" start=disabled
# Remote Desktop Services UserMode Port Redirector
sc.exe config "UmRdpService" start=disabled
# Remote Registry
sc.exe config "RemoteRegistry" start=disabled
# Smart Card
sc.exe config "SCardSvr" start=disabled
# Smart Card Device Enumeration Service
sc.exe config "ScDeviceEnum" start=disabled
# Smart Card Removal Policy
sc.exe config "SCPolicySvc" start=disabled
# Telephony
sc.exe config "TapiSrv" start=disabled

