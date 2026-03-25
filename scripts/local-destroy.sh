#!/usr/bin/env bash
# local-destroy.sh — destroy all Vagrant VMs and clean up leftover disk images
#
# Usage:
#   ./scripts/local-destroy.sh          # destroy + clean disks
#   ./scripts/local-destroy.sh --keep-disks  # destroy VMs only, keep .vdi files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
KEEP_DISKS=false

for arg in "$@"; do
  [[ "${arg}" == "--keep-disks" ]] && KEEP_DISKS=true
done

echo "╔══════════════════════════════════════════════════════════════╗"
echo "  Destroying Vagrant VMs"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

cd "${PROJECT_ROOT}"

# On Windows + WSL2 Vagrant must be called as vagrant.exe
VAGRANT_CMD="vagrant.exe"
if ! command -v vagrant.exe &>/dev/null; then
  VAGRANT_CMD="vagrant"
fi

"${VAGRANT_CMD}" destroy -f

# Remove leftover .vdi disk images — VirtualBox does not delete them
# automatically when the VM is destroyed.
if [[ "${KEEP_DISKS}" == "false" ]]; then
  DISK_DIR="${PROJECT_ROOT}/.vagrant/disks"
  if [[ -d "${DISK_DIR}" ]]; then
    echo ""
    echo "Removing leftover disk images in ${DISK_DIR} ..."
    rm -f "${DISK_DIR}"/*.vdi
    echo "Done."
  fi
fi

echo ""
echo "✓ All VMs destroyed. Run 'vagrant.exe up' to recreate the cluster."
