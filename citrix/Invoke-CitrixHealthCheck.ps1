# Citrix health check script
# Source: https://sessionright.com/blog/citrix-health-check-powershell-script
# License: MIT
# Read-only: calls Get-* cmdlets only. Changes nothing in the estate; writes one local HTML report.

<#
  Invoke-CitrixHealthCheck.ps1
  Read-only health check for Citrix Virtual Apps and Desktops and Citrix DaaS.
  Calls Get-* cmdlets only and writes one HTML file. Run as a Read Only Administrator.
#>
param(
  [ValidateSet('Cvad', 'DaaS')] [string] $Mode = 'Cvad',
  [string] $AdminAddress = 'localhost',
  [string] $OutFile = (Join-Path $PWD ('CitrixHealth-{0:yyyyMMdd-HHmm}.html' -f (Get-Date))),
  [int] $ChangeDays = 7,
  [int] $MaxRecords = 100000
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command Get-BrokerMachine -ErrorAction SilentlyContinue)) {
  Add-PSSnapin Citrix.*.Admin.V*
}

$c = @{}
if ($Mode -eq 'Cvad') { $c.AdminAddress = $AdminAddress }
$summary = New-Object System.Collections.ArrayList
$detail  = New-Object System.Collections.ArrayList
$machines = $null

function Get-HcMachine {
  if ($null -eq $script:machines) {
    $script:machines = @(Get-BrokerMachine @c -MaxRecordCount $MaxRecords)
  }
  $script:machines
}

function Invoke-Check {
  param([string] $Name, [string] $Scope, [string[]] $Columns, [switch] $Info, [scriptblock] $Test)
  if ($Scope -eq 'CVAD' -and $Mode -ne 'Cvad') { return }
  try {
    $rows = @(& $Test | Where-Object { $_ })
    $status = if ($Info) { 'INFO' } elseif ($rows.Count) { 'FAIL' } else { 'PASS' }
  } catch {
    $rows = @()
    $status = 'ERROR: ' + $_.Exception.Message
  }
  [void]$summary.Add([pscustomobject]@{ Check = $Name; Scope = $Scope; Status = $status; Items = $rows.Count })
  if ($rows.Count) {
    [void]$detail.Add(($rows | Select-Object -Property $Columns |
      ConvertTo-Html -Fragment -PreContent "<h2>$Name</h2>" | Out-String))
  }
}

$fma = 'Get-BrokerServiceStatus', 'Get-ConfigServiceStatus', 'Get-LogServiceStatus', 'Get-MonitorServiceStatus',
       'Get-HypServiceStatus', 'Get-ProvServiceStatus', 'Get-AcctServiceStatus', 'Get-AdminServiceStatus'
$vdaCols = 'DNSName', 'CatalogName', 'DesktopGroupName', 'PowerState', 'RegistrationState',
           'FaultState', 'LastDeregistrationReason', 'LastDeregistrationTime', 'AgentVersion'
$changeFilter = 'StartTime -ge "{0:yyyy-MM-dd HH:mm:ss}"' -f (Get-Date).AddDays(-$ChangeDays)

