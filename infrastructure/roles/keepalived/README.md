# Role: keepalived

Keepalived VRRP for floating VIP / high availability on app nodes

## Variables

See `defaults/main.yml` for all tunable variables with their default values.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: <target_group>
  roles:
    - role: keepalived
```
