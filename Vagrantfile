# -*- mode: ruby -*-
# vi: set ft=ruby :
# Managed by project — 5-node Nuxeo Platform dev cluster on VirtualBox
# Ubuntu 24.04 LTS Noble Numbat — used for local Vagrant dev and production.
# PGDG noble-pgdg provides PostgreSQL 16 which is required by Nuxeo LTS 2025.

VAGRANT_BOX     = "bento/ubuntu-24.04"
SECOND_DISK_GB  = 20
ANSIBLE_KEY_DIR = ".vagrant/ansible_key"
ANSIBLE_KEY     = "#{ANSIBLE_KEY_DIR}/id_rsa"

NODES = [
  { name: "node1", ip: "192.168.56.11", role: "db",  cpu: 2, ram: 4096 },
  { name: "node2", ip: "192.168.56.12", role: "db",  cpu: 2, ram: 4096 },
  { name: "node3", ip: "192.168.56.13", role: "db",  cpu: 2, ram: 4096 },
  { name: "node4", ip: "192.168.56.14", role: "app", cpu: 2, ram: 4096 },
  { name: "node5", ip: "192.168.56.15", role: "app", cpu: 2, ram: 4096 },
].freeze

# Generate shared Ansible SSH keypair once (on `vagrant up`)
unless File.exist?(ANSIBLE_KEY)
  FileUtils.mkdir_p(ANSIBLE_KEY_DIR)
  system("ssh-keygen -t rsa -b 4096 -f #{ANSIBLE_KEY} -N '' -C 'ansible@vagrant' -q")
  puts "Generated Ansible SSH keypair at #{ANSIBLE_KEY}"
end
ANSIBLE_PUBKEY = File.read("#{ANSIBLE_KEY}.pub").strip

Vagrant.configure("2") do |config|
  config.vm.box               = VAGRANT_BOX
  config.vm.box_check_update  = false

  # Disable default /vagrant sync — Ansible runs over SSH
  config.vm.synced_folder ".", "/vagrant", disabled: true

  NODES.each do |node|
    config.vm.define node[:name] do |vm_cfg|
      vm_cfg.vm.hostname = node[:name]
      vm_cfg.vm.network "private_network", ip: node[:ip]

      # ── VirtualBox provider ──────────────────────────────────────────────────
      vm_cfg.vm.provider "virtualbox" do |vb|
        vb.name          = "nuxeo-#{node[:name]}"
        vb.cpus          = node[:cpu]
        vb.memory        = node[:ram]
        vb.linked_clone  = true

        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--ioapic",              "on"]
        vb.customize ["modifyvm", :id, "--nictype1",            "virtio"]
        vb.customize ["modifyvm", :id, "--nictype2",            "virtio"]

        # Second disk for data (Elasticsearch / Kafka / MinIO)
        disk_path = File.join(
          File.dirname(File.expand_path(__FILE__)),
          ".vagrant", "disks", "#{node[:name]}-data.vdi"
        )
        unless File.exist?(disk_path)
          FileUtils.mkdir_p(File.dirname(disk_path))
          vb.customize [
            "createhd",
            "--filename", disk_path,
            "--size",     SECOND_DISK_GB * 1024,
            "--format",   "VDI",
            "--variant",  "Standard"
          ]
        end
        vb.customize [
          "storageattach", :id,
          "--storagectl",  "SATA Controller",
          "--port",        2,
          "--device",      0,
          "--type",        "hdd",
          "--medium",      disk_path
        ]
      end

      # ── Inline shell: inject Ansible public key ──────────────────────────────
      # Minimal provisioner — only adds the SSH key. Ansible does the rest.
      vm_cfg.vm.provision "shell", inline: <<~SHELL, privileged: false
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        echo "#{ANSIBLE_PUBKEY}" >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        echo "Ansible SSH key injected on #{node[:name]}"
      SHELL
    end
  end
end
