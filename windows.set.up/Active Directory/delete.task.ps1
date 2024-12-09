Unregister-ScheduledTask -TaskName "AD RMS Rights Policy Template Management (Automated)" -Confirm:$false
Unregister-ScheduledTask -TaskName "AD RMS Rights Policy Template Management (Manual)" -Confirm:$false

# Workplace Join
Unregister-ScheduledTask -TaskName "Automatic-Device-Join" -Confirm:$false
Unregister-ScheduledTask -TaskName "Device-Sync" -Confirm:$false
Unregister-ScheduledTask -TaskName "Recovery-Check" -Confirm:$false
