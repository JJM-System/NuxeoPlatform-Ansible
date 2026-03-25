#!/usr/bin/env bash
# vagrant-ssh-setup.sh — generate Ansible SSH keypair for Vagrant VMs
# Run ONCE before `vagrant up` if you need the key pre-generated.
# (vagrant up also auto-generates via Vagrantfile if missing.)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
KEY_DIR="${PROJECT_ROOT}/.vagrant/ansible_key"
KEY_FILE="${KEY_DIR}/id_rsa"

echo "==> Creating key directory: ${KEY_DIR}"
mkdir -p "${KEY_DIR}"
chmod 700 "${KEY_DIR}"

if [[ -f "${KEY_FILE}" ]]; then
  echo "==> SSH keypair already exists at: ${KEY_FILE}"
  echo "    Delete it manually to regenerate."
else
  echo "==> Generating 4096-bit RSA keypair..."
  ssh-keygen -t rsa -b 4096 \
    -f "${KEY_FILE}" \
    -N "" \
    -C "ansible@vagrant" \
    -q
  chmod 600 "${KEY_FILE}"
  chmod 644 "${KEY_FILE}.pub"
  echo "==> Keypair generated:"
  echo "    Private: ${KEY_FILE}"
  echo "    Public:  ${KEY_FILE}.pub"
fi

echo ""
echo "==> Public key (copy this to authorized_keys on non-Vagrant targets):"
echo "--------------------------------------------------------------------"
cat "${KEY_FILE}.pub"
echo "--------------------------------------------------------------------"
echo ""
echo "==> The Vagrantfile injects this key automatically on 'vagrant up'."
echo "==> For production, add the public key to the 'ansible' user on each node."
