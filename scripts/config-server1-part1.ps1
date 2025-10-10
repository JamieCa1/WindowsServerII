# ================================================================= #
# Script:  config-server1-part1.ps1 (FINALE VERSIE)
# ================================================================= #
Start-Sleep -Seconds 10
Set-SConfig -AutoLaunch $false
$voornaam = "Jamie"

Write-Host "Stap 1: Netwerkadapter configureren..."
$netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Sort-Object InterfaceIndex)[1].InterfaceIndex }

# ERROR HANDLING: Controleer of het IP-adres al bestaat voordat je het aanmaakt.
$ip = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq "192.168.25.10"}
if (-not $ip) {
    Write-Host "IP-adres 192.168.25.10 niet gevonden. Bezig met configureren..."
    New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress "192.168.25.10" -PrefixLength 24
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "127.0.0.1"
} else {
    Write-Host "IP-adres 192.168.25.10 is al geconfigureerd. Stap wordt overgeslagen."
}

# Wacht-lus: Wacht tot het IP-adres stabiel en geldig is.
Write-Host "Wachten tot het netwerkadres stabiel is..."
$ipCheck = $null
$counter = 0
while ($ipCheck.AddressState -ne 'Preferred' -and $counter -lt 30) {
    Start-Sleep -Seconds 2
    $ipCheck = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq "192.168.25.10"}
    Write-Host "Huidige status van IP-adres: $($ipCheck.AddressState)"
    $counter++
}
if ($ipCheck.AddressState -ne 'Preferred') {
    Write-Error "Netwerkadres kon niet stabiel worden gemaakt. Script stopt."
    exit 1
}
Write-Host "Netwerkadres is stabiel en Preferred. We gaan verder."

Write-Host "Stap 2: Benodigde Windows-rollen installeren..."
Install-WindowsFeature -Name AD-Domain-Services, DHCP, AD-Certificate, ADCS-Web-Enrollment, DNS, Web-Server, Web-Asp-Net45, NET-WCF-HTTP-Activation45, GPMC -IncludeManagementTools

Write-Host "Stap 3: Server promoten tot domeincontroller... Dit kan lang duren. Wacht geduldig."
try {
    Install-ADDSForest `
        -DomainName "WS2-25-$voornaam.hogent" `
        -DomainNetbiosName "WS2$($voornaam.ToUpper())" `
        -DomainMode Win2025 `
        -ForestMode Win2025 `
        -InstallDns:$true `
        -NoRebootOnCompletion:$false ` # <-- DIT IS DE CRUCIALE CORRECTIE
        -Force:$true
    Write-Host "Promotie tot domeincontroller is succesvol gestart. DEZE VM ZAL HERSTARTEN."
}
catch {
    # ERROR HANDLING: Vang eventuele fouten tijdens de promotie op en toon ze.
    Write-Error "Er is een kritieke fout opgetreden tijdens de domeinpromotie:"
    Write-Error $_.Exception.Message
    exit 1
}