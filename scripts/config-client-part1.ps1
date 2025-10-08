# ================================================================= #
# Script:  config-client-part1.ps1 (VOOR de reboot) - VERSIE 2
# ================================================================= #
$voornaam = "Jamie"

# OPLOSSING 1: Robuustere selectie van de netwerkadapter.
Write-Host "Stap 1: DNS-server instellen op server1..."
$netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Sort-Object InterfaceIndex)[1].InterfaceIndex }
Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "192.168.25.10"

# ... (bovenaan het script, na de netwerkconfiguratie)
Write-Host "Stap 2: Machine toevoegen aan het domein... DEZE VM ZAL HERSTARTEN"
$wachtwoord = ConvertTo-SecureString "Vagrant123!" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("WS2-25-$voornaam\Admin1", $wachtwoord)
Add-Computer -DomainName "WS2-25-$voornaam.hogent" -Credential $credential -Restart -Force