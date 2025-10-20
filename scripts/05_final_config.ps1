# ================================================================= #
# Script:  05_final_config.ps1 (DHCP, DNS, Users/OU, GPO) - FIX v2
# Doel:    Finale configuraties na de herstart, met robuuste checks
# ================================================================= #
$ErrorActionPreference = "Stop" # Stop bij ECHTE fouten
$voornaam = "Jamie" # Jouw voornaam
$wachtwoord = ConvertTo-SecureString "Vagrant123!" -AsPlainText -Force # Standaard wachtwoord
$domainFqdn = "WS2-25-$voornaam.hogent"
# Bouw DC path correct op, zelfs met meerdere delen in voornaam etc.
$domainDN = (Get-ADDomain).DistinguishedName
$domainPath = $domainDN # Gebruik DistinguishedName als basis pad
$reverseZone = "25.168.192.in-addr.arpa"
$scopeId = "192.168.25.0"
$scopeIdObject = $scopeId -as [ipaddress]

Write-Host "--- Stap 5: Finale Configuratie (DHCP, DNS, Users/OU, GPO) ---" -ForegroundColor Green

# --- STAP 5.1: OU's en Gebruikers Aanmaken ---
Write-Host "Controleren/aanmaken OU's en Standaard Gebruikers..."
try {
    # Functie om OU aan te maken indien niet bestaand
    function New-ADOUIfNotExists {
        param([string]$Name, [string]$Path)
        # Gebruik een specifieke LDAP filter en zoek alleen direct onder het pad
        $ldapFilter = "(&(objectClass=organizationalUnit)(name=$Name))"
        if (-not (Get-ADOrganizationalUnit -LDAPFilter $ldapFilter -SearchBase $Path -SearchScope OneLevel -ErrorAction SilentlyContinue)) {
            Write-Host "OU '$Name' aanmaken in '$Path'..."
            New-ADOrganizationalUnit -Name $Name -Path $Path
        } else {
            Write-Host "OU '$Name' bestaat al in '$Path'."
        }
    }

    New-ADOUIfNotExists -Name "Beheer" -Path $domainPath
    New-ADOUIfNotExists -Name "Staf" -Path $domainPath
    New-ADOUIfNotExists -Name "Computers" -Path $domainPath

    # Functie om gebruiker aan te maken indien niet bestaand
    function New-ADUserIfNotExists {
        param(
            [string]$Name,
            [string]$SamAccountName,
            [string]$OUPath, # Volledig pad naar OU
            [securestring]$Password,
            [bool]$IsAdmin = $false
        )
        # Check specifiek op SamAccountName (domein-breed uniek)
        if (-not (Get-ADUser -Filter {SamAccountName -eq $SamAccountName} -ErrorAction SilentlyContinue)) {
            Write-Host "Gebruiker '$SamAccountName' aanmaken in '$OUPath'..."
            New-ADUser -Name $Name -SamAccountName $SamAccountName -AccountPassword $Password -Enabled $true -Path $OUPath `
                       -UserPrincipalName "$SamAccountName@$domainFqdn" # Best practice
            if ($IsAdmin) {
                # Wacht even voor user object volledig is gerepliceerd
                Start-Sleep -Seconds 3
                try {
                    Add-ADGroupMember -Identity "Domain Admins" -Members $SamAccountName
                    Write-Host "'$SamAccountName' toegevoegd aan Domain Admins."
                } catch {
                     Write-Warning "Kon gebruiker '$SamAccountName' niet direct toevoegen aan Domain Admins: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Host "Gebruiker '$SamAccountName' bestaat al."
        }
    }

    $beheerOUPath = "OU=Beheer,$domainPath"
    $stafOUPath = "OU=Staf,$domainPath"

    New-ADUserIfNotExists -Name "Admin1" -SamAccountName "Admin1" -OUPath $beheerOUPath -Password $wachtwoord -IsAdmin $true
    New-ADUserIfNotExists -Name "Admin2" -SamAccountName "Admin2" -OUPath $beheerOUPath -Password $wachtwoord -IsAdmin $true
    New-ADUserIfNotExists -Name "User1" -SamAccountName "User1" -OUPath $stafOUPath -Password $wachtwoord
    New-ADUserIfNotExists -Name "User2" -SamAccountName "User2" -OUPath $stafOUPath -Password $wachtwoord

    Write-Host "OU's en gebruikers gecontroleerd/aangemaakt."

} catch {
    # Vang specifiek de "already exists" fout af en geef een waarschuwing i.p.v. een error
    if ($_.Exception.GetType().Name -eq 'ADIdentityAlreadyExistsException' -or $_.Exception.Message -like "*already in use*") {
        Write-Warning "Object (OU/User) bestond al, dit is waarschijnlijk OK: $($_.TargetObject)"
        # Ga door met het script!
    } else {
        # Voor andere fouten, stop wel
        Write-Error "Onverwachte Fout bij aanmaken OU's/Gebruikers: $($_.Exception.Message)"
        exit 1
    }
}

# --- STAP 5.2: DHCP Server Configureren ---
Write-Host "Configureren DHCP Server..."
try {
    # Wacht tot DHCP service gestart is
    $dhcpService = Get-Service -Name DHCPServer -ErrorAction SilentlyContinue
    if ($dhcpService -and $dhcpService.Status -ne 'Running') {
        Write-Host "Wachten op DHCP Service..."
        Start-Sleep -Seconds 15
    }

    # Voeg scope alleen toe als deze nog niet bestaat
    if (-not (Get-DhcpServerv4Scope -ComputerName localhost -ScopeId $scopeIdObject -ErrorAction SilentlyContinue)) {
        Write-Host "DHCP scope $scopeId aanmaken..."
        Add-DhcpServerv4Scope -Name "ClientScope" -StartRange "192.168.25.50" -EndRange "192.168.25.150" -SubnetMask 255.255.255.0 -State Active
        Write-Host "Scope aangemaakt. Opties instellen..."
        Set-DhcpServerv4OptionValue -ScopeId $scopeIdObject -DnsServer "192.168.25.10" -DnsDomain $domainFqdn -Router "192.168.25.1" # Router is vaak .1 in host-only
        Write-Host "Exclusion range toevoegen..."
        Add-DhcpServerv4ExclusionRange -ScopeId $scopeIdObject -StartRange "192.168.25.101" -EndRange "192.168.25.150"
    } else {
        Write-Host "DHCP scope $scopeId bestaat al."
        # Zorg wel dat de opties correct staan
        Set-DhcpServerv4OptionValue -ScopeId $scopeIdObject -DnsServer "192.168.25.10" -DnsDomain $domainFqdn -Router "192.168.25.1" -ErrorAction SilentlyContinue
    }

    # Autoriseer DHCP in AD (indien nog niet gebeurd)
    $dhcpServerFqdn = "server1.$domainFqdn"
    if (-not (Get-DhcpServerInDC -DnsName $dhcpServerFqdn -ErrorAction SilentlyContinue)) {
        Write-Host "DHCP Server autoriseren in Active Directory..."
         Add-DhcpServerInDC -DnsName $dhcpServerFqdn
    } else {
        Write-Host "DHCP Server was al geautoriseerd in AD."
    }
    Write-Host "DHCP Service herstarten (force)..."
    Restart-Service DHCPServer -Force
    Write-Host "DHCP geconfigureerd."
} catch {
    Write-Error "Fout bij configureren DHCP: $($_.Exception.Message)"
    exit 1
}

# --- STAP 5.3: Geavanceerde DNS Configuratie ---
Write-Host "Configureren Geavanceerde DNS (Reverse Zone, PTRs, Secure Transfer)..."
try {
    # Maak reverse zone alleen aan als deze niet bestaat
    if (-not (Get-DnsServerZone -Name $reverseZone -ComputerName localhost -ErrorAction SilentlyContinue)) {
        Write-Host "Reverse DNS zone $reverseZone aanmaken..."
        # Gebruik NetworkID voor correcte naam
        Add-DnsServerPrimaryZone -NetworkID $scopeId -ReplicationScope "Domain"
    } else {
        Write-Host "Reverse zone $reverseZone bestaat al."
    }

    # Wacht even tot zone volledig gerepliceerd is binnen AD DNS
    Start-Sleep -Seconds 15

    # Maak PTR records alleen aan als ze niet bestaan
    Write-Host "Controleren/aanmaken PTR records..."
    $server1PtrName = "server1.$domainFqdn"
    $server2PtrName = "server2.$domainFqdn" # Belangrijk voor later

    if (-not (Get-DnsServerResourceRecord -ZoneName $reverseZone -Name "10" -RRType Ptr -ComputerName localhost -ErrorAction SilentlyContinue)) {
        Add-DnsServerResourceRecord -Ptr -Name "10" -ZoneName $reverseZone -PtrDomainName $server1PtrName -TimeToLive (New-TimeSpan -Hours 1)
    }
    if (-not (Get-DnsServerResourceRecord -ZoneName $reverseZone -Name "20" -RRType Ptr -ComputerName localhost -ErrorAction SilentlyContinue)) {
        Add-DnsServerResourceRecord -Ptr -Name "20" -ZoneName $reverseZone -PtrDomainName $server2PtrName -TimeToLive (New-TimeSpan -Hours 1)
    }

    # Voeg NS record voor server2 toe aan de forward zone
     if (-not (Get-DnsServerResourceRecord -ZoneName $domainFqdn -Name "@" -RRType Ns -ComputerName localhost -ErrorAction SilentlyContinue | Where-Object {$_.RecordData.NameServer -eq "$server2PtrName."})) { # Punt op einde is belangrijk!
        Write-Host "NS record voor $server2PtrName toevoegen aan $domainFqdn..."
        Add-DnsServerResourceRecord -ZoneName $domainFqdn -Ns -Name "@" -NameServer $server2PtrName
    } else {
         Write-Host "NS record voor $server2PtrName bestaat al in $domainFqdn."
    }

    # Stel secure secondaries en notify in (belangrijk voor server2)
    Write-Host "Zone transfer instellingen configureren..."
    # Haal ALLE Name Servers op uit de zone (inclusief de net toegevoegde server2)
    $nameServers = (Get-DnsServerZone -Name $domainFqdn -ComputerName localhost).NameServers.RecordData.NameServer
    if ($nameServers) {
        Set-DnsServerPrimaryZone -Name $domainFqdn -SecureSecondaries "TransferToSecureServers" -Notify "NotifyServers" -SecondaryServers $nameServers -ErrorAction SilentlyContinue
        Set-DnsServerPrimaryZone -Name $reverseZone -SecureSecondaries "TransferToSecureServers" -Notify "NotifyServers" -SecondaryServers $nameServers -ErrorAction SilentlyContinue
        Write-Host "Zone transfer ingesteld voor Name Servers: $($nameServers -join ', ')"
    } else {
        Write-Warning "Kon geen Name Servers vinden om Zone Transfer voor in te stellen."
    }

    Write-Host "DNS configuratie voltooid."
} catch {
     Write-Error "Fout bij configureren DNS: $($_.Exception.Message)"
     exit 1
}

# --- STAP 5.4: GPO voor CA Certificaat Distributie ---
Write-Host "Controleren en eventueel aanmaken GPO voor CA distributie..."
# Controleer of de CA service draait EN de web enrollment feature geïnstalleerd is
if ((Get-Service -Name CertSvc -ErrorAction SilentlyContinue) -and (Get-WindowsFeature -Name ADCS-Web-Enrollment).Installed) {
    try {
        $gpoName = "AutoTrust-CA"
        if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
            Write-Host "Aanmaken GPO '$gpoName'..."

            # Zoek de CA naam dynamisch
            $caConfig = Get-CA -ErrorAction SilentlyContinue
            if ($caConfig) {
                $caName = $caConfig.Name
                # Exporteer het Root CA certificaat
                $certPath = "C:\vagrant\$($caName)_CA_Cert.cer" # Unieke naam in gedeelde map
                certutil.exe -ca.cert "$certPath"
                if (Test-Path $certPath) {
                    Write-Host "CA certificaat geëxporteerd naar $certPath"

                    # Maak GPO en importeer certificaat
                    $newGPO = New-GPO -Name $gpoName -Comment "Distribueert het root CA certificaat naar alle domeincomputers."
                    # Gebruik Import-GPOCertificate (vereist GPMC feature)
                    Import-GPOCertificate -Path $certPath -TargetStore Computer -StoreName Root -GPO $newGPO.DisplayName
                    New-GPLink -Name $newGPO.DisplayName -Target $domainPath
                    Write-Host "GPO '$gpoName' aangemaakt, certificaat geïmporteerd en gelinkt aan domein."
                    Remove-Item $certPath -ErrorAction SilentlyContinue # Ruim op
                } else {
                    Write-Warning "Exporteren CA certificaat met certutil.exe mislukt."
                }
            } else {
                Write-Warning "Kon CA configuratie niet vinden om certificaat te exporteren."
            }
        } else {
            Write-Host "GPO '$gpoName' bestaat al."
        }
    } catch {
        Write-Warning "Fout bij aanmaken/linken GPO voor CA: $($_.Exception.Message)"
        # Ga door
    }
} else {
    Write-Warning "CA Service (CertSvc) of Web Enrollment niet gevonden/actief, GPO stap overgeslagen."
}

Write-Host "Finale configuratie voltooid."