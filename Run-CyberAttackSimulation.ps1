<#
.SYNOPSIS
    Entry point voor Cyber Attack Simulator.

.EXAMPLE
    .\Run-CyberAttackSimulation.ps1 -Difficulty Medium -NumberOfVMs 3 -Parallel
#>

[CmdletBinding()]
param(
    [ValidateSet('Easy','Medium','Hard')]
    [string]$Difficulty = 'Easy',

    [int]$NumberOfVMs = 2,

    [string[]]$AttackTypes = @('BruteForce','PrivilegeEscalation','PortScan','LateralMovement'), #validateset

    [switch]$Parallel,

    [string]$LabPrefix = 'CAS-LAB',

    [string]$VirtualSwitch = 'CAS-Switch',

    [string]$LogPath = '.\Logs', #valideren padden

    [string]$ReportPath = '.\Reports', #valideren padden

    [switch]$WhatIfSimulation,

    # Host-only is default; use -AllowGuestLogon to attempt PowerShell Direct into guests
[switch]$AllowGuestLogon,  # kept for compatibility; guest logon now on by default when possible
[System.Management.Automation.PSCredential]$GuestCredential,

    [string]$SIEMEndpoint,

    [switch]$EducationalMode,

    [switch]$ChallengeMode,

    [string]$VHDPath,

    [string]$ISOPath,

    [switch]$AutoConnectConsole,

    # Optional attacker (e.g. Kali) to run real network attacks from
    [string]$AttackerVMName,
    [string]$AttackerSSHUser,
    [string]$AttackerSSHPrivateKeyPath,
    [int]$AttackerSSHPort = 22
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'CyberAttackSimulator.Core.psm1'
Import-Module $modulePath -Force

# Interactieve fallback als er bv. weinig parameters zijn ingevuld
if (-not $PSBoundParameters.ContainsKey('Difficulty')) {
    $Difficulty = Read-Host 'Difficulty (Easy/Medium/Hard)'
}
if (-not $PSBoundParameters.ContainsKey('NumberOfVMs')) {
    $NumberOfVMs = [int](Read-Host 'Number of VMs to create')
}

# Default Base VM image if none provided
if (-not $PSBoundParameters.ContainsKey('VHDPath')) {
    $defaultVhdPath = Get-CASDefaultVHDPath
    if ($defaultVhdPath) { $VHDPath = $defaultVhdPath }
}
# Default ISO if no valid VHD is present; will be attached for install/boot
if (-not $PSBoundParameters.ContainsKey('ISOPath')) {
    $defaultIsoPath = Get-CASDefaultISOPath
    if ($defaultIsoPath) { $ISOPath = $defaultIsoPath }
}

Write-Host "Initializing CAS..." -ForegroundColor Cyan

[void](Initialize-CASSimulator -Difficulty $Difficulty `
    -NumberOfVMs $NumberOfVMs `
    -AttackTypes $AttackTypes `
    -LabPrefix $LabPrefix `
    -VirtualSwitch $VirtualSwitch `
    -LogPath $LogPath `
    -ReportPath $ReportPath `
    -VHDPath $VHDPath `
    -ISOPath $ISOPath `
    -AutoConnectConsole:$AutoConnectConsole `
    -AllowGuestLogon:$true `
    -GuestCredential $GuestCredential `
    -AttackerVMName $AttackerVMName `
    -AttackerSSHUser $AttackerSSHUser `
    -AttackerSSHPrivateKeyPath $AttackerSSHPrivateKeyPath `
    -AttackerSSHPort $AttackerSSHPort `
    -SIEMEndpoint $SIEMEndpoint `
    -EducationalMode:$EducationalMode `
    -ChallengeMode:$ChallengeMode `
    -Verbose)

Write-Host "Creating lab VMs..." -ForegroundColor Cyan
$vmNames = New-CASLab -WhatIfSimulation:$WhatIfSimulation.IsPresent -Verbose

Write-Host "Running scenarios..." -ForegroundColor Cyan
[void](Invoke-CASSimulation -VMNames $vmNames -AttackTypes $AttackTypes -Parallel:$Parallel.IsPresent -Verbose)

Write-Host "Generating report..." -ForegroundColor Cyan
$report = New-CASReport -Format Html -Verbose

Write-Host "Done. Report: $report" -ForegroundColor Green
