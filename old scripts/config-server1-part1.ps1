# ================================================================= #
# Script:  config-server1-part1.ps1 (fixed)
# ================================================================= #
$ErrorActionPreference = "Stop"
Start-Sleep -Seconds 10
Set-SConfig -AutoLaunch $false
$voornaam = "Jamie"
Write-Host "Stap 1: Netwerkadapter configureren..."

# Wacht tot de tweede netwerkadapter actief is
for ($i=0; $i -lt 30; $i++) {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Ethernet*" }
    if ($adapters.Count -ge 2) {
        Write-Host "Twee actieve netwerkadapters gevonden."
        break
    }
    Write-Host "Wachten op tweede netwerkadapter... ($i/30)"
    Start-Sleep -Seconds 5
}
if ($adapters.Count -lt 2) {
    Write-Error "Tweede netwerkadapter werd niet gevonden, stop script."
    exit 1
}

# Gebruik de tweede adapter (de host-only)
$netAdapter = $adapters | Sort-Object InterfaceIndex | Select-Object -Last 1
Write-Host "Gebruik adapter: $($netAdapter.Name)"

# Configureer IP + DNS
$existingIP = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -eq "192.168.25.10"}
if (-not $existingIP) {
    Write-Host "Instellen vast IP en DNS..."
    New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress "192.168.25.10" -PrefixLength 24
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "127.0.0.1"
} else {
    Write-Host "IP-adres 192.168.25.10 al ingesteld, overslaan."
}

# Rollen installeren
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Promotie
try {
    Write-Host "Start domeinpromotie..."
    $wachtwoord = ConvertTo-SecureString "Vagrant123!" -AsPlainText -Force
    Install-ADDSForest `
        -DomainName "WS2-25-$voornaam.hogent" `
        -DomainNetbiosName "WS2$($voornaam.ToUpper())" `
        -DomainMode Win2025 `
        -ForestMode Win2025 `
        -InstallDns:$true `
        -SafeModeAdministratorPassword $wachtwoord `
        -NoRebootOnCompletion:$true `
        -Force:$true

    # Markeer domein pas als succesvol aangemaakt
    Write-Host "Promotie voltooid, herstart volgt via Vagrant."
    exit 0
}
catch {
    Write-Error "Fout tijdens domeinpromotie: $($_.Exception.Message)"
    exit 1
}
