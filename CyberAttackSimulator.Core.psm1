<#
.SYNOPSIS
    Cyber Attack Simulator - Core Module (MVP+)

.DESCRIPTION
    Bevat kernfunctionaliteit:
    - Voorwaarden checken (Hyper-V, rechten, paden)
    - VM-automatisering (Hyper-V skeleton)
    - Scenario framework (brute force simulatie, privilege escalation check, port scan)
    - Levelstructuur via "Difficulty"
    - Logging (JSON + CSV)
    - Parallelle uitvoering via Start-Job (hergebruikt module)
    - Simpele HTML/CSV rapportage
#>

#region Globals & Types

$script:CasSessionId   = $null
$script:CasConfig      = $null
$script:CasModulePath  = $MyInvocation.MyCommand.Path
$script:CasChallenges  = $null
$script:CasProfiles    = @{}
$script:CasUserProfiles= @()

class CasScenarioResult {
    [string]$SessionId
    [string]$Scenario
    [string]$VMName
    [datetime]$Timestamp
    [string]$Difficulty
    [string]$Status
    [string]$Message
    [string]$Details
}

#endregion Globals & Types

#region Helper: Logging & Paths

function New-CASDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    return (Resolve-Path -Path $Path).ProviderPath
}

function Write-CASLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Scenario,
        [Parameter(Mandatory)][string]$VMName,
        [Parameter(Mandatory)][string]$Status,
        [Parameter()][string]$Message,
        [Parameter()][string]$Details
    )

    if (-not $script:CasConfig) {
        throw 'CAS configuration is not initialized. Call Initialize-CASSimulator first.'
    }
    if (-not $script:CasSessionId) {
        $script:CasSessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
    }

    $result = [CasScenarioResult]::new()
    $result.SessionId  = $script:CasSessionId
    $result.Scenario   = $Scenario
    $result.VMName     = $VMName
    $result.Timestamp  = Get-Date
    $result.Difficulty = $script:CasConfig.Difficulty
    $result.Status     = $Status
    $result.Message    = $Message
    $result.Details    = $Details

    $logRoot  = $script:CasConfig.LogRoot
    $jsonFile = Join-Path $logRoot "CAS-Log-$($script:CasSessionId).jsonl"
    $csvFile  = Join-Path $logRoot "CAS-Log-$($script:CasSessionId).csv"

    $result | ConvertTo-Json -Depth 5 -Compress | Add-Content -Path $jsonFile

    if (-not (Test-Path $csvFile)) {
        $result | Export-Csv -NoTypeInformation -Path $csvFile
    }
    else {
        $result | Export-Csv -NoTypeInformation -Path $csvFile -Append
    }

    # Forward stub to SIEM (file/URI placeholder)
    if ($script:CasConfig.SIEMEndpoint) {
        Send-CASSIEMEvent -Endpoint $script:CasConfig.SIEMEndpoint -Payload $result
    }

    return $result
}

#endregion Helper: Logging & Paths

#region Initialization & Validation

function Test-CASPrerequisites {
    [CmdletBinding()]
    param(
        [switch]$SkipHyperVCheck
    )

    $issues = @()

    # Admin check
    if (-not ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

        $issues += 'Script is not running elevated (Administrator). Hyper-V operations may fail.'
    }

    if (-not $SkipHyperVCheck) {
        $hyperVAvailable = Get-Module -ListAvailable -Name Hyper-V -ErrorAction SilentlyContinue
        if (-not $hyperVAvailable) {
            $issues += 'Hyper-V module not available. Install and enable Hyper-V or run on a host with Hyper-V.'
        }
    }

    [pscustomobject]@{
        PrerequisitesMet = ($issues.Count -eq 0)
        Issues           = $issues
    }
}

function Get-CASModuleRoot {
    if ($script:CasModulePath) { return (Split-Path -Parent $script:CasModulePath) }
    return $PSScriptRoot
}

function Get-CASDefaultVHDPath {
    $root = Get-CASModuleRoot
    $candidates = @(
        Join-Path $root 'VMS\BaseVM\Virtual Hard Disks\BaseVM.vhdx',
        Join-Path $root 'VMS\PatientZero\PatientZero.vhdx',
        Join-Path $root 'PatientZero.vhdx'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).ProviderPath
        }
    }

    $patientZero = Get-ChildItem -Path (Join-Path $root 'VMS') -Filter 'PatientZero.vhdx' -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($patientZero) {
        return $patientZero.FullName
    }
}

function Get-CASDefaultISOPath {
    $root = Get-CASModuleRoot
    $isoDir = Join-Path $root 'VMS\ISO'
    if (Test-Path $isoDir) {
        $iso = Get-ChildItem -Path $isoDir -Filter *.iso -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($iso) { return $iso.FullName }
    }
}

function Get-CASDifficultyScriptPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Difficulty
    )

    $root = Get-CASModuleRoot
    $candidate = Join-Path $root ("VMS\PDifficulty\{0}.ps1" -f $Difficulty)
    if (Test-Path $candidate) {
        return (Resolve-Path $candidate).ProviderPath
    }
}

function New-CASDiffDisk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VMName
    )

    if (-not $script:CasConfig) { return $null }

    $parent = $script:CasConfig.VHDPath
    $diffRoot = $script:CasConfig.DiffDiskRoot
    if (-not $diffRoot) { return $null }

    New-CASDirectory -Path $diffRoot | Out-Null

    # If we have a usable parent, create differencing; otherwise create a blank dynamic disk
    if ($parent -and $script:CasConfig.BaseVhdUsable) {
        $diffPath = Join-Path $diffRoot ("{0}.vhdx" -f $VMName)
        if (-not (Test-Path $diffPath)) {
            Write-Verbose "Creating differencing disk for '$VMName'..."
            New-VHD -Path $diffPath -ParentPath $parent -Differencing | Out-Null
        }
        else {
            Write-Verbose "Differencing disk already exists for '$VMName'."
        }
        return (Resolve-Path $diffPath).ProviderPath
    }
    else {
        $blankPath = Join-Path $diffRoot ("{0}.vhdx" -f $VMName)
        if (-not (Test-Path $blankPath)) {
            Write-Verbose "Creating blank dynamic disk for '$VMName' (no base image detected)..."
            New-VHD -Path $blankPath -SizeBytes 40GB -Dynamic | Out-Null
        }
        else {
            Write-Verbose "Blank disk already exists for '$VMName'."
        }
        return (Resolve-Path $blankPath).ProviderPath
    }
}

