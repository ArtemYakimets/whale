Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false
  config.ssh.insert_key = false
  config.vm.boot_timeout = 600

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
    vb.memory = 2048
  end

  nodes = [
    { name: "swarm-mgr", ip: "10.10.56.10", role: "manager", memory: 3072, cpus: 2 },
    { name: "swarm-linux-1", ip: "10.10.56.11", role: "worker", memory: 1536, cpus: 1 },
    { name: "swarm-linux-2", ip: "10.10.56.12", role: "worker", memory: 1536, cpus: 1 }
  ]

  manager = nodes.find { |n| n[:role] == "manager" }
  manager_ip = manager[:ip]
  manager_name = manager[:name]

  worker_count = nodes.count { |n| n[:role] == "worker" }

  nodes.each do |node|
    config.vm.define node[:name] do |node_config|
      node_config.vm.hostname = node[:name]
      node_config.vm.network "private_network", ip: node[:ip]

      node_config.vm.provider "virtualbox" do |vb|
        vb.cpus = node[:cpus] || 2
        vb.memory = node[:memory] || 2048
      end

      node_config.vm.provision "shell",
        path: "provision/bootstrap.sh",
        args: [node[:role], node[:name], node[:ip], manager_ip, manager_name, worker_count]
    end
  end
end
