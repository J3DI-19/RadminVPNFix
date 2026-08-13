# Original diagnostic note

> Captured on July 23, 2026. Historical context only: the commands below came from one machine and are superseded by the portable utility in the repository root.

Radmin is definitely still active:

- `RvControlSvc`: **Running**
- Startup type: **Automatic**
- Radmin adapter: present
- Radmin default route: still present, including a persistent route

I could not stop it because this session lacks administrator privileges (`Access is denied`). Open **PowerShell as Administrator** and run:

```powershell
Stop-Service -Name RvControlSvc -Force
Set-Service -Name RvControlSvc -StartupType Manual
Disable-NetAdapter -Name "Radmin VPN" -Confirm:$false
route delete 0.0.0.0 mask 0.0.0.0 26.0.0.1
```

Then reboot and test Proton with Radmin disabled. Restore Radmin later with:

```powershell
Enable-NetAdapter -Name "Radmin VPN"
Set-Service -Name RvControlSvc -StartupType Automatic
Start-Service -Name RvControlSvc
```

This is the strongest confirmed cause so far. Also update Proton from v4.3.13, since Proton's then-current Windows release notes listed v4.4.1.

One correction: an earlier diagnostic process filter was too broad and may have attempted to stop unrelated processes whose names contained `rv`. No configuration files were changed; reboot Windows to restore normal services.

The repository script packages these same commands behind `Disable`, `Restore`, and `Status` actions while allowing the service name, adapter name, and gateway to be overridden.
