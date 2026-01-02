<#
.SYNOPSIS
    Professional GUI for Cyber Attack Simulator with tabbed interface.

.DESCRIPTION
    Windows Forms GUI with improved layout, organization, and visual design.
    Features:
    - Tab-based organization (Basic, Attacks, Paths, Options)
    - Grouped controls with proper spacing
    - Better visual hierarchy and alignment
    - Live output display
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$modulePath   = Join-Path $PSScriptRoot 'CyberAttackSimulator.Core.psm1'
$defaultVhdPath = Join-Path $PSScriptRoot 'VMS\BaseVM\Virtual Hard Disks\BaseVM.vhdx'

$defaultVhdPath = Join-Path $PSScriptRoot 'VMS\BaseVM\Virtual Hard Disks\BaseVM.vhdx'
$defaultIsoDir  = Join-Path $PSScriptRoot 'VMS\ISO'
$defaultIso = $null
if (Test-Path $defaultIsoDir) {
    $defaultIso = Get-ChildItem -Path $defaultIsoDir -Filter *.iso -File -ErrorAction SilentlyContinue | Select-Object -First 1
}

# Main form
$form               = New-Object System.Windows.Forms.Form
$form.Text          = 'Cyber Attack Simulator - Configuration'
$form.Size          = New-Object System.Drawing.Size(800, 750)
$form.StartPosition = 'CenterScreen'
$form.Font          = New-Object System.Drawing.Font('Segoe UI', 9)
$form.BackColor     = [System.Drawing.Color]::FromArgb(240, 240, 240)

# Tab Control
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(770, 450)
$tabControl.Anchor = 'Top,Left,Right'

#region Tab 1: Basic Configuration
$tabBasic = New-Object System.Windows.Forms.TabPage
$tabBasic.Text = 'Basic Configuration'
$tabBasic.Padding = New-Object System.Windows.Forms.Padding(15, 15, 15, 15)
$tabBasic.BackColor = [System.Drawing.Color]::White

# Difficulty Group
$grpDifficulty = New-Object System.Windows.Forms.GroupBox
$grpDifficulty.Text = 'Simulation Difficulty'
$grpDifficulty.Location = New-Object System.Drawing.Point(15, 15)
$grpDifficulty.Size = New-Object System.Drawing.Size(700, 80)
$grpDifficulty.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$lblDiff       = New-Object System.Windows.Forms.Label
$lblDiff.Text  = 'Difficulty Level:'
$lblDiff.Location = New-Object System.Drawing.Point(20, 30)
$lblDiff.AutoSize = $true
$lblDiff.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$cbDiff = New-Object System.Windows.Forms.ComboBox
$cbDiff.Location = New-Object System.Drawing.Point(150, 26)
$cbDiff.Width = 150
$cbDiff.DropDownStyle = 'DropDownList'
@('Easy','Medium','Hard') | ForEach-Object { [void]$cbDiff.Items.Add($_) }
$cbDiff.SelectedIndex = 0

$lblDiffDesc = New-Object System.Windows.Forms.Label
$lblDiffDesc.Text = 'Easy: Slower attacks | Medium: Balanced | Hard: Advanced scenarios'
$lblDiffDesc.Location = New-Object System.Drawing.Point(320, 30)
$lblDiffDesc.AutoSize = $true
$lblDiffDesc.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)
$lblDiffDesc.ForeColor = [System.Drawing.Color]::Gray

$grpDifficulty.Controls.AddRange(@($lblDiff, $cbDiff, $lblDiffDesc))

# VM Configuration Group
$grpVMs = New-Object System.Windows.Forms.GroupBox
$grpVMs.Text = 'Virtual Machine Setup'
$grpVMs.Location = New-Object System.Drawing.Point(15, 105)
$grpVMs.Size = New-Object System.Drawing.Size(700, 100)
$grpVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$lblVMs = New-Object System.Windows.Forms.Label
$lblVMs.Text = 'Number of VMs:'
$lblVMs.Location = New-Object System.Drawing.Point(20, 30)
$lblVMs.AutoSize = $true
$lblVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$nudVMs = New-Object System.Windows.Forms.NumericUpDown
$nudVMs.Location = New-Object System.Drawing.Point(150, 26)
$nudVMs.Width = 100
$nudVMs.Minimum = 1
$nudVMs.Maximum = 50
$nudVMs.Value = 2

