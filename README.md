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
- Voldoende schijfruimte voor een Windows 10 base image (of lege disks) en differencing disks.
- Windows 10 ISO (download van Microsoft) en optioneel een voorgebouwde Kali (Hyper-V) image.

## Installatie
1. Clone de repository naar een Hyper-V geschikte host.
2. Open een verhoogde PowerShell sessie (Run as Administrator) in de root van de repo.
3. Controleer met `Get-Module -ListAvailable -Name Hyper-V` of het Hyper-V modulepakket beschikbaar is.

## Configuratie
- **Moeilijkheidsgraad:** via `-Difficulty Easy|Medium|Hard` voor aangepaste profielen en scenario-varianten.
- **Aantal VM's:** ingesteld met `-NumberOfVMs` (standaard 2) zodat de labgrootte aansluit bij de oefening.
- **Aanvalstypen:** `-AttackTypes` accepteert een array met scenario's (`BruteForce`, `PrivilegeEscalation`, `PortScan`, `LateralMovement`).
- **Netwerk:** `-VirtualSwitch` bepaalt de te gebruiken Hyper-V switch; CAS maakt deze aan indien nodig.
- **Bestanden:** `-VHDPath` en `-ISOPath` kunnen custom paden zijn; standaard leest CAS deze uit `.env`.
- **Toegang tot guests:** met `-AllowGuestLogon` en `-GuestCredential` kan CAS PowerShell Direct gebruiken om settings binnen de guest te pushen.
- **Logging & SIEM:** `-LogPath`, `-ReportPath` en `-SIEMEndpoint` bepalen waar resultaten terechtkomen en of ze extern worden doorgestuurd.
- **Attacker VM (Kali):** configureer `-AttackerVMName`, `-AttackerSSHUser` (meestal `kali`) en optioneel key/port. CAS start Kali automatisch, voert BruteForce/PortScan/Privilege probes vanaf Kali uit en zet Kali na de run weer uit.
- **Auto-cleanup:** wanneer een aanval slaagt, wordt de doel-VM verwijderd; attacker wordt na alle aanvallen uitgezet.

## Gebruik
Snelle start vanuit een verhoogde PowerShell sessie:
```powershell
.\Run-CyberAttackSimulation.ps1 -Difficulty Medium -NumberOfVMs 2 -AllowGuestLogon -GuestCredential (Get-Credential)
```
- Het script zoekt automatisch naar een base image en creëert per VM een differencing disk.
- Met `-Parallel` worden scenario's per VM gelijktijdig uitgevoerd (ChallengeMode forceert seriële uitvoering).
- Rapporteerresultaten worden opgeslagen in de opgegeven `Reports` map en de loglijn data in JSONL/CSV onder `Logs`.

### VMs bouwen vanaf een ISO (Windows 10)
1. Download een Windows 10 ISO (Microsoft) en noteer het pad, bijv. `C:\ISOs\Win10.iso`.
2. Zet in `.env`:
   ```
   CAS_ISO_PATH=C:\ISOs\Win10.iso
   CAS_BASE_VHD_PATH=
   ```
3. Start de simulatie zonder `-VHDPath`; CAS maakt per VM een lege dynamische VHDX (40GB) in `DiffDisks` en boot vanaf de ISO:
   ```powershell
   .\Run-CyberAttackSimulation.ps1 -Difficulty Easy -NumberOfVMs 1 -AllowGuestLogon -GuestCredential (Get-Credential)
   ```
4. In Windows Setup: verwijder eventuele oude partities, installeer naar de lege disk, rond setup af. Daarna kun je het geinstalleerde VHDX-pad invullen in `.env` (`CAS_BASE_VHD_PATH`) zodat volgende runs differencing disks daarop baseren.

### Aanvallende VM (Kali)
- Download een voorgebouwde Kali Hyper-V image (kali.org), importeer als VM (bijv. naam `KaliAttacker`), standaard inlog `kali`/`kali`.
- Geef de aanvaller door via `-AttackerVMName`, `-AttackerSSHUser kali` (en eventueel `-AttackerSSHPrivateKeyPath`).
- CAS start Kali automatisch, voert de aanvallen uit vanaf Kali en zet Kali na de run weer uit. Wanneer een aanval slaagt, wordt de doel-VM verwijderd.

### .env voorbeeld
Plaats een `.env` in de repo-root:
```
CAS_BASE_VHD_PATH=C:\HyperV\BaseImages\Win10-Base.vhdx
CAS_ISO_PATH=C:\ISOs\Win10.iso

ATTACKER_VM_NAME=KaliAttacker
ATTACKER_SSH_USER=kali
ATTACKER_SSH_PRIVATE_KEY=
ATTACKER_SSH_PORT=22

CAS_WEAK_USER=casuser
CAS_WEAK_PASS=P@ssw0rd123
CAS_STUDENT_USER=student
CAS_STUDENT_WEAK_PASS=student
CAS_STUDENT_STRONG_PASS=P@ssw0rd123!
CAS_BRUTEFORCE_PASSLIST=Winter2025!,P@ssw0rd123,Welcome1!
```
De code leest `CAS_BASE_VHD_PATH` en `CAS_ISO_PATH` als defaults en gebruikt `ATTACKER_*` bij een geconfigureerde aanvaller.

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

## SWOT-analyse

### Strengths
- Volledig geautomatiseerd Hyper-V lab voor educatieve security-oefeningen
- Ondersteuning voor meerdere aanvalsscenario’s (brute force, port scan, privilege escalation, laterale beweging)
- Gebruik van een aparte aanvallende Kali Linux VM voor realistische maar gecontroleerde simulaties
- Configureerbare moeilijkheidsgraad en parallelle uitvoering van scenario’s
- Uitgebreide logging en rapportage (JSONL, CSV en HTML), met optionele SIEM-doorsturing
- Gebruik van differencing disks en automatische cleanup voor snelle en reproduceerbare labs

### Weaknesses
- Sterk afhankelijk van Windows, Hyper-V en PowerShell
- Vereist voldoende hardware resources (CPU, RAM en opslag)
- Aanvalsscenario’s zijn bewust vereenvoudigd en simulatief van aard, geen echte exploitatie

### Opportunities
- Toevoegen van extra aanvalsscenario’s en complexere aanvalsketens
- Verdere integratie met SIEM- of SOC-platformen
- Uitbreiding naar meerdere aanvallende VM’s of cloudgebaseerde labomgevingen
- Inzet als vaste oefen- en demonstratieomgeving binnen cybersecurity- en ethical hacking-opleidingen

### Threats
- Mogelijk misbruik indien de tool buiten een gecontroleerde testomgeving wordt gebruikt
- Afhankelijkheid van wijzigingen in Hyper-V, PowerShell of Windows
- Snelle evolutie van aanvalstechnieken waardoor scenario’s regelmatig geüpdatet moeten worden

## Bronnen

Microsoft. (n.d.). *PowerShell documentation*. Microsoft Learn.  
Gebruikt als referentie voor PowerShell-syntax, modules, parameterisatie en scripting-best practices.  
https://learn.microsoft.com/en-us/powershell/

Microsoft. (n.d.). *Hyper-V PowerShell documentation*. Microsoft Learn.  
Gebruikt voor het automatiseren van Hyper-V taken zoals VM-aanmaak, virtuele switches en VHD(X)-beheer.  
https://learn.microsoft.com/en-us/powershell/module/hyper-v/

Erasmus Hogeschool Brussel. (2025). *System Automation & Scripting* [Cursusmateriaal en slides].  
Gebruikt als basis voor de structuur van de PowerShell-module, configuratiebeheer, foutafhandeling en automatiseringsprincipes.

Erasmus Hogeschool Brussel. (2025). *Ethical Hacking* [Cursusmateriaal en slides].  
Gebruikt als conceptuele achtergrond voor veelvoorkomende aanvalstechnieken die in dit project gesimuleerd worden.

Offensive Security. (n.d.). *Kali Linux*.  
Gebruikt als aanvallende virtuele machine voor het uitvoeren van gesimuleerde aanvalsscenario’s binnen een gecontroleerde Hyper-V labomgeving.  
https://www.kali.org/

MITRE. (n.d.). *MITRE ATT&CK® framework*.  
Gebruikt als referentiekader voor het structureren en benoemen van aanvalsscenario’s.  
https://attack.mitre.org/

MITRE. (n.d.). *CALDERA: Automated adversary emulation system*.  
Gebruikt als conceptueel voorbeeld van geautomatiseerde aanvalssimulatie in professionele omgevingen.  
https://caldera.mitre.org/

Red Canary. (2023). *What is breach and attack simulation (BAS)?*  
Gebruikt om het project te positioneren binnen het domein van breach and attack simulation.  
https://redcanary.com/blog/breach-and-attack-simulation/

Scarfone, K., & Mell, P. (2012). *Guide to intrusion detection and prevention systems (IDPS)* (NIST Special Publication 800-94).  
Gebruikt ter onderbouwing van het belang van logging en detectie tijdens securitytests.  
https://nvlpubs.nist.gov/

OpenAI. (2025). *ChatGPT* (GPT-5.x).  
Gebruikt als hulpmiddel voor documentatie, structuurvoorstellen en tekstuele verduidelijkingen; geen code blind overgenomen.  
https://openai.com/