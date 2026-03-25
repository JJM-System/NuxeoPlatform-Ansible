# Role: common

OS baseline applied to **all nodes** before any service role runs.
Target: Ubuntu 22.04 LTS (jammy).

## What it does

| Sub-task | File | Description |
|---|---|---|
| Packages | `tasks/packages.yml` | Installs `common_packages`, sets timezone, disables unattended-upgrades, deploys ulimits |
| Sysctl | `tasks/sysctl.yml` | Writes kernel parameters to `/etc/sysctl.d/99-ansible.conf` |
| Security | `tasks/security.yml` | Hardens sshd, configures UFW (default deny + allow SSH) |
| Java | `tasks/java.yml` | Installs OpenJDK, sets `JAVA_HOME` in `/etc/environment` |
| NTP | `tasks/ntp.yml` | Installs chrony, deploys config from template, waits for sync |
| Users | `tasks/users.yml` | Creates system users with sudo NOPASSWD + authorized_keys |
| Health check | `tasks/health_check.yml` | Asserts Java, chrony, sysctl — run separately with `--tags health_check` |

## Variables

| Variable | Default | Description |
|---|---|---|
| `common_packages` | see defaults | List of base apt packages |
| `disable_unattended_upgrades` | `true` | Remove and disable apt auto-updates |
| `java_version` | `"21"` | OpenJDK major version |
| `java_package` | `openjdk-21-jdk` | Apt package name |
| `java_home` | `/usr/lib/jvm/java-21-openjdk-amd64` | JAVA_HOME path |
| `timezone` | `Europe/Warsaw` | tzdata timezone string |
| `ntp_servers` | `[0/1.pool.ntp.org]` | Chrony pool servers |
| `ntp_makestep_threshold` | `1` | Max step size (seconds) |
| `ntp_makestep_limit` | `3` | Updates during which stepping is allowed |
| `vm_max_map_count` | `262144` | Required by Elasticsearch |
| `fs_file_max` | `1000000` | System-wide open file limit |
| `net_core_somaxconn` | `65535` | Socket listen backlog |
| `net_ipv4_tcp_max_syn_backlog` | `65535` | TCP SYN backlog |
| `net_disable_ipv6` | `false` | Disable IPv6 via sysctl |
| `system_limits` | see defaults | List of ulimit entries (nofile, nproc) |
| `system_users` | `[ansible]` | Users to create; supports `authorized_keys` list |
| `ssh_disable_password_auth` | `true` | `PasswordAuthentication no` in sshd_config |
| `ssh_disable_root_login` | `true` | `PermitRootLogin no` in sshd_config |
| `ssh_port` | `22` | SSH listen port |
| `ufw_enabled` | `true` | Enable UFW and apply rules |
| `ufw_allow_ports` | `[]` | Extra ports to open (list of `{port, proto, comment}`) |

## Tags

| Tag | Runs |
|---|---|
| `common` | Everything in this role |
| `packages` | Apt packages, timezone, ulimits |
| `sysctl` | Kernel parameters |
| `security` | sshd hardening + UFW |
| `java` | JDK install + JAVA_HOME |
| `ntp` | chrony install + config |
| `users` | System user creation + authorized_keys |
| `health_check` | Post-deploy assertions (run separately) |

## Usage

```yaml
# site.yml — full baseline
- hosts: all_nodes
  roles:
    - role: common

# Run only sysctl + java on db nodes
ansible-playbook playbooks/site.yml \
  -i inventories/local/hosts.ini \
  --limit db_nodes \
  --tags sysctl,java

# Run health checks only
ansible-playbook playbooks/site.yml \
  -i inventories/local/hosts.ini \
  --tags health_check
```

## Dependencies

None. Must run before any service role.