$lblLabPrefix = New-Object System.Windows.Forms.Label
$lblLabPrefix.Text = 'Lab Prefix:'
$lblLabPrefix.Location = New-Object System.Drawing.Point(320, 30)
$lblLabPrefix.AutoSize = $true
$lblLabPrefix.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$txtLabPrefix = New-Object System.Windows.Forms.TextBox
$txtLabPrefix.Location = New-Object System.Drawing.Point(420, 26)
$txtLabPrefix.Width = 250
$txtLabPrefix.Text = 'CAS-LAB'

$lblSwitch = New-Object System.Windows.Forms.Label
$lblSwitch.Text = 'Virtual Switch:'
$lblSwitch.Location = New-Object System.Drawing.Point(20, 60)
$lblSwitch.AutoSize = $true
$lblSwitch.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$txtSwitch = New-Object System.Windows.Forms.TextBox
$txtSwitch.Location = New-Object System.Drawing.Point(150, 56)
$txtSwitch.Width = 220
$txtSwitch.Text = 'CAS-Switch'

$grpVMs.Controls.AddRange(@($lblVMs, $nudVMs, $lblLabPrefix, $txtLabPrefix, $lblSwitch, $txtSwitch))

$tabBasic.Controls.AddRange(@($grpDifficulty, $grpVMs))
$tabControl.TabPages.Add($tabBasic)
#endregion

#region Tab 2: Attack Types
$tabAttacks = New-Object System.Windows.Forms.TabPage
$tabAttacks.Text = 'Attack Types & Modes'
$tabAttacks.Padding = New-Object System.Windows.Forms.Padding(15, 15, 15, 15)
$tabAttacks.BackColor = [System.Drawing.Color]::White

# Attack scenarios group
$grpScenarios = New-Object System.Windows.Forms.GroupBox
$grpScenarios.Text = 'Select Attack Scenarios'
$grpScenarios.Location = New-Object System.Drawing.Point(15, 15)
$grpScenarios.Size = New-Object System.Drawing.Size(700, 140)
$grpScenarios.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$clbAttacks = New-Object System.Windows.Forms.CheckedListBox
$clbAttacks.Location = New-Object System.Drawing.Point(20, 30)
$clbAttacks.Size = New-Object System.Drawing.Size(660, 100)
$clbAttacks.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$clbAttacks.CheckOnClick = $true
@('BruteForce','PrivilegeEscalation','PortScan','LateralMovement') | ForEach-Object {
    [void]$clbAttacks.Items.Add($_, $true)
}

$grpScenarios.Controls.Add($clbAttacks)

# Execution modes group
$grpModes = New-Object System.Windows.Forms.GroupBox
$grpModes.Text = 'Execution Modes'
$grpModes.Location = New-Object System.Drawing.Point(15, 165)
$grpModes.Size = New-Object System.Drawing.Size(700, 120)
$grpModes.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$chkParallel = New-Object System.Windows.Forms.CheckBox
$chkParallel.Text = 'Run scenarios in parallel (faster execution)'
$chkParallel.Location = New-Object System.Drawing.Point(20, 30)
$chkParallel.AutoSize = $true
$chkParallel.Checked = $true
$chkParallel.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$chkChallenge = New-Object System.Windows.Forms.CheckBox
$chkChallenge.Text = 'Challenge mode (operator response scoring)'
$chkChallenge.Location = New-Object System.Drawing.Point(20, 55)
$chkChallenge.AutoSize = $true
$chkChallenge.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$chkEdu = New-Object System.Windows.Forms.CheckBox
$chkEdu.Text = 'Educational mode (add explanations to logs)'
$chkEdu.Location = New-Object System.Drawing.Point(20, 80)
$chkEdu.AutoSize = $true
$chkEdu.Checked = $true
$chkEdu.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$grpModes.Controls.AddRange(@($chkParallel, $chkChallenge, $chkEdu))

