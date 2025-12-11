Vagrant.configure("2") do |config|
    nodes = {
      "manager" => "192.168.56.10",
      "linux-1" => "192.168.56.11",
      "linux-2" => "192.168.56.12"
    }
  
    config.vm.box = "ubuntu/jammy64"
  
    config.vm.provider :virtualbox do |vb|
      vb.memory = 2048
      vb.cpus = 2
    end
  
    nodes.each do |name, ip|
      config.vm.define name do |node|
        node.vm.hostname = name
        node.vm.network "private_network", ip: ip
  
        node.vm.synced_folder ".", "/vagrant", type: "virtualbox"

        node.vm.provision "shell", path: "scripts/install_docker.sh"
  
        node.vm.provision "shell", path: "scripts/swarm_init.sh", args: [ip, name], run: "always"
      end
    end
  
    config.vm.define "linux-3" do |node|
      node.vm.hostname = "linux-3"
      node.vm.network "private_network", ip: "192.168.56.13"
      
      node.vm.synced_folder ".", "/vagrant", type: "virtualbox"
      
      node.vm.provision "shell", path: "scripts/install_docker.sh"
  
      node.vm.provision "shell", path: "scripts/swarm_init.sh", args: ["192.168.56.13", "linux-3"], run: "always"
    end
  end
  