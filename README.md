# Radmin VPN Fix

A small PowerShell script that runs the commands from the original troubleshooting note when Radmin VPN interferes with another VPN.

It has no user-specific paths, installation paths, or fixed interface indexes.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7+
- PowerShell opened with **Run as administrator**
- Radmin VPN installed with its standard service and adapter names

## Disable Radmin VPN

Open an elevated PowerShell in this folder and run:

```powershell
.\RadminVPNFix.ps1
```

That performs the equivalent of:

```powershell
Stop-Service -Name RvControlSvc -Force
Set-Service -Name RvControlSvc -StartupType Manual
Disable-NetAdapter -Name "Radmin VPN" -Confirm:$false
route delete 0.0.0.0 mask 0.0.0.0 26.0.0.1
```

## Restore Radmin VPN

```powershell
.\RadminVPNFix.ps1 -Action Restore
```

That performs the equivalent of:

```powershell
Enable-NetAdapter -Name "Radmin VPN"
Set-Service -Name RvControlSvc -StartupType Automatic
Start-Service -Name RvControlSvc
```

## Check status

```powershell
.\RadminVPNFix.ps1 -Action Status
```

For a nonstandard installation, override the defaults:

```powershell
.\RadminVPNFix.ps1 -AdapterName "My Radmin Adapter" -ServiceName "RvControlSvc" -Gateway "26.0.0.1"
```

See [docs/original-diagnostic-note.md](docs/original-diagnostic-note.md) for the source note.

## License

MIT. See [LICENSE](LICENSE).
