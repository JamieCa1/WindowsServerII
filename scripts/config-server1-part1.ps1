# ================================================================= #
# Script:  config-server1-part1.ps1 
# ================================================================= #
Start-Sleep -Seconds 10
Set-SConfig -AutoLaunch $false
$voornaam = "Jamie"

Write-Host "Stap 1: Netwerkadapter configureren..."
$netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Sort-Object InterfaceIndex)[1].InterfaceIndex }

$ip = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq "192.168.25.10"}
if (-not $ip) {
    Write-Host "IP-adres 192.168.25.10 niet gevonden. Bezig met configureren..."
    New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress "192.168.25.10" -PrefixLength 24
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "127.0.0.1"
} else {
    Write-Host "IP-adres 192.168.25.10 is al geconfigureerd. Stap wordt overgeslagen."
}

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

Write-Host "Stap 2: Enkel Active Directory Domain Services installeren..."
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Write-Host "Stap 3: Server promoten tot domeincontroller..."
try {
    New-Item -Path "C:\vagrant\.dc_provisioned" -ItemType File -Force
    $wachtwoord = ConvertTo-SecureString "Vagrant123!" -AsPlainText -Force
    Install-ADDSForest `
        -DomainName "WS2-25-$voornaam.hogent" `
        -DomainNetbiosName "WS2$($voornaam.ToUpper())" `
        -DomainMode Win2025 `
        -ForestMode Win2025 `
        -InstallDns:$true `
        -SafeModeAdministratorPassword $wachtwoord `
        -NoRebootOnCompletion:$false `
        -Force:$true

    Write-Host "Promotie tot domeincontroller is succesvol gestart. DEZE VM ZAL HERSTARTEN."
}
catch {
    Write-Error "Er is een kritieke fout opgetreden tijdens de domeinpromotie:"
    Write-Error $_.Exception.Message
    exit 1
}