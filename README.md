# Cyber Attack Simulator (CAS)

PowerShell lab automation for spinning up Hyper-V based cyber-attack simulations.

## Highlights
- Automatically provisions lab VMs, attachable to a base image (supports `BaseVM.vhdx` and `PatientZero.vhdx`).
- Scenario framework (brute force, privilege escalation, port scan, lateral movement) with logging and reporting.
- Difficulty-aware per-VM defense profiles plus high-level user personas for Easy/Medium/Hard runs.
- Optional SIEM forwarding stub, educational hints, and operator challenge prompts.

## Quick start
```powershell
# From an elevated PowerShell session on a Hyper-V capable host
.\Run-CyberAttackSimulation.ps1 -Difficulty Medium -NumberOfVMs 2 -AllowGuestLogon -GuestCredential (Get-Credential)
```

- Place your base image as `VMS\BaseVM\Virtual Hard Disks\BaseVM.vhdx` or `VMS\PatientZero\PatientZero.vhdx` (or anywhere under `VMS` with that filename). Differencing disks are created next to the detected base image.
- Use `test-launchvhdx.ps1` to validate launching a single VM with a specific VHDX before running the full simulator.

## User personas
Call `Get-CASUserProfiles` (exported by the core module) to see the built-in persona descriptions for each difficulty. The selected persona set is also stored in the configuration returned by `Initialize-CASSimulator` under `UserProfiles`.