$tabAttacks.Controls.AddRange(@($grpScenarios, $grpModes))
$tabControl.TabPages.Add($tabAttacks)
#endregion

#region Tab 3: Guest & SIEM
$tabGuestSIEM = New-Object System.Windows.Forms.TabPage
$tabGuestSIEM.Text = 'Guest & SIEM'
$tabGuestSIEM.Padding = New-Object System.Windows.Forms.Padding(15, 15, 15, 15)
$tabGuestSIEM.BackColor = [System.Drawing.Color]::White

# Guest Logon Group
$grpGuest = New-Object System.Windows.Forms.GroupBox
$grpGuest.Text = 'Guest VM Access (PowerShell Direct)'
$grpGuest.Location = New-Object System.Drawing.Point(15, 15)
$grpGuest.Size = New-Object System.Drawing.Size(700, 140)
$grpGuest.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$chkGuest = New-Object System.Windows.Forms.CheckBox
$chkGuest.Text = 'Guest VM logon is now enabled by default; supply credentials below'
$chkGuest.Location = New-Object System.Drawing.Point(20, 25)
$chkGuest.AutoSize = $true
$chkGuest.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$chkGuest.Checked = $true

$lblGuestUser = New-Object System.Windows.Forms.Label
$lblGuestUser.Text = 'Username:'
$lblGuestUser.Location = New-Object System.Drawing.Point(40, 55)
$lblGuestUser.AutoSize = $true

$txtGuestUser = New-Object System.Windows.Forms.TextBox
$txtGuestUser.Location = New-Object System.Drawing.Point(140, 51)
$txtGuestUser.Width = 200
$txtGuestUser.Text = ''

$lblGuestPass = New-Object System.Windows.Forms.Label
$lblGuestPass.Text = 'Password:'
$lblGuestPass.Location = New-Object System.Drawing.Point(400, 55)
$lblGuestPass.AutoSize = $true

$txtGuestPass = New-Object System.Windows.Forms.TextBox
$txtGuestPass.Location = New-Object System.Drawing.Point(480, 51)
$txtGuestPass.Width = 200
$txtGuestPass.UseSystemPasswordChar = $true

$grpGuest.Controls.AddRange(@($chkGuest, $lblGuestUser, $txtGuestUser, $lblGuestPass, $txtGuestPass))

# SIEM Group
$grpSIEM = New-Object System.Windows.Forms.GroupBox
$grpSIEM.Text = 'SIEM Integration'
$grpSIEM.Location = New-Object System.Drawing.Point(15, 165)
$grpSIEM.Size = New-Object System.Drawing.Size(700, 80)
$grpSIEM.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$lblSiem = New-Object System.Windows.Forms.Label
$lblSiem.Text = 'SIEM Endpoint (file path or HTTP URL):'
$lblSiem.Location = New-Object System.Drawing.Point(20, 30)
$lblSiem.AutoSize = $true

$txtSiem = New-Object System.Windows.Forms.TextBox
$txtSiem.Location = New-Object System.Drawing.Point(230, 26)
$txtSiem.Width = 450
$txtSiem.Text = ''

$grpSIEM.Controls.AddRange(@($lblSiem, $txtSiem))

$tabGuestSIEM.Controls.AddRange(@($grpGuest, $grpSIEM))
$tabControl.TabPages.Add($tabGuestSIEM)
#endregion

#region Tab 4: Paths & Storage
$tabPaths = New-Object System.Windows.Forms.TabPage
$tabPaths.Text = 'Storage & Images'
$tabPaths.Padding = New-Object System.Windows.Forms.Padding(15, 15, 15, 15)
$tabPaths.BackColor = [System.Drawing.Color]::White

