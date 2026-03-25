# Local Development Environment — Step-by-Step Setup Guide

Stack: **Windows 11 + WSL2 (Ubuntu 24.04 LTS) + VirtualBox + Vagrant + Ansible**

> **This file is a living document.** Role status sections are updated as each role is tested.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install VirtualBox and Vagrant (Windows)](#2-install-virtualbox-and-vagrant-windows)
3. [Configure WSL2](#3-configure-wsl2)
4. [Install Ansible in WSL2](#4-install-ansible-in-wsl2)
5. [Clone the Project](#5-clone-the-project)
6. [SSH Key and Vault Configuration](#6-ssh-key-and-vault-configuration)
7. [Start the Virtual Machines](#7-start-the-virtual-machines)
8. [Test Ansible Connectivity](#8-test-ansible-connectivity)
9. [Role Installation — Order and Commands](#9-role-installation--order-and-commands)
10. [Full Environment Verification](#10-full-environment-verification)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

### Windows (host)
| Software | Minimum version | Link |
|---|---|---|
| Windows 11 | 22H2 | — |
| VirtualBox | 7.0+ | https://www.virtualbox.org/wiki/Downloads |
| Vagrant | 2.3+ | https://developer.hashicorp.com/vagrant/downloads |
| WSL2 with Ubuntu 24.04 LTS | — | Microsoft Store or `wsl --install` |

### WSL2 (Ubuntu 24.04 LTS)
| Software | Version |
|---|---|
| Python | 3.12+ (built into Ubuntu 24.04 LTS) |
| Ansible | 2.14+ |
| Ansible Galaxy collections | see `requirements.yml` |

---

## 2. Install VirtualBox and Vagrant (Windows)

### VirtualBox
1. Download the installer from https://www.virtualbox.org/wiki/Downloads
2. Run the installer — accept default options
3. **Restart Windows** after installation
4. Verify in PowerShell:
   ```powershell
   VBoxManage --version
   # expected: 7.x.x
   ```

### Vagrant
1. Download the installer from https://developer.hashicorp.com/vagrant/downloads
2. Run the installer — accept default options
3. **Restart Windows** (or open a new terminal)
4. Verify in PowerShell:
   ```powershell
   vagrant --version
   # expected: Vagrant 2.x.x
   ```

> **Important:** Inside WSL2, Vagrant commands must be called as `vagrant.exe` because
> Vagrant is installed on the Windows side, not inside WSL2.
> Example: `vagrant.exe up`, `vagrant.exe ssh node1`, `vagrant.exe status`

---

## 3. Configure WSL2

### Install WSL2
If WSL2 is not yet installed:
```powershell
# PowerShell as Administrator
wsl --install
# After system restart:
wsl --set-default-version 2
wsl --install -d Ubuntu-24.04
```

### Verify
```bash
# Inside WSL2 terminal:
wsl --list --verbose   # from PowerShell — check VERSION=2
uname -r               # kernel 5.x or 6.x
lsb_release -a         # Ubuntu 24.04 LTS
```

### Recommended `/etc/wsl.conf`
```bash
sudo tee /etc/wsl.conf <<EOF
[boot]
systemd=true

[interop]
appendWindowsPath=false
EOF
```
After saving: run `wsl --shutdown` in PowerShell, then reopen WSL2.

---

## 4. Install Ansible in WSL2

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y python3-pip python3-venv software-properties-common

# Install Ansible via pip
pip3 install --user ansible

# Add ~/.local/bin to PATH if not already present
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
ansible --version
# expected: ansible [core 2.14+]
```

### Install Galaxy Collections

Run from the `infrastructure/` directory of the project:
```bash
cd /path/to/NuxeoPlatform-Ansible/infrastructure
ansible-galaxy collection install -r requirements.yml
```

Collections installed (`requirements.yml`):
- `ansible.posix >= 1.5.0`
- `community.general >= 8.0.0`
- `community.postgresql >= 3.0.0`
- `community.docker >= 3.0.0`
- `community.crypto >= 2.0.0`
- `ansible.utils >= 3.0.0`

---

## 5. Clone the Project

```bash
# Inside WSL2:
cd /path/to/your/repos
git clone <repo-url> NuxeoPlatform-Ansible
cd NuxeoPlatform-Ansible
```

### Project Structure
```
NuxeoPlatform-Ansible/
├── Vagrantfile                    # 5-VM cluster definition
├── local-up.sh                    # full startup script
├── local-destroy.sh               # full teardown script
├── scripts/
│   ├── test-connectivity.sh       # Ansible connectivity test
│   ├── test-role.sh               # single-role deploy + health check
│   └── vagrant-ssh-setup.sh       # SSH keypair generator
├── docs/
│   └── local-setup.md             # this file
└── infrastructure/
    ├── ansible.cfg
    ├── requirements.yml
    ├── inventories/
    │   ├── local/                 # Vagrant environment
    │   │   ├── hosts.ini
    │   │   └── group_vars/
    │   │       ├── all/
    │   │       │   ├── main.yml   # global variables
    │   │       │   └── vault.yml  # secrets (encrypt before commit)
    │   │       ├── db_nodes.yml
    │   │       └── app_nodes.yml
    │   └── production/            # production environment
    ├── playbooks/
    │   ├── site.yml               # full stack deployment
    │   ├── update.yml             # rolling update
    │   ├── recover.yml            # node recovery
    │   └── smoke-test.yml         # post-deploy validation
    └── roles/
        ├── common/
        ├── etcd/
        ├── postgresql/
        ├── elasticsearch/
        ├── kafka/
        ├── minio/
        ├── nuxeo/
        ├── haproxy/
        ├── keepalived/
        └── monitoring/
```

---

## 6. SSH Key and Vault Configuration

### SSH Key for Ansible

The SSH keypair is automatically generated on the first `vagrant.exe up` by the Vagrantfile.
To generate it manually beforehand:
```bash
bash scripts/vagrant-ssh-setup.sh
```
The key is saved to `.vagrant/ansible_key/id_rsa`.

### SSH configuration in `hosts.ini`

`infrastructure/inventories/local/hosts.ini` uses a shared key for all nodes:
```ini
[all:vars]
ansible_user=vagrant
ansible_ssh_private_key_file=~/.ssh/ansible_project/id_rsa
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

> Make sure the key path is accessible from WSL2. If the key is in a Windows location,
> use `/mnt/c/Users/<user>/.ssh/...` or copy it to `~/.ssh/`.

### Vault password file

`ansible.cfg` points to `~/.ansible/vault_pass`:
```bash
mkdir -p ~/.ansible
echo "your-vault-password" > ~/.ansible/vault_pass
chmod 600 ~/.ansible/vault_pass
```

Secrets (unencrypted, for local testing only) are stored in:
- `infrastructure/inventories/local/group_vars/all/vault.yml`

Encrypt before committing:
```bash
ansible-vault encrypt infrastructure/inventories/local/group_vars/all/vault.yml
```

---

## 7. Start the Virtual Machines

### Network Topology
```
Windows Host (VirtualBox NAT + Host-only network 192.168.56.0/24)
│
├── node1  192.168.56.11  db_node   (etcd, PostgreSQL/Patroni, Elasticsearch, Kafka)
├── node2  192.168.56.12  db_node   (etcd, PostgreSQL/Patroni, Elasticsearch, Kafka)
├── node3  192.168.56.13  db_node   (etcd, PostgreSQL/Patroni, Elasticsearch, Kafka)
├── node4  192.168.56.14  app_node  (Nuxeo, MinIO, HAProxy, Keepalived)
└── node5  192.168.56.15  app_node  (Nuxeo, MinIO, HAProxy, Keepalived, Monitoring)

VIP (Keepalived): 192.168.56.10
```

Each VM: 2 vCPU, 4 GB RAM, OS disk + 20 GB data disk.

### Start the cluster

**Option 1 — automated script:**
```bash
bash local-up.sh
```

**Option 2 — manual:**
```bash
# From the project root directory:
vagrant.exe up

# Check status:
vagrant.exe status
```

Expected output:
```
node1                     running (virtualbox)
node2                     running (virtualbox)
node3                     running (virtualbox)
node4                     running (virtualbox)
node5                     running (virtualbox)
```

### VM management reference
```bash
vagrant.exe halt              # stop all VMs
vagrant.exe up                # start all VMs
vagrant.exe suspend           # suspend all VMs
vagrant.exe resume            # resume all VMs
vagrant.exe destroy -f        # destroy all VMs (irreversible)
vagrant.exe ssh node1         # SSH into node1
```

---

## 8. Test Ansible Connectivity

```bash
# From the infrastructure/ directory:
cd infrastructure
ansible all -m ansible.builtin.ping -i inventories/local/hosts.ini
```

Or via script:
```bash
bash scripts/test-connectivity.sh
```

Expected output:
```yaml
node1 | SUCCESS => { "ping": "pong" }
node2 | SUCCESS => { "ping": "pong" }
node3 | SUCCESS => { "ping": "pong" }
node4 | SUCCESS => { "ping": "pong" }
node5 | SUCCESS => { "ping": "pong" }
✓ All 5 nodes reachable
```

---

## 9. Role Installation — Order and Commands

> All commands below are run from the `infrastructure/` directory.
> `test-role.sh` deploys the role and then runs its health check.

```bash
cd infrastructure
```

### One-shot full deployment
```bash
ansible-playbook playbooks/site.yml -i inventories/local/hosts.ini
```

### Step-by-step (recommended for first-time setup)

---

#### Role 1: `common` — OS baseline ✅ TESTED

Installs: base packages, Java 21, chrony NTP, sysctl tuning, UFW firewall, ansible system user.
Target: **all 5 nodes**.

```bash
./../scripts/test-role.sh common
```

Manual verification:
```bash
ansible all_nodes -m ansible.builtin.command -a "java -version" -i inventories/local/hosts.ini
ansible all_nodes -m ansible.builtin.command -a "chronyc tracking" -i inventories/local/hosts.ini
ansible all_nodes -m ansible.builtin.command -a "sudo ufw status" -i inventories/local/hosts.ini
```

---

#### Role 2: `etcd` — etcd 3.5 cluster ✅ TESTED

Installs: etcd + etcdctl binaries (from GitHub releases), 3-node cluster.
Target: **db_nodes (node1, node2, node3)**.

> **Important:** etcd requires all 3 nodes to start **simultaneously** to reach quorum.
> The role uses `serial: "100%"` — all nodes are configured and started at the same time.

Reset etcd state before re-running:
```bash
for node in node1 node2 node3; do
  vagrant.exe ssh $node -c "sudo systemctl stop etcd 2>/dev/null; sudo rm -rf /var/lib/etcd/*"
done
```

Deploy:
```bash
./../scripts/test-role.sh etcd db_nodes
```

Manual verification:
```bash
vagrant.exe ssh node1 -c "ETCDCTL_API=3 etcdctl member list --endpoints=http://127.0.0.1:2379"
vagrant.exe ssh node1 -c "ETCDCTL_API=3 etcdctl endpoint health --cluster --endpoints=http://127.0.0.1:2379"
```

Expected `member list` output:
```
<id>, started, node1, http://192.168.56.11:2380, http://192.168.56.11:2379, false
<id>, started, node2, http://192.168.56.12:2380, http://192.168.56.12:2379, false
<id>, started, node3, http://192.168.56.13:2380, http://192.168.56.13:2379, false
```

---

#### Role 3: `postgresql` — PostgreSQL 16 + Patroni ⏳ NOT YET TESTED

Installs: PostgreSQL 16, Patroni HA manager, cluster bootstrap.
Target: **db_nodes (node1, node2, node3)**.
Dependency: etcd cluster must be healthy before running.

```bash
./../scripts/test-role.sh postgresql db_nodes
```

---

#### Role 4: `elasticsearch` — Elasticsearch 8.x ⏳ NOT YET IMPLEMENTED

Installs: Elasticsearch 8.x, 3-node cluster.
Target: **db_nodes (node1, node2, node3)**.
Dependency: `common` (sysctl `vm.max_map_count=262144` must be set).

```bash
./../scripts/test-role.sh elasticsearch db_nodes
```

---

#### Role 5: `kafka` — Apache Kafka ⏳ NOT YET IMPLEMENTED

Installs: Apache Kafka with KRaft mode (no Zookeeper), 3 brokers.
Target: **db_nodes (node1, node2, node3)**.

```bash
./../scripts/test-role.sh kafka db_nodes
```

---

#### Role 6: `minio` — MinIO S3-compatible storage ⏳ NOT YET IMPLEMENTED

Installs: MinIO object storage, used as Nuxeo binary store.
Target: **app_nodes (node4, node5)**.

```bash
./../scripts/test-role.sh minio app_nodes
```

---

#### Role 7: `nuxeo` — Nuxeo Platform 2025 ⏳ NOT YET IMPLEMENTED

Installs: Nuxeo Platform, configured to connect to PostgreSQL, Elasticsearch, Kafka, MinIO.
Target: **app_nodes (node4, node5)**, 50% rolling deploy.
Dependencies: postgresql, elasticsearch, kafka, minio.

```bash
./../scripts/test-role.sh nuxeo app_nodes
```

---

#### Role 8: `haproxy` — HAProxy load balancer ⏳ NOT YET IMPLEMENTED

Installs: HAProxy 2.8, frontend routing to Nuxeo backends.
Target: **app_nodes (node4, node5)**.

```bash
./../scripts/test-role.sh haproxy app_nodes
```

---

#### Role 9: `keepalived` — VRRP floating VIP ⏳ NOT YET IMPLEMENTED

Installs: Keepalived, floating VIP `192.168.56.10` on the app tier.
Target: **app_nodes (node4, node5)**.

```bash
./../scripts/test-role.sh keepalived app_nodes
```

---

#### Role 10: `monitoring` — Prometheus + Grafana ⏳ NOT YET IMPLEMENTED

Installs: Prometheus, Grafana, node_exporter on all nodes.
Target: **node5 only**.

```bash
./../scripts/test-role.sh monitoring node5
```

---

## 10. Full Environment Verification

After all roles are installed, run the smoke test playbook:
```bash
ansible-playbook playbooks/smoke-test.yml -i inventories/local/hosts.ini
```

| Service | Test |
|---|---|
| All nodes | `ping` |
| Elasticsearch | `GET /_cluster/health` → status green |
| Kafka | `kafka-broker-api-versions.sh` |
| PostgreSQL/Patroni | `patronictl list` → 1 leader |
| MinIO | `mc admin info` → online |
| Nuxeo (node4, node5) | `GET /nuxeo/runningstatus` → HTTP 200 |
| HAProxy | stats page port 8404 → HTTP 200 |
| Keepalived | ping VIP 192.168.56.10 |

---

## 11. Troubleshooting

### `vagrant: command not found` inside WSL2
```
Command 'vagrant' not found
```
**Cause:** Vagrant is installed on Windows, not inside WSL2.
**Fix:** Always use `vagrant.exe`:
```bash
vagrant.exe up
vagrant.exe status
vagrant.exe ssh node1
```

### Ansible cannot connect to VMs
```
UNREACHABLE! => SSH connection failed
```
**Check:**
```bash
# Are the VMs running?
vagrant.exe status

# Does the SSH key exist and is it accessible from WSL2?
ls -la ~/.ssh/ansible_project/id_rsa

# Test SSH manually:
ssh -i ~/.ssh/ansible_project/id_rsa -o StrictHostKeyChecking=no vagrant@192.168.56.11
```

### etcd fails to start — timeout
```
Unable to start service etcd: Job for etcd.service failed because a timeout was exceeded.
```
**Cause:** UFW is blocking ports 2379/2380 (inter-node peer traffic), or nodes are not
starting simultaneously (serial:1 instead of serial:"100%").

**Fix:**
```bash
# Reset etcd on all db_nodes:
for node in node1 node2 node3; do
  vagrant.exe ssh $node -c "sudo systemctl stop etcd 2>/dev/null; sudo rm -rf /var/lib/etcd/*"
done

# Re-run (serial: "100%" ensures all 3 nodes start at the same time):
./../scripts/test-role.sh etcd db_nodes
```

**Check etcd logs and firewall:**
```bash
vagrant.exe ssh node1 -c "sudo journalctl -xeu etcd.service --no-pager | tail -50"
vagrant.exe ssh node1 -c "sudo ufw status"
```

### `vault_xxx` is undefined
```
AnsibleUndefinedVariable: 'vault_etcd_initial_cluster_token' is undefined
```
**Cause:** Ansible does not load `all.vault.yml` as vars for the `all` group — it treats it
as vars for a group named `all.vault` (which does not exist). The correct structure is a
`group_vars/all/` directory containing individual files.

**Check:**
```bash
ls infrastructure/inventories/local/group_vars/all/
# must contain: main.yml  vault.yml
```

### `'limit' is not a valid attribute for a Play`
```
ERROR! 'limit' is not a valid attribute for a Play
```
**Cause:** `limit:` is not a play-level attribute in Ansible. Use `hosts:` directly.
**Fix:** Replace `hosts: app_nodes` + `limit: node5` with `hosts: node5`.

### Clear the environment
```bash
# Destroy all VMs and clean up:
bash local-destroy.sh

# Clear only the Ansible fact cache:
rm -rf infrastructure/.cache/facts/
```