function Initialize-CASSimulator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Easy','Medium','Hard')]
        [string]$Difficulty,

        [Parameter(Mandatory)]
        [int]$NumberOfVMs,

        [Parameter()][string[]]$AttackTypes = @('BruteForce','PrivilegeEscalation','PortScan','LateralMovement'),

        [Parameter()][string]$LabPrefix = 'CAS-LAB',
        [Parameter()][string]$VirtualSwitch = 'CAS-Switch',

        [Parameter()][string]$LogPath = '.\Logs',
        [Parameter()][string]$ReportPath = '.\Reports',

        # Optioneel: sessie-ID van buitenaf (bv. parallel jobs)
        [Parameter()][string]$SessionId,

        # Optioneel: pad naar een bestaande VHD/VHDX met Windows
        [Parameter()][string]$VHDPath,

        # Optioneel: ISO om te booten/installeren als geen geldige VHD aanwezig is
        [Parameter()][string]$ISOPath,

        # Host-only standaard; override met -AllowGuestLogon en GuestCredential om PowerShell Direct te proberen
        [Parameter()][switch]$AllowGuestLogon,
        [Parameter()][System.Management.Automation.PSCredential]$GuestCredential,

        # SIEM/extern endpoint (stub): pad of URI waarheen JSON wordt geforward
        [Parameter()][string]$SIEMEndpoint,

        # Educatieve toelichtingen toevoegen aan logs/rapport
        [Parameter()][switch]$EducationalMode,

        # Challenge mode: vraag operator om detectie/response, meet tijd en score
        [Parameter()][switch]$ChallengeMode
    )

    $pre = Test-CASPrerequisites
    if (-not $pre.PrerequisitesMet) {
        Write-Warning "CAS prerequisites not fully met:"
        $pre.Issues | ForEach-Object { Write-Warning " - $_" }
    }

    $logRoot    = New-CASDirectory -Path $LogPath
    $reportRoot = New-CASDirectory -Path $ReportPath
    $hasCred    = [bool]$GuestCredential
    $skipGuest  = -not ($AllowGuestLogon.IsPresent -and $hasCred)

    $resolvedVhdPath = $null
    $baseVhdUsable = $false
    $diffDiskRoot = $null

    if ($VHDPath) {
        if (Test-Path $VHDPath) {
            $resolvedVhdPath = (Resolve-Path $VHDPath).ProviderPath
            $baseSizeGB = ([math]::Round((Get-Item $resolvedVhdPath).Length / 1GB,2))
            $baseVhdUsable = $baseSizeGB -ge 1
            if (-not $baseVhdUsable) {
                Write-Warning "Base image '$resolvedVhdPath' is only $baseSizeGB GB and likely not an installed OS."
            }
        }
        else {
            Write-Warning "Specified VHDPath '$VHDPath' not found. VMs will be created empty unless a valid image is provided."
        }
    }
    else {
        $defaultVhd = Get-CASDefaultVHDPath
        if ($defaultVhd) {
            $resolvedVhdPath = $defaultVhd
            $baseSizeGB = ([math]::Round((Get-Item $resolvedVhdPath).Length / 1GB,2))
            $baseVhdUsable = $baseSizeGB -ge 1
            Write-Verbose "Using default base image at '$defaultVhd'."
            if (-not $baseVhdUsable) {
                Write-Warning "Default base image '$defaultVhd' is only $baseSizeGB GB and likely not an installed OS."
            }
        }
        else {
            Write-Warning "No VHD/VHDX provided and default base image not found. VMs will be created empty."
        }
    }

    if ($resolvedVhdPath) {
        $parentDir = Split-Path -Path $resolvedVhdPath -Parent
        $diffDiskRoot = Join-Path $parentDir 'DiffDisks'
    }
    else {
        $diffDiskRoot = Join-Path (Get-CASModuleRoot) 'VMS\BaseVM\Virtual Hard Disks\DiffDisks'
    }

    $resolvedIsoPath = $null
    if ($ISOPath) {
        if (Test-Path $ISOPath) {
            $resolvedIsoPath = (Resolve-Path $ISOPath).ProviderPath
        }
        else {
            Write-Warning "Specified ISOPath '$ISOPath' not found."
        }
    }
    elseif (-not $baseVhdUsable) {
        $resolvedIsoPath = Get-CASDefaultISOPath
        if ($resolvedIsoPath) {
            Write-Verbose "Using default ISO '$resolvedIsoPath' because no usable base image was found."
        }
    }

    $difficultyScript = Get-CASDifficultyScriptPath -Difficulty $Difficulty
    if (-not $difficultyScript) {
        Write-Verbose "No difficulty initialization script found for '$Difficulty'."
    }

    $script:CasConfig = [pscustomobject]@{
        Difficulty      = $Difficulty
        NumberOfVMs     = $NumberOfVMs
        AttackTypes     = $AttackTypes
        LabPrefix       = $LabPrefix
        VirtualSwitch   = $VirtualSwitch
        LogRoot         = $logRoot
        ReportRoot      = $reportRoot
        VHDPath         = $resolvedVhdPath
        BaseVhdUsable   = $baseVhdUsable
        DiffDiskRoot    = $diffDiskRoot
        ISOPath         = $resolvedIsoPath
        SkipGuestLogon  = $skipGuest
        GuestCredential = $GuestCredential
        SIEMEndpoint    = $SIEMEndpoint
        EducationalMode = $EducationalMode.IsPresent
        ChallengeMode   = $ChallengeMode.IsPresent
        DifficultyScript= $difficultyScript
        UserProfiles    = Get-CASUserProfiles -Difficulty $Difficulty
    }

    # Build per-VM profiles for defenses/countermeasures
    $script:CasProfiles = New-CASProfiles -LabPrefix $LabPrefix -NumberOfVMs $NumberOfVMs -Difficulty $Difficulty

    if ($SessionId) {
        $script:CasSessionId = $SessionId
    }
    elseif (-not $script:CasSessionId) {
        $script:CasSessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
    }

    Write-Verbose "CAS initialized. SessionId: $($script:CasSessionId)"
    return $script:CasConfig
}

#endregion Initialization & Validation

#region VM Provisioning (Hyper-V skeleton)

function New-CASVirtualSwitch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )

    if (-not (Get-VMSwitch -Name $Name -ErrorAction SilentlyContinue)) {
        Write-Verbose "Creating Hyper-V switch '$Name'..."
        New-VMSwitch -Name $Name -SwitchType Internal | Out-Null
    }
    else {
        Write-Verbose "Hyper-V switch '$Name' already exists."
    }
}

