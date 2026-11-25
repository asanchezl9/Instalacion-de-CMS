Vagrant.configure("2") do |config|
  # Imagen base común para las 8 máquinas (Debian 12)
  config.vm.box = "debian/bookworm64"

  # ----------------------------------------------------------------------------
  # CAPA 4: Clúster MariaDB Galera (3 nodos)
  # ----------------------------------------------------------------------------
  config.vm.define "serverdatosAmparo" do |node|
    node.vm.hostname = "serverdatosAmparo"
    node.vm.network "private_network", ip: "192.168.10.41", virtualbox__intnet: "red_lemp_ha"
    node.vm.provider "virtualbox" do |vb|
      vb.name = "serverdatosAmparo"
      vb.memory = "1024"
      vb.cpus = 1
    end
    node.vm.provision "shell", path: "provision/galera.sh", args: ["192.168.10.41", "bootstrap"]
  end

  config.vm.define "serverdatos2Amparo" do |node|
    node.vm.hostname = "serverdatos2Amparo"
    node.vm.network "private_network", ip: "192.168.10.42", virtualbox__intnet: "red_lemp_ha"
    node.vm.provider "virtualbox" do |vb|
      vb.name = "serverdatos2Amparo"
      vb.memory = "1024"
      vb.cpus = 1
    end
    node.vm.provision "shell", path: "provision/galera.sh", args: ["192.168.10.42", "join"]
  end

  config.vm.define "serverdatos3Amparo" do |node|
    node.vm.hostname = "serverdatos3Amparo"
    node.vm.network "private_network", ip: "192.168.10.43", virtualbox__intnet: "red_lemp_ha"
    node.vm.provider "virtualbox" do |vb|
      vb.name = "serverdatos3Amparo"
      vb.memory = "1024"
      vb.cpus = 1
    end
    node.vm.provision "shell", path: "provision/galera.sh", args: ["192.168.10.43", "join"]
  end

  # ----------------------------------------------------------------------------
  # CAPA 3: Balanceador de base de datos HAProxy
  # ----------------------------------------------------------------------------
  config.vm.define "proxyBBDDAmparo" do |node|
    node.vm.hostname = "proxyBBDDAmparo"
    node.vm.network "private_network", ip: "192.168.10.30", virtualbox__intnet: "red_lemp_ha"
    node.vm.provider "virtualbox" do |vb|
      vb.name = "proxyBBDDAmparo"
      vb.memory = "512"
      vb.cpus = 1
    end
    node.vm.provision "shell", path: "provision/haproxy.sh"
  end

  # ----------------------------------------------------------------------------
  # CAPA 2: Servidor NFS + PHP-FPM + WordPress y 2 servidores web Nginx
  # ----------------------------------------------------------------------------
  config.vm.define "serverNFSAmparo" do |node|
    node.vm.hostname = "serverNFSAmparo"
    node.vm.network "private_network", ip: "192.168.10.20", virtualbox__intnet: "red_lemp_ha"
    node.vm.provider "virtualbox" do |vb|
      vb.name = "serverNFSAmparo"
      vb.memory = "512"
      vb.cpus = 1
    end
    node.vm.provision "shell", path: "provision/nfs_php.sh"
  end

  config.vm.define "serverweb1Amparo" do |node|
    node.vm.hostname = "serverweb1Amparo"
    node.vm.network "private_network", ip: "192.168.10.21", virtualbox__intnet: "red_lemp_ha"
    node.vm.provider "virtualbox" do |vb|
      vb.name = "serverweb1Amparo"
      vb.memory = "512"
      vb.cpus = 1
    end
    node.vm.provision "shell", path: "provision/web.sh"
  end

  config.vm.define "serverweb2Amparo" do |node|
    node.vm.hostname = "serverweb2Amparo"
    node.vm.network "private_network", ip: "192.168.10.22", virtualbox__intnet: "red_lemp_ha"
    node.vm.provider "virtualbox" do |vb|
      vb.name = "serverweb2Amparo"
      vb.memory = "512"
      vb.cpus = 1
    end
    node.vm.provision "shell", path: "provision/web.sh"
  end

  # ----------------------------------------------------------------------------
  # CAPA 1: Balanceador de carga Nginx (única máquina expuesta al anfitrión)
  # ----------------------------------------------------------------------------
  config.vm.define "balanceadorAmparo" do |node|
    node.vm.hostname = "balanceadorAmparo"
    node.vm.network "private_network", ip: "192.168.10.10", virtualbox__intnet: "red_lemp_ha"
    node.vm.network "forwarded_port", guest: 80, host: 8080
    node.vm.provider "virtualbox" do |vb|
      vb.name = "balanceadorAmparo"
      vb.memory = "512"
      vb.cpus = 1
    end
    node.vm.provision "shell", path: "provision/balanceador.sh"
  end
end