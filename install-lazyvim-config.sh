#!/usr/bin/env bash
# install-lazyvim-config.sh
# Clones the LazyVim starter into ~/.config/nvim.  If a `nvim/` directory
# exists alongside this script (e.g. when run from this repo with a custom
# config tracked there), its contents are overlaid on top of the starter.
#
# Usage:
#   ./install-lazyvim-config.sh           # install into a fresh ~/.config/nvim
#   ./install-lazyvim-config.sh --force   # back up any existing config and replace

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; CYAN=''; NC=''
fi
log()  { echo -e "${GREEN}==>${NC} $*"; }
warn() { echo -e "${YELLOW}  ! $*${NC}"; }
die()  { echo -e "${RED}ERROR:${NC} $*" >&2; exit 1; }

CONFIG="${HOME}/.config/nvim"
FORCE="${1:-}"

if [[ -d "${CONFIG}" ]]; then
  if [[ "${FORCE}" == "--force" ]]; then
    BACKUP="${CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
    warn "Backing up existing config → ${BACKUP}"
    mv "${CONFIG}" "${BACKUP}"
  else
    die "${CONFIG} already exists. Re-run with --force to back up and replace."
  fi
fi

mkdir -p "$(dirname "${CONFIG}")"

log "Cloning LazyVim starter"
git clone --depth=1 https://github.com/LazyVim/starter "${CONFIG}"
rm -rf "${CONFIG}/.git"

# Overlay personal config if this script is run from the vim-starter repo and
# a nvim/ directory is present.  The overlay copies files on top of the
# starter, preserving the starter's structure but overriding any matching paths.
if [[ -d "${SCRIPT_DIR}/nvim" ]] && \
   [[ -n "$(find "${SCRIPT_DIR}/nvim" -mindepth 1 -not -name .gitkeep -print -quit 2>/dev/null)" ]]; then
  log "Overlaying custom nvim/ from ${SCRIPT_DIR}/nvim"
  # cp -R nvim/. dest/  → copy contents of nvim/ into dest/ (not nvim/ itself)
  cp -R "${SCRIPT_DIR}/nvim/." "${CONFIG}/"
fi

log "LazyVim config installed → ${CONFIG}"
echo
echo -e "  Start neovim with:  ${CYAN}nvim${NC}"
echo -e "  LazyVim will install plugins on first launch."