function New-CASLab {
    [CmdletBinding()]
    param(
        [Parameter()][switch]$WhatIfSimulation
    )

    if (-not $script:CasConfig) {
        throw 'CAS configuration is not initialized. Call Initialize-CASSimulator first.'
    }

    $cfg = $script:CasConfig

    if (-not $WhatIfSimulation) {
        New-CASVirtualSwitch -Name $cfg.VirtualSwitch
    } else {
        Write-Verbose "[WhatIf] Would create Hyper-V switch '$($cfg.VirtualSwitch)'."
    }

    $vmNames = @()

    for ($i = 1; $i -le $cfg.NumberOfVMs; $i++) {
        $vmName = "{0}-{1:00}" -f $cfg.LabPrefix, $i
        $vmNames += $vmName

        if ($WhatIfSimulation) {
            Write-Verbose "[WhatIf] Would create and start VM '$vmName'."
            continue
        }

        if (-not (Get-VM -Name $vmName -ErrorAction SilentlyContinue)) {
            Write-Verbose "Creating VM '$vmName'..."
            $diskPath = $null
            $diskPath = New-CASDiffDisk -VMName $vmName

            if ($diskPath) {
                New-VM -Name $vmName -MemoryStartupBytes 1GB -SwitchName $cfg.VirtualSwitch -VHDPath $diskPath -Generation 2 | Out-Null
            }
            else {
                Write-Warning "No VHD/VHDX specified for $vmName (VHDPath). VM will be empty."
                New-VM -Name $vmName -MemoryStartupBytes 1GB -SwitchName $cfg.VirtualSwitch -Generation 2 | Out-Null
            }
            Set-VM -Name $vmName -DynamicMemory -MemoryMinimumBytes 512MB -MemoryMaximumBytes 2GB | Out-Null

            if ($cfg.ISOPath) {
                if (-not (Get-VMDvdDrive -VMName $vmName -ErrorAction SilentlyContinue)) {
                    Add-VMDvdDrive -VMName $vmName -Path $cfg.ISOPath | Out-Null
                }
                else {
                    Set-VMDvdDrive -VMName $vmName -Path $cfg.ISOPath | Out-Null
                }

                try {
                    $dvd = Get-VMDvdDrive -VMName $vmName
                    Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd | Out-Null
                }
                catch {
                    Write-Verbose "Could not set DVD as first boot device for '$vmName': $($_.Exception.Message)"
                }
            }
        }
        else {
            Write-Verbose "VM '$vmName' already exists."
        }

        if ((Get-VM -Name $vmName).State -ne 'Running') {
            Write-Verbose "Starting VM '$vmName'..."
            Start-VM -Name $vmName | Out-Null
        }

        # Apply per-VM profile settings inside the guest if allowed
        if (-not $cfg.SkipGuestLogon -and $cfg.GuestCredential) {
            Invoke-CASDifficultyScript -VMName $vmName
            $profile = Get-CASProfile -VMName $vmName
            Apply-CASProfileGuest -Profile $profile -Credential $cfg.GuestCredential
        }
        elseif ($cfg.DifficultyScript) {
            Write-Verbose "Skipping difficulty script for '$vmName' (guest logon disabled or missing credential)."
        }
    }

    return $vmNames
}

#endregion VM Provisioning

#region Scenario Helpers

function Get-CASScenarioSleep {
    param(
        [Parameter(Mandatory)][string]$Difficulty
    )
    switch ($Difficulty) {
        'Easy'   { 1 }
        'Medium' { 2 }
        'Hard'   { 3 }
        default  { 1 }
    }
}

function Get-CASVMIP {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VMName
    )

    # Simpel: pak eerste IPv4-adres dat niet APIPA is
    $vm = Get-VM -Name $VMName -ErrorAction Stop
    $ips = (Get-VMNetworkAdapter -VMName $vm.Name).IPAddresses |
           Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' -and -not $_.StartsWith('169.254.') }

    return $ips | Select-Object -First 1
}

# Scenario library manifest (static for now)
$script:CasScenarioLibrary = @(
    [pscustomobject]@{ Name='BruteForce'; Difficulty='Easy'; Version='1.0'; Description='Simulated brute-force login attempts' }
    [pscustomobject]@{ Name='PrivilegeEscalation'; Difficulty='Easy'; Version='1.0'; Description='Checks admin rights inside the VM' }
    [pscustomobject]@{ Name='PortScan'; Difficulty='Easy'; Version='1.0'; Description='Host-based port scan of guest IP' }
    [pscustomobject]@{ Name='LateralMovement'; Difficulty='Medium'; Version='1.0'; Description='Simulated lateral movement log trail' }
)

function New-CASProfiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LabPrefix,
        [Parameter(Mandatory)][int]$NumberOfVMs,
        [Parameter(Mandatory)][string]$Difficulty
    )

    $profiles = @{}
    for ($i=1; $i -le $NumberOfVMs; $i++) {
        $vmName = "{0}-{1:00}" -f $LabPrefix, $i

        switch ($Difficulty) {
            'Easy' {
                $profile = [pscustomobject]@{
                    VMName          = $vmName
                    WeakCreds       = $true
                    AllowRDP        = $true
                    AllowSMB        = $true
                    AllowWinRM      = $true
                    Hardened        = $false
                }
            }
            'Medium' {
                $profile = [pscustomobject]@{
                    VMName          = $vmName
                    WeakCreds       = ($i % 2 -eq 1)
                    AllowRDP        = $true
                    AllowSMB        = ($i % 2 -eq 0)
                    AllowWinRM      = $true
                    Hardened        = ($i % 3 -eq 0)
                }
            }
            'Hard' {
                $profile = [pscustomobject]@{
                    VMName          = $vmName
                    WeakCreds       = $false
                    AllowRDP        = ($i % 2 -eq 0)
                    AllowSMB        = $false
                    AllowWinRM      = $true
                    Hardened        = $true
                }
            }
            default {
                $profile = [pscustomobject]@{
                    VMName          = $vmName
                    WeakCreds       = $true
                    AllowRDP        = $true
                    AllowSMB        = $true
                    AllowWinRM      = $true
                    Hardened        = $false
                }
            }
        }

        $profiles[$vmName] = $profile
    }
    return $profiles
}

function Get-CASUserProfiles {
    [CmdletBinding()]
    param(
        [Parameter()][ValidateSet('Easy','Medium','Hard')]
        [string]$Difficulty
    )

    if (-not $script:CasUserProfiles -or $script:CasUserProfiles.Count -eq 0) {
        $script:CasUserProfiles = @(
            [pscustomobject]@{ Difficulty='Easy';   Persona='SOC Trainee';     CredentialStrength='Weak';    Notes='Weak defaults to drive detection of bad practices.' },
            [pscustomobject]@{ Difficulty='Medium'; Persona='Tier-1 Analyst';  CredentialStrength='Moderate'; Notes='Mix of weak and hardened hosts for balanced labs.' },
            [pscustomobject]@{ Difficulty='Hard';   Persona='Tier-2 Engineer'; CredentialStrength='Strong';   Notes='Hardened baseline with minimal exposed services.' }
        )
    }

    $profiles = $script:CasUserProfiles
    if ($Difficulty) {
        return $profiles | Where-Object { $_.Difficulty -eq $Difficulty }
    }
    return $profiles
}