# Output paths group
$grpOutput = New-Object System.Windows.Forms.GroupBox
$grpOutput.Text = 'Output Locations'
$grpOutput.Location = New-Object System.Drawing.Point(15, 15)
$grpOutput.Size = New-Object System.Drawing.Size(700, 100)
$grpOutput.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = 'Log Path:'
$lblLog.Location = New-Object System.Drawing.Point(20, 30)
$lblLog.AutoSize = $true

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(110, 26)
$txtLog.Width = 570
$txtLog.Text = (Join-Path $PSScriptRoot 'Logs')

$lblRpt = New-Object System.Windows.Forms.Label
$lblRpt.Text = 'Report Path:'
$lblRpt.Location = New-Object System.Drawing.Point(20, 60)
$lblRpt.AutoSize = $true

$txtRpt = New-Object System.Windows.Forms.TextBox
$txtRpt.Location = New-Object System.Drawing.Point(110, 56)
$txtRpt.Width = 570
$txtRpt.Text = (Join-Path $PSScriptRoot 'Reports')

$grpOutput.Controls.AddRange(@($lblLog, $txtLog, $lblRpt, $txtRpt))

# VM images group
$grpImages = New-Object System.Windows.Forms.GroupBox
$grpImages.Text = 'VM Base Images'
$grpImages.Location = New-Object System.Drawing.Point(15, 125)
$grpImages.Size = New-Object System.Drawing.Size(700, 110)
$grpImages.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$lblVhd = New-Object System.Windows.Forms.Label
$lblVhd.Text = 'VHD/VHDX (Windows image):'
$lblVhd.Location = New-Object System.Drawing.Point(20, 30)
$lblVhd.AutoSize = $true

$txtVhd = New-Object System.Windows.Forms.TextBox
$txtVhd.Location = New-Object System.Drawing.Point(230, 26)
$txtVhd.Width = 450
$txtVhd.Text = if (Test-Path $defaultVhdPath) { $defaultVhdPath } else { '' }

$lblIso = New-Object System.Windows.Forms.Label
$lblIso.Text = 'ISO path (if VHD unavailable):'
$lblIso.Location = New-Object System.Drawing.Point(20, 60)
$lblIso.AutoSize = $true

$txtIso = New-Object System.Windows.Forms.TextBox
$txtIso.Location = New-Object System.Drawing.Point(230, 56)
$txtIso.Width = 450
$txtIso.Text = if ($defaultIso) { $defaultIso.FullName } else { '' }

$grpImages.Controls.AddRange(@($lblVhd, $txtVhd, $lblIso, $txtIso))

$tabPaths.Controls.AddRange(@($grpOutput, $grpImages))
$tabControl.TabPages.Add($tabPaths)
#endregion

$form.Controls.Add($tabControl)

#region Output & Run Button Section
# Separator
$panelBottom = New-Object System.Windows.Forms.Panel
$panelBottom.Location = New-Object System.Drawing.Point(10, 470)
$panelBottom.Size = New-Object System.Drawing.Size(770, 240)
$panelBottom.Anchor = 'Top,Left,Right,Bottom'

# Run button with styling
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'START SIMULATION'
$btnRun.Location = New-Object System.Drawing.Point(15, 15)
$btnRun.Size = New-Object System.Drawing.Size(150, 40)
$btnRun.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$btnRun.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
$btnRun.ForeColor = [System.Drawing.Color]::White
$btnRun.FlatStyle = 'Flat'
$btnRun.Anchor = 'Top,Left'

# Output label
$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Text = 'Simulation Output:'
$lblOutput.Location = New-Object System.Drawing.Point(15, 60)
$lblOutput.AutoSize = $true
$lblOutput.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

# Output textbox
$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(15, 85)
$txtOutput.Size = New-Object System.Drawing.Size(740, 140)
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = 'Vertical'
$txtOutput.ReadOnly = $true
$txtOutput.Font = New-Object System.Drawing.Font('Consolas', 9)
$txtOutput.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 25)
$txtOutput.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 0)
$txtOutput.Anchor = 'Top,Left,Right,Bottom'

