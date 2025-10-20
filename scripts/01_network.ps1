# ================================================================= #
# Script:  01_network.ps1
# Doel:    Netwerkconfiguratie voor server1
# ================================================================= #
$ErrorActionPreference = "Stop"
Write-Host "--- Stap 1: Netwerkadapter configureren ---" -ForegroundColor Green

# Wacht tot de tweede netwerkadapter actief is (max 2.5 min)
Write-Host "Wachten op tweede netwerkadapter (Host-Only)..."
$netAdapter = $null
for ($i=0; $i -lt 30; $i++) {
    # Zoek naar actieve adapters die niet de NAT-adapter zijn (InterfaceDescription bevat vaak 'NAT')
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*NAT*" }
    if ($adapters.Count -ge 1) {
        # Neem de eerste gevonden adapter die geen NAT is (meestal de tweede qua index)
        $netAdapter = $adapters | Sort-Object InterfaceIndex | Select-Object -First 1
        Write-Host "Adapter gevonden: $($netAdapter.Name) ($($netAdapter.InterfaceDescription))"
        break
    }
    Write-Host "Poging $($i+1)/30 - wacht 5 seconden..."
    Start-Sleep -Seconds 5
}
if (-not $netAdapter) {
    Write-Error "Host-Only netwerkadapter werd niet gevonden of niet 'Up', stop script."
    exit 1
}

# Configureer IP + DNS (alleen als nodig)
$targetIP = "192.168.25.10"
$existingIP = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -eq $targetIP}

if (-not $existingIP) {
    Write-Host "Instellen vast IP ($targetIP) en DNS (127.0.0.1)..."
    try {
        # Verwijder eventuele oude DHCP-adressen op deze adapter
        Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq 'Dhcp'} | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress $targetIP -PrefixLength 24
        Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "127.0.0.1"
        Write-Host "IP en DNS ingesteld."
    } catch {
        Write-Error "Fout bij instellen IP/DNS: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Host "IP-adres $targetIP al ingesteld, overslaan."
    # Zorg er wel voor dat DNS correct staat voor de promotie
    $currentDns = (Get-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
    if (($currentDns -notcontains "127.0.0.1") -or ($null -eq $currentDns)) {
        Write-Host "DNS corrigeren naar 127.0.0.1..."
        Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses "127.0.0.1"
    }
}

# Wacht tot IP-adres stabiel is
Write-Host "Wachten tot het IP-adres ($targetIP) stabiel is..."
$ipCheck = $null
$counter = 0
while ($ipCheck.AddressState -ne 'Preferred' -and $counter -lt 30) {
    Start-Sleep -Seconds 2
    $ipCheck = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq $targetIP}
    Write-Host "Huidige status IP-adres: $($ipCheck.AddressState)"
    $counter++
}
if ($ipCheck.AddressState -ne 'Preferred') {
    Write-Error "Netwerkadres ($targetIP) kon niet stabiel 'Preferred' worden gemaakt. Script stopt."
    exit 1
}

Write-Host "Netwerkconfiguratie stabiel en voltooid."
Start-Sleep -Seconds 5 # Kleine pauze voor volgende stap