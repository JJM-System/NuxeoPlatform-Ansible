#!/usr/bin/env bash
# test-connectivity.sh — verify Ansible can reach all 5 nodes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
INVENTORY="${PROJECT_ROOT}/infrastructure/inventories/local/hosts.ini"
ANSIBLE_CFG="${PROJECT_ROOT}/infrastructure/ansible.cfg"

echo "==> Testing connectivity to all nodes..."
echo "    Inventory: ${INVENTORY}"
echo ""

cd "${PROJECT_ROOT}/infrastructure"

# Run ping module, capture output and exit code
set +e
output=$(ANSIBLE_CONFIG="${ANSIBLE_CFG}" \
  ansible all \
    -i "${INVENTORY}" \
    -m ansible.builtin.ping \
    2>&1)
exit_code=$?
set -e

echo "${output}"
echo ""

# Parse failures from output
failed_nodes=()
while IFS= read -r line; do
  if echo "${line}" | grep -qE "^[a-z0-9_-]+ \| FAILED|^[a-z0-9_-]+ \| UNREACHABLE"; then
    node=$(echo "${line}" | awk '{print $1}')
    failed_nodes+=("${node}")
  fi
done <<< "${output}"

if [[ ${exit_code} -eq 0 && ${#failed_nodes[@]} -eq 0 ]]; then
  echo "✓ All 5 nodes reachable"
  exit 0
else
  echo "✗ The following nodes FAILED:"
  for node in "${failed_nodes[@]}"; do
    echo "    - ${node}"
  done
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check VMs are running:   vagrant.exe status"
  echo "  2. Check SSH key:           cat .vagrant/ansible_key/id_rsa.pub"
  echo "  3. SSH manually:            ssh -i .vagrant/ansible_key/id_rsa vagrant@192.168.56.11"
  exit 1
fi
