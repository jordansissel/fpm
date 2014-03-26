# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  config.vm.define "centos6" do |centos6|
    centos6.vm.box = "centos6"
    centos6.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/centos-65-x64-virtualbox-puppet.box"
  end

  config.vm.define "debian6" do |debian6|
    debian6.vm.box = "debian6"
    debian6.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/debian-607-x64-vbox4210.box"
  end

  config.vm.define "debian7" do |debian7|
    debian7.vm.box = "debian7"
    debian7.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/debian-73-x64-virtualbox-puppet.box"
  end

  config.vm.define :smartos do |smartos|
    smartos.vm.box = "smartos-base1310-64-virtualbox-20130806.box"
    smartos.vm.box_url = "http://dlc-int.openindiana.org/aszeszo/vagrant/smartos-base1310-64-virtualbox-20130806.box"
  end

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "test"
    puppet.manifest_file = "vagrant.pp"
  end

end
