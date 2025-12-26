<#
.SYNOPSIS
    Eenvoudige GUI voor het starten van de Cyber Attack Simulator.

.DESCRIPTION
    Windows Forms GUI waarmee je:
    - Difficulty kiest
    - Aantal VMs instelt
    - Scenario's aanvinkt
    - Parallel aan/uit zet
    - De run start en de output/rapportlocatie ziet
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$modulePath   = Join-Path $PSScriptRoot 'CyberAttackSimulator.Core.psm1'
$defaultVhdPath = Join-Path $PSScriptRoot 'VMS\BaseVM\Virtual Hard Disks\BaseVM.vhdx'

$form               = New-Object System.Windows.Forms.Form
$form.Text          = 'Cyber Attack Simulator'
$form.Size          = New-Object System.Drawing.Size(600, 650)
$form.StartPosition = 'CenterScreen'

# Difficulty
$lblDiff       = New-Object System.Windows.Forms.Label
$lblDiff.Text  = 'Difficulty:'
$lblDiff.Location = New-Object System.Drawing.Point(20,20)
$lblDiff.AutoSize = $true

$cbDiff = New-Object System.Windows.Forms.ComboBox
$cbDiff.Location = New-Object System.Drawing.Point(120,16)
$cbDiff.Width = 120
$cbDiff.DropDownStyle = 'DropDownList'
@('Easy','Medium','Hard') | ForEach-Object { [void]$cbDiff.Items.Add($_) }
$cbDiff.SelectedIndex = 0

# Number of VMs
$lblVMs = New-Object System.Windows.Forms.Label
$lblVMs.Text = 'Number of VMs:'
$lblVMs.Location = New-Object System.Drawing.Point(20,55)
$lblVMs.AutoSize = $true

$nudVMs = New-Object System.Windows.Forms.NumericUpDown
$nudVMs.Location = New-Object System.Drawing.Point(120,50)
$nudVMs.Width = 80
$nudVMs.Minimum = 1
$nudVMs.Maximum = 50
$nudVMs.Value   = 2

$defaultVhdPath = Join-Path $PSScriptRoot 'VMS\BaseVM\Virtual Hard Disks\BaseVM.vhdx'
$defaultIsoDir  = Join-Path $PSScriptRoot 'VMS\ISO'
$defaultIso = $null
if (Test-Path $defaultIsoDir) {
    $defaultIso = Get-ChildItem -Path $defaultIsoDir -Filter *.iso -File -ErrorAction SilentlyContinue | Select-Object -First 1
}

# Attack types
$lblAttacks = New-Object System.Windows.Forms.Label
$lblAttacks.Text = 'Attack types:'
$lblAttacks.Location = New-Object System.Drawing.Point(20,90)
$lblAttacks.AutoSize = $true

$clbAttacks = New-Object System.Windows.Forms.CheckedListBox
$clbAttacks.Location = New-Object System.Drawing.Point(120,90)
$clbAttacks.Size = New-Object System.Drawing.Size(200,80)
@('BruteForce','PrivilegeEscalation','PortScan') | ForEach-Object {
    [void]$clbAttacks.Items.Add($_, $true)
}
# Add advanced scenario
[void]$clbAttacks.Items.Add('LateralMovement', $true)

# Parallel
$chkParallel = New-Object System.Windows.Forms.CheckBox
$chkParallel.Text = 'Run in parallel'
$chkParallel.Location = New-Object System.Drawing.Point(20,190)
$chkParallel.AutoSize = $true
$chkParallel.Checked = $true

$chkChallenge = New-Object System.Windows.Forms.CheckBox
$chkChallenge.Text = 'Challenge mode (ask operator responses)'
$chkChallenge.Location = New-Object System.Drawing.Point(20,210)
$chkChallenge.AutoSize = $true
$chkChallenge.Checked = $false

# Allow guest logon (optional)
$chkGuest = New-Object System.Windows.Forms.CheckBox
$chkGuest.Text = 'Allow guest logon (PowerShell Direct)'
$chkGuest.Location = New-Object System.Drawing.Point(20,235)
$chkGuest.AutoSize = $true
$chkGuest.Checked = $false

$lblGuestUser = New-Object System.Windows.Forms.Label
$lblGuestUser.Text = 'Guest user:'
$lblGuestUser.Location = New-Object System.Drawing.Point(40,260)
$lblGuestUser.AutoSize = $true

$txtGuestUser = New-Object System.Windows.Forms.TextBox
$txtGuestUser.Location = New-Object System.Drawing.Point(140,255)
$txtGuestUser.Width = 180
$txtGuestUser.Text = ''

$lblGuestPass = New-Object System.Windows.Forms.Label
$lblGuestPass.Text = 'Guest password:'
$lblGuestPass.Location = New-Object System.Drawing.Point(40,290)
$lblGuestPass.AutoSize = $true

$txtGuestPass = New-Object System.Windows.Forms.TextBox
$txtGuestPass.Location = New-Object System.Drawing.Point(140,285)
$txtGuestPass.Width = 180
$txtGuestPass.Text = ''
$txtGuestPass.UseSystemPasswordChar = $true

# Educational mode
$chkEdu = New-Object System.Windows.Forms.CheckBox
$chkEdu.Text = 'Educational mode (add explanations)'
$chkEdu.Location = New-Object System.Drawing.Point(20,260)
$chkEdu.AutoSize = $true
$chkEdu.Checked = $true

