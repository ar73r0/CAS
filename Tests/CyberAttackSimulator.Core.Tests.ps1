<#
.SYNOPSIS
    Pester tests voor CyberAttackSimulator.Core
#>

Import-Module (Join-Path $PSScriptRoot '..\CyberAttackSimulator.Core.psm1') -Force

Describe 'Initialize-CASSimulator' {
    It 'Initializes configuration and creates folders' {
        $log   = Join-Path $TestDrive 'Logs'
        $report= Join-Path $TestDrive 'Reports'

        $cfg = Initialize-CASSimulator -Difficulty Easy -NumberOfVMs 1 -LogPath $log -ReportPath $report

        $cfg.Difficulty  | Should -Be 'Easy'
        Test-Path $log   | Should -BeTrue
        Test-Path $report| Should -BeTrue
    }
}

Describe 'Write-CASLog' {
    It 'Creates JSONL and CSV log files' {
        $log   = Join-Path $TestDrive 'Logs'
        $report= Join-Path $TestDrive 'Reports'

        Initialize-CASSimulator -Difficulty Easy -NumberOfVMs 1 -LogPath $log -ReportPath $report | Out-Null

        $res = Write-CASLog -Scenario 'TestScenario' -VMName 'TEST-VM' -Status 'Succeeded' -Message 'Unit test' -Details 'N/A'

        $res.Scenario | Should -Be 'TestScenario'

        $json = Get-ChildItem -Path $log -Filter 'CAS-Log-*.jsonl'
        $csv  = Get-ChildItem -Path $log -Filter 'CAS-Log-*.csv'

        $json | Should -Not -BeNullOrEmpty
        $csv  | Should -Not -BeNullOrEmpty
    }
}

Describe 'New-CASReport' {
    It 'Generates HTML report from CSV' {
        $log   = Join-Path $TestDrive 'Logs'
        $report= Join-Path $TestDrive 'Reports'

        Initialize-CASSimulator -Difficulty Easy -NumberOfVMs 1 -LogPath $log -ReportPath $report | Out-Null
        Write-CASLog -Scenario 'TestScenario' -VMName 'TEST-VM' -Status 'Succeeded' -Message 'Unit test' -Details 'N/A' | Out-Null

        $path = New-CASReport -Format Html

        Test-Path $path | Should -BeTrue
    }
}
