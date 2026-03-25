# Role: haproxy

HAProxy load balancer fronting Nuxeo app nodes

## Variables

See `defaults/main.yml` for all tunable variables with their default values.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: <target_group>
  roles:
    - role: haproxy
```
