# Radmin VPN Fix

A small, double-clickable Windows utility for when Radmin VPN prevents another VPN from connecting or working correctly.

It temporarily stops Radmin VPN, disables its network adapter, and removes the default route it may leave behind. No user-specific folders, installation paths, or fixed interface indexes are used.

## Quick start

1. Download this repository and extract the ZIP.
2. Double-click **`RadminVPNFix.cmd`**.
3. Approve the Windows administrator prompt.
4. Choose **Disable Radmin VPN so another VPN can work**.
5. Try connecting to your other VPN again.

The window stays open afterward so you can read the result.

> Double-click the `.cmd` launcher, not the `.ps1` file. Windows does not reliably run PowerShell scripts directly when they are double-clicked.

## Menu options

### 1. Disable Radmin VPN

Use this when Radmin VPN is interfering with another VPN. It:

- Stops the `RvControlSvc` service.
- Changes its startup type to `Manual`.
- Disables the `Radmin VPN` network adapter.
- Removes the default route through `26.0.0.1`.

### 2. Restore Radmin VPN — optional

You normally do **not** need to use this option. Radmin VPN generally restores or reactivates itself the next time you connect with it.

The manual Restore option is kept as a fallback in case Radmin does not come back automatically. It enables the adapter, changes the service startup type to `Automatic`, and starts the service.

### 3. Check status

Shows whether the Radmin service and network adapter are running and whether its default route is present. It does not change anything.

## Requirements

- Windows 10 or Windows 11
- Radmin VPN installed
- Windows PowerShell 5.1 or PowerShell 7+
- Permission to approve the Windows administrator prompt

## What the utility runs

Disable performs the same commands as the original troubleshooting fix:

```powershell
Stop-Service -Name RvControlSvc -Force
Set-Service -Name RvControlSvc -StartupType Manual
Disable-NetAdapter -Name "Radmin VPN" -Confirm:$false
route delete 0.0.0.0 mask 0.0.0.0 26.0.0.1
```

The optional Restore action runs:

```powershell
Enable-NetAdapter -Name "Radmin VPN"
Set-Service -Name RvControlSvc -StartupType Automatic
Start-Service -Name RvControlSvc
```

## Command-line use

The PowerShell script asks for administrator permission automatically when needed:

```powershell
.\RadminVPNFix.ps1 -Action Disable
.\RadminVPNFix.ps1 -Action Restore
.\RadminVPNFix.ps1 -Action Status
```

If Radmin uses nonstandard names or a different gateway, override the defaults:

```powershell
.\RadminVPNFix.ps1 -Action Disable -AdapterName "My Radmin Adapter" -ServiceName "RvControlSvc" -Gateway "26.0.0.1"
```

## Troubleshooting

- If Windows SmartScreen appears, inspect the downloaded files and choose to run the launcher only if you trust this repository.
- If the administrator prompt is declined, the utility cannot change the service, adapter, or route.
- If another VPN still does not work, reboot Windows after disabling Radmin VPN and try again.
- If Radmin does not reactivate on its next connection, run the launcher and choose **Restore Radmin VPN**.

The [original diagnostic note](docs/original-diagnostic-note.md) is included for context.

## License

Licensed under the [MIT License](LICENSE).