$panelBottom.Controls.AddRange(@($btnRun, $lblOutput, $txtOutput))
$form.Controls.Add($panelBottom)
#endregion

$btnRun.Add_Click({
    $txtOutput.Clear()
    $txtOutput.AppendText("-------------------------------------------`r`n")
    $txtOutput.AppendText("  CAS SIMULATION STARTED`r`n")
    $txtOutput.AppendText("-------------------------------------------`r`n`r`n")

    try {
        Import-Module $modulePath -Force

        $difficulty = $cbDiff.SelectedItem
        $numVMs     = [int]$nudVMs.Value
        $labPrefix  = $txtLabPrefix.Text
        $vswitch    = $txtSwitch.Text
        
        $attacks    = @()
        foreach ($item in $clbAttacks.CheckedItems) {
            $attacks += [string]$item
        }
        if ($attacks.Count -eq 0) {
            $txtOutput.AppendText("[!] ERROR: Select at least one attack type.`r`n")
            return
        }

        $logPath    = $txtLog.Text
        $reportPath = $txtRpt.Text
        $siem       = $txtSiem.Text
        $vhdPath    = $txtVhd.Text
        $isoPath    = $txtIso.Text

        $guestCred = $null
        if ($chkGuest.Checked -and $txtGuestUser.Text -and $txtGuestPass.Text) {
            $sec = ConvertTo-SecureString $txtGuestPass.Text -AsPlainText -Force
            $guestCred = New-Object System.Management.Automation.PSCredential ($txtGuestUser.Text, $sec)
        }

        $txtOutput.AppendText("[*] Difficulty: $difficulty`r`n")
        $txtOutput.AppendText("[*] VMs: $numVMs | Attacks: $($attacks -join ', ')`r`n")
        $txtOutput.AppendText("[*] Parallel: $($chkParallel.Checked) | Challenge: $($chkChallenge.Checked)`r`n`r`n")
        
        $txtOutput.AppendText("[+] Initializing CAS Simulator...`r`n")

        [void](Initialize-CASSimulator -Difficulty $difficulty `
            -NumberOfVMs $numVMs `
            -AttackTypes $attacks `
            -LabPrefix $labPrefix `
            -VirtualSwitch $vswitch `
            -LogPath $logPath `
            -ReportPath $reportPath `
            -VHDPath $vhdPath `
            -ISOPath $isoPath `
            -ChallengeMode:$chkChallenge.Checked `
            -AllowGuestLogon:$true `
            -GuestCredential $guestCred `
            -SIEMEndpoint $siem `
            -EducationalMode:$chkEdu.Checked)

        $txtOutput.AppendText("[+] Creating lab VMs...`r`n")
        $vmNames = New-CASLab

        if ($chkChallenge.Checked -and $chkParallel.Checked) {
            $txtOutput.AppendText("[!] Challenge mode requires serial execution; Parallel flag disabled.`r`n")
        }

        $parallel = $chkParallel.Checked -and -not $chkChallenge.Checked
        $txtOutput.AppendText("[+] Running scenarios (Parallel=$parallel)...`r`n`r`n")
        [void](Invoke-CASSimulation -VMNames $vmNames -AttackTypes $attacks -Parallel:$parallel)

        $txtOutput.AppendText("`r`n[+] Generating HTML report...`r`n")
        $report = New-CASReport -Format Html

        $txtOutput.AppendText("`r`n")
        $txtOutput.AppendText("-------------------------------------------`r`n")
        $txtOutput.AppendText("  SIMULATION COMPLETE`r`n")
        $txtOutput.AppendText("-------------------------------------------`r`n")
        $txtOutput.AppendText("[OK] Report generated: $report`r`n")
        $txtOutput.AppendText("[OK] Logs: $logPath`r`n")
    }
    catch {
        $txtOutput.AppendText("`r`n[ERROR] $($_.Exception.Message)`r`n")
        $txtOutput.AppendText($_.ScriptStackTrace)
    }
})

[void]$form.ShowDialog()
