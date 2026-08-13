#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Status', 'Disable', 'Restore')]
    [string]$Action = 'Status',

    [string]$AdapterName,

    [string]$ServiceName = 'RvControlSvc',

    [string]$StatePath = (Join-Path $PSScriptRoot '.radmin-vpn-fix-state.json'),

    [switch]$RemoveDefaultRoutes
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-RadminAdapter {
    param([string]$RequestedName)

    if ($RequestedName) {
        return Get-NetAdapter -Name $RequestedName -ErrorAction Stop
    }

    $matches = @(Get-NetAdapter -IncludeHidden -ErrorAction Stop | Where-Object {
        $_.Name -match 'Radmin' -or $_.InterfaceDescription -match 'Radmin'
    })

    if ($matches.Count -eq 0) {
        throw 'No Radmin VPN adapter was found. Use -AdapterName with the exact adapter name.'
    }
    if ($matches.Count -gt 1) {
        $names = ($matches | ForEach-Object Name) -join ', '
        throw "Multiple Radmin adapters were found ($names). Use -AdapterName to select one."
    }
    return $matches[0]
}

function Get-ServiceDetails {
    param([string]$Name)

    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        return $null
    }

    $startMode = $null
    if ($service.PSObject.Properties.Name -contains 'StartType') {
        $startMode = switch ([string]$service.StartType) {
            'Automatic' { 'Auto' }
            'Manual'    { 'Manual' }
            'Disabled'  { 'Disabled' }
            default     { [string]$service.StartType }
        }
    }
    else {
        try {
            $escapedName = $Name.Replace("'", "''")
            $startMode = [string](Get-CimInstance -ClassName Win32_Service -Filter "Name='$escapedName'").StartMode
        }
        catch {
            Write-Warning "Could not read the startup type for service '$Name': $($_.Exception.Message)"
            $startMode = 'Unknown'
        }
    }

    [pscustomobject]@{
        Name      = $service.Name
        Status    = [string]$service.Status
        StartMode = $startMode
    }
}

function Get-RadminDefaultRoutes {
    param([uint32]$InterfaceIndex)

    return @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -InterfaceIndex $InterfaceIndex -ErrorAction SilentlyContinue)
}

function Show-Status {
    $service = Get-ServiceDetails -Name $ServiceName
    if ($service) {
        $service | Format-List Name, Status, StartMode
    }
    else {
        Write-Warning "Service '$ServiceName' was not found."
    }

    try {
        $adapter = Get-RadminAdapter -RequestedName $AdapterName
    }
    catch {
        Write-Warning $_.Exception.Message
        return
    }

    $adapter | Select-Object Name, InterfaceDescription, ifIndex, Status, MacAddress, LinkSpeed | Format-List
    $routes = @(Get-RadminDefaultRoutes -InterfaceIndex $adapter.ifIndex)
    if ($routes.Count -eq 0) {
        Write-Host 'No IPv4 default routes are assigned to this adapter.'
    }
    else {
        $routes | Select-Object DestinationPrefix, NextHop, RouteMetric, InterfaceMetric, PolicyStore | Format-Table -AutoSize
    }
}

