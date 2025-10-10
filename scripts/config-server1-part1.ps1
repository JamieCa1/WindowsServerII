# ================================================================= #
# Script:  config-server1-part1.ps1 (FINALE VERSIE)
# ================================================================= #
Write-Host "Start van de configuratie... Wacht 15 seconden tot de VM stabiel is."
Start-Sleep -Seconds 15

Write-Host "SConfig uitschakelen om automatisering mogelijk te maken..."
Set-SConfig -AutoLaunch $false

$voornaam = "Jamie"

Write-Host "Stap 1: Netwerkadapter configureren..."
$netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Sort-Object InterfaceIndex)[1].InterfaceIndex }
New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress "192.168.25.10" -PrefixLength 24
Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "127.0.0.1"

# Wacht-lus: Wacht tot het IP-adres stabiel en geldig is. DIT IS CRUCIAAL.
Write-Host "Wachten tot het netwerkadres stabiel is..."
$ip = $null
$counter = 0
while ($ip.AddressState -ne 'Preferred' -and $counter -lt 30) {
    Start-Sleep -Seconds 2
    $ip = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq "192.168.25.10"}
    Write-Host "Huidige status van IP-adres: $($ip.AddressState)"
    $counter++
}

if ($ip.AddressState -ne 'Preferred') {
    Write-Error "Netwerkadres kon niet stabiel worden gemaakt. Script stopt."
    exit 1
}
Write-Host "Netwerkadres is stabiel en Preferred. We gaan verder."

Write-Host "Stap 2: Benodigde Windows-rollen installeren..."
Install-WindowsFeature -Name AD-Domain-Services, DHCP, AD-Certificate, ADCS-Web-Enrollment, DNS, Web-Server, Web-Asp-Net45, NET-WCF-HTTP-Activation45, GPMC -IncludeManagementTools

Write-Host "Stap 3: Server promoten tot domeincontroller... DEZE VM ZAL HERSTARTEN"
Import-Module ADDSDeployment
Install-ADDSForest `
    -DomainName "WS2-25-$voornaam.hogent" `
    -DomainNetbiosName "WS2$($voornaam.ToUpper())" `
    -DomainMode Win2025 `
    -ForestMode Win2025 `
    -InstallDns:$true `
    -NoRebootOnCompletion:$true `
    -Force:$true