# Log/Report path
$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = 'Log path:'
$lblLog.Location = New-Object System.Drawing.Point(20,325)
$lblLog.AutoSize = $true

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(220,320)
$txtLog.Width = 300
$txtLog.Text = (Join-Path $PSScriptRoot 'Logs')

$lblRpt = New-Object System.Windows.Forms.Label
$lblRpt.Text = 'Report path:'
$lblRpt.Location = New-Object System.Drawing.Point(20,355)
$lblRpt.AutoSize = $true

$txtRpt = New-Object System.Windows.Forms.TextBox
$txtRpt.Location = New-Object System.Drawing.Point(220,350)
$txtRpt.Width = 300
$txtRpt.Text = (Join-Path $PSScriptRoot 'Reports')

# VHD path
$lblVhd = New-Object System.Windows.Forms.Label
$lblVhd.Text = 'VHD/VHDX path (Windows image):'
$lblVhd.Location = New-Object System.Drawing.Point(20,385)
$lblVhd.AutoSize = $true

$txtVhd = New-Object System.Windows.Forms.TextBox
$txtVhd.Location = New-Object System.Drawing.Point(220,380)
$txtVhd.Width = 300
$txtVhd.Text = if (Test-Path $defaultVhdPath) { $defaultVhdPath } else { '' }

$lblIso = New-Object System.Windows.Forms.Label
$lblIso.Text = 'ISO path (used if VHD missing/unbootable):'
$lblIso.Location = New-Object System.Drawing.Point(20,415)
$lblIso.AutoSize = $true

$txtIso = New-Object System.Windows.Forms.TextBox
$txtIso.Location = New-Object System.Drawing.Point(220,410)
$txtIso.Width = 300
$txtIso.Text = if ($defaultIso) { $defaultIso.FullName } else { '' }

# SIEM endpoint
$lblSiem = New-Object System.Windows.Forms.Label
$lblSiem.Text = 'SIEM endpoint (optional file path):'
$lblSiem.Location = New-Object System.Drawing.Point(20,445)
$lblSiem.AutoSize = $true

$txtSiem = New-Object System.Windows.Forms.TextBox
$txtSiem.Location = New-Object System.Drawing.Point(220,440)
$txtSiem.Width = 200
$txtSiem.Text = ''

# Run button
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'Run simulation'
$btnRun.Location = New-Object System.Drawing.Point(20,480)
$btnRun.Width = 150

# Output textbox
$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(20,490)
$txtOutput.Size = New-Object System.Drawing.Size(540,60)
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = 'Vertical'
$txtOutput.ReadOnly = $true

$form.Controls.AddRange(@(
    $lblDiff, $cbDiff,
    $lblVMs, $nudVMs,
    $lblAttacks, $clbAttacks,
    $chkParallel,
    $chkChallenge,
    $chkGuest,
    $lblGuestUser, $txtGuestUser,
    $lblGuestPass, $txtGuestPass,
    $chkEdu,
    $lblLog, $txtLog,
    $lblRpt, $txtRpt,
    $lblVhd, $txtVhd,
    $lblIso, $txtIso,
    $lblSiem, $txtSiem,
    $btnRun,
    $txtOutput
))

$btnRun.Add_Click({
    $txtOutput.Text = "Starting simulation..." + [Environment]::NewLine

    try {
        Import-Module $modulePath -Force

        $difficulty = $cbDiff.SelectedItem
        $numVMs     = [int]$nudVMs.Value
        $attacks    = @()
        foreach ($item in $clbAttacks.CheckedItems) {
            $attacks += [string]$item
        }
        if ($attacks.Count -eq 0) {
            [void][System.Windows.Forms.MessageBox]::Show('Select at least one attack type.')
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

        $txtOutput.AppendText("Initializing CAS...`r`n")

        $cfg = Initialize-CASSimulator -Difficulty $difficulty `
            -NumberOfVMs $numVMs `
            -AttackTypes $attacks `
            -LogPath $logPath `
            -ReportPath $reportPath `
            -VHDPath $vhdPath `
            -ISOPath $isoPath `
            -ChallengeMode:$chkChallenge.Checked `
            -AllowGuestLogon:$chkGuest.Checked `
            -GuestCredential $guestCred `
            -SIEMEndpoint $siem `
            -EducationalMode:$chkEdu.Checked

        $txtOutput.AppendText("Creating lab VMs...`r`n")
        $vmNames = New-CASLab

        if ($chkChallenge.Checked -and $chkParallel.Checked) {
            $txtOutput.AppendText("Challenge mode forces serial execution; ignoring Parallel flag.`r`n")
        }

        $txtOutput.AppendText("Running scenarios (Parallel=$($chkParallel.Checked -and -not $chkChallenge.Checked))...`r`n")
        $results = Invoke-CASSimulation -VMNames $vmNames -AttackTypes $attacks -Parallel:($chkParallel.Checked -and -not $chkChallenge.Checked)

        $txtOutput.AppendText("Generating HTML report...`r`n")
        $report = New-CASReport -Format Html

        $txtOutput.AppendText("Done. Report: $report`r`n")
    }
    catch {
        $txtOutput.AppendText("ERROR: $($_.Exception.Message)`r`n")
    }
})

[void]$form.ShowDialog()
