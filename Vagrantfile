config_ers_fqdn     = 'ers.example.com'
config_ers_ip       = '10.10.10.100'

Vagrant.configure(2) do |config|
  config.vm.provider 'virtualbox' do |vb|
    vb.linked_clone = true
    vb.cpus = 2
    vb.memory = 2048
    vb.gui = true
    vb.customize ["modifyvm", :id, "--vram", 64]
    vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
    vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
  end

  config.vm.box = 'ubuntu-16.04-amd64'

  config.vm.define :ers do |config|
    config.vm.provider 'virtualbox' do |vb|
      vb.gui = false
    end
    config.vm.hostname = config_ers_fqdn
    config.vm.network :private_network, ip: config_ers_ip
    config.vm.provision :shell, path: 'provision.sh'
  end
end
