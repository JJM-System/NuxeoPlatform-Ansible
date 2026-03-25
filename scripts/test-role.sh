#!/usr/bin/env bash
# test-role.sh — deploy and health-check a single Ansible role
#
# Usage:
#   ./scripts/test-role.sh <role_name> [node_limit]
#
# Examples:
#   ./scripts/test-role.sh common                # all nodes
#   ./scripts/test-role.sh common node1          # node1 only
#   ./scripts/test-role.sh etcd db_nodes         # db_nodes group
#   ./scripts/test-role.sh nuxeo app_nodes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
INFRA_DIR="${PROJECT_ROOT}/infrastructure"
INVENTORY="${INFRA_DIR}/inventories/local/hosts.ini"
PLAYBOOK="${INFRA_DIR}/playbooks/site.yml"
ANSIBLE_CFG="${INFRA_DIR}/ansible.cfg"

# ── Argument parsing ──────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <role_name> [node_limit]"
  echo ""
  echo "Available roles: common etcd postgresql elasticsearch kafka minio nuxeo haproxy keepalived monitoring"
  exit 1
fi

ROLE="${1}"
LIMIT="${2:-}"

# ── Preflight ─────────────────────────────────────────────────────────────────
if ! command -v ansible-playbook &>/dev/null; then
  echo "✗ ansible-playbook not found. Install Ansible first:"
  echo "  pip3 install ansible"
  exit 1
fi

if [[ ! -f "${PLAYBOOK}" ]]; then
  echo "✗ Playbook not found: ${PLAYBOOK}"
  exit 1
fi

# ── Build command ─────────────────────────────────────────────────────────────
ANSIBLE_ARGS=(
  ansible-playbook
  "${PLAYBOOK}"
  -i "${INVENTORY}"
  --tags "${ROLE}"
  -v
)

if [[ -n "${LIMIT}" ]]; then
  ANSIBLE_ARGS+=(-l "${LIMIT}")
fi

# ── Run role deployment ───────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════════════╗"
echo "  Deploying role: ${ROLE}${LIMIT:+ (limit: ${LIMIT})}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

start_time=$(date +%s)

cd "${INFRA_DIR}"
ANSIBLE_CONFIG="${ANSIBLE_CFG}" "${ANSIBLE_ARGS[@]}"
deploy_exit=$?

if [[ ${deploy_exit} -ne 0 ]]; then
  echo ""
  echo "✗ Role '${ROLE}' FAILED (deploy phase). See output above."
  exit ${deploy_exit}
fi

# ── Run health check ──────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "  Running health check: ${ROLE}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Use the role-specific health_check_<role> tag so only THIS role's health
# checks run — not every health_check-tagged task across all roles.
HC_ARGS=(
  ansible-playbook
  "${PLAYBOOK}"
  -i "${INVENTORY}"
  --tags "health_check_${ROLE}"
  -v
)

if [[ -n "${LIMIT}" ]]; then
  HC_ARGS+=(-l "${LIMIT}")
fi

ANSIBLE_CONFIG="${ANSIBLE_CFG}" "${HC_ARGS[@]}"
hc_exit=$?

end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
if [[ ${hc_exit} -eq 0 ]]; then
  echo "✓ Role '${ROLE}' deployed and health check PASSED"
else
  echo "✗ Role '${ROLE}' deployed but health check FAILED"
fi

printf "  Duration: %dm %ds\n" $((duration / 60)) $((duration % 60))
exit ${hc_exit}
