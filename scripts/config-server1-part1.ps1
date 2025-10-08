# ================================================================= #
# Script:  config-server1-part1.ps1 (PROMOTIE-VERSIE)
# ================================================================= #
Start-Sleep -Seconds 15
Set-SConfig -AutoLaunch $false
$voornaam = "Jamie"

# Netwerkconfiguratie (zoals je terecht opmerkte)
Write-Host "Stap 1: Netwerkadapter configureren..."
$netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Sort-Object InterfaceIndex)[1].InterfaceIndex }
New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress "192.168.25.10" -PrefixLength 24
Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "127.0.0.1"

# Domeinpromotie
Write-Host "Stap 3: Server promoten tot domeincontroller... DEZE VM ZAL HERSTARTEN"
Import-Module ADDSDeployment
Install-ADDSForest `
    -DomainName "WS2-25-$voornaam.hogent" `
    -DomainNetbiosName "WS2$($voornaam.ToUpper())" `
    -DomainMode Win2025 `
    -ForestMode Win2025 `
    -InstallDns:$true `
    -NoRebootOnCompletion:$false `
    -Force:$true