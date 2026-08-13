#requires -Version 5.1
#requires -RunAsAdministrator

param(
    [ValidateSet('Disable', 'Restore', 'Status')]
    [string]$Action = 'Disable',

    [string]$ServiceName = 'RvControlSvc',

    [string]$AdapterName = 'Radmin VPN',

    [string]$Gateway = '26.0.0.1'
)

$ErrorActionPreference = 'Stop'

switch ($Action) {
    'Disable' {
        Stop-Service -Name $ServiceName -Force
        Set-Service -Name $ServiceName -StartupType Manual
        Disable-NetAdapter -Name $AdapterName -Confirm:$false

        & route.exe delete 0.0.0.0 mask 0.0.0.0 $Gateway | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The route was already absent or could not be removed. Check with: route print 0.0.0.0"
        }

        Write-Host 'Radmin VPN has been disabled.'
    }

    'Restore' {
        Enable-NetAdapter -Name $AdapterName -Confirm:$false
        Set-Service -Name $ServiceName -StartupType Automatic
        Start-Service -Name $ServiceName

        Write-Host 'Radmin VPN has been restored.'
    }

    'Status' {
        Get-Service -Name $ServiceName |
            Select-Object Name, Status, StartType |
            Format-List

        $adapter = Get-NetAdapter -Name $AdapterName
        $adapter |
            Select-Object Name, InterfaceDescription, ifIndex, Status, LinkSpeed |
            Format-List

        $routes = @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue)
        if ($routes.Count -eq 0) {
            Write-Host 'No IPv4 default route is assigned to the Radmin VPN adapter.'
        }
        else {
            $routes |
                Select-Object DestinationPrefix, NextHop, RouteMetric, InterfaceMetric |
                Format-Table -AutoSize
        }
    }
}