function Save-State {
    param($State)

    $parent = Split-Path -Parent $StatePath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $State | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Disable-Radmin {
    if (-not (Test-IsAdministrator)) {
        throw 'Administrator privileges are required for Disable. Relaunch PowerShell as Administrator.'
    }
    if (Test-Path -LiteralPath $StatePath) {
        throw "A saved state already exists at '$StatePath'. Restore it before disabling again."
    }

    $adapter = Get-RadminAdapter -RequestedName $AdapterName
    $service = Get-ServiceDetails -Name $ServiceName
    $routes = @(Get-RadminDefaultRoutes -InterfaceIndex $adapter.ifIndex)
    $savedRoutes = @()

    if ($RemoveDefaultRoutes) {
        $savedRoutes = @($routes | ForEach-Object {
            $policyStore = if ($_.PSObject.Properties.Name -contains 'PolicyStore') {
                [string]$_.PolicyStore
            }
            else {
                $null
            }
            [pscustomobject]@{
                DestinationPrefix = [string]$_.DestinationPrefix
                NextHop           = [string]$_.NextHop
                RouteMetric       = [uint32]$_.RouteMetric
                PolicyStore       = $policyStore
            }
        })
    }

    $state = [pscustomobject]@{
        SchemaVersion       = 1
        SavedAtUtc          = [DateTime]::UtcNow.ToString('o')
        ServiceName         = $ServiceName
        ServiceStatus       = if ($service) { $service.Status } else { $null }
        ServiceStartMode    = if ($service) { $service.StartMode } else { $null }
        AdapterName         = [string]$adapter.Name
        AdapterInterfaceGuid = [string]$adapter.InterfaceGuid
        AdapterAdminStatus  = [string]$adapter.AdminStatus
        RemovedRoutes       = $savedRoutes
    }

    if (-not $PSCmdlet.ShouldProcess("Radmin adapter '$($adapter.Name)'", 'Save state and disable')) {
        return
    }

    Save-State -State $state

    if ($service) {
        if ($service.Status -ne 'Stopped') {
            Stop-Service -Name $ServiceName -Force
        }
        Set-Service -Name $ServiceName -StartupType Manual
    }
    else {
        Write-Warning "Service '$ServiceName' was not found; continuing with the adapter."
    }

    if ($RemoveDefaultRoutes) {
        foreach ($route in $routes) {
            Remove-NetRoute -InputObject $route -Confirm:$false
        }
    }

    Disable-NetAdapter -Name $adapter.Name -Confirm:$false
    Write-Host "Radmin VPN is disabled. Saved state: $StatePath"
}

function Convert-StartMode {
    param([string]$StartMode)

    switch ($StartMode) {
        'Auto'     { return 'Automatic' }
        'Manual'   { return 'Manual' }
        'Disabled' { return 'Disabled' }
        default    { throw "Unsupported saved service start mode '$StartMode'." }
    }
}

function Restore-Radmin {
    if (-not (Test-IsAdministrator)) {
        throw 'Administrator privileges are required for Restore. Relaunch PowerShell as Administrator.'
    }
    if (-not (Test-Path -LiteralPath $StatePath)) {
        throw "No saved state was found at '$StatePath'."
    }

    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.SchemaVersion -ne 1) {
        throw "Unsupported state schema version '$($state.SchemaVersion)'."
    }

    $adapter = Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue |
        Where-Object { [string]$_.InterfaceGuid -eq [string]$state.AdapterInterfaceGuid } |
        Select-Object -First 1
    if (-not $adapter) {
        $adapter = Get-NetAdapter -Name $state.AdapterName -ErrorAction Stop
    }

    if (-not $PSCmdlet.ShouldProcess("Radmin adapter '$($adapter.Name)'", 'Restore saved state')) {
        return
    }

    if ($state.AdapterAdminStatus -eq 'Up') {
        Enable-NetAdapter -Name $adapter.Name -Confirm:$false
    }

    if ($state.ServiceStartMode) {
        $startupType = Convert-StartMode -StartMode $state.ServiceStartMode
        Set-Service -Name $state.ServiceName -StartupType $startupType
        if ($state.ServiceStatus -eq 'Running') {
            Start-Service -Name $state.ServiceName
        }
    }

    foreach ($route in @($state.RemovedRoutes)) {
        $existing = Get-NetRoute -AddressFamily IPv4 -InterfaceIndex $adapter.ifIndex -DestinationPrefix $route.DestinationPrefix -ErrorAction SilentlyContinue |
            Where-Object { $_.NextHop -eq $route.NextHop }
        if (-not $existing) {
            $parameters = @{
                AddressFamily      = 'IPv4'
                InterfaceIndex     = $adapter.ifIndex
                DestinationPrefix  = $route.DestinationPrefix
                NextHop            = $route.NextHop
                RouteMetric        = [uint32]$route.RouteMetric
            }
            if ($route.PolicyStore -and $route.PolicyStore -ne 'ActiveStore') {
                $parameters.PolicyStore = $route.PolicyStore
            }
            New-NetRoute @parameters | Out-Null
        }
    }

    Remove-Item -LiteralPath $StatePath -Force
    Write-Host 'The saved Radmin VPN state has been restored.'
}

switch ($Action) {
    'Status'  { Show-Status }
    'Disable' { Disable-Radmin }
    'Restore' { Restore-Radmin }
}
