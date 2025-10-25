# ================================================================= #
# Script:  04_post_dc_features_ca_firewall.ps1
# Doel:    Installatie extra features, CA configuratie, Firewall na DC promo
# ================================================================= #
$ErrorActionPreference = "Stop"
Write-Host "--- Stap 4: Post-DC Configuratie (Features, CA, Firewall) ---" -ForegroundColor Green

# Wacht tot AD volledig operationeel is (max 5 min)
$maxAttempts = 60
$attempt = 0
Write-Host "Wachten tot Active Directory volledig operationeel is..."
while ($attempt -lt $maxAttempts) {
    $attempt++
    try {
        Get-ADDomain -ErrorAction Stop | Out-Null
        Write-Host "AD is operationeel!"
        break
    }
    catch {
        Write-Host "Poging $attempt/$maxAttempts - AD nog niet klaar, wacht 10 seconden..."
        Start-Sleep -Seconds 10
    }
}
if ($attempt -eq $maxAttempts) {
    Write-Error "Timeout: Active Directory werd niet operationeel binnen 5 minuten."
    exit 1
}

# --- STAP 4.1: INSTALLEER OVERIGE FEATURES ---
Write-Host "Installatie van overige features (DHCP, Web, CA, GPMC)..."
try {
    $featuresToInstall = @("DHCP", "Web-Server", "ADCS-Cert-Authority", "ADCS-Web-Enrollment", "GPMC", "Web-Asp-Net45", "NET-WCF-HTTP-Activation45") | Where-Object { -not (Get-WindowsFeature -Name $_).Installed }
    if ($featuresToInstall.Count -gt 0) {
        Install-WindowsFeature -Name $featuresToInstall -IncludeManagementTools
        Write-Host "Features geïnstalleerd: $($featuresToInstall -join ', ')"
    } else {
        Write-Host "Alle benodigde features waren al geïnstalleerd."
    }
} catch {
    Write-Error "Fout bij installeren overige features: $($_.Exception.Message)"
    exit 1
}

# --- STAP 4.2: CONFIGUREER CERTIFICATION AUTHORITY (CA) ---
Write-Host "Basisconfiguratie van de CA (Enterprise Root)..."
try {
    if (-not (Get-Service -Name CertSvc -ErrorAction SilentlyContinue)) {
        $domainInfo = Get-ADDomain
        Install-AdcsCertificationAuthority -CAType EnterpriseRootCA `
            -CACommonName "$($domainInfo.NetBIOSName)-CA" `
            -KeyLength 2048 `
            -HashAlgorithm SHA256 `
            -Force
        Install-AdcsWebEnrollment -Force
        Write-Host "CA is geconfigureerd. Wacht 15s op services..."
        Start-Sleep -Seconds 15
    } else {
        Write-Host "CA service (CertSvc) draait al, configuratie overgeslagen."
    }
} catch {
    Write-Error "Fout bij configureren CA: $($_.Exception.Message)" # Stop script bij CA fout
    exit 1
}

# --- STAP 4.3: CONFIGUREER SERVICE FIREWALL REGELS ---
Write-Host "Firewall regels voor services activeren..."
try {
    Enable-NetFirewallRule -DisplayGroup "Active Directory Domain Services" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "DNS Service" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "DHCP Server" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "World Wide Web Services (HTTP Traffic-In)" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "Active Directory Certificate Services" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
    Write-Host "Belangrijkste service firewall regels zijn (poging tot) geactiveerd."
} catch {
     Write-Warning "Kon niet alle firewall regels activeren: $($_.Exception.Message)"
}

Write-Host "Post-DC Features, CA, Firewall voltooid."