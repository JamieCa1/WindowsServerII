# ================================================================= #
# Script:  config-server2-part2.ps1 (NA de reboot) - GEFIXTE VERSIE 3
# ================================================================= #
# Stop bij fouten, zodat try/catch werkt
$ErrorActionPreference = "Stop"
$voornaam = "Jamie"

Write-Host "Stap 3: DNS-rol installeren..."
try {
    # Install-WindowsFeature is al idempotent (geeft NoChangeNeeded als het al geinstalleerd is)
    Install-WindowsFeature DNS -IncludeManagementTools
    Write-Host "DNS-rol is geinstalleerd of was al aanwezig."
} catch {
    # GEFIXTE REGEL: Gebruik $($_.Exception.Message)
    Write-Error "Fout bij installeren van DNS-rol: $($_.Exception.Message)"
}

Write-Host "Stap 4: DNS configureren als secundaire server (idempotent)..."
$zoneName1 = "WS2-25-$voornaam.hogent"
$zoneName2 = "25.168.192.in-addr.arpa"
$masterServer = "192.168.25.10"

# Controleer of de zone al bestaat voordat je deze toevoegt
if (-not (Get-DnsServerZone -Name $zoneName1 -ErrorAction SilentlyContinue)) {
    try {
        Write-Host "Zone $zoneName1 toevoegen..."
        Add-DnsServerSecondaryZone -Name $zoneName1 -ZoneFile "$zoneName1.dns" -MasterServers $masterServer
    } catch {
        # GEFIXTE REGEL: Gebruik $($_.Exception.Message)
        Write-Error "Fout bij toevoegen zone $zoneName1. Details: $($_.Exception.Message)"
    }
} else {
    Write-Host "Zone $zoneName1 bestaat al, wordt overgeslagen."
}

# Controleer de reverse zone
if (-not (Get-DnsServerZone -Name $zoneName2 -ErrorAction SilentlyContinue)) {
    try {
        Write-Host "Zone $zoneName2 toevoegen..."
        Add-DnsServerSecondaryZone -Name $zoneName2 -ZoneFile "$zoneName2.dns" -MasterServers $masterServer
    } catch {
        # GEFIXTE REGEL: Gebruik $($_.Exception.Message)
        Write-Error "Fout bij toevoegen zone $zoneName2. Details: $($_.Exception.Message)"
    }
} else {
    Write-Host "Zone $zoneName2 bestaat al, wordt overgeslagen."
}

Write-Host "Stap 5: SQL Server installeren..."
$isoName = "enu_sql_server_2022_standard_edition_x64_dvd_43079f69.iso"
$isoPath = "C:\vagrant\$isoName"

# Wacht-lus voor de Vagrant synced folder.
$maxWait = 60 # Wacht maximaal 60 seconden
$counter = 0
Write-Host "Wachten tot $isoPath beschikbaar is (max $maxWait sec)..."
while (-not (Test-Path $isoPath) -and $counter -lt $maxWait) {
    Start-Sleep -Seconds 1
    $counter++
    Write-Host -NoNewline "."
}
Write-Host "" # Nieuwe regel

# Ga alleen verder als de ISO daadwerkelijk is gevonden
if (-not (Test-Path $isoPath)) {
    Write-Error "SQL ISO niet gevonden op $isoPath. Zorg ervoor dat het bestand in de Vagrant-map staat. Installatie wordt overgeslagen."
} else {
    Write-Host "SQL ISO gevonden. Bezig met installatie..."
    
    # Controleer of SQL al geinstalleerd is om opnieuw uitvoeren te voorkomen
    $sqlService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
    if ($sqlService) {
        Write-Warning "SQL Server (MSSQLSERVER) lijkt al geinstalleerd. Installatie wordt overgeslagen."
    } else {
        # Gebruik een try/finally om te zorgen dat de ISO altijd gedismount wordt
        try {
            # Mount de ISO
            Write-Host "Mounting $isoPath..."
            # -PassThru geeft het gemounte object terug
            $diskImage = Mount-DiskImage -ImagePath $isoPath -PassThru
            
            # Haal de drive letter op van het gemounte volume
            $driveLetter = ($diskImage | Get-Volume).DriveLetter
            
            # Controleer of de drive letter correct is
            if (-not $driveLetter) {
                Write-Error "Kon drive letter niet vinden na mounten van ISO."
                # Ga naar de 'finally' block
                return
            }
            
            $setupPath = "${driveLetter}:\setup.exe"
            Write-Host "ISO gemount op drive $driveLetter. Setup starten vanaf $setupPath..."
            
            # Start de installatie
            Start-Process -FilePath $setupPath -ArgumentList "/q /ACTION=Install /FEATURES=SQLENGINE /INSTANCENAME=MSSQLSERVER /SQLSVCACCOUNT=`"NT AUTHORITY\System`" /SQLSYSADMINACCOUNTS=`"BUILTIN\ADMINISTRATORS`" /AGTSVCACCOUNT=`"NT AUTHORITY\Network Service`" /IACCEPTSQLSERVERLICENSETERMS" -Wait
            
            Write-Host "SQL Server installatie voltooid."
            
        } catch {
            # GEFIXTE REGEL: Gebruik $($_.Exception.Message)
            Write-Error "Er is een fout opgetreden tijdens de SQL-installatie: $($_.Exception.Message)"
        } finally {
            # Zorg ervoor dat de ISO altijd wordt gedismount
            $image = Get-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue
            if ($image -and $image.Attached -eq $true) {
                Write-Host "Dismounting $isoPath..."
                Dismount-DiskImage -ImagePath $isoPath
            }
        }
    }
}

Write-Host "Stap 6: Firewall-regels configureren..."
try {
    Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"
    
    # Idempotente check voor SQL-regel
    if (-not (Get-NetFirewallRule -DisplayName "SQL-In" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "SQL-In" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433
    } else {
        Write-Host "Firewall-regel 'SQL-In' bestaat al."
    }
    
    Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
    Enable-NetFirewallRule -DisplayGroup "Network Discovery"
} catch {
    # GEFIXTE REGEL: Gebruik $($_.Exception.Message)
    Write-Error "Fout bij configureren firewall: $($_.Exception.Message)"
}

Write-Host "Configuratie van server2 is voltooid."