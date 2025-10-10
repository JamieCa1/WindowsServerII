# ================================================================= #
# Script:  config-server2-part1.ps1 (FINALE VERSIE)
# ================================================================= #
Start-Sleep -Seconds 10
Set-SConfig -AutoLaunch $false
$voornaam = "Jamie"

Write-Host "Stap 1: Netwerkadapter configureren..."
$netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Sort-Object InterfaceIndex)[1].InterfaceIndex }

# ERROR HANDLING: Controleer of het IP-adres al bestaat.
$ip = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq "192.168.25.20"}
if (-not $ip) {
    Write-Host "IP-adres 192.168.25.20 niet gevonden. Bezig met configureren..."
    New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress "192.168.25.20" -PrefixLength 24
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "192.168.25.10"
} else {
    Write-Host "IP-adres 192.168.25.20 is al geconfigureerd. Stap wordt overgeslagen."
}

# Wacht-lus: Wacht tot het IP-adres stabiel en geldig is.
Write-Host "Wachten tot het netwerkadres stabiel is..."
$ipCheck = $null
$counter = 0
while ($ipCheck.AddressState -ne 'Preferred' -and $counter -lt 30) {
    Start-Sleep -Seconds 2
    $ipCheck = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq "192.168.25.20"}
    Write-Host "Huidige status van IP-adres: $($ipCheck.AddressState)"
    $counter++
}
if ($ipCheck.AddressState -ne 'Preferred') {
    Write-Error "Netwerkadres kon niet stabiel worden gemaakt. Script stopt."
    exit 1
}
Write-Host "Netwerkadres is stabiel en Preferred. We gaan verder."

Write-Host "Stap 2: Machine toevoegen aan het domein... DEZE VM ZAL HERSTARTEN"
$wachtwoord = ConvertTo-SecureString "Vagrant123!" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("WS2-25-$voornaam\Admin1", $wachtwoord)
Add-Computer -DomainName "WS2-25-$voornaam.hogent" -Credential $credential -Restart -Force