#!/usr/bin/env bash
# local-up.sh — start the full 5-node Vagrant dev environment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# ── Colour helpers ────────────────────────────────────────────────────────────
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }

# ── Preflight checks ──────────────────────────────────────────────────────────
echo "==> Checking prerequisites..."

if ! command -v VBoxManage.exe &>/dev/null && ! command -v vboxmanage &>/dev/null; then
  red "✗ VirtualBox not found. Install from: https://www.virtualbox.org/"
  exit 1
fi
green "  ✓ VirtualBox found"

if ! command -v vagrant.exe &>/dev/null; then
  red "✗ Vagrant not found. Install from: https://www.vagrantup.com/"
  exit 1
fi
green "  ✓ Vagrant found ($(vagrant.exe --version | tr -d '\r'))"

if ! command -v ansible &>/dev/null; then
  yellow "  ⚠ ansible not found — install before provisioning:"
  yellow "    pip3 install ansible"
  yellow "    ansible-galaxy collection install -r infrastructure/requirements.yml"
fi

# ── SSH keypair ───────────────────────────────────────────────────────────────
if [[ ! -f ".vagrant/ansible_key/id_rsa" ]]; then
  echo "==> Generating Ansible SSH keypair..."
  bash scripts/vagrant-ssh-setup.sh
fi

# ── vagrant up ────────────────────────────────────────────────────────────────
echo ""
echo "==> Starting all 5 VMs..."

# Use --parallel if Vagrant >= 2.3.0 supports it cleanly
VAGRANT_VERSION=$(vagrant.exe --version | grep -oE '[0-9]+\.[0-9]+' | head -1 | tr -d '\r')
VAGRANT_MAJOR=$(echo "${VAGRANT_VERSION}" | cut -d. -f1)
VAGRANT_MINOR=$(echo "${VAGRANT_VERSION}" | cut -d. -f2)

VAGRANT_FLAGS=""
if [[ ${VAGRANT_MAJOR} -gt 2 ]] || [[ ${VAGRANT_MAJOR} -eq 2 && ${VAGRANT_MINOR} -ge 3 ]]; then
  VAGRANT_FLAGS="--parallel"
  echo "    (using --parallel, Vagrant ${VAGRANT_VERSION})"
fi

# shellcheck disable=SC2086
vagrant.exe up ${VAGRANT_FLAGS}

# ── Wait for all VMs to be SSH-ready ─────────────────────────────────────────
echo ""
echo "==> Waiting for all VMs to be SSH-ready..."

NODES=("node1" "node2" "node3" "node4" "node5")
MAX_RETRIES=30
RETRY_INTERVAL=5

for node in "${NODES[@]}"; do
  retries=0
  echo -n "    ${node}: "
  while true; do
    if vagrant.exe ssh "${node}" -c "echo ok" &>/dev/null 2>&1; then
      green "ready"
      break
    fi
    retries=$((retries + 1))
    if [[ ${retries} -ge ${MAX_RETRIES} ]]; then
      red "TIMEOUT after $((MAX_RETRIES * RETRY_INTERVAL))s"
      red "Run 'vagrant status' and 'vagrant ssh ${node}' to debug."
      exit 1
    fi
    echo -n "."
    sleep ${RETRY_INTERVAL}
  done
done

# ── Connectivity test ─────────────────────────────────────────────────────────
echo ""
echo "==> Testing Ansible connectivity..."
bash scripts/test-connectivity.sh

# ── Next steps ────────────────────────────────────────────────────────────────
echo ""
green "╔══════════════════════════════════════════════════════════════════╗"
green "  Environment is UP — all 5 nodes reachable                       "
green "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "  1. Install Ansible collections (once):"
echo "     ansible-galaxy collection install -r infrastructure/requirements.yml"
echo ""
echo "  2. Run full provisioning:"
echo "     ansible-playbook infrastructure/playbooks/site.yml \\"
echo "       -i infrastructure/inventories/local/hosts.ini"
echo ""
echo "  3. Or provision role by role:"
echo "     ./scripts/test-role.sh common"
echo "     ./scripts/test-role.sh etcd    db_nodes"
echo "     ./scripts/test-role.sh nuxeo   app_nodes"
echo ""
echo "  4. Run smoke tests after provisioning:"
echo "     ansible-playbook infrastructure/playbooks/smoke-test.yml \\"
echo "       -i infrastructure/inventories/local/hosts.ini"
echo ""
echo "  5. Tear down when done:"
echo "     ./local-destroy.sh"