function Get-CASProfile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$VMName)
    if ($script:CasProfiles.ContainsKey($VMName)) { return $script:CasProfiles[$VMName] }
    return [pscustomobject]@{
        VMName          = $VMName
        WeakCreds       = $true
        AllowRDP        = $true
        AllowSMB        = $true
        AllowWinRM      = $true
        Hardened        = $false
    }
}

function Apply-CASProfileGuest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Profile,
        [Parameter()][System.Management.Automation.PSCredential]$Credential
    )

    $vm = $Profile.VMName
    $weakUser = 'casuser'
    $weakPass = 'P@ssw0rd123'

    $scriptBlock = {
        param($profile, $user, $pass)

        # Create or remove weak user
        if ($profile.WeakCreds) {
            if (-not (Get-LocalUser -Name $user -ErrorAction SilentlyContinue)) {
                New-LocalUser -Name $user -Password (ConvertTo-SecureString $pass -AsPlainText -Force) -PasswordNeverExpires -UserMayNotChangePassword:$true | Out-Null
            }
        } else {
            if (Get-LocalUser -Name $user -ErrorAction SilentlyContinue) {
                Remove-LocalUser -Name $user -ErrorAction SilentlyContinue
            }
        }

        # Firewall rules
        if ($profile.AllowRDP) { Set-NetFirewallRule -DisplayGroup "Remote Desktop" -Enabled True -Action Allow -ErrorAction SilentlyContinue }
        else { Set-NetFirewallRule -DisplayGroup "Remote Desktop" -Enabled True -Action Block -ErrorAction SilentlyContinue }

        if ($profile.AllowSMB) { Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled True -Action Allow -ErrorAction SilentlyContinue }
        else { Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled True -Action Block -ErrorAction SilentlyContinue }

        if ($profile.AllowWinRM) { Set-Service -Name WinRM -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service -Name WinRM -ErrorAction SilentlyContinue }
        else { Stop-Service -Name WinRM -ErrorAction SilentlyContinue; Set-Service -Name WinRM -StartupType Disabled -ErrorAction SilentlyContinue }

        if ($profile.Hardened) {
            # Basic hardening: enable auditing of logon events
            AuditPol /set /subcategory:"Logon" /success:enable /failure:enable | Out-Null
        }
    }

    $invokeParams = @{
        VMName      = $vm
        ScriptBlock = $scriptBlock
        ArgumentList= @($Profile, $weakUser, $weakPass)
        ErrorAction = 'SilentlyContinue'
    }
    if ($Credential) { $invokeParams.Credential = $Credential }

    Invoke-Command @invokeParams
}

#region Difficulty Setup

function Invoke-CASDifficultyScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VMName
    )

    if (-not $script:CasConfig) {
        throw 'CAS configuration is not initialized. Call Initialize-CASSimulator first.'
    }

    $cfg = $script:CasConfig
    if (-not $cfg.DifficultyScript) {
        return
    }
    if ($cfg.SkipGuestLogon -or -not $cfg.GuestCredential) {
        Write-Verbose "Difficulty script found for '$($cfg.Difficulty)' but guest logon is disabled; skipping for '$VMName'."
        return
    }

    try {
        $scriptContent = Get-Content -Path $cfg.DifficultyScript -Raw
        Write-Verbose "Applying difficulty initialization script '$($cfg.DifficultyScript)' to VM '$VMName'..."
        Invoke-Command -VMName $VMName -Credential $cfg.GuestCredential -ScriptBlock {
            param($content)
            Invoke-Expression $content
        } -ArgumentList $scriptContent -ErrorAction Stop
    }
    catch {
        Write-CASLog -Scenario 'Provisioning' -VMName $VMName -Status 'Failed' `
            -Message "Difficulty script failed on $VMName." `
            -Details $_.Exception.Message
        throw
    }
}

#endregion Difficulty Setup

$script:CasChallenges = @{
    'BruteForce' = @{
        Question  = 'Welke events/logs tonen de mislukte logins en welke actie zou je nemen?'
        Keywords  = @('4625','lockout','account','threshold','SIEM')
    }
    'PrivilegeEscalation' = @{
        Question  = 'Hoe detecteer je privilege escalation pogingen (welke event IDs) en wat is je onmiddellijke respons?'
        Keywords  = @('4672','admin','group','alert','isolation')
    }
    'PortScan' = @{
        Question  = 'Welke indicatoren wijzen op een portscan en welke netwerkmaatregel neem je?'
        Keywords  = @('firewall','block','connection','rate','IDS')
    }
    'LateralMovement' = @{
        Question  = 'Welke logbronnen en event IDs controleren voor laterale beweging, en welke containment doe je?'
        Keywords  = @('4624','remote','service','SMB','isolation')
    }
}

function Get-CASScenarioLibrary {
    [CmdletBinding()]
    param()
    return $script:CasScenarioLibrary
}

function Export-CASScenarioLibrary {
    [CmdletBinding()]
    param(
        [Parameter()][string]$Path = '.\ScenarioLibrary.json'
    )
    $lib = Get-CASScenarioLibrary
    $lib | ConvertTo-Json -Depth 4 | Set-Content -Path $Path -Encoding UTF8
    return (Resolve-Path $Path).ProviderPath
}

function Get-CASOperatorResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Scenario,
        [Parameter(Mandatory)][string]$VMName
    )

    $challenge = $script:CasChallenges[$Scenario]
    if (-not $challenge) { return }

    $question = $challenge.Question
    $keywords = $challenge.Keywords

    Write-Host "`nCHALLENGE ($Scenario on $VMName): $question" -ForegroundColor Yellow
    $start = Get-Date
    $response = Read-Host "Jouw antwoord"
    $duration = (Get-Date) - $start

    $hitCount = 0
    foreach ($kw in $keywords) {
        if ($response -match [regex]::Escape($kw)) {
            $hitCount++
        }
    }
    $score = if ($keywords.Count -gt 0) { [math]::Round(($hitCount / $keywords.Count) * 100, 0) } else { 0 }

    Write-CASLog -Scenario $Scenario -VMName $VMName -Status 'OperatorResponse' `
        -Message "Operator response captured (Score=$score; TimeSec=$([math]::Round($duration.TotalSeconds,2)))" `
        -Details "Response=""$response""; Score=$score; DurationSec=$([math]::Round($duration.TotalSeconds,2)); Matched=$hitCount/$($keywords.Count)"
}

