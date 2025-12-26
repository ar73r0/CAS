<#  Test-LaunchVhdxVm.ps1
    Creates/uses a Hyper-V VM with an existing VHDX, starts it, and opens VMConnect.
    Run in an elevated PowerShell (Admin).
#>

param(
  [Parameter(Mandatory=$true)]
  [string]$VMName,

  [Parameter(Mandatory=$true)]
  [string]$VhdxPath,

  [string]$SwitchName = "",          # Optional: name of an existing vSwitch
  [int64]$MemoryStartupBytes = 2GB,  # 2GB default
  [int]$Generation = 2,              # 2 for modern OS (UEFI), 1 for legacy/BIOS
  [int]$CPUCount = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { throw "Run PowerShell as Administrator." }
}

function Assert-HyperV {
  if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
    throw "Hyper-V PowerShell module not available. Enable Hyper-V and/or install RSAT Hyper-V tools."
  }
}

Assert-Admin
Assert-HyperV

if (-not (Test-Path -LiteralPath $VhdxPath)) {
  throw "VHDX not found: $VhdxPath"
}

# Check for existing VM
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue

if (-not $vm) {
  Write-Host "Creating VM '$VMName' (Gen $Generation) using VHDX: $VhdxPath"

  $newParams = @{
    Name               = $VMName
    Generation         = $Generation
    MemoryStartupBytes = $MemoryStartupBytes
    VHDPath            = $VhdxPath
  }

  if ($SwitchName -and (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    $newParams["SwitchName"] = $SwitchName
  } elseif ($SwitchName) {
    Write-Warning "Switch '$SwitchName' not found. VM will be created without a vNIC."
  }

  $vm = New-VM @newParams

  Set-VM -Name $VMName -ProcessorCount $CPUCount -AutomaticStopAction ShutDown | Out-Null

  # For Gen2, make sure it boots from the disk (usually automatic, but this is explicit)
  if ($Generation -eq 2) {
    $hdd = Get-VMHardDiskDrive -VMName $VMName
    Set-VMFirmware -VMName $VMName -FirstBootDevice $hdd | Out-Null
  }
} else {
  Write-Host "VM '$VMName' already exists."
  $attached = Get-VMHardDiskDrive -VMName $VMName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
  if ($attached -notcontains (Resolve-Path $VhdxPath).Path) {
    Write-Warning "Existing VM does not appear to use this VHDX. Attached disk(s): $($attached -join ', ')"
  }
}

# Start VM if needed
$vm = Get-VM -Name $VMName
if ($vm.State -ne "Running") {
  Write-Host "Starting VM '$VMName'..."
  Start-VM -Name $VMName | Out-Null
}

# Optional: wait briefly for heartbeat (requires Integration Services in the guest OS)
try {
  Write-Host "Waiting for Heartbeat (up to 60s)..."
  $timeout = (Get-Date).AddSeconds(60)
  do {
    Start-Sleep -Seconds 2
    $hb = (Get-VMIntegrationService -VMName $VMName -Name "Heartbeat").PrimaryStatusDescription
  } while ($hb -notmatch "OK" -and (Get-Date) -lt $timeout)
  Write-Host "Heartbeat status: $hb"
} catch {
  Write-Warning "Could not read Heartbeat (guest may not have integration services yet)."
}

# Open console
Write-Host "Opening VMConnect..."
vmconnect.exe localhost $VMName
