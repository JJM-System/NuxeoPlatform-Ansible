#!/usr/bin/env bash
# local-destroy.sh — tear down the full Vagrant dev environment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }

# ── Confirmation prompt ───────────────────────────────────────────────────────
echo ""
yellow "WARNING: This will DESTROY all 5 Vagrant VMs and clean up local state."
yellow "         All unsaved VM data will be lost."
echo ""
read -r -p "This will destroy ALL 5 VMs. Continue? [y/N] " confirm

if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# ── Destroy VMs ───────────────────────────────────────────────────────────────
echo ""
echo "==> Destroying all VMs..."
if command -v vagrant.exe &>/dev/null; then
  vagrant.exe destroy -f
else
  red "vagrant.exe not found — skipping VM destroy"
fi

# ── Clean up VirtualBox orphaned disks ───────────────────────────────────────
echo "==> Removing data disks..."
if [[ -d ".vagrant/disks" ]]; then
  rm -rf ".vagrant/disks"
  echo "    Removed .vagrant/disks/"
fi

# ── Clean up Vagrant machine state ───────────────────────────────────────────
echo "==> Cleaning .vagrant/machines/..."
if [[ -d ".vagrant/machines" ]]; then
  rm -rf ".vagrant/machines"
  echo "    Removed .vagrant/machines/"
fi

# ── Clean up Ansible fact cache ───────────────────────────────────────────────
echo "==> Cleaning Ansible fact cache..."
FACT_CACHE="infrastructure/.cache/facts"
if [[ -d "${FACT_CACHE}" ]]; then
  rm -rf "${FACT_CACHE}"
  echo "    Removed ${FACT_CACHE}/"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
green "Environment destroyed."
echo ""
echo "To rebuild from scratch:"
echo "  ./local-up.sh"
