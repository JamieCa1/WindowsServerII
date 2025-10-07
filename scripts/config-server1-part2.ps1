# ================================================================= #
# Script:  config-server1-part2.ps1 (NA de reboot)
# ================================================================= #
$voornaam = "Jamie"
Write-Host "Stap 4: Standaardwachtwoord voor nieuwe gebruikers instellen..."
$credential = Get-Credential -UserName "NieuweGebruikers" -Message "Voer het standaardwachtwoord in voor Admin1, Admin2, User1 en User2"
$wachtwoord = $credential.Password
Write-Host "Stap 5: OU's en gebruikers aanmaken..."
New-ADOrganizationalUnit -Name "Beheer" -Path "DC=WS2-25-$voornaam,DC=hogent"
New-ADOrganizationalUnit -Name "Staf" -Path "DC=WS2-25-$voornaam,DC=hogent"
New-ADOrganizationalUnit -Name "Computers" -Path "DC=WS2-25-$voornaam,DC=hogent"
New-ADUser -Name "Admin1" -SamAccountName "Admin1" -AccountPassword $wachtwoord -Enabled $true -Path "OU=Beheer,DC=WS2-25-$voornaam,DC=hogent"
New-ADUser -Name "Admin2" -SamAccountName "Admin2" -AccountPassword $wachtwoord -Enabled $true -Path "OU=Beheer,DC=WS2-25-$voornaam,DC=hogent"
New-ADUser -Name "User1" -SamAccountName "User1" -AccountPassword $wachtwoord -Enabled $true -Path "OU=Staf,DC=WS2-25-$voornaam,DC=hogent"
New-ADUser -Name "User2" -SamAccountName "User2" -AccountPassword $wachtwoord -Enabled $true -Path "OU=Staf,DC=WS2-25-$voornaam,DC=hogent"
Add-ADGroupMember -Identity "Domain Admins" -Members "Admin1", "Admin2"
Write-Host "Stap 6: DHCP-server configureren..."
Add-DhcpServerv4Scope -Name "ClientScope" -StartRange "192.168.25.50" -EndRange "192.168.25.150" -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId "192.168.25.0" -DnsServer "192.168.25.10" -DnsDomain "WS2-25-$voornaam.hogent"
Add-DhcpServerv4ExclusionRange -ScopeId "192.168.25.0" -StartRange "192.168.25.101" -EndRange "192.168.25.150"
Add-DhcpServerInDC -DnsName "server1.WS2-25-$voornaam.hogent"
Write-Host "Stap 7: Certification Authority configureren..."
Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -CACommonName "WS2-25-CA" -Force
Write-Host "Stap 8: Geavanceerde DNS-configuratie voltooien..."
Add-DnsServerPrimaryZone -NetworkID "192.168.25.0/24" -ReplicationScope "Domain"
Add-DnsServerResourceRecord -Ptr -Name "10" -ZoneName "25.168.192.in-addr.arpa" -PtrDomainName "server1.WS2-25-$voornaam.hogent"
Add-DnsServerResourceRecord -Ptr -Name "20" -ZoneName "25.168.192.in-addr.arpa" -PtrDomainName "server2.WS2-25-$voornaam.hogent"
Add-DnsServerResourceRecord -ZoneName "WS2-25-$voornaam.hogent" -NS -Name "." -NameServer "server2.WS2-25-$voornaam.hogent"
Set-DnsServerPrimaryZone -Name "WS2-25-$voornaam.hogent" -SecureSecondaries "TransferToZoneNameServer"
Set-DnsServerPrimaryZone -Name "25.168.192.in-addr.arpa" -SecureSecondaries "TransferToZoneNameServer"
Write-Host "Stap 9: GPO aanmaken om de CA-certificaten te distribueren..."
$certPath = "C:\vagrant\WS2-25-CA.cer"
certutil.exe -ca.cert "$certPath"
$gpoName = "AutoTrust-CA"
New-GPO -Name $gpoName -Comment "Distribueert het root CA certificaat naar alle domeincomputers."
$gpoCert = Import-Certificate -FilePath $certPath
New-GPOCertificate -GPO $gpoName -Store "Root" -Certificate $gpoCert
New-GPLink -Name $gpoName -Target "dc=WS2-25-$voornaam,dc=hogent"
Write-Host "Stap 10: Firewall-regels configureren..."
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"
Enable-NetFirewallRule -DisplayGroup "Active Directory Domain Services"
Enable-NetFirewallRule -DisplayGroup "DNS Service"
Enable-NetFirewallRule -DisplayGroup "DHCP Server"
New-NetFirewallRule -DisplayName "HTTP-In for CertSrv" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80
Write-Host "Configuratie van server1 is voltooid."