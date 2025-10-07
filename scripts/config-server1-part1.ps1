# ================================================================= #
# Script:  config-server1-part1.ps1 (VOOR de reboot) - FINALE VERSIE
# ================================================================= #

# OPLOSSING 1: Forceer het verlaten van SConfig en start een PowerShell-prompt
# Dit zorgt ervoor dat het script altijd kan draaien, zelfs als SConfig start.

$voornaam = "Jamie"

# OPLOSSING 2: Correctie van de typefout in het IP-adres (192 i.p.v. 19)
# en verwijdering van de '-DefaultGateway' parameter.
Write-Host "Stap 1: Netwerkadapter configureren..."
$netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Sort-Object InterfaceIndex)[1].InterfaceIndex }
New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress "192.168.25.10" -PrefixLength 24
Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "127.0.0.1"

# OPLOSSING 3: Gebruik de correcte feature-namen voor Web Enrollment.
Write-Host "Stap 2: Benodigde Windows-rollen installeren..."
Install-WindowsFeature -Name AD-Domain-Services, DHCP, AD-Certificate, ADCS-Web-Enrollment, DNS, Web-Server, Web-Asp-Net45, NET-WCF-HTTP-Activation45 -IncludeManagementTools

# OPLOSSING 4: Gebruik de correcte waarde 'Win2025'.
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