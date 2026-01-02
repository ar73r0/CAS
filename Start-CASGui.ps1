# Clean, single-pass GUI for Cyber Attack Simulator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$modulePath = Join-Path $PSScriptRoot 'CyberAttackSimulator.Core.psm1'
Import-Module $modulePath -Force

$defaultVhdPath = Get-CASDefaultVHDPath
$defaultIsoPath = Get-CASDefaultISOPath

# Main form
$form               = New-Object System.Windows.Forms.Form
$form.Text          = 'Cyber Attack Simulator - Configuration'
$form.Size          = New-Object System.Drawing.Size(820, 780)
$form.StartPosition = 'CenterScreen'
$form.Font          = New-Object System.Drawing.Font('Segoe UI', 9)
$form.BackColor     = [System.Drawing.Color]::FromArgb(240, 240, 240)

# Tabs
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(780, 500)
$tabControl.Anchor = 'Top,Left,Right'

### Tab 1: Basic Configuration
$tabBasic = New-Object System.Windows.Forms.TabPage
$tabBasic.Text = 'Basic'
$tabBasic.Padding = New-Object System.Windows.Forms.Padding(12)
$tabBasic.BackColor = [System.Drawing.Color]::White

$grpDifficulty = New-Object System.Windows.Forms.GroupBox
$grpDifficulty.Text = 'Simulation Difficulty'
$grpDifficulty.Location = New-Object System.Drawing.Point(12, 12)
$grpDifficulty.Size = New-Object System.Drawing.Size(730, 80)
$grpDifficulty.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$lblDiff = New-Object System.Windows.Forms.Label
$lblDiff.Text = 'Difficulty:'
$lblDiff.Location = New-Object System.Drawing.Point(20, 32)
$lblDiff.AutoSize = $true

$cbDiff = New-Object System.Windows.Forms.ComboBox
$cbDiff.Location = New-Object System.Drawing.Point(120, 28)
$cbDiff.Width = 140
$cbDiff.DropDownStyle = 'DropDownList'
@('Easy','Medium','Hard') | ForEach-Object { [void]$cbDiff.Items.Add($_) }
$cbDiff.SelectedIndex = 0

$lblDiffDesc = New-Object System.Windows.Forms.Label
$lblDiffDesc.Text = 'Easy: slower | Medium: balanced | Hard: advanced'
$lblDiffDesc.Location = New-Object System.Drawing.Point(280, 32)
$lblDiffDesc.AutoSize = $true
$lblDiffDesc.ForeColor = [System.Drawing.Color]::Gray
$lblDiffDesc.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)

$grpDifficulty.Controls.AddRange(@($lblDiff, $cbDiff, $lblDiffDesc))

$grpVMs = New-Object System.Windows.Forms.GroupBox
$grpVMs.Text = 'Lab Settings'
$grpVMs.Location = New-Object System.Drawing.Point(12, 105)
$grpVMs.Size = New-Object System.Drawing.Size(730, 110)
$grpVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$lblVMs = New-Object System.Windows.Forms.Label
$lblVMs.Text = 'Number of VMs:'
$lblVMs.Location = New-Object System.Drawing.Point(20, 30)
$lblVMs.AutoSize = $true

$nudVMs = New-Object System.Windows.Forms.NumericUpDown
$nudVMs.Location = New-Object System.Drawing.Point(150, 26)
$nudVMs.Width = 80
$nudVMs.Minimum = 1
$nudVMs.Maximum = 50
$nudVMs.Value = 1

$lblLabPrefix = New-Object System.Windows.Forms.Label
$lblLabPrefix.Text = 'Lab Prefix:'
$lblLabPrefix.Location = New-Object System.Drawing.Point(260, 30)
$lblLabPrefix.AutoSize = $true

$txtLabPrefix = New-Object System.Windows.Forms.TextBox
$txtLabPrefix.Location = New-Object System.Drawing.Point(340, 26)
$txtLabPrefix.Width = 160
$txtLabPrefix.Text = 'CAS-LAB'

$lblSwitch = New-Object System.Windows.Forms.Label
$lblSwitch.Text = 'Virtual Switch:'
$lblSwitch.Location = New-Object System.Drawing.Point(520, 30)
$lblSwitch.AutoSize = $true

$txtSwitch = New-Object System.Windows.Forms.TextBox
$txtSwitch.Location = New-Object System.Drawing.Point(620, 26)
$txtSwitch.Width = 90
$txtSwitch.Text = 'CAS-Switch'

$chkAutoConsole = New-Object System.Windows.Forms.CheckBox
$chkAutoConsole.Text = 'Auto-connect to VM console on start'
$chkAutoConsole.Location = New-Object System.Drawing.Point(20, 60)
$chkAutoConsole.AutoSize = $true
$chkAutoConsole.Checked = $false

$grpVMs.Controls.AddRange(@($lblVMs, $nudVMs, $lblLabPrefix, $txtLabPrefix, $lblSwitch, $txtSwitch, $chkAutoConsole))

$tabBasic.Controls.AddRange(@($grpDifficulty, $grpVMs))
$tabControl.TabPages.Add($tabBasic)

### Tab 2: Attacks & Modes
$tabAttacks = New-Object System.Windows.Forms.TabPage
$tabAttacks.Text = 'Attacks'
$tabAttacks.Padding = New-Object System.Windows.Forms.Padding(12)
$tabAttacks.BackColor = [System.Drawing.Color]::White

$grpScenarios = New-Object System.Windows.Forms.GroupBox
$grpScenarios.Text = 'Attack Scenarios'
$grpScenarios.Location = New-Object System.Drawing.Point(12, 12)
$grpScenarios.Size = New-Object System.Drawing.Size(730, 150)
$grpScenarios.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$clbAttacks = New-Object System.Windows.Forms.CheckedListBox
$clbAttacks.Location = New-Object System.Drawing.Point(20, 30)
$clbAttacks.Size = New-Object System.Drawing.Size(690, 100)
$clbAttacks.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$clbAttacks.CheckOnClick = $true
@('BruteForce','PrivilegeEscalation','PortScan','LateralMovement') | ForEach-Object { [void]$clbAttacks.Items.Add($_) }

$grpScenarios.Controls.Add($clbAttacks)

$grpModes = New-Object System.Windows.Forms.GroupBox
$grpModes.Text = 'Execution Modes'
$grpModes.Location = New-Object System.Drawing.Point(12, 170)
$grpModes.Size = New-Object System.Drawing.Size(730, 90)
$grpModes.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$chkParallel = New-Object System.Windows.Forms.CheckBox
$chkParallel.Text = 'Run scenarios in parallel (faster)'
$chkParallel.Location = New-Object System.Drawing.Point(20, 30)
$chkParallel.AutoSize = $true
$chkParallel.Checked = $true

$chkChallenge = New-Object System.Windows.Forms.CheckBox
$chkChallenge.Text = 'Challenge mode (serial, operator response)'
$chkChallenge.Location = New-Object System.Drawing.Point(20, 55)
$chkChallenge.AutoSize = $true

$chkEdu = New-Object System.Windows.Forms.CheckBox
$chkEdu.Text = 'Educational mode (add explanations)'
$chkEdu.Location = New-Object System.Drawing.Point(320, 30)
$chkEdu.AutoSize = $true
$chkEdu.Checked = $true

$grpModes.Controls.AddRange(@($chkParallel, $chkChallenge, $chkEdu))
$tabAttacks.Controls.AddRange(@($grpScenarios, $grpModes))
$tabControl.TabPages.Add($tabAttacks)

$chkChallenge.Add_CheckedChanged({
    if ($chkChallenge.Checked) {
        $chkParallel.Checked = $false
        $chkAutoConsole.Checked = $true
    }
    else {
        $chkAutoConsole.Checked = $false
    }
})

