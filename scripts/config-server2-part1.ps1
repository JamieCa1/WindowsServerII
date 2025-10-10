# ================================================================= #
# Script:  config-server2-part1.ps1 (FINALE VERSIE)
# ================================================================= #
Write-Host "Start van de configuratie... Wacht 15 seconden tot de VM stabiel is."
Start-Sleep -Seconds 15

Write-Host "SConfig uitschakelen om automatisering mogelijk te maken..."
Set-SConfig -AutoLaunch $false

$voornaam = "Jamie"

Write-Host "Stap 1: Netwerkadapter configureren..."
$netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Sort-Object InterfaceIndex)[1].InterfaceIndex }
New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress "192.168.25.20" -PrefixLength 24
Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "192.168.25.10"

# Wacht-lus: Wacht tot het IP-adres stabiel en geldig is.
Write-Host "Wachten tot het netwerkadres stabiel is..."
$ip = $null
$counter = 0
while ($ip.AddressState -ne 'Preferred' -and $counter -lt 30) {
    Start-Sleep -Seconds 2
    $ip = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq "192.168.25.20"}
    Write-Host "Huidige status van IP-adres: $($ip.AddressState)"
    $counter++
}

if ($ip.AddressState -ne 'Preferred') {
    Write-Error "Netwerkadres kon niet stabiel worden gemaakt. Script stopt."
    exit 1
}
Write-Host "Netwerkadres is stabiel en Preferred. We gaan verder."

Write-Host "Stap 2: Machine toevoegen aan het domein... DEZE VM ZAL HERSTARTEN"
$wachtwoord = ConvertTo-SecureString "Vagrant123!" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("WS2-25-$voornaam\Admin1", $wachtwoord)
Add-Computer -DomainName "WS2-25-$voornaam.hogent" -Credential $credential -Restart -Force