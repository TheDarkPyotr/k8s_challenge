IMAGE_NAME = "ubuntu/jammy64"
MASTER_NODE_IP = "192.168.56.10"
WORKER_NODE_IPS = ["192.168.56.12", "192.168.56.13"]
K8S_VERSION = "v1.29"
POD_NETWORK_CIDR = "192.168.0.0/16"

Vagrant.configure(2) do |config|

    config.vm.box = IMAGE_NAME
    config.vm.box_check_update = false
    config.ssh.insert_key = false
    

    config.vm.define "master" do |master|
        master.vm.provider "virtualbox" do |v|
            v.memory = 4096
            v.cpus = 2
            v.name = "k8s-master"
        end

        master.vm.hostname = "master"
        master.vm.network "private_network", ip: MASTER_NODE_IP

        master.vm.provision "ansible" do |general|
            general.playbook = "playbooks/general.yml"
            general.extra_vars = {
              node_ip: MASTER_NODE_IP,
              k8s_version: K8S_VERSION
            }
        end

        master.vm.provision "ansible" do |master_setup|
            master_setup.playbook = "playbooks/master.yml"
            master_setup.extra_vars = {
              node_ip: MASTER_NODE_IP,
              user: "vagrant",
              pod_network_cidr: POD_NETWORK_CIDR
            }
        end
    end

    WORKER_NODE_IPS.each_with_index do |node_ip, index|
        hostname = "worker-#{'%02d' % (index + 1)}"
        config.vm.define "#{hostname}" do |worker|
            worker.vm.box = IMAGE_NAME
            worker.vm.hostname = "#{hostname}"
            worker.vm.network "private_network", ip: node_ip

            worker.vm.provider "virtualbox" do |v|
                v.memory = 2048
                v.cpus = 2
                v.name = "k8s-#{hostname}"
            end
            

            worker.vm.provision "ansible" do |general|
                general.playbook = "playbooks/general.yml"
                general.extra_vars = {
                  node_ip: node_ip,
                  k8s_version: K8S_VERSION
                }
            end

            worker.vm.provision "ansible" do |worker_setup|
                worker_setup.playbook = "playbooks/worker.yml"
                worker_setup.extra_vars = {
                  node_ip: node_ip,
                  master_ip: MASTER_NODE_IP
                }
            end
        end
    end
end