function Send-CASSIEMEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Endpoint,
        [Parameter(Mandatory)][psobject]$Payload
    )

    # Stub: if endpoint is a file path, append JSON; otherwise warn
    if (Test-Path -Path $Endpoint -IsValid) {
        $target = $Endpoint
        if ((Get-Item $target -ErrorAction SilentlyContinue) -and -not (Test-Path $target -PathType Leaf)) {
            Write-Warning "SIEM endpoint '$Endpoint' is not a file. Skipping forward."
            return
        }
        $dir = Split-Path -Path $target -Parent
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $Payload | ConvertTo-Json -Depth 5 | Add-Content -Path $target
    }
    else {
        Write-Verbose "SIEM endpoint '$Endpoint' not recognized; no forward performed (stub)."
    }
}

#endregion Scenario Helpers

#region Scenario Implementaties (lab-veilig)

function Invoke-CASBruteForce {
    <#
    .SYNOPSIS
        Simuleert een brute-force aanval binnen de VM.
    .DESCRIPTION
        In plaats van echt wachtwoorden te raden tegen een externe dienst,
        schrijft dit scenario "mislukte logins" naar een logbestand in de VM
        via PowerShell Direct. Dit is puur voor detectie-oefeningen in je lab.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VMName
    )

    if (-not $script:CasConfig) {
        throw 'CAS configuration is not initialized. Call Initialize-CASSimulator first.'
    }

    $delay = Get-CASScenarioSleep -Difficulty $script:CasConfig.Difficulty

    try {
        $attempts = switch ($script:CasConfig.Difficulty) {
            'Easy'   { 5 }
            'Medium' { 15 }
            'Hard'   { 30 }
        }

        $profile = Get-CASProfile -VMName $VMName
        Write-Verbose "Simulating brute-force attack on '$VMName' (difficulty $($script:CasConfig.Difficulty), Hardened=$($profile.Hardened), WeakCreds=$($profile.WeakCreds))..."

        $edu = if ($script:CasConfig.EducationalMode) {
            'Educational: Brute force attempts generate repeated failed logins; monitor for abnormal login patterns.'
        } else { $null }

        if ($script:CasConfig.SkipGuestLogon -or -not $script:CasConfig.GuestCredential) {
            Start-Sleep -Seconds $delay
            $status = if ($profile.Hardened -and -not $profile.WeakCreds) { 'Blocked' } else { 'Succeeded' }

            Write-CASLog -Scenario 'BruteForce' -VMName $VMName -Status $status `
                -Message "Simulated brute-force ($attempts attempts) on $VMName (guest login skipped)." `
                -Details ("GuestLog=Skipped; Delay(s)={0}; Profile(Hardened={1},WeakCreds={2}); {3}" -f $delay, $profile.Hardened, $profile.WeakCreds, $edu)
        }
        else {
            $scriptBlock = {
                param($Attempts, $Profile)

                $path = 'C:\CAS'
                if (-not (Test-Path $path)) {
                    New-Item -ItemType Directory -Path $path -Force | Out-Null
                }

                $logFile = Join-Path $path 'BruteForceSimulation.log'

                1..$Attempts | ForEach-Object {
                    $user = "labuser$($_)"
                    $line = "{0:u} FAILED_LOGIN Username={1}; Source=CAS-Bruteforce" -f (Get-Date), $user
                    Add-Content -Path $logFile -Value $line
                    Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 250)
                }

                [pscustomobject]@{
                    LogFile   = $logFile
                    Hardened  = $Profile.Hardened
                    WeakCreds = $Profile.WeakCreds
                }
            }

            $info = Invoke-Command -VMName $VMName -Credential $script:CasConfig.GuestCredential -ScriptBlock $scriptBlock -ArgumentList $attempts, $profile -ErrorAction Stop

            Start-Sleep -Seconds $delay

            $status = if ($profile.Hardened -and -not $profile.WeakCreds) { 'Blocked' } else { 'Succeeded' }

            Write-CASLog -Scenario 'BruteForce' -VMName $VMName -Status $status `
                -Message "Simulated brute-force ($attempts attempts) on $VMName." `
                -Details ("GuestLog={0}; Delay(s)={1}; Profile(Hardened={2},WeakCreds={3}); {4}" -f $info.LogFile, $delay, $profile.Hardened, $profile.WeakCreds, $edu)
        }
    }
    catch {
        Write-CASLog -Scenario 'BruteForce' -VMName $VMName -Status 'Failed' `
            -Message 'Brute-force simulation failed.' `
            -Details $_.Exception.Message
        throw
    }
}

function Invoke-CASPrivilegeEscalation {
    <#
    .SYNOPSIS
        Voert een privilege-check uit binnen de VM.
    .DESCRIPTION
        Controleert of de huidige gebruiker adminrechten heeft en logt de
        relevante info. Geen echte exploit, puur detectie/demo.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VMName
    )

    if (-not $script:CasConfig) {
        throw 'CAS configuration is not initialized. Call Initialize-CASSimulator first.'
    }

    $delay = Get-CASScenarioSleep -Difficulty $script:CasConfig.Difficulty

    try {
        Write-Verbose "Simulating privilege escalation assessment on '$VMName'..."

        $edu = if ($script:CasConfig.EducationalMode) {
            'Educational: Checks admin group membership; look for elevation attempts and token use.'
        } else { $null }

        $profile = Get-CASProfile -VMName $VMName

        if ($script:CasConfig.SkipGuestLogon -or -not $script:CasConfig.GuestCredential) {
            Start-Sleep -Seconds $delay

            $status = if ($profile.Hardened) { 'Blocked' } else { 'Succeeded' }

            Write-CASLog -Scenario 'PrivilegeEscalation' -VMName $VMName -Status $status `
                -Message "Privilege escalation check skipped guest login on $VMName." `
                -Details ("GuestLog=Skipped; Delay(s)={0}; Profile(Hardened={1}); {2}" -f $delay, $profile.Hardened, $edu)
        }
        else {
            $scriptBlock = {
                $path = 'C:\CAS'
                if (-not (Test-Path $path)) {
                    New-Item -ItemType Directory -Path $path -Force | Out-Null
                }

                $logFile = Join-Path $path 'PrivilegeEscalationSimulation.log'

                $isAdmin = ([Security.Principal.WindowsPrincipal] `
                    [Security.Principal.WindowsIdentity]::GetCurrent()
                ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

                $groups  = (whoami /groups) 2>$null
                $whoami  = (whoami) 2>$null

                $line = "{0:u} PRIV_CHECK User={1}; IsAdmin={2}" -f (Get-Date), $whoami, $isAdmin
                Add-Content -Path $logFile -Value $line
                Add-Content -Path $logFile -Value '--- GROUPS ---'
                $groups | ForEach-Object { Add-Content -Path $logFile -Value $_ }

                [pscustomobject]@{
                    User    = $whoami
                    IsAdmin = $isAdmin
                    LogFile = $logFile
                }
            }

            $info = Invoke-Command -VMName $VMName -Credential $script:CasConfig.GuestCredential -ScriptBlock $scriptBlock -ErrorAction Stop

            Start-Sleep -Seconds $delay

            $status  = if ($profile.Hardened -and -not $info.IsAdmin) { 'Blocked' } else { 'Succeeded' }
            $message = if ($info.IsAdmin) {
                "Privilege escalation check: user $($info.User) has admin rights."
            } else {
                "Privilege escalation check: user $($info.User) has no admin rights."
            }

            Write-CASLog -Scenario 'PrivilegeEscalation' -VMName $VMName -Status $status `
                -Message $message `
                -Details ("GuestLog={0}; Delay(s)={1}; {2}" -f $info.LogFile, $delay, $edu)
        }
    }
    catch {
        Write-CASLog -Scenario 'PrivilegeEscalation' -VMName $VMName -Status 'Failed' `
            -Message 'Privilege escalation simulation failed.' `
            -Details $_.Exception.Message
        throw
    }
}

function Invoke-CASPortScan {
    <#
    .SYNOPSIS
        Voert een simpele portscan uit vanaf de host.
    .DESCRIPTION
        Gebruikt Test-NetConnection tegen een kleine reeks poorten,
        alleen bedoeld voor je Hyper-V lab VMs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VMName
    )

    if (-not $script:CasConfig) {
        throw 'CAS configuration is not initialized. Call Initialize-CASSimulator first.'
    }

    $delay = Get-CASScenarioSleep -Difficulty $script:CasConfig.Difficulty

    try {
        Write-Verbose "Simulating port scan on '$VMName'..."

        $edu = if ($script:CasConfig.EducationalMode) {
            'Educational: Port scans enumerate exposed services; monitor for connection bursts on common ports.'
        } else { $null }

        $profile = Get-CASProfile -VMName $VMName
        $expectedOpen = @()
        if ($profile.AllowRDP) { $expectedOpen += 3389 }
        if ($profile.AllowSMB) { $expectedOpen += 445 }
        if ($profile.AllowWinRM) { $expectedOpen += 5985 }

        if ($script:CasConfig.SkipGuestLogon -or -not $script:CasConfig.GuestCredential) {
            Start-Sleep -Seconds $delay
            $status = if ($expectedOpen.Count -eq 0 -or $profile.Hardened) { 'Blocked' } else { 'Succeeded' }

            Write-CASLog -Scenario 'PortScan' -VMName $VMName -Status $status `
                -Message "Port scan skipped guest access for $VMName." `
                -Details ("TargetIP=Skipped; PortsChecked=Skipped; ExpectedOpen={0}; Delay(s)={1}; Profile(Hardened={2}) ; {3}" -f ($expectedOpen -join ','), $delay, $profile.Hardened, $edu)
        }
        else {
            $targetIP = Get-CASVMIP -VMName $VMName
            if (-not $targetIP) {
                throw "Could not determine IP address for VM '$VMName'."
            }

            $ports = switch ($script:CasConfig.Difficulty) {
                'Easy'   { 22, 80, 3389, 445, 5985 }
                'Medium' { 22, 80, 135, 139, 445, 3389, 5985 }
                'Hard'   { 22, 80, 135, 139, 445, 3389, 5985, 5986 }
            }

            $openPorts = @()
            foreach ($p in $ports) {
                $res = Test-NetConnection -ComputerName $targetIP -Port $p -WarningAction SilentlyContinue
                $isAllowed = $expectedOpen -contains $p
                if ($res.TcpTestSucceeded -and $isAllowed) {
                    $openPorts += $p
                }
            }

            Start-Sleep -Seconds $delay
            $status = if ($openPorts.Count -gt 0) { 'Succeeded' } else { 'Blocked' }

            Write-CASLog -Scenario 'PortScan' -VMName $VMName -Status $status `
                -Message "Port scan complete against $targetIP (VM $VMName)." `
                -Details ("PortsChecked={0}; OpenPorts={1}; ExpectedOpen={2}; Delay(s)={3}; Profile(Hardened={4}); {5}" -f ($ports -join ','), ($openPorts -join ','), ($expectedOpen -join ','), $delay, $profile.Hardened, $edu)
        }
    }
    catch {
        Write-CASLog -Scenario 'PortScan' -VMName $VMName -Status 'Failed' `
            -Message 'Port scan simulation failed.' `
            -Details $_.Exception.Message
        throw
    }
}

function Invoke-CASLateralMovement {
    <#
    .SYNOPSIS
        Simuleert laterale beweging (log trail).
    .DESCRIPTION
        Schrijft een audit trail van RDP/SMB/generic hops. In host-only modus
        worden alleen logregels gemaakt; met guest login wordt een logbestand
        in de VM aangemaakt (PowerShell Direct).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VMName
    )

    if (-not $script:CasConfig) {
        throw 'CAS configuration is not initialized. Call Initialize-CASSimulator first.'
    }

    $delay = Get-CASScenarioSleep -Difficulty $script:CasConfig.Difficulty

    try {
        Write-Verbose "Simulating lateral movement trail on '$VMName'..."

        $hops = switch ($script:CasConfig.Difficulty) {
            'Easy'   { @('RDP:3389->ServiceAccount','SMB:445->AdminShare') }
            'Medium' { @('RDP:3389->ServiceAccount','SMB:445->AdminShare','WMI:135->SvcMgmt') }
            'Hard'   { @('RDP:3389->ServiceAccount','SMB:445->AdminShare','WMI:135->SvcMgmt','WinRM:5985->Automation') }
        }

        $edu = if ($script:CasConfig.EducationalMode) {
            'Educational: Lateral movement often leaves login events (4624/4625), service creations, and SMB/WMI traffic.'
        } else { $null }

        $profile = Get-CASProfile -VMName $VMName

        if ($script:CasConfig.SkipGuestLogon -or -not $script:CasConfig.GuestCredential) {
            Start-Sleep -Seconds $delay
            $status = if ($profile.Hardened) { 'Blocked' } else { 'Succeeded' }

            Write-CASLog -Scenario 'LateralMovement' -VMName $VMName -Status $status `
                -Message "Simulated lateral movement hops on $VMName (host-only)." `
                -Details ("Hops={0}; GuestLog=Skipped; Delay(s)={1}; Profile(Hardened={2}); {3}" -f ($hops -join '|'), $delay, $profile.Hardened, $edu)
        }
        else {
            $scriptBlock = {
                param($Hops)
                $path = 'C:\CAS'
                if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
                $logFile = Join-Path $path 'LateralMovementSimulation.log'
                foreach ($h in $Hops) {
                    $line = "{0:u} LATERAL_HOP {1}; Source=CAS-LateralMovement" -f (Get-Date), $h
                    Add-Content -Path $logFile -Value $line
                    Start-Sleep -Milliseconds (Get-Random -Minimum 80 -Maximum 250)
                }
                return $logFile
            }

            $logFileInGuest = Invoke-Command -VMName $VMName -Credential $script:CasConfig.GuestCredential -ScriptBlock $scriptBlock -ArgumentList $hops -ErrorAction Stop
            Start-Sleep -Seconds $delay

            $status = if ($profile.Hardened -and -not $profile.AllowSMB -and -not $profile.AllowRDP) { 'Blocked' } else { 'Succeeded' }

            Write-CASLog -Scenario 'LateralMovement' -VMName $VMName -Status $status `
                -Message "Simulated lateral movement hops on $VMName." `
                -Details ("Hops={0}; GuestLog={1}; Delay(s)={2}; Profile(Hardened={3},RDP={4},SMB={5}); {6}" -f ($hops -join '|'), $logFileInGuest, $delay, $profile.Hardened, $profile.AllowRDP, $profile.AllowSMB, $edu)
        }
    }
    catch {
        Write-CASLog -Scenario 'LateralMovement' -VMName $VMName -Status 'Failed' `
            -Message 'Lateral movement simulation failed.' `
            -Details $_.Exception.Message
        throw
    }
}

function Invoke-CASScenario {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('BruteForce','PrivilegeEscalation','PortScan','LateralMovement')]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$VMName
    )

    switch ($Name) {
        'BruteForce'          { Invoke-CASBruteForce           -VMName $VMName }
        'PrivilegeEscalation' { Invoke-CASPrivilegeEscalation  -VMName $VMName }
        'PortScan'            { Invoke-CASPortScan             -VMName $VMName }
        'LateralMovement'     { Invoke-CASLateralMovement      -VMName $VMName }
    }
}

#endregion Scenario Implementaties

#region Orchestratie & Parallelle Uitvoering

function Invoke-CASSimulation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$VMNames,
        [Parameter()][string[]]$AttackTypes = $script:CasConfig.AttackTypes,
        [Parameter()][switch]$Parallel
    )

    if (-not $script:CasConfig) {
        throw 'CAS configuration is not initialized. Call Initialize-CASSimulator first.'
    }
    if (-not $script:CasSessionId) {
        $script:CasSessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
    }

    $cfg = $script:CasConfig

    $targets = foreach ($vm in $VMNames) {
        foreach ($atk in $AttackTypes) {
            [pscustomobject]@{
                VMName = $vm
                Attack = $atk
            }
        }
    }

    $results = @()

    if ($Parallel) {
        if ($cfg.ChallengeMode) {
            Write-Warning "ChallengeMode is enabled; forcing serial execution to prompt operator responses."
            $Parallel = $false
        }
    }

    if ($Parallel) {
        Write-Verbose "Running simulations in parallel using Start-Job..."

        $modulePath = $script:CasModulePath

        $jobs = foreach ($t in $targets) {
            Start-Job -ScriptBlock {
                param(
                    $vm, $attack,
                    $difficulty, $numberOfVMs, $attackTypes,
                    $labPrefix, $virtualSwitch,
                    $logRoot, $reportRoot,
                    $sessionId, $modulePath,
                    $skipGuestLogon,
                    $siemEndpoint,
                    $educationalMode,
                    $challengeMode
                )

                Import-Module $modulePath -Force | Out-Null

                Initialize-CASSimulator -Difficulty $difficulty `
                    -NumberOfVMs $numberOfVMs `
                    -AttackTypes $attackTypes `
                    -LabPrefix $labPrefix `
                    -VirtualSwitch $virtualSwitch `
                    -LogPath $logRoot `
                    -ReportPath $reportRoot `
                    -SessionId $sessionId `
                    -AllowGuestLogon:(!$skipGuestLogon) `
                    -SIEMEndpoint $siemEndpoint `
                    -EducationalMode:$educationalMode `
                    -ChallengeMode:$challengeMode | Out-Null

                Invoke-CASScenario -Name $attack -VMName $vm
            } -ArgumentList $t.VMName, $t.Attack,
                    $cfg.Difficulty, $cfg.NumberOfVMs, $cfg.AttackTypes,
                    $cfg.LabPrefix, $cfg.VirtualSwitch,
                    $cfg.LogRoot, $cfg.ReportRoot,
                    $script:CasSessionId, $modulePath,
                    $cfg.SkipGuestLogon,
                    $cfg.SIEMEndpoint,
                    $cfg.EducationalMode,
                    $cfg.ChallengeMode
        }

        $jobResults = Receive-Job -Job $jobs -Wait -AutoRemoveJob
        if ($jobResults) { $results += $jobResults }
    }
    else {
        foreach ($t in $targets) {
            $res = Invoke-CASScenario -Name $t.Attack -VMName $t.VMName
            if ($res) {
                $results += $res
            }
            if ($cfg.ChallengeMode) {
                Get-CASOperatorResponse -Scenario $t.Attack -VMName $t.VMName
            }
        }
    }

    return $results
}

