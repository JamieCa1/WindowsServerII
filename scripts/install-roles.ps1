# ================================================================= #
# Script:  install-roles.ps1 (DEFINITIEVE VERSIE)
# Doel:    Installeert basis-rollen en laat Vagrant de herstart doen.
# ================================================================= #
Write-Host "Installeren van benodigde Windows-rollen..."
Install-WindowsFeature -Name AD-Domain-Services, DHCP, AD-Certificate, ADCS-Web-Enrollment, DNS, Web-Server, Web-Asp-Net45, NET-WCF-HTTP-Activation45 -IncludeManagementTools
Write-Host "Rollen geinstalleerd. Vagrant zal de machine nu herstarten."