# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.


  config.vm.define "centos6" do |centos6|
    centos6.vm.box = "puppetlabs/centos-6.6-64-puppet"
  end

  config.vm.define "centos7" do |centos7|
    centos7.vm.box = "puppetlabs/centos-7.0-64-puppet"
  end

  config.vm.define "debian6" do |debian6|
    debian6.vm.box = "puppetlabs/debian-6.0.10-64-puppet"
  end

  config.vm.define "debian7" do |debian7|
    debian7.vm.box = "puppetlabs/centos-7.0-64-puppet"
  end

  config.vm.define "arch" do |arch|
    arch.vm.box = "jfredett/arch-puppet"
  end

  config.vm.define "freebsd10" do |freebsd10|
    freebsd10.vm.box = "tjay/freebsd-10.1"
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
