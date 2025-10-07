# ================================================================= #
# Script:  config-server2-part1.ps1 (VOOR de reboot) - BIJGEWERKT
# ================================================================= #

$voornaam = "Jamie"

Write-Host "Stap 1: Netwerkadapter configureren..."
$netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Sort-Object InterfaceIndex)[1].InterfaceIndex }
New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress "192.168.25.20" -PrefixLength 24
Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "192.168.25.10"

Write-Host "Stap 2: Server toevoegen aan het domein... DEZE VM ZAL HERSTARTEN"
$credential = Get-Credential -UserName "WS2-25-$voornaam\Admin1" -Message "Voer het wachtwoord in voor de domeinbeheerder"
Add-Computer -DomainName "WS2-25-$voornaam.hogent" -Credential $credential -Restart