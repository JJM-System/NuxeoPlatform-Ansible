# Role: postgresql

Installs and configures a 3-node PostgreSQL 16 HA cluster managed by Patroni, using etcd as the distributed configuration store (DCS).

## Architecture

```
db1 (192.168.56.11)  ─┐
db2 (192.168.56.12)  ──┤──▶  Patroni (etcd DCS)  ──▶  1 Leader + 2 Replicas
db3 (192.168.56.13)  ─┘
```

- **PostgreSQL 16** — installed from the official PGDG apt repository
- **Patroni 3.3.2** — HA manager; owns and manages the data directory exclusively
- **etcd** — DCS backend for leader election (deployed by the `etcd` role, listed as dependency)
- The default PostgreSQL systemd service is disabled; Patroni starts and manages `postgres` itself

## Bootstrap behaviour

All 3 nodes must start at the same time (`serial: "100%"` in the play). Whichever node wins the etcd leader race runs `initdb`, then becomes the Patroni primary. The other two nodes detect the primary via etcd and run `pg_basebackup` to bootstrap as replicas.

## Key ports

| Port | Service |
|------|---------|
| 5432 | PostgreSQL |
| 8008 | Patroni REST API |

## Important variables

| Variable | Default | Description |
|----------|---------|-------------|
| `postgresql_version` | `"16"` | PostgreSQL major version |
| `postgresql_port` | `5432` | PostgreSQL listen port |
| `patroni_version` | `"3.3.2"` | Patroni pip package version |
| `patroni_restapi_port` | `8008` | Patroni REST API port |
| `patroni_scope` | `nuxeo-patroni-local` | Patroni cluster name in etcd |
| `postgresql_max_connections` | `100` | Max PG connections |
| `postgresql_shared_buffers` | `256MB` | Shared buffer size |
| `postgresql_wal_level` | `replica` | WAL level (replica enables streaming) |
| `postgresql_nuxeo_db` | `nuxeo` | Application database name |
| `postgresql_nuxeo_user` | `nuxeo` | Application database user |

See `defaults/main.yml` for the full list.

## Required vault variables

These must be defined in an Ansible Vault–encrypted file (e.g. `group_vars/all/vault.yml`):

| Variable | Purpose |
|----------|---------|
| `vault_postgresql_password` | Password for the `postgres` superuser |
| `vault_postgresql_replication_password` | Password for the streaming replication user |
| `vault_patroni_restapi_password` | Password for the Patroni REST API |
| `vault_nuxeo_db_password` | Password for the `nuxeo` application user |

## Dependencies

- `common` — base OS configuration, UFW, system users
- `etcd` — etcd cluster must be running before Patroni starts

## Tags

| Tag | Scope |
|-----|-------|
| `postgresql` | All tasks |
| `install` | Package installation and service setup |
| `configure` | Patroni config, pg_hba, service start, DB/user creation |
| `health_check` | Patroni REST API check, patronictl list, DB verification |

## Usage

```bash
# Full install
ansible-playbook playbooks/site.yml --tags postgresql

# Health check only
ansible-playbook playbooks/site.yml --tags postgresql,health_check

# Via test-role.sh
bash scripts/test-role.sh postgresql
```

## Playbook requirement

The postgresql play **must** use `serial: "100%"` so all 3 nodes start Patroni simultaneously. Without this, the first node times out waiting for etcd quorum before the other nodes have joined.

```yaml
- name: Deploy PostgreSQL + Patroni cluster
  hosts: db_nodes
  serial: "100%"
  roles:
    - role: postgresql
```
