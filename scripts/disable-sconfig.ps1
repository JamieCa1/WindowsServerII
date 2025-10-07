# ================================================================= #
# Script:  disable-sconfig.ps1
# Doel:    SConfig uitschakelen en de machine herstarten.
# ================================================================= #
Set-SConfig -AutoLaunch $false
Restart-Computer -Force