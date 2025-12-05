Vagrant.configure("2") do |config|
  vm_configs = {
    :node1 => { :hostname => "docker-swarm-1", :ip => "192.168.56.10" },
    :node2 => { :hostname => "docker-swarm-2", :ip => "192.168.56.11" },
    :node3 => { :hostname => "docker-swarm-3", :ip => "192.168.56.12" }
  }

  # config.vm.provider :libvirt do |libvirt|
  #   libvirt.driver = "kvm"
  #   libvirt.host = 'localhost'
  #   libvirt.uri = 'qemu:///system'
  #   libvirt.cpus = 4
  #   libvirt.memory = 2048 
  # end
  config.vm.provider :virtualbox do |vb|
    vb.memory = "8192"
    vb.cpus = 4
  end

 
  vm_configs.each_with_index do |(node_id, node_settings), index|
      config.vm.define node_id do |node|
      node.vm.hostname = node_settings[:hostname]
      # node.vm.box = "generic/ubuntu2204"
      node.vm.box = "ubuntu/jammy64"
      node.vm.network :private_network, ip: node_settings[:ip]
      
      if index == vm_configs.size - 1
        node.vm.provision "shell", inline: <<-SHELL
          chmod 600 /vagrant/.vagrant/machines/node1/virtualbox/private_key
          chmod 600 /vagrant/.vagrant/machines/node2/virtualbox/private_key
          chmod 600 /vagrant/.vagrant/machines/node3/virtualbox/private_key
        SHELL

        node.vm.provision "ansible_local" do |ansible|
          ansible.playbook = "playbooks/install-apache-pulsar.yml"
          ansible.inventory_path = "inventory/linux.yml"
          ansible.limit = "all"
        end
      end
    end
  end
end