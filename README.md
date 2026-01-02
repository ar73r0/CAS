# Cyber Attack Simulator (CAS)

Cyber Attack Simulator automatiseert een Hyper-V lab om veelvoorkomende aanvalsscenario's (brute force, privilege escalation, port scan, laterale beweging) veilig te demonstreren. Het project is bedoeld voor educatieve doeleinden en voor het testen van detectie- en responsprocessen in een gecontroleerde omgeving.

## Doel en functionaliteit
- Snel een volledig virtueel lab opbouwen met configureerbare moeilijkheidsgraad (Easy/Medium/Hard).
- Aanvalsflows uitvoeren op meerdere VM's, sequentieel of parallel.
- Simulatielogs bewaren voor rapportage en optioneel doorsturen naar een SIEM endpoint.
- Rapportage genereren (HTML/CSV) zodat studenten of operators achteraf kunnen analyseren welke stappen zijn uitgevoerd.

## Requirements
- Windows-host met Hyper-V ingeschakeld en beheerdersrechten.
- PowerShell 5.1 of hoger met toegang tot het Hyper-V modulepakket.
- Voldoende schijfruimte voor het base image (`VMS\BaseVM\Virtual Hard Disks\BaseVM.vhdx` of `VMS\PatientZero\PatientZero.vhdx`) en eventuele differencing disks.
- Optioneel: een ISO-bestand in `VMS\ISO` wanneer geen bruikbaar base image aanwezig is.

## Installatie
1. Clone de repository naar een Hyper-V geschikte host.
2. Plaats het base image (`BaseVM.vhdx` of `PatientZero.vhdx`) in de map `VMS` volgens de standaardpaden.
3. Open een verhoogde PowerShell sessie (Run as Administrator) in de root van de repo.
4. Controleer met `Get-Module -ListAvailable -Name Hyper-V` of het Hyper-V modulepakket beschikbaar is.

## Configuratie
- **Moeilijkheidsgraad:** via `-Difficulty Easy|Medium|Hard` voor aangepaste profielen en scenario-varianten.
- **Aantal VM's:** ingesteld met `-NumberOfVMs` (standaard 2) zodat de labgrootte aansluit bij de oefening.
- **Aanvalstypen:** `-AttackTypes` accepteert een array met scenario's (`BruteForce`, `PrivilegeEscalation`, `PortScan`, `LateralMovement`).
- **Netwerk:** `-VirtualSwitch` bepaalt de te gebruiken Hyper-V switch; CAS maakt deze aan indien nodig.
- **Bestanden:** `-VHDPath` en `-ISOPath` kunnen custom paden zijn; standaard zoekt CAS naar bestanden in `VMS`.
- **Toegang tot guests:** met `-AllowGuestLogon` en `-GuestCredential` kan CAS PowerShell Direct gebruiken om settings binnen de guest te pushen.
- **Logging & SIEM:** `-LogPath`, `-ReportPath` en `-SIEMEndpoint` bepalen waar resultaten terechtkomen en of ze extern worden doorgestuurd.

## Gebruik
Snelle start vanuit een verhoogde PowerShell sessie:
```powershell
.\Run-CyberAttackSimulation.ps1 -Difficulty Medium -NumberOfVMs 2 -AllowGuestLogon -GuestCredential (Get-Credential)
```
- Het script zoekt automatisch naar een base image en creëert per VM een differencing disk.
- Met `-Parallel` worden scenario's per VM gelijktijdig uitgevoerd (ChallengeMode forceert seriële uitvoering).
- Gebruik `test-launchvhdx.ps1` om een VHDX te testen voordat het volledige lab wordt opgebouwd.
- Rapporteerresultaten worden opgeslagen in de opgegeven `Reports` map en de loglijn data in JSONL/CSV onder `Logs`.

### VMs bouwen vanaf een ISO (zonder vooraf gemaakte VHDX)
1. Zet een Windows ISO in de repo of vul het pad in `.env` als `CAS_ISO_PATH=C:\pad\naar\windows.iso`.
2. Laat `CAS_BASE_VHD_PATH` leeg of verwijder de regel zodat er geen base image wordt verwacht.
3. Start de simulatie zonder `-VHDPath`; CAS maakt per VM een lege dynamische VHDX (40GB) in `DiffDisks` en hangt de ISO eraan als bootmedium:
```powershell
.\Run-CyberAttackSimulation.ps1 -Difficulty Easy -NumberOfVMs 1 -AllowGuestLogon -GuestCredential (Get-Credential)
```
4. De VM boot vanaf de ISO; installeer het OS in de VM. Voor volgende runs kun je het geinstalleerde VHDX-pad in `.env` zetten (`CAS_BASE_VHD_PATH`) of `-VHDPath` meegeven zodat CAS differencing disks daarop baseert.

### Aanvallende VM (Kali)
- Standaard inlog: gebruiker `kali`, wachtwoord `kali`.
- Geef de aanvaller door via `-AttackerVMName` en `-AttackerSSHUser kali` (en eventueel `-AttackerSSHPrivateKeyPath`).
- De Kali-VM wordt automatisch gestart als deze is geconfigureerd.

## Projectstructuur
- `Run-CyberAttackSimulation.ps1`: entrypoint dat de module importeert en het volledige proces (initialisatie ➜ provisioning ➜ scenario's ➜ rapportage) start.
- `CyberAttackSimulator.Core.psm1`: kernmodule met configuratiebeheer, Hyper-V provisioning, scenario-implementaties, logging en rapportage.
- `Start-CASGui.ps1`: Windows Forms GUI voor een visuele configuratie van simulaties.
- `ScenarioLibrary.json`: statische manifestinformatie over beschikbare scenario's.
- `Tests/`: bevat helper scripts voor validaties (bijv. opstarten van een specifieke VHDX).

## Architectuur en technische uitleg
- **Configuratie en sessiebeheer:** `Initialize-CASSimulator` slaat alle parameters op in een gedeeld `$script:CasConfig` object, inclusief paden voor logs/rapporten en gevonden VHD/ISO-bestanden.
- **Provisioning-laag:** `New-CASLab` maakt een Hyper-V switch aan, genereert differencing disks (`DiffDisks` map naast het base image) en start VM's. Optioneel worden difficulty-scripts en profielen binnen de guest toegepast.
- **Scenario-uitvoering:** `Invoke-CASSimulation` bouwt een matrix van VM's en aanvalstypes en voert scenario's sequentieel of parallel uit. ChallengeMode vraagt per scenario operator-input.
- **Logging & rapportage:** `Write-CASLog` schrijft elk scenarioresultaat naar JSONL/CSV, `New-CASReport` leest die logs terug en produceert HTML/CSV rapporten. Een optionele `SIEMEndpoint` kan dezelfde payloads ontvangen.

## Bronnen
- Hyper-V PowerShell documentatie (Microsoft Learn) voor cmdlets zoals `New-VM`, `Set-VMFirmware`, `Add-VMDvdDrive`.
- Eigen kennis en eerder ontwikkelde scripts uit de cursus; geen externe codefragmenten gekopieerd.
- Interactie met A.I. (OpenAI GPT-5.1-Codex-Max) voor het opstellen van documentatie en commentaar.