#endregion Orchestratie & Parallelle Uitvoering

#region Rapportage

function New-CASReport {
    [CmdletBinding()]
    param(
        [Parameter()][string]$Format = 'Html'  # Html of Csv
    )

    if (-not $script:CasConfig) {
        throw 'CAS configuration is not initialized. Call Initialize-CASSimulator first.'
    }
    if (-not $script:CasSessionId) {
        Write-Warning "No active session id. Did you run any simulations?"
        return
    }

    $logRoot    = $script:CasConfig.LogRoot
    $reportRoot = $script:CasConfig.ReportRoot

    $csvFile = Get-ChildItem -Path $logRoot -Filter "CAS-Log-$($script:CasSessionId).csv" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $csvFile) {
        Write-Warning "No CSV log found for session '$($script:CasSessionId)'."
        return
    }

    $data = Import-Csv -Path $csvFile.FullName

    switch ($Format.ToLower()) {
        'csv' {
            $reportPath = Join-Path $reportRoot "CAS-Report-$($script:CasSessionId).csv"
            $data | Export-Csv -NoTypeInformation -Path $reportPath
        }
        'html' {
            $reportPath = Join-Path $reportRoot "CAS-Report-$($script:CasSessionId).html"

            $style = @"
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin:20px; }
h1 { color:#333; }
table { border-collapse:collapse; width:100%; margin-top:10px; }
th, td { border:1px solid #ccc; padding:4px 6px; font-size:12px; }
th { background:#f0f0f0; text-align:left; }
tr:nth-child(even) { background:#fafafa; }
.badge-success { color:#155724; background:#d4edda; padding:2px 6px; border-radius:4px; }
.badge-failed { color:#721c24; background:#f8d7da; padding:2px 6px; border-radius:4px; }
.badge-info { color:#0c5460; background:#d1ecf1; padding:2px 6px; border-radius:4px; }
.badge-blocked { color:#856404; background:#fff3cd; padding:2px 6px; border-radius:4px; }
.summary { margin-top:10px; padding:10px; background:#f7f7f7; border:1px solid #e0e0e0; }
</style>
"@

            $rows = $data | Sort-Object VMName, Scenario | ForEach-Object {
                $badgeClass = switch ($_.Status) {
                    'Succeeded' { 'badge-success' }
                    'OperatorResponse' { 'badge-info' }
                    'Blocked' { 'badge-blocked' }
                    default { 'badge-failed' }
                }
                $statusHtml = "<span class='$badgeClass'>$($_.Status)</span>"

                "<tr>" +
                    "<td>$($_.Timestamp)</td>" +
                    "<td>$($_.VMName)</td>" +
                    "<td>$($_.Scenario)</td>" +
                    "<td>$($_.Difficulty)</td>" +
                    "<td>$statusHtml</td>" +
                    "<td>$($_.Message)</td>" +
                    "<td>$($_.Details)</td>" +
                "</tr>"
            }

            $table = @"
<table>
<thead>
<tr>
    <th>Timestamp</th>
    <th>VM</th>
    <th>Scenario</th>
    <th>Difficulty</th>
    <th>Status</th>
    <th>Message</th>
    <th>Details</th>
</tr>
</thead>
<tbody>
$($rows -join "`r`n")
</tbody>
</table>
"@

            $scenarioCounts = ($data | Group-Object Scenario | ForEach-Object {
                "{ name: '$($_.Name)', total: $($_.Count), success: $($_.Group | Where-Object { $_.Status -eq 'Succeeded' }).Count }"
            }) -join ","

            $educationalNote = if ($script:CasConfig.EducationalMode) {
                "<p><strong>Educational mode:</strong> enabled (details per scenario included).</p>"
            } else { '' }

            $challenge = $data | Where-Object { $_.Status -eq 'OperatorResponse' }
            $challengeCount = $challenge.Count
            $avgScore = if ($challengeCount -gt 0) {
                ($challenge | ForEach-Object {
                    if ($_.Details -match 'Score=(\d+(?:\.\d+)?)') { [double]$Matches[1] }
                } | Measure-Object -Average).Average
            } else { $null }
            $avgDuration = if ($challengeCount -gt 0) {
                ($challenge | ForEach-Object {
                    if ($_.Details -match 'DurationSec=(\d+(?:\.\d+)?)') { [double]$Matches[1] }
                } | Measure-Object -Average).Average
            } else { $null }
            $challengeSummary = if ($challengeCount -gt 0) {
                "<p><strong>Challenge responses:</strong> $challengeCount, Avg score: $([math]::Round($avgScore,1))%, Avg time: $([math]::Round($avgDuration,1)) sec</p>"
            } else { '' }

            $lib = Get-CASScenarioLibrary | ForEach-Object {
                "<li>$($_.Name) v$($_.Version) - $($_.Description) (Level: $($_.Difficulty))</li>"
            } | Out-String

            $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<title>Cyber Attack Simulator Report - $($script:CasSessionId)</title>
$style
</head>
<body>
<h1>Cyber Attack Simulator Report</h1>
<p><strong>Session:</strong> $($script:CasSessionId)</p>
<p><strong>Difficulty:</strong> $($script:CasConfig.Difficulty)</p>
<p><strong>Attack types:</strong> $($script:CasConfig.AttackTypes -join ', ')</p>
$educationalNote
$challengeSummary
<div class="summary">
<canvas id="chart" width="400" height="200"></canvas>
<p id="summaryText"></p>
</div>
$table
<h3>Scenario Library</h3>
<ul>
$lib
</ul>
<script>
(function() {
    var data = [$scenarioCounts];
    var successes = data.reduce((a,b)=>a+b.success,0);
    var total = data.reduce((a,b)=>a+b.total,0);
    var ctx = document.getElementById('chart').getContext('2d');
    var labels = data.map(d=>d.name);
    var successData = data.map(d=>d.success);
    var totalData = data.map(d=>d.total);
    var max = Math.max.apply(null,totalData.concat([1]));
    function drawBar(x, y, w, h, color){
        ctx.fillStyle = color; ctx.fillRect(x,y,w,h);
    }
    ctx.clearRect(0,0,400,200);
    var barWidth = 30; var gap = 10; var startX = 30; var baseY = 180; var scale = max>0 ? 120/max : 1;
    labels.forEach(function(lbl, i){
        var x = startX + i*(barWidth*2+gap);
        var totalH = totalData[i]*scale;
        var succH = successData[i]*scale;
        drawBar(x, baseY-totalH, barWidth, totalH, '#d0d0d0');
        drawBar(x+barWidth, baseY-succH, barWidth, succH, '#4caf50');
        ctx.fillStyle='#333'; ctx.fillText(lbl, x, baseY+12);
    });
    document.getElementById('summaryText').textContent = 'Total: ' + total + ' | Succeeded: ' + successes + ' | Failed: ' + (total - successes);
})();
</script>
</body>
</html>
"@

            $html | Set-Content -Path $reportPath -Encoding UTF8
        }
        'pdf' {
            # Simple stub: generate HTML and save with .pdf extension (consumer can print to PDF)
            $reportPath = Join-Path $reportRoot "CAS-Report-$($script:CasSessionId).pdf"
            $tempHtml   = New-CASReport -Format Html
            Copy-Item -Path $tempHtml -Destination $reportPath -Force
            Write-Warning "PDF export is stubbed by copying HTML to .pdf. Use a PDF printer or converter for true PDF."
        }
        default {
            throw "Unsupported report format '$Format'. Use 'Html', 'Pdf' or 'Csv'."
        }
    }

    Write-Verbose "Report generated at '$reportPath'."
    return $reportPath
}

#endregion Rapportage

Export-ModuleMember -Function *-CAS*
