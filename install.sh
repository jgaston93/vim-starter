#!/usr/bin/env bash
# install.sh — vim-starter entry point.
#
# The actual work lives in three orthogonal scripts:
#   install-build-deps.sh       system packages (run as root)
#   install-user-tools.sh       neovim/lazygit/rust/node/python/opencode → $HOME
#   install-lazyvim-config.sh   LazyVim starter → ~/.config/nvim
#
# Run them individually, or use the subcommands below.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  sudo ./install.sh --system           install system packages (root)
       ./install.sh --user             install user tools to ~/.local
       ./install.sh --config [--force] set up LazyVim at ~/.config/nvim
       ./install.sh --all              run all three (sudo prompted for --system)

The three stages may also be run as standalone scripts:
  install-build-deps.sh
  install-user-tools.sh
  install-lazyvim-config.sh
EOF
  exit "${1:-1}"
}

case "${1:-}" in
  --system)
    exec "${SCRIPT_DIR}/install-build-deps.sh" ;;
  --user)
    exec "${SCRIPT_DIR}/install-user-tools.sh" ;;
  --config)
    shift
    exec "${SCRIPT_DIR}/install-lazyvim-config.sh" "$@" ;;
  --all)
    sudo "${SCRIPT_DIR}/install-build-deps.sh"
    "${SCRIPT_DIR}/install-user-tools.sh"
    "${SCRIPT_DIR}/install-lazyvim-config.sh"
    ;;
  -h|--help)
    usage 0 ;;
  *)
    usage ;;
esac
