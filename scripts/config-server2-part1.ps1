# ================================================================= #
# Script:  config-server2-part1.ps1 (VOOR de reboot) - BIJGEWERKT
# ================================================================= #
Start-Sleep -Seconds 15
Set-SConfig -AutoLaunch $false

$voornaam = "Jamie"

Write-Host "Stap 1: Netwerkadapter configureren..."
$netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Sort-Object InterfaceIndex)[1].InterfaceIndex }
New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress "192.168.25.20" -PrefixLength 24
Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "192.168.25.10"

# ... (bovenaan het script, na de netwerkconfiguratie)
Write-Host "Stap 2: Machine toevoegen aan het domein... DEZE VM ZAL HERSTARTEN"
$wachtwoord = ConvertTo-SecureString "Vagrant123!" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("WS2-25-$voornaam\Admin1", $wachtwoord)
Add-Computer -DomainName "WS2-25-$voornaam.hogent" -Credential $credential -Restart -Force