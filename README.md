# Sessionright health checks

Free, read-only health checks for Citrix Virtual Apps and Desktops, Citrix DaaS
and Azure Virtual Desktop. Every file comes from a published Sessionright guide.
The Citrix script is built on documented SDK cmdlets and writes one local HTML
report. The queries read log data. They make no changes to your estate.

Read every file before you run it.

## Files

| File | What it checks | Guide |
| --- | --- | --- |
| [citrix/Invoke-CitrixHealthCheck.ps1](citrix/Invoke-CitrixHealthCheck.ps1) | 15 read-only checks for Citrix Virtual Apps and Desktops and Citrix DaaS, built on documented SDK cmdlets and written to one colour-coded HTML report. | [Citrix health check PowerShell script](https://sessionright.com/blog/citrix-health-check-powershell-script) |
| [avd/kql/billed-mb-per-counter.kql](avd/kql/billed-mb-per-counter.kql) | Records and billed megabytes per performance counter over the last day, for the session hosts you name. | [AVD monitoring guide](https://sessionright.com/blog/avd-monitoring-guide) |
| [avd/kql/latest-unavailable-host-status.kql](avd/kql/latest-unavailable-host-status.kql) | The latest health status from the last 30 minutes for every session host that is not Available, with component versions and session counts. | [AVD monitoring guide](https://sessionright.com/blog/avd-monitoring-guide) |
| [avd/kql/completed-without-connecting.kql](avd/kql/completed-without-connecting.kql) | Connection attempts in the last day that reached Completed without ever reaching Connected, joined to their errors. | [AVD monitoring guide](https://sessionright.com/blog/avd-monitoring-guide) |
| [avd/kql/error-trends.kql](avd/kql/error-trends.kql) | Errors in the last day counted by error code, source and the ServiceError flag, with the number of users affected. | [AVD monitoring guide](https://sessionright.com/blog/avd-monitoring-guide) |
| [avd/kql/autoscale-evaluations.kql](avd/kql/autoscale-evaluations.kql) | Every pooled autoscale evaluation in the last day: phase, result, session and host counts and the scaling reason. | [AVD scaling plan guide](https://sessionright.com/blog/avd-scaling-plan-guide) |
| [avd/kql/autoscale-failures.kql](avd/kql/autoscale-failures.kql) | Autoscale evaluations that did not succeed, joined to their errors. | [AVD scaling plan guide](https://sessionright.com/blog/avd-scaling-plan-guide) |
| [avd/kql/hosts-not-available-last-day.kql](avd/kql/hosts-not-available-last-day.kql) | Each session host's latest health status from the last day where it is not Available, with its last heartbeat. | [AVD session host unavailable](https://sessionright.com/blog/avd-session-host-unavailable) |
| [avd/kql/connection-errors-by-user-count.kql](avd/kql/connection-errors-by-user-count.kql) | The ten connection errors that affect the most users, limited to errors where ServiceError is false. | [AVD no available resources](https://sessionright.com/blog/avd-no-available-resources) |
| [avd/kql/fslogix-event-counts.kql](avd/kql/fslogix-event-counts.kql) | FSLogix Operational and Admin event IDs counted per host over the last day, with the last time each was seen. | [FSLogix event ID 26](https://sessionright.com/blog/fslogix-event-id-26) |

## Run the Citrix health check

Use the built-in Read Only Administrator role, scoped to all the objects you want
to check ([CVAD delegated administration](https://docs.citrix.com/en-us/citrix-virtual-apps-desktops/secure/delegated-administration.html),
[DaaS delegated administration](https://docs.citrix.com/en-us/citrix-daas/manage-deployment/delegated-administration.html)).

On CVAD, use Windows PowerShell on a Delivery Controller or a machine with Studio
installed. The SDK supports PowerShell 3 through 5
([CVAD SDK requirements](https://docs.citrix.com/en-us/citrix-virtual-apps-desktops/sdk-api.html)).
From the pack's `citrix` folder, unblock the downloaded file, then run it:

```powershell
Unblock-File .\Invoke-CitrixHealthCheck.ps1
.\Invoke-CitrixHealthCheck.ps1 -AdminAddress ddc01.corp.example
```

Replace the example Controller name with your own. `Unblock-File` unblocks a
downloaded script for execution under RemoteSigned
([execution policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)).
`-AdminAddress` targets a Controller
([SDK common parameters](https://developer-docs.citrix.com/us/en/citrix-virtual-apps-desktops-sdk/2603/about_broker_accesspolicy/get-brokerservicestatus.html)).

On DaaS, install the Remote PowerShell SDK on a domain-joined machine in the
resource location, never on a Cloud Connector, on-premises Delivery Controller
or Studio machine. Install Edge WebView2, use PowerShell 3.0 to 7.0, and remove
the CVAD SDK first if installed. The installer adds .NET Framework 4.8 if needed
([DaaS SDK requirements](https://docs.citrix.com/en-us/citrix-daas/sdk-api.html)).
From the `citrix` folder, unblock the file as above, then authenticate and run:

```powershell
Get-XdAuthentication
.\Invoke-CitrixHealthCheck.ps1 -Mode DaaS
```

Open the local HTML file named in the last output line. DaaS skips the five
Controller and site checks because those cmdlets are disabled remotely
([DaaS SDK](https://docs.citrix.com/en-us/citrix-daas/sdk-api.html)). Read the
[full guide](https://sessionright.com/blog/citrix-health-check-powershell-script)
for parameters, report statuses and coverage limits. This is a snapshot, not a
full assessment.

## Run a KQL query

Open Logs in the Log Analytics workspace receiving your AVD diagnostics, paste
the contents of a `.kql` file and run the query. Read the
[AVD monitoring guide](https://sessionright.com/blog/avd-monitoring-guide) for the
tables and diagnostic settings. Performance queries also need performance counters;
FSLogix queries need the Operational and Admin event logs described in the
[FSLogix guide](https://sessionright.com/blog/fslogix-event-id-26). Replace example
host names with your own where present. Queries cannot report on data that has
not been collected.

## Issues and security

For a script problem, open an issue in this repository with the file name and a
redacted description. Do not include estate details, user names or credentials.
For security issues, follow [SECURITY.md](SECURITY.md) and email hello@sessionright.com.

## About Sessionright

Sessionright is a management platform for Azure Virtual Desktop that also assesses
Citrix and NetScaler estates. It finds problems with evidence, proposes each change
as a plan that a named person must approve, and is licensed annually by estate size.
The [free read-only AVD assessment](https://sessionright.com/free-assessment) runs
without a license.

## License and trademarks

[MIT](LICENSE). Copyright (c) 2026 Sessionright.

Citrix and NetScaler are trademarks of Cloud Software Group, Inc.
Microsoft, Azure and Azure Virtual Desktop are trademarks of the Microsoft group
of companies. Sessionright is not affiliated with or endorsed by them.
