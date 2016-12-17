config_ers_fqdn     = 'ers.example.com'
config_ers_ip       = '10.10.10.100'
config_ubuntu_fqdn  = "ubuntu.#{config_ers_fqdn}"
config_ubuntu_ip    = '10.10.10.101'
config_windows_fqdn = "windows.#{config_ers_fqdn}"
config_windows_ip   = '10.10.10.102'
config_macos_fqdn   = "macos.#{config_ers_fqdn}"
config_macos_ip     = '10.10.10.103'

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

  config.vm.define :ubuntu do |config|
    config.vm.provider :virtualbox do |vb|
      vb.customize ["storageattach", :id, "--storagectl", "IDE Controller", "--device", 0, "--port", 1, "--type", "dvddrive", "--medium", "additions"]
    end
    config.vm.hostname = config_ubuntu_fqdn
    config.vm.network :private_network, ip: config_ubuntu_ip
    config.vm.provision :shell, inline: "echo '#{config_ers_ip} #{config_ers_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, path: 'provision-ubuntu.sh'
    config.vm.provision :reload
    config.vm.provision 'shell', path: 'provision-ubuntu-virtualbox-guest-additions.sh'
    config.vm.provision :reload
  end

  config.vm.define :windows do |config|
    config.vm.box = 'windows_2012_r2'
    config.vm.hostname = 'windows'
    config.vm.network :private_network, ip: config_windows_ip
    config.vm.provision :shell, inline: "echo '#{config_ers_ip} #{config_ers_fqdn}' | Out-File -Encoding ASCII -Append c:/Windows/System32/drivers/etc/hosts"
    config.vm.provision :shell, inline: "$env:chocolateyVersion='0.10.3'; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex", name: "Install Chocolatey"
    config.vm.provision :shell, path: 'provision-windows.ps1', args: [config_ers_fqdn, config_windows_fqdn]
  end

  config.vm.define :macos do |config|
    config.vm.provider :virtualbox do |vb|
      # set the screen resolution. can be one of 0,1,2,3,4,5 referring to the 640x480, 800x600, 1024x768, 1280x1024, 1440x900, 1920x1200 respectively.
      # see https://www.virtualbox.org/manual/ch03.html#efividmode
      vb.customize ['setextradata', :id, 'VBoxInternal2/EfiGopMode', '4']
    end
    config.vm.box = 'macOS'
    config.vm.hostname = config_macos_fqdn
    config.vm.network :private_network, ip: config_macos_ip
    config.vm.provision :shell, inline: "echo '#{config_ers_ip} #{config_ers_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, path: 'provision-macos.sh', privileged: false
  end
end
