# Role: etcd

Deploys a **3-node etcd 3.5 cluster** on `db_nodes` (node1, node2, node3).
etcd is the consensus backend for Patroni PostgreSQL HA — it holds the leader
lock and stores cluster state. Installed from official GitHub binary releases,
not via apt.

## Cluster layout

```
node1 (192.168.56.11)  ──┐
node2 (192.168.56.12)  ──┤  etcd cluster  (quorum = 2 of 3)
node3 (192.168.56.13)  ──┘
```

All three nodes are peers. Any node can serve client requests. Patroni connects
to all three via `http://nodeX:2379`.

## Variables

| Variable | Default | Description |
|---|---|---|
| `etcd_version` | `3.5.13` | GitHub release to download |
| `etcd_download_url` | GitHub tarball URL | Constructed from version |
| `etcd_install_dir` | `/usr/local/bin` | Where `etcd` and `etcdctl` are placed |
| `etcd_data_dir` | `/var/lib/etcd` | WAL and snapshot storage |
| `etcd_config_dir` | `/etc/etcd` | Config and env files |
| `etcd_user` / `etcd_group` | `etcd` | System user/group (no login) |
| `etcd_client_port` | `2379` | Client API port |
| `etcd_peer_port` | `2380` | Peer replication port |
| `etcd_cluster_name` | from group_vars | Human-readable cluster name |
| `etcd_initial_cluster_state` | `new` | `new` or `existing` — see Recovery |
| `etcd_initial_cluster_token` | vault | Prevents cross-cluster joins |
| `etcd_auto_compaction_retention` | `"1"` | Compact history older than 1 hour |
| `etcd_snapshot_count` | `10000` | Transactions between snapshots |
| `etcd_heartbeat_interval` | `100` | Leader heartbeat interval (ms) |
| `etcd_election_timeout` | `1000` | Follower election timeout (ms) |
| `etcd_quota_backend_bytes` | `8589934592` | 8 GB backend size quota |

## Tags

| Tag | Runs |
|---|---|
| `etcd` | Everything in this role |
| `install` | Binary download, user/dirs, systemd unit |
| `configure` | etcd.conf template only |
| `health_check` | Endpoint health + member list assertions |

## Example playbook

```yaml
- hosts: db_nodes
  roles:
    - role: common
    - role: etcd
```

```bash
# Deploy only etcd on db_nodes
ansible-playbook playbooks/site.yml \
  -i inventories/local/hosts.ini \
  --limit db_nodes \
  --tags etcd

# Re-push config and restart without reinstalling binary
ansible-playbook playbooks/site.yml \
  -i inventories/local/hosts.ini \
  --limit db_nodes \
  --tags etcd,configure

# Run health checks only
ansible-playbook playbooks/site.yml \
  -i inventories/local/hosts.ini \
  --limit db_nodes \
  --tags health_check
```

## Recovery — rejoining a failed node

When a node's data is corrupted or lost and must rejoin the **existing** cluster:

1. Stop etcd on the failed node:
   ```bash
   systemctl stop etcd
   ```

2. Remove the failed member from the cluster (run on a healthy node):
   ```bash
   ETCDCTL_API=3 etcdctl member list --endpoints=http://127.0.0.1:2379
   ETCDCTL_API=3 etcdctl member remove <MEMBER_ID> --endpoints=http://127.0.0.1:2379
   ```

3. Add the member back:
   ```bash
   ETCDCTL_API=3 etcdctl member add nodeX \
     --peer-urls=http://<NODE_IP>:2380 \
     --endpoints=http://127.0.0.1:2379
   ```

4. Wipe the stale data directory on the failed node:
   ```bash
   rm -rf /var/lib/etcd/*
   ```

5. Re-run Ansible with `etcd_initial_cluster_state: existing`:
   ```bash
   ansible-playbook playbooks/site.yml \
     -i inventories/production/hosts.ini \
     --limit <failed_node> \
     --tags etcd \
     -e "etcd_initial_cluster_state=existing"
   ```

## Dependencies

- `common` (sets sysctl, ulimits, Java baseline)
