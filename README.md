# NuxeoPlatform-Ansible

Ansible automation for deploying a production-grade **Nuxeo Platform** cluster on Ubuntu 24.04 LTS.

## Architecture

5-node cluster split into two tiers:

| Node | IP | Role | Services |
|---|---|---|---|
| node1 | 192.168.56.11 | db | etcd, PostgreSQL/Patroni, Elasticsearch, Kafka |
| node2 | 192.168.56.12 | db | etcd, PostgreSQL/Patroni, Elasticsearch, Kafka |
| node3 | 192.168.56.13 | db | etcd, PostgreSQL/Patroni, Elasticsearch, Kafka |
| node4 | 192.168.56.14 | app | Nuxeo, MinIO, HAProxy, Keepalived |
| node5 | 192.168.56.15 | app | Nuxeo, MinIO, HAProxy, Keepalived, Monitoring |

**VIP (Keepalived):** `192.168.56.10`

## Stack

| Layer | Technology |
|---|---|
| OS | Ubuntu 24.04 LTS |
| Database | PostgreSQL 16 + Patroni (HA, 3-node) |
| DCS | etcd 3.5 (leader election for Patroni) |
| Search | Elasticsearch 8.x (3-node cluster) |
| Messaging | Apache Kafka (KRaft, 3 brokers) |
| Object storage | MinIO |
| Application | Nuxeo Platform LTS 2025 |
| Load balancer | HAProxy 2.8 |
| VIP failover | Keepalived (VRRP) |
| Monitoring | Prometheus + Grafana |

## Local Development

Requires: Windows 11, VirtualBox 7+, Vagrant 2.3+, WSL2 (Ubuntu 24.04 LTS).

```bash
# Start the cluster
vagrant.exe up

# Deploy all roles
cd infrastructure
ansible-playbook playbooks/site.yml -i inventories/local/hosts.ini
```

See [docs/local-setup.md](docs/local-setup.md) for full setup instructions.

## Role Status

| Role | Status |
|---|---|
| common | ✅ Tested |
| etcd | ✅ Tested |
| postgresql | ✅ Tested |
| elasticsearch | ⏳ Not yet implemented |
| kafka | ⏳ Not yet implemented |
| minio | ⏳ Not yet implemented |
| nuxeo | ⏳ Not yet implemented |
| haproxy | ⏳ Not yet implemented |
| keepalived | ⏳ Not yet implemented |
| monitoring | ⏳ Not yet implemented |