Invoke-Check -Name 'Controllers not Active' -Scope CVAD -Columns DNSName, State, ControllerVersion, LastActivityTime -Test {
  Get-BrokerController @c | Where-Object { $_.State -ne 'Active' }
}
Invoke-Check -Name 'Controller versions' -Scope CVAD -Columns ControllerVersion, Count, Controllers -Test {
  $g = @(Get-BrokerController @c | Group-Object ControllerVersion)
  if ($g.Count -gt 1) {
    $g | Select-Object @{ n = 'ControllerVersion'; e = { $_.Name } }, Count,
      @{ n = 'Controllers'; e = { ($_.Group | ForEach-Object { $_.DNSName }) -join ', ' } }
  }
}
Invoke-Check -Name 'FMA services not OK' -Scope CVAD -Columns Controller, Service, ServiceStatus -Test {
  foreach ($ddc in (Get-BrokerController @c | ForEach-Object { $_.DNSName })) {
    foreach ($cmd in $fma) {
      try { $st = (& $cmd -AdminAddress $ddc).ServiceStatus } catch { $st = 'Unreachable: ' + $_.Exception.Message }
      if ($st -ne 'OK') { [pscustomobject]@{ Controller = $ddc; Service = $cmd; ServiceStatus = $st } }
    }
  }
}
Invoke-Check -Name 'Licensing state' -Scope CVAD -Columns DNSName, LicensingServerState, LicensingGraceState -Test {
  Get-BrokerController @c | Where-Object {
    $_.LicensingGraceState -ne 'NotActive' -or $_.LicensingServerState -notin 'OK', 'LasConnectionOK' }
}
Invoke-Check -Name 'Local Host Cache off' -Scope CVAD -Columns Name, LocalHostCacheEnabled -Test {
  Get-BrokerSite @c | Where-Object { -not $_.LocalHostCacheEnabled }
}
Invoke-Check -Name 'Delivery groups' -Scope Both -Columns Name, Enabled, InMaintenanceMode, TotalDesktops, DesktopsAvailable, DesktopsFaulted, Sessions -Test {
  Get-BrokerDesktopGroup @c -MaxRecordCount $MaxRecords |
    Where-Object { -not $_.Enabled -or $_.InMaintenanceMode -or $_.DesktopsFaulted -gt 0 }
}
Invoke-Check -Name 'Hypervisor connections' -Scope Both -Columns Name, State, IsReady, FaultState, FaultReason -Test {
  Get-BrokerHypervisorConnection @c | Where-Object { -not $_.IsReady -or $_.FaultState -ne 'None' }
}
Invoke-Check -Name 'Powered-on VDAs not registered' -Scope Both -Columns $vdaCols -Test {
  Get-HcMachine | Where-Object { $_.RegistrationState -ne 'Registered' -and $_.PowerState -in 'On', 'Unmanaged' }
}
Invoke-Check -Name 'VDAs in the registration sin bin' -Scope Both -Columns $vdaCols -Test {
  Get-HcMachine | Where-Object { $_.InRegistrationSinBin }
}
Invoke-Check -Name 'VDAs in a fault state' -Scope Both -Columns $vdaCols -Test {
  Get-HcMachine | Where-Object { $_.FaultState -ne 'None' }
}
Invoke-Check -Name 'VDAs in maintenance mode' -Scope Both -Columns DNSName, DesktopGroupName, PowerState, SummaryState -Test {
  Get-HcMachine | Where-Object { $_.InMaintenanceMode }
}
Invoke-Check -Name 'VDA versions' -Scope Both -Info -Columns AgentVersion, Count -Test {
  Get-HcMachine | Group-Object AgentVersion | Sort-Object Count -Descending |
    Select-Object @{ n = 'AgentVersion'; e = { $_.Name } }, Count
}
Invoke-Check -Name "Configuration changes, last $ChangeDays days" -Scope Both -Info -Columns StartTime, User, Text, IsSuccessful -Test {
  Get-LogHighLevelOperation @c -OperationType ConfigurationChange -Filter $changeFilter -MaxRecordCount $MaxRecords
}
Invoke-Check -Name "Failed configuration changes, last $ChangeDays days" -Scope Both -Columns StartTime, User, Text -Test {
  Get-LogHighLevelOperation @c -OperationType ConfigurationChange -Filter $changeFilter -MaxRecordCount $MaxRecords |
    Where-Object { $_.IsSuccessful -eq $false }
}
Invoke-Check -Name 'Administrators' -Scope Both -Info -Columns Name, Enabled -Test {
  Get-AdminAdministrator @c -MaxRecordCount $MaxRecords
}

$style = @'
<style>
body { font-family: Segoe UI, Arial, sans-serif; font-size: 13px; }
table { border-collapse: collapse; margin-bottom: 16px; }
th, td { border: 1px solid #ccc; padding: 4px 8px; text-align: left; }
th { background: #f0f0f0; }
.pass { background: #d4edda; } .fail { background: #f8d7da; } .error { background: #fff3cd; }
</style>
'@
$title = 'Citrix health check ({0}, {1:yyyy-MM-dd HH:mm})' -f $Mode, (Get-Date)
$top = $summary | ConvertTo-Html -Fragment -PreContent "<h1>$title</h1>" | Out-String
$top = $top -replace '<td>PASS</td>', '<td class="pass">PASS</td>' `
            -replace '<td>FAIL</td>', '<td class="fail">FAIL</td>' `
            -replace '<td>ERROR', '<td class="error">ERROR'
ConvertTo-Html -Head "<title>$title</title>$style" -Body (@($top) + $detail) |
  Out-File -FilePath $OutFile -Encoding utf8
Write-Output "Report written to $OutFile"
if ($summary | Where-Object { $_.Status -ne 'PASS' -and $_.Status -ne 'INFO' }) { exit 1 }
