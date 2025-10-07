# ================================================================= #
# Script:  config-client-part2.ps1 (NA de reboot)
# ================================================================= #
Write-Host "Stap 3: RSAT en SSMS installeren..."
Get-WindowsCapability -Name RSAT* -Online | Where-Object {
    $_.Name -like "*ActiveDirectory*" -or
    $_.Name -like "*DNS*" -or
    $_.Name -like "*DHCP*"
} | Add-WindowsCapability -Online
$ssmsUrl = "https://aka.ms/ssmsfullsetup"
$ssmsInstaller = "C:\vagrant\SSMS-Setup-ENU.exe"
Invoke-WebRequest -Uri $ssmsUrl -OutFile $ssmsInstaller
Start-Process $ssmsInstaller -ArgumentList "/install /quiet /norestart" -Wait
Write-Host "Stap 4: Automatische DNS-registratie uitschakelen..."
$netAdapterName = (Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*NAT*"}).Name
Set-DnsClient -InterfaceAlias $netAdapterName -RegisterThisConnectionsAddress $false
Write-Host "Configuratie van de client is voltooid."