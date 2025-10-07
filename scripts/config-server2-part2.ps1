# ================================================================= #
# Script:  config-server2-part2.ps1 (NA de reboot)
# ================================================================= #
$voornaam = "Jamie"
Write-Host "Stap 3: DNS-rol installeren..."
Install-WindowsFeature DNS -IncludeManagementTools
Write-Host "Stap 4: DNS configureren als secundaire server..."
Add-DnsServerSecondaryZone -Name "WS2-25-$voornaam.hogent" -ZoneFile "WS2-25-$voornaam.hogent.dns" -MasterServers "192.168.25.10"
Add-DnsServerSecondaryZone -Name "25.168.192.in-addr.arpa" -ZoneFile "25.168.192.in-addr.arpa.dns" -MasterServers "192.168.25.10"
Write-Host "Stap 5: SQL Server installeren..."
$isoName = "enu_sql_server_2022_standard_edition_x64_dvd_43079f69.iso"
$isoPath = "C:\vagrant\$isoName"
Mount-DiskImage -ImagePath $isoPath
$driveLetter = (Get-DiskImage -ImagePath $isoPath | Get-Volume).DriveLetter
& "${driveLetter}:\setup.exe" /q /ACTION=Install /FEATURES=SQLENGINE /INSTANCENAME=MSSQLSERVER /SQLSVCACCOUNT="NT AUTHORITY\System" /SQLSYSADMINACCOUNTS="BUILTIN\ADMINISTRATORS" /AGTSVCACCOUNT="NT AUTHORITY\Network Service" /IACCEPTSQLSERVERLICENSETERMS
Dismount-DiskImage -ImagePath $isoPath
Write-Host "Stap 6: Firewall-regels configureren..."
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"
New-NetFirewallRule -DisplayName "SQL-In" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
Enable-NetFirewallRule -DisplayGroup "Network Discovery"
Write-Host "Configuratie van server2 is voltooid."