# Windows Server II - Vagrant template
#  2025-2026
# ------------------------------------
#                                      
# This is the Vagrantfile for the assignment of Windows Server II - 2025-2026.
# The setup consists of 2 Windows Server machines (no GUI) and 1 Windows 10 client.
#
# Use `vagrant up` to bring up the environment, 
#   or `vagrant reload` to redeploy the environment after changing this file.
#
# You are allowed to modify this file as needed.
# However, you are not allowed to use any other vagrant boxes than the ones used in this file:
# - Windows Server 2025 core (no GUI): gusztavvargadr/windows-server-2025-standard-core
# - Windows 10 Enterprise 22H2: gusztavvargadr/windows-10-22h2-enterprise
# For both versions, the version is pinned to 2506.0.0 - do not change this.
# You can change the amount of vRAM and vCPU assigned to each VM if needed.
# Each VM has 2 network interfaces:
# - first adapter in (default) NAT mode, for internet access + vagrant
# - second adapter connected to a (private) Host-Only network (no IP configuration done, this needs to be done by PowerShell!)
# Use PowerShell scripts to configure the second NIC interfaces, 
#   and to install and configure the required software.
# You are allowed to add lines for automatic provisioning

Vagrant.configure("2") do |config|
  # Server 1
  config.vm.define "server1" do |server1|
    # This is the base image for the VM - do not change this!
    server1.vm.box = "gusztavvargadr/windows-server-2025-standard-core"
    server1.vm.box_version = "2506.0.0"
    # Connect the second adapter to an internal network, do not configure IP (the provided IP is just a place holder)
    server1.vm.network "private_network", ip: "192.168.25.10", auto_config: false
    # Set the host name of the VM
    server1.vm.hostname = "server1"
    # --- CRUCIALE TIMEOUT INSTELLINGEN ---
    server1.winrm.transport = :plaintext
    server1.winrm.basic_auth_only = true

    # VirtualBox specific configuration
    server1.vm.provider "virtualbox" do |vb|
      # VirtualBox Display Name
      vb.name = "server1"
      # VirtualBox Group
      vb.customize ["modifyvm", :id, "--groups", "/WS2"]
      # 2GB vRAM
      vb.memory = "4048"
      # 2vCPU
      vb.cpus = "2"
    end

# --- PROVISIONING MET NIEUWE SCRIPTS EN GEBRUIKERSWISSEL ---

    # Fase 1: Voorbereiding en Promotie (als 'vagrant')
    server1.vm.provision "shell", path: "scripts/01_network.ps1", run: "once", name: "Configure Network"
    server1.vm.provision "shell", path: "scripts/02_install_adds_features.ps1", run: "once", name: "Install ADDS Features"
    server1.vm.provision "shell", path: "scripts/03_promote_dc.ps1", run: "once", name: "Promote DC"
    server1.vm.provision "shell", reboot: true
    server1.vm.provision "shell", path: "scripts/04_post_dc_features_ca_firewall.ps1", run: "once", name: "Post-DC Features/CA/Firewall"
    server1.vm.provision "shell", path: "scripts/05_final_config.ps1", run: "once", name: "Final Config (DHCP/DNS/Users/GPO)"
  end

  # Server 2 (met vertraging)
  config.vm.define "server2" do |server2|
    server2.vm.box = "gusztavvargadr/windows-server-2025-standard-core"
    server2.vm.box_version = "2506.0.0"
    server2.vm.network "private_network", ip: "192.168.25.20", auto_config: false
    server2.vm.hostname = "server2"
    server2.vm.provider "virtualbox" do |vb|
      vb.name = "server2"
      vb.customize ["modifyvm", :id, "--groups", "/WS2"]
      vb.memory = "3072"
      vb.cpus = "2"
    end

    # Wacht even voor server1 klaar is
    server2.vm.provision "shell", inline: "Start-Sleep -Seconds 60", run: "once" 

    server2.vm.provision "shell", path: "scripts/config-server2-part1.ps1", run: "once"
    server2.vm.provision "reload" 
    server2.vm.provision "shell", path: "scripts/config-server2-part2.ps1", run: "once"
  end

  # Client (met vertraging)
  config.vm.define "client" do |client|
    client.vm.box = "gusztavvargadr/windows-10-22h2-enterprise"
    client.vm.box_version = "2506.0.0"
    client.vm.network "private_network", ip: "192.168.25.30", auto_config: false
    client.vm.hostname = "client"
    client.vm.provider "virtualbox" do |vb|
      vb.name = "client"
      vb.customize ["modifyvm", :id, "--groups", "/WS2"]
      vb.memory = "2048"
      vb.cpus = "2"
    end
    
    # Wacht even voor server1 klaar is
    client.vm.provision "shell", inline: "Start-Sleep -Seconds 60", run: "once"

    client.vm.provision "shell", path: "scripts/config-client-part1.ps1", run: "once"
    client.vm.provision "reload" 
    client.vm.provision "shell", path: "scripts/config-client-part2.ps1", run: "once"
  end

end