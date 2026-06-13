<#
    Run-Tests-Locally.ps1

    Local equivalent of the CI workflow: creates a BC v28 container with the test toolkit,
    publishes the DataDebugger app (which contains the [Test] codeunit 50140), and runs the
    tests, writing TestResults.xml.

    Prerequisites:
      - Docker Desktop running in *Windows containers* mode (BC images are Windows-based).
      - Run from an ELEVATED PowerShell (container creation + host entries need admin).
      - Internet access for the first artifact download (several GB).

    Usage (from the repo root):
      pwsh -File .\scripts\Run-Tests-Locally.ps1
#>

param(
    [string] $ContainerName = 'bcdd28',
    [string] $Password      = 'P@ssw0rd123!',
    [string] $ProjectFolder = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
$AppId = 'fcd31dc9-7240-48cd-a991-ed43a5b7997f'   # DataDebugger

if (-not (Get-Module -ListAvailable BcContainerHelper)) {
    Write-Host 'Installing BcContainerHelper...' -ForegroundColor Cyan
    Install-Module BcContainerHelper -Force -Scope CurrentUser -AllowClobber
}
Import-Module BcContainerHelper

$artifactUrl = Get-BCArtifactUrl -type Sandbox -version '28' -country 'w1' -select Latest
$cred = New-Object pscredential 'admin', (ConvertTo-SecureString $Password -AsPlainText -Force)

New-BcContainer `
    -accept_eula `
    -containerName $ContainerName `
    -artifactUrl $artifactUrl `
    -auth UserPassword `
    -credential $cred `
    -updateHosts `
    -includeTestToolkit `
    -includeTestLibrariesOnly

Compile-AppInBcContainer -containerName $ContainerName -credential $cred `
    -appProjectFolder $ProjectFolder -appOutputFolder (Join-Path $ProjectFolder 'out') -UpdateSymbols |
    Publish-BcContainerApp -containerName $ContainerName -credential $cred -skipVerification -sync -install -useDevEndpoint

$resultFile = Join-Path $ProjectFolder 'TestResults.xml'
Run-TestsInBcContainer -containerName $ContainerName -credential $cred `
    -extensionId $AppId -detailed -XUnitResultFileName $resultFile

Write-Host "Done. Results: $resultFile" -ForegroundColor Green
