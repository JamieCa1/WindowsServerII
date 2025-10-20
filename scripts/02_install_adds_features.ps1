# ================================================================= #
# Script:  02_install_adds_features.ps1
# Doel:    Installeer ADDS en DNS features
# ================================================================= #
$ErrorActionPreference = "Stop"
Write-Host "--- Stap 2: Installeren van AD-Domain-Services en DNS features ---" -ForegroundColor Green

try {
    # Controleer of feature al geïnstalleerd is om tijd te besparen
    $addsInstalled = Get-WindowsFeature -Name AD-Domain-Services | Select-Object -ExpandProperty Installed
    $dnsInstalled = Get-WindowsFeature -Name DNS | Select-Object -ExpandProperty Installed

    if (-not $addsInstalled -or -not $dnsInstalled) {
        Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
        Write-Host "ADDS en/of DNS features geïnstalleerd."
    } else {
        Write-Host "ADDS en DNS features waren al geïnstalleerd."
    }
} catch {
    Write-Error "Fout bij installeren features: $($_.Exception.Message)"
    exit 1
}

Write-Host "Klaar voor DC promotie."