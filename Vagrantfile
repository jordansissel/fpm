# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  config.vm.define "centos6" do |centos6|
    centos6.vm.box = "centos6"
    centos6.vm.box_url = "http://vagrant-jls.objects.dreamhost.com/CentOS-6.4-x86_64-minimal.box"
  end

  config.vm.define "debian6" do |centos6|
    centos6.vm.box = "debian6"
    centos6.vm.box_url = "http://vagrant-jls.objects.dreamhost.com/Debian-6.0.7-amd64-netboot.box"
  end

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "test"
    puppet.manifest_file = "vagrant.pp"
  end
end
