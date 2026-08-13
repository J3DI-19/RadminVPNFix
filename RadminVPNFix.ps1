#requires -Version 5.1

param(
    [ValidateSet('Prompt', 'Disable', 'Restore', 'Status')]
    [string]$Action = 'Prompt',

    [string]$ServiceName = 'RvControlSvc',

    [string]$AdapterName = 'Radmin VPN',

    [string]$Gateway = '26.0.0.1'
)

$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"' + $PSCommandPath + '"')
        '-Action', $Action
        '-ServiceName', ('"' + $ServiceName + '"')
        '-AdapterName', ('"' + $AdapterName + '"')
        '-Gateway', $Gateway
    )

    try {
        $process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments -Wait -PassThru
        exit $process.ExitCode
    }
    catch {
        Write-Host 'Administrator permission was not granted.' -ForegroundColor Red
        exit 1
    }
}

$interactive = $Action -eq 'Prompt'

if ($interactive) {
    Clear-Host
    Write-Host 'Radmin VPN Fix' -ForegroundColor Cyan
    Write-Host
    Write-Host '1. Disable Radmin VPN so another VPN can work'
    Write-Host '2. Restore Radmin VPN'
    Write-Host '3. Check Radmin VPN status'
    Write-Host 'Q. Quit'
    Write-Host

    switch ((Read-Host 'What do you want to do?').Trim().ToUpperInvariant()) {
        '1' { $Action = 'Disable' }
        '2' { $Action = 'Restore' }
        '3' { $Action = 'Status' }
        'Q' { exit 0 }
        default {
            Write-Host 'Invalid selection. Nothing was changed.' -ForegroundColor Yellow
            Read-Host 'Press Enter to close'
            exit 1
        }
    }

    Write-Host
}

try {
    switch ($Action) {
        'Disable' {
            Stop-Service -Name $ServiceName -Force
            Set-Service -Name $ServiceName -StartupType Manual
            Disable-NetAdapter -Name $AdapterName -Confirm:$false

            & route.exe delete 0.0.0.0 mask 0.0.0.0 $Gateway | Out-Host
            Write-Host
            Write-Host 'Radmin VPN has been disabled.' -ForegroundColor Green
        }

        'Restore' {
            Enable-NetAdapter -Name $AdapterName -Confirm:$false
            Set-Service -Name $ServiceName -StartupType Automatic
            Start-Service -Name $ServiceName

            Write-Host 'Radmin VPN has been restored.' -ForegroundColor Green
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
}
catch {
    Write-Host "Operation failed: $($_.Exception.Message)" -ForegroundColor Red
    $exitCode = 1
}

if ($interactive) {
    Write-Host
    Read-Host 'Press Enter to close'
}

if ($exitCode) {
    exit $exitCode
}
