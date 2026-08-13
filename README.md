# Radmin VPN Fix

A double-clickable Windows utility that runs the commands from the original troubleshooting note when Radmin VPN interferes with another VPN.

It has no user-specific paths, installation paths, or fixed interface indexes.

## Use it

1. Download or clone the repository.
2. Double-click **`RadminVPNFix.cmd`**.
3. Approve the Windows administrator prompt.
4. Choose an option:
   - Disable Radmin VPN so another VPN can work.
   - Restore Radmin VPN.
   - Check its current status.

The window remains open so you can read the result.

> Windows does not reliably execute `.ps1` files when they are double-clicked, so the `.cmd` launcher is provided as the dependable entry point.

## What Disable runs

```powershell
Stop-Service -Name RvControlSvc -Force
Set-Service -Name RvControlSvc -StartupType Manual
Disable-NetAdapter -Name "Radmin VPN" -Confirm:$false
route delete 0.0.0.0 mask 0.0.0.0 26.0.0.1
```

## What Restore runs

```powershell
Enable-NetAdapter -Name "Radmin VPN"
Set-Service -Name RvControlSvc -StartupType Automatic
Start-Service -Name RvControlSvc
```

## Command-line use

The PowerShell script self-elevates when needed:

```powershell
.\RadminVPNFix.ps1 -Action Disable
.\RadminVPNFix.ps1 -Action Restore
.\RadminVPNFix.ps1 -Action Status
```

For a nonstandard installation, override the defaults:

```powershell
.\RadminVPNFix.ps1 -Action Disable -AdapterName "My Radmin Adapter" -ServiceName "RvControlSvc" -Gateway "26.0.0.1"
```

See [docs/original-diagnostic-note.md](docs/original-diagnostic-note.md) for the source note.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7+
- Radmin VPN installed

## License

MIT. See [LICENSE](LICENSE).
