# Radmin VPN Fix

A small, reversible PowerShell utility for diagnosing and temporarily disabling Radmin VPN when its service, virtual adapter, or default route interferes with another VPN.

The project grew out of a local troubleshooting note. The utility does not depend on any user profile, drive letter, installation directory, or laptop-specific path.

## What it does

- Reports the state of the `RvControlSvc` service and matching Radmin VPN adapter.
- Shows IPv4 default routes assigned to that adapter.
- Temporarily sets the service to `Manual`, stops it, and disables the adapter.
- Saves the previous service and adapter state beside the script so it can be restored.
- Optionally removes only default routes tied to the detected Radmin interface. Removed routes are saved and recreated on restore.

It does **not** uninstall Radmin VPN, edit application files, or delete unrelated routes.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7+
- Administrator privileges for `Disable` and `Restore`
- The built-in `NetAdapter`, `NetTCPIP`, and `CimCmdlets` modules

## Usage

Open PowerShell in this folder. Status checks can normally run without elevation:

```powershell
.\RadminVPNFix.ps1 -Action Status
```

To temporarily disable Radmin VPN, open PowerShell **as Administrator**:

```powershell
.\RadminVPNFix.ps1 -Action Disable
```

If a Radmin-owned default route remains a problem, use the opt-in route cleanup. The script limits removal to the detected Radmin adapter and records each route before changing it:

```powershell
.\RadminVPNFix.ps1 -Action Disable -RemoveDefaultRoutes
```

Restore the saved state later:

```powershell
.\RadminVPNFix.ps1 -Action Restore
```

If the adapter has a nonstandard name, specify it explicitly:

```powershell
.\RadminVPNFix.ps1 -Action Status -AdapterName "My Radmin Adapter"
```

Use `-WhatIf` with a modifying action to preview changes:

```powershell
.\RadminVPNFix.ps1 -Action Disable -RemoveDefaultRoutes -WhatIf
```

## Safety and recovery

The state file, `.radmin-vpn-fix-state.json`, is intentionally ignored by Git because it contains local interface details. Keep it until restoration succeeds. Running `Disable` again does not overwrite an existing state file.

If the script cannot restore a route automatically, reconnecting or reinstalling Radmin VPN will normally recreate its adapter configuration. A Windows reboot is recommended after disabling or restoring if another VPN still sees stale network state.

## Troubleshooting

- **Administrator privileges are required**: relaunch PowerShell using **Run as administrator**.
- **No Radmin VPN adapter was found**: check `Get-NetAdapter` and pass its exact name with `-AdapterName`.
- **Execution policy blocks the script**: use a process-scoped policy without changing the machine-wide setting:

  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

See [docs/original-diagnostic-note.md](docs/original-diagnostic-note.md) for the original troubleshooting context.

## License

MIT. See [LICENSE](LICENSE).
