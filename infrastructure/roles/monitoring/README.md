# Role: monitoring

Monitoring stack (Prometheus, Grafana, exporters)

## Variables

See `defaults/main.yml` for all tunable variables with their default values.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: <target_group>
  roles:
    - role: monitoring
```