### Tab 3: Guest & SIEM
$tabGuest = New-Object System.Windows.Forms.TabPage
$tabGuest.Text = 'Guest & SIEM'
$tabGuest.Padding = New-Object System.Windows.Forms.Padding(12)
$tabGuest.BackColor = [System.Drawing.Color]::White

$grpGuest = New-Object System.Windows.Forms.GroupBox
$grpGuest.Text = 'Guest VM Access (PowerShell Direct)'
$grpGuest.Location = New-Object System.Drawing.Point(12, 12)
$grpGuest.Size = New-Object System.Drawing.Size(730, 120)
$grpGuest.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$chkGuest = New-Object System.Windows.Forms.CheckBox
$chkGuest.Text = 'Allow guest logon and apply profiles'
$chkGuest.Location = New-Object System.Drawing.Point(20, 25)
$chkGuest.AutoSize = $true
$chkGuest.Checked = $true

$lblGuestUser = New-Object System.Windows.Forms.Label
$lblGuestUser.Text = 'Username:'
$lblGuestUser.Location = New-Object System.Drawing.Point(40, 55)
$lblGuestUser.AutoSize = $true

$txtGuestUser = New-Object System.Windows.Forms.TextBox
$txtGuestUser.Location = New-Object System.Drawing.Point(120, 52)
$txtGuestUser.Width = 200

$txtGuestUser.Text = 'admin'

$lblGuestPass = New-Object System.Windows.Forms.Label
$lblGuestPass.Text = 'Password:'
$lblGuestPass.Location = New-Object System.Drawing.Point(360, 55)
$lblGuestPass.AutoSize = $true

$txtGuestPass = New-Object System.Windows.Forms.TextBox
$txtGuestPass.Location = New-Object System.Drawing.Point(440, 52)
$txtGuestPass.Width = 200
$txtGuestPass.UseSystemPasswordChar = $true
$txtGuestPass.Text = 'admin'

$grpGuest.Controls.AddRange(@($chkGuest, $lblGuestUser, $txtGuestUser, $lblGuestPass, $txtGuestPass))

$grpSIEM = New-Object System.Windows.Forms.GroupBox
$grpSIEM.Text = 'SIEM Integration'
$grpSIEM.Location = New-Object System.Drawing.Point(12, 140)
$grpSIEM.Size = New-Object System.Drawing.Size(730, 80)
$grpSIEM.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$lblSiem = New-Object System.Windows.Forms.Label
$lblSiem.Text = 'SIEM Endpoint (file path or URL):'
$lblSiem.Location = New-Object System.Drawing.Point(20, 32)
$lblSiem.AutoSize = $true

$txtSiem = New-Object System.Windows.Forms.TextBox
$txtSiem.Location = New-Object System.Drawing.Point(240, 28)
$txtSiem.Width = 470

$grpSIEM.Controls.AddRange(@($lblSiem, $txtSiem))

$grpAttacker = New-Object System.Windows.Forms.GroupBox
$grpAttacker.Text = 'Attacker VM (Kali)'
$grpAttacker.Location = New-Object System.Drawing.Point(12, 230)
$grpAttacker.Size = New-Object System.Drawing.Size(730, 110)
$grpAttacker.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$chkAttacker = New-Object System.Windows.Forms.CheckBox
$chkAttacker.Text = 'Enable attacker VM (SSH-based attacks)'
$chkAttacker.Location = New-Object System.Drawing.Point(20, 25)
$chkAttacker.AutoSize = $true
$chkAttacker.Checked = $true

$lblAttackerVM = New-Object System.Windows.Forms.Label
$lblAttackerVM.Text = 'VM Name:'
$lblAttackerVM.Location = New-Object System.Drawing.Point(40, 50)
$lblAttackerVM.AutoSize = $true

$txtAttackerVM = New-Object System.Windows.Forms.TextBox
$txtAttackerVM.Location = New-Object System.Drawing.Point(110, 46)
$txtAttackerVM.Width = 170
$txtAttackerVM.Text = 'KaliAttacker'

$lblAttackerUser = New-Object System.Windows.Forms.Label
$lblAttackerUser.Text = 'SSH User:'
$lblAttackerUser.Location = New-Object System.Drawing.Point(300, 50)
$lblAttackerUser.AutoSize = $true

$txtAttackerUser = New-Object System.Windows.Forms.TextBox
$txtAttackerUser.Location = New-Object System.Drawing.Point(370, 46)
$txtAttackerUser.Width = 120
$txtAttackerUser.Text = 'kali'

$lblAttackerPort = New-Object System.Windows.Forms.Label
$lblAttackerPort.Text = 'SSH Port:'
$lblAttackerPort.Location = New-Object System.Drawing.Point(520, 50)
$lblAttackerPort.AutoSize = $true

$numAttackerPort = New-Object System.Windows.Forms.NumericUpDown
$numAttackerPort.Location = New-Object System.Drawing.Point(585, 46)
$numAttackerPort.Width = 60
$numAttackerPort.Minimum = 1
$numAttackerPort.Maximum = 65535
$numAttackerPort.Value = 22

$lblAttackerKey = New-Object System.Windows.Forms.Label
$lblAttackerKey.Text = 'SSH Private Key (optional):'
$lblAttackerKey.Location = New-Object System.Drawing.Point(40, 78)
$lblAttackerKey.AutoSize = $true

$txtAttackerKey = New-Object System.Windows.Forms.TextBox
$txtAttackerKey.Location = New-Object System.Drawing.Point(200, 74)
$txtAttackerKey.Width = 450

$grpAttacker.Controls.AddRange(@($chkAttacker, $lblAttackerVM, $txtAttackerVM, $lblAttackerUser, $txtAttackerUser, $lblAttackerPort, $numAttackerPort, $lblAttackerKey, $txtAttackerKey))

$tabGuest.Controls.AddRange(@($grpGuest, $grpSIEM, $grpAttacker))
$tabControl.TabPages.Add($tabGuest)

### Tab 4: Paths & Images
$tabPaths = New-Object System.Windows.Forms.TabPage
$tabPaths.Text = 'Paths'
$tabPaths.Padding = New-Object System.Windows.Forms.Padding(12)
$tabPaths.BackColor = [System.Drawing.Color]::White

$grpOutput = New-Object System.Windows.Forms.GroupBox
$grpOutput.Text = 'Output Locations'
$grpOutput.Location = New-Object System.Drawing.Point(12, 12)
$grpOutput.Size = New-Object System.Drawing.Size(730, 100)
$grpOutput.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = 'Log Path:'
$lblLog.Location = New-Object System.Drawing.Point(20, 30)
$lblLog.AutoSize = $true

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(120, 26)
$txtLog.Width = 580
$txtLog.Text = (Join-Path $PSScriptRoot 'Logs')

$lblRpt = New-Object System.Windows.Forms.Label
$lblRpt.Text = 'Report Path:'
$lblRpt.Location = New-Object System.Drawing.Point(20, 60)
$lblRpt.AutoSize = $true

$txtRpt = New-Object System.Windows.Forms.TextBox
$txtRpt.Location = New-Object System.Drawing.Point(120, 56)
$txtRpt.Width = 580
$txtRpt.Text = (Join-Path $PSScriptRoot 'Reports')

$grpOutput.Controls.AddRange(@($lblLog, $txtLog, $lblRpt, $txtRpt))

$grpImages = New-Object System.Windows.Forms.GroupBox
$grpImages.Text = 'Images'
$grpImages.Location = New-Object System.Drawing.Point(12, 120)
$grpImages.Size = New-Object System.Drawing.Size(730, 100)
$grpImages.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$lblVhd = New-Object System.Windows.Forms.Label
$lblVhd.Text = 'Base VHD/VHDX:'
$lblVhd.Location = New-Object System.Drawing.Point(20, 30)
$lblVhd.AutoSize = $true

$txtVhd = New-Object System.Windows.Forms.TextBox
$txtVhd.Location = New-Object System.Drawing.Point(140, 26)
$txtVhd.Width = 560
$txtVhd.Text = if ($defaultVhdPath -and (Test-Path $defaultVhdPath)) { $defaultVhdPath } else { '' }

$lblIso = New-Object System.Windows.Forms.Label
$lblIso.Text = 'ISO (fallback when VHD missing):'
$lblIso.Location = New-Object System.Drawing.Point(20, 60)
$lblIso.AutoSize = $true

$txtIso = New-Object System.Windows.Forms.TextBox
$txtIso.Location = New-Object System.Drawing.Point(220, 56)
$txtIso.Width = 480
$txtIso.Text = if ($defaultIsoPath -and (Test-Path $defaultIsoPath)) { $defaultIsoPath } else { '' }

$grpImages.Controls.AddRange(@($lblVhd, $txtVhd, $lblIso, $txtIso))

$tabPaths.Controls.AddRange(@($grpOutput, $grpImages))
$tabControl.TabPages.Add($tabPaths)

$form.Controls.Add($tabControl)

# Bottom panel
$panelBottom = New-Object System.Windows.Forms.Panel
$panelBottom.Location = New-Object System.Drawing.Point(10, 520)
$panelBottom.Size = New-Object System.Drawing.Size(780, 210)
$panelBottom.Anchor = 'Top,Left,Right,Bottom'

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'START SIMULATION'
$btnRun.Location = New-Object System.Drawing.Point(15, 15)
$btnRun.Size = New-Object System.Drawing.Size(170, 42)
$btnRun.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$btnRun.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
$btnRun.ForeColor = [System.Drawing.Color]::White
$btnRun.FlatStyle = 'Flat'

$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Text = 'Simulation Output:'
$lblOutput.Location = New-Object System.Drawing.Point(15, 65)
$lblOutput.AutoSize = $true
$lblOutput.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(15, 90)
$txtOutput.Size = New-Object System.Drawing.Size(740, 100)
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = 'Vertical'
$txtOutput.ReadOnly = $true
$txtOutput.Font = New-Object System.Drawing.Font('Consolas', 9)
$txtOutput.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 25)
$txtOutput.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 0)
$txtOutput.Anchor = 'Top,Left,Right,Bottom'

$panelBottom.Controls.AddRange(@($btnRun, $lblOutput, $txtOutput))
$form.Controls.Add($panelBottom)

function Add-CASOutput {
    param([string]$Text)
    $txtOutput.AppendText("$Text`r`n")
}

$btnRun.Add_Click({
    $txtOutput.Clear()
    Add-CASOutput '-------------------------------------------'
    Add-CASOutput '  CAS SIMULATION STARTED'
    Add-CASOutput '-------------------------------------------'
    Add-CASOutput ''

    try {
        Import-Module $modulePath -Force

        $difficulty = $cbDiff.SelectedItem
        $numVMs     = [int]$nudVMs.Value
        $labPrefix  = $txtLabPrefix.Text
        $vswitch    = $txtSwitch.Text

        $attacks = @()
        foreach ($item in $clbAttacks.CheckedItems) { $attacks += [string]$item }
        if ($attacks.Count -eq 0) {
            Add-CASOutput "[!] ERROR: Select at least one attack type."
            return
        }

        $logPath    = $txtLog.Text
        $reportPath = $txtRpt.Text
        $siem       = $txtSiem.Text
        $vhdPath    = $txtVhd.Text
        $isoPath    = $txtIso.Text
        $attackerVM = $null
        $attackerUser = $null
        $attackerKey = $null
        $attackerPort = 22

        if ($chkAttacker.Checked) {
            $attackerVM = $txtAttackerVM.Text
            $attackerUser = $txtAttackerUser.Text
            $attackerKey = if ($txtAttackerKey.Text) { $txtAttackerKey.Text } else { $null }
            $attackerPort = [int]$numAttackerPort.Value
            if (-not $attackerVM -or -not $attackerUser) {
                Add-CASOutput "[!] ERROR: Provide attacker VM name and SSH user when attacker is enabled."
                return
            }
        }

        $guestCred = $null
        if ($chkGuest.Checked -and $txtGuestUser.Text -and $txtGuestPass.Text) {
            $sec = ConvertTo-SecureString $txtGuestPass.Text -AsPlainText -Force
            $guestCred = New-Object System.Management.Automation.PSCredential ($txtGuestUser.Text, $sec)
        }

        Add-CASOutput ("[*] Difficulty: {0}" -f $difficulty)
        Add-CASOutput ("[*] VMs: {0} | Attacks: {1}" -f $numVMs, ($attacks -join ', '))
        Add-CASOutput ("[*] Parallel: {0} | Challenge: {1}" -f $chkParallel.Checked, $chkChallenge.Checked)
        Add-CASOutput ''

        Add-CASOutput '[+] Initializing CAS Simulator...'
        [void](Initialize-CASSimulator -Difficulty $difficulty `
            -NumberOfVMs $numVMs `
            -AttackTypes $attacks `
            -LabPrefix $labPrefix `
            -VirtualSwitch $vswitch `
            -LogPath $logPath `
            -ReportPath $reportPath `
            -VHDPath $vhdPath `
            -ISOPath $isoPath `
            -AttackerVMName $attackerVM `
            -AttackerSSHUser $attackerUser `
            -AttackerSSHPrivateKeyPath $attackerKey `
            -AttackerSSHPort $attackerPort `
            -AutoConnectConsole:$chkAutoConsole.Checked `
            -ChallengeMode:$chkChallenge.Checked `
            -AllowGuestLogon:$chkGuest.Checked `
            -GuestCredential $guestCred `
            -SIEMEndpoint $siem `
            -EducationalMode:$chkEdu.Checked)

        if ($script:CasConfig.PathDiagnostics) {
            foreach ($pd in $script:CasConfig.PathDiagnostics) {
                Add-CASOutput ("[-] {0}: {1} (Exists={2})" -f $pd.Name, $pd.Path, $pd.Exists)
            }
            Add-CASOutput ''
        }

        Add-CASOutput '[+] Creating lab VMs...'
        $vmNames = New-CASLab

        if ($chkChallenge.Checked -and $chkParallel.Checked) {
            Add-CASOutput "[!] Challenge mode requires serial execution; Parallel flag disabled."
        }

        $parallel = $chkParallel.Checked -and -not $chkChallenge.Checked
        Add-CASOutput ("[+] Running scenarios (Parallel={0})..." -f $parallel)
        Add-CASOutput ''
        [void](Invoke-CASSimulation -VMNames $vmNames -AttackTypes $attacks -Parallel:$parallel)

        Add-CASOutput ''
        Add-CASOutput '[+] Generating HTML report...'
        $report = New-CASReport -Format Html

        Add-CASOutput ''
        Add-CASOutput '-------------------------------------------'
        Add-CASOutput '  SIMULATION COMPLETE'
        Add-CASOutput '-------------------------------------------'
        Add-CASOutput ("[OK] Report: {0}" -f $report)
        Add-CASOutput ("[OK] Logs:   {0}" -f $logPath)
    }
    catch {
        Add-CASOutput ("[ERROR] {0}" -f $_.Exception.Message)
        if ($_.ScriptStackTrace) { Add-CASOutput $_.ScriptStackTrace }
    }
})

[void]$form.ShowDialog()
