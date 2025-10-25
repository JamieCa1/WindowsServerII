# ================================================================= #
# Script:  03_promote_dc.ps1 - FIX
# Doel:    Promoveer server tot Domain Controller
# ================================================================= #
$ErrorActionPreference = "Stop"
# --- VARIABELEN (Pas aan!) ---
$voornaam         = "Jamie" # Jouw voornaam
$DomainName       = "WS2-25-$voornaam.hogent"
$NetbiosName      = "WS2JAMIE" # Jouw NetBIOS naam (MAX 15 karakters!)
$SafeModePassword = ConvertTo-SecureString "Vagrant123!" -AsPlainText -Force # WACHTWOORD VOOR Administrator!

Write-Host "--- Stap 3: Start DC promotie ---" -ForegroundColor Green
Write-Host "Domeinnaam: $DomainName"
Write-Host "NetBIOS Naam: $NetbiosName"

if ($NetbiosName.Length -gt 15) {
    Write-Error "NetBIOS naam '$NetbiosName' is te lang (max 15 karakters)."
    exit 1
}

try {
    Import-Module ADDSDeployment -ErrorAction Stop

    # BELANGRIJK: NoRebootOnCompletion MOET $true zijn
    Write-Host "Install-ADDSForest uitvoeren (NoRebootOnCompletion = $true)..."
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainMode "Win2025" `
        -DomainNetbiosName $NetbiosName `
        -ForestMode "Win2025" `
        -InstallDns:$true `
        -SafeModeAdministratorPassword $SafeModePassword `
        -CreateDnsDelegation:$false ` # <-- DEZE REGEL IS VERWIJDERD/UIT COMMENTAAR
        -DatabasePath "C:\Windows\NTDS" `
        -LogPath "C:\Windows\NTDS" `
        -SysvolPath "C:\Windows\SYSVOL" `
        -NoRebootOnCompletion:$true ` # <-- ESSENTIEEL VOOR VAGRANT RELOAD
        -Force:$true

    # Maak het vlag-bestand AAN NADAT de promotie succesvol is
    # (Optioneel, maar kan handig zijn voor debuggen)
    # New-Item -Path "C:\vagrant\.dc_provisioned" -ItemType File -Force
    # Write-Host "Vlag-bestand '.dc_provisioned' aangemaakt."

    Write-Host "DC promotie commando succesvol voltooid. Vagrant zal herstarten."
    exit 0 # Succes
} catch {
    Write-Error "FATALE FOUT tijdens domeinpromotie: $($_.Exception.Message)"
    exit 1 # Fout
}