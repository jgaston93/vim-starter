#!/usr/bin/env bash
# install.sh — Two-stage local LazyVim installation
#
# Stage 1 (system packages, run with sudo):
#   sudo ./install.sh --system
#
# Stage 2 (user packages, run as yourself):
#   ./install.sh --user
#
# Everything user-facing lands under ~/.local.  Source the generated env file
# to put all installed tools on your PATH:
#   source ~/.local/share/vim-starter/env.sh
# Add that line to your ~/.bashrc or ~/.zshrc to make it permanent.

set -euo pipefail

# ── Versions (keep in sync with Dockerfile) ────────────────────────────────────
RUST_VERSION="1.95"
NEOVIM_TAG="v0.12.2"
LAZYGIT_TAG="v0.61.1"

# ── Paths ──────────────────────────────────────────────────────────────────────
PREFIX="${HOME}/.local"
SHARE_DIR="${PREFIX}/share/vim-starter"
ENV_FILE="${SHARE_DIR}/env.sh"

# ── ANSI colors ────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD='\033[1m'; RESET='\033[0m'
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'
else
  BOLD=''; RESET=''
  GREEN=''; YELLOW=''; RED=''; CYAN=''
fi

# ── Helpers ────────────────────────────────────────────────────────────────────
log()  { echo -e "${GREEN}==>${RESET}${BOLD} $*${RESET}"; }
info() { echo -e "${CYAN}   $*${RESET}"; }
warn() { echo -e "${YELLOW}  ! $*${RESET}"; }
die()  { echo -e "${RED}ERROR:${RESET} $*" >&2; exit 1; }

# Print a step header
step() { echo; echo -e "${BOLD}${CYAN}── $* ──${RESET}"; }

# Return 0 if $1 is an executable on PATH
has() { command -v "$1" &>/dev/null; }

# Return 0 if installed binary $1 reports a version string containing $2
version_matches() {
  local cmd="$1" want="$2"
  has "$cmd" && "$cmd" --version 2>&1 | grep -qF "$want"
}

# Run a temporary-directory build; clean up on exit or error
TMPDIR_BUILD=""
cleanup() { [[ -n "$TMPDIR_BUILD" ]] && rm -rf "$TMPDIR_BUILD"; }
trap cleanup EXIT

make_tmpdir() {
  TMPDIR_BUILD="$(mktemp -d)"
  echo "$TMPDIR_BUILD"
}

usage() {
  echo "Usage:"
  echo "  sudo $0 --system   # install apt packages (once, as root)"
  echo "       $0 --user     # install user tools to ~/.local"
  exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
# STAGE 1 — system packages (must run as root / sudo)
# ══════════════════════════════════════════════════════════════════════════════
stage_system() {
  [[ $EUID -ne 0 ]] && die "Stage 1 requires root.  Run: sudo $0 --system"

  step "Updating apt"
  apt-get update -y

  step "Installing system packages"
  apt-get install -y \
    git curl wget \
    clang cmake ninja-build build-essential gettext \
    golang \
    npm \
    python3-pip \
    fzf ripgrep \
    unzip xclip \
    locales

  step "Configuring locale (en_US.UTF-8)"
  locale-gen en_US.UTF-8
  update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

  apt-get clean

  echo
  log "System stage complete."
  info "Now run (as your normal user):  ./install.sh --user"
}

# ══════════════════════════════════════════════════════════════════════════════
# STAGE 2 — user packages, everything lands under ~/.local
# ══════════════════════════════════════════════════════════════════════════════
stage_user() {
  [[ $EUID -eq 0 ]] && die "Stage 2 must run as your normal user, not root."

  # ── Prerequisite check ──────────────────────────────────────────────────────
  for cmd in git cmake clang curl npm go python3; do
    has "$cmd" || die "'$cmd' not found — did you run 'sudo $0 --system' first?"
  done

  # ── Directory setup ─────────────────────────────────────────────────────────
  step "Creating ~/.local directory tree"
  mkdir -p "${PREFIX}/bin" "${PREFIX}/lib" "${PREFIX}/share" "${SHARE_DIR}"

  # ── Env file ────────────────────────────────────────────────────────────────
  step "Writing env file → ${ENV_FILE}"
  cat > "${ENV_FILE}" <<'ENVEOF'
# vim-starter environment
# Source this file (or add the line below to ~/.bashrc / ~/.zshrc):
#   source ~/.local/share/vim-starter/env.sh

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# User-local binaries (neovim, lazygit, npm globals, etc.)
export PATH="${HOME}/.local/bin:${PATH}"

# Cargo / Rust binaries (tree-sitter, stylua, fd, rustup)
export PATH="${HOME}/.cargo/bin:${PATH}"

# Redirect Go module cache and installed binaries to ~/.local
export GOPATH="${HOME}/.local/go"
export GOBIN="${HOME}/.local/bin"
ENVEOF
  info "Written: ${ENV_FILE}"

  # Source it for the rest of this script
  # shellcheck source=/dev/null
  source "${ENV_FILE}"

  # ── npm: configure user prefix ───────────────────────────────────────────────
  step "Configuring npm prefix → ${PREFIX}"
  npm config set prefix "${PREFIX}"
  # npm writes to ~/.npmrc; keeps global installs out of /usr/local

  # ── npm packages ─────────────────────────────────────────────────────────────
  step "Installing npm packages (neovim provider)"
  npm install -g neovim

  # ── Rust / rustup ────────────────────────────────────────────────────────────
  step "Installing Rust via rustup"
  if has rustup; then
    info "rustup already present, skipping download"
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path
  fi

  # Ensure cargo env is on PATH for the rest of this script
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"

  info "Setting default toolchain to ${RUST_VERSION}"
  rustup toolchain install "${RUST_VERSION}" --no-self-update
  rustup default "${RUST_VERSION}"

  # ── Cargo tools ──────────────────────────────────────────────────────────────
  step "Installing cargo tools (tree-sitter-cli, stylua, fd-find)"
  # These land in ~/.cargo/bin which is already on PATH via the env file.
  # fd-find installs as 'fd'; replaces the npm fd-find shim with a native binary.
  cargo install --locked tree-sitter-cli stylua fd-find

  # ── pynvim ───────────────────────────────────────────────────────────────────
  step "Installing pynvim (Python neovim provider)"
  # --user installs to ~/.local/lib/pythonX.Y/site-packages
  # --break-system-packages handles Ubuntu 23.04+ PEP 668 enforcement
  pip install --user --break-system-packages pynvim 2>/dev/null \
    || pip3 install --user pynvim

  # ── Neovim (built from source) ───────────────────────────────────────────────
  step "Installing Neovim ${NEOVIM_TAG}"
  if version_matches nvim "${NEOVIM_TAG#v}"; then
    info "Neovim ${NEOVIM_TAG} already installed, skipping build"
  else
    TMP="$(make_tmpdir)"
    info "Cloning neovim ${NEOVIM_TAG}…"
    git clone --depth=1 --branch "${NEOVIM_TAG}" \
      https://github.com/neovim/neovim.git "${TMP}/neovim"

    # Step 1: build neovim's bundled deps (luv, libvterm, etc.)
    # cmake.deps installs to .deps/usr; the main build finds them via CMAKE_SOURCE_DIR/.deps/usr
    info "Building bundled deps…"
    cmake -S "${TMP}/neovim/cmake.deps" -B "${TMP}/neovim/.deps" \
      -DCMAKE_BUILD_TYPE=Release -G Ninja
    cmake --build "${TMP}/neovim/.deps" --parallel "$(nproc)"

    # Step 2: build neovim itself, picking up the just-built deps automatically
    info "Configuring neovim…"
    cmake -S "${TMP}/neovim" -B "${TMP}/neovim/build" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
      -G Ninja

    info "Building (this takes a few minutes)…"
    cmake --build "${TMP}/neovim/build" --parallel "$(nproc)"

    info "Installing to ${PREFIX}…"
    cmake --install "${TMP}/neovim/build"

    rm -rf "${TMP}"
    TMPDIR_BUILD=""
  fi

  # ── Lazygit ───────────────────────────────────────────────────────────────────
  step "Installing lazygit ${LAZYGIT_TAG}"
  if version_matches lazygit "${LAZYGIT_TAG#v}"; then
    info "lazygit ${LAZYGIT_TAG} already installed, skipping"
  else
    info "Downloading and building lazygit…"
    # GOBIN overrides where 'go install' places the binary (→ ~/.local/bin)
    # GOPATH keeps the module cache under ~/.local/go
    GOPATH="${PREFIX}/go" GOBIN="${PREFIX}/bin" \
      go install "github.com/jesseduffield/lazygit@${LAZYGIT_TAG}"
  fi

  # ── LazyVim starter config ────────────────────────────────────────────────────
  step "Setting up LazyVim starter config"
  if [[ -d "${HOME}/.config/nvim" ]]; then
    warn "~/.config/nvim already exists — skipping clone."
    warn "To start fresh: rm -rf ~/.config/nvim && ./install.sh --user"
  else
    git clone https://github.com/LazyVim/starter "${HOME}/.config/nvim"
    rm -rf "${HOME}/.config/nvim/.git"
    info "LazyVim starter cloned to ~/.config/nvim"
  fi

  # ── Done ─────────────────────────────────────────────────────────────────────
  echo
  log "User stage complete!"
  echo
  echo -e "  Add this line to your ${BOLD}~/.bashrc${RESET} or ${BOLD}~/.zshrc${RESET}:"
  echo -e "    ${CYAN}source ${ENV_FILE}${RESET}"
  echo
  echo -e "  Or source it right now:  ${CYAN}source ${ENV_FILE}${RESET}"
  echo -e "  Then launch neovim:      ${CYAN}nvim${RESET}"
}

# ── Main ───────────────────────────────────────────────────────────────────────
case "${1:-}" in
  --system) stage_system ;;
  --user)   stage_user   ;;
  *)        usage        ;;
esac
