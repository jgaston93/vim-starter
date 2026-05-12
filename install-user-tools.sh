#!/usr/bin/env bash
# install-user-tools.sh
# Installs neovim, lazygit, fd, ripgrep, fzf, tree-sitter, stylua, opencode,
# nvm+node, and python providers - everything lands under $HOME.
# Run as your normal user (or as root inside a Docker image).
#
# Requires that install-build-deps.sh has already installed the compilers,
# git, curl, etc.  Re-running this script is safe: each step is idempotent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
. "${SCRIPT_DIR}/versions.env"

if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; CYAN=''; BOLD=''; NC=''
fi
log()  { echo -e "${GREEN}==>${NC}${BOLD} $*${NC}"; }
info() { echo -e "${CYAN}   $*${NC}"; }
warn() { echo -e "${YELLOW}  ! $*${NC}"; }
die()  { echo -e "${RED}ERROR:${NC} $*" >&2; exit 1; }

# Allow root inside a container; refuse root on a host.
in_container() {
  [[ -f /.dockerenv ]]                                                                            && return 0
  [[ -f /run/.containerenv ]]                                                                     && return 0
  grep -qE 'docker|containerd|buildkit|kubepods|lxc' /proc/1/cgroup 2>/dev/null                   && return 0
  [[ "${VIM_STARTER_ALLOW_ROOT:-}" == "1" ]]                                                      && return 0
  return 1
}
if [[ $EUID -eq 0 ]] && ! in_container; then
  die "Do not run this as root on a host system.  Run as your normal user."
fi

has() { command -v "$1" &>/dev/null; }

uname_arch() {
  case "$(uname -m)" in
    x86_64)        echo x86_64 ;;
    aarch64|arm64) echo aarch64 ;;
    *)             die "Unsupported architecture: $(uname -m)" ;;
  esac
}
ARCH="$(uname_arch)"

# Pick the newest Python available.  Modern wheels (ruff, black, ...) need >= 3.9.
# RHEL 8's default python3 is 3.6 (EOL); install-build-deps.sh installs
# python3.11 alongside so this picker can find a usable interpreter.
pick_python() {
  local p ver maj min
  for p in python3.12 python3.11 python3.10 python3.9 python3; do
    if has "$p"; then
      ver=$("$p" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || echo "0.0")
      maj=${ver%.*}; min=${ver#*.}
      if [[ "$maj" == "3" ]] && [[ "$min" -ge 9 ]]; then
        echo "$p"; return 0
      fi
    fi
  done
  return 1
}
PYTHON="$(pick_python)" || die "No Python 3.9+ found.  Run install-build-deps.sh first."

# NOTE: do NOT name this variable PREFIX.  nvm is a shell function loaded into
# the current shell and reads $PREFIX directly; npm also dislikes it.  Using
# VS_PREFIX avoids the collision.
VS_PREFIX="${HOME}/.local"
SHARE_DIR="${VS_PREFIX}/share/vim-starter"
ENV_FILE="${SHARE_DIR}/env.sh"
BUILD_DIR="${VS_PREFIX}/src/vim-starter-build"

mkdir -p "${VS_PREFIX}/bin" "${VS_PREFIX}/lib" "${VS_PREFIX}/share" "${SHARE_DIR}" "${BUILD_DIR}"

for cmd in git make cmake gcc curl wget go; do
  has "$cmd" || die "'$cmd' not found.  Run install-build-deps.sh first."
done
info "Using ${PYTHON} ($(${PYTHON} --version 2>&1))"

log "Writing env file -> ${ENV_FILE}"
cat > "${ENV_FILE}" <<'ENVEOF'
# vim-starter environment - source from ~/.bashrc or ~/.zshrc:
#   source ~/.local/share/vim-starter/env.sh

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

export PATH="${HOME}/.local/bin:${PATH}"
export PATH="${HOME}/.cargo/bin:${PATH}"
export PATH="${HOME}/.opencode/bin:${PATH}"

export GOPATH="${HOME}/.local/go"
export GOBIN="${HOME}/.local/bin"

export NVM_DIR="${HOME}/.nvm"
[ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
[ -s "${NVM_DIR}/bash_completion" ] && . "${NVM_DIR}/bash_completion"

export MANPATH="${HOME}/.local/share/man:${MANPATH:-}"
ENVEOF

# shellcheck source=/dev/null
. "${ENV_FILE}"

log "Installing Rust ${RUST_VERSION}"
if ! has rustup; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain "${RUST_VERSION}"
fi
# shellcheck source=/dev/null
. "${HOME}/.cargo/env"
rustup toolchain install "${RUST_VERSION}" --no-self-update
rustup default "${RUST_VERSION}"

log "Installing cargo tools: tree-sitter-cli, stylua, fd-find"
cargo install --locked tree-sitter-cli stylua fd-find

log "Installing Neovim ${NEOVIM_TAG}"
if has nvim && nvim --version | head -n1 | grep -qF "${NEOVIM_TAG#v}"; then
  info "Neovim ${NEOVIM_TAG} already installed, skipping"
else
  rm -rf "${BUILD_DIR}/neovim"
  git clone --depth=1 --branch "${NEOVIM_TAG}" \
    https://github.com/neovim/neovim.git "${BUILD_DIR}/neovim"

  cmake -S "${BUILD_DIR}/neovim/cmake.deps" -B "${BUILD_DIR}/neovim/.deps" \
    -DCMAKE_BUILD_TYPE=Release -G Ninja
  cmake --build "${BUILD_DIR}/neovim/.deps" --parallel "$(nproc)"

  cmake -S "${BUILD_DIR}/neovim" -B "${BUILD_DIR}/neovim/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${VS_PREFIX}" \
    -G Ninja
  cmake --build "${BUILD_DIR}/neovim/build" --parallel "$(nproc)"
  cmake --install "${BUILD_DIR}/neovim/build"

  rm -rf "${BUILD_DIR}/neovim"
fi

log "Installing lazygit ${LAZYGIT_TAG}"
if has lazygit && lazygit --version 2>&1 | grep -qF "${LAZYGIT_TAG#v}"; then
  info "lazygit ${LAZYGIT_TAG} already installed, skipping"
else
  GOBIN="${VS_PREFIX}/bin" GOPATH="${VS_PREFIX}/go" \
    go install "github.com/jesseduffield/lazygit@${LAZYGIT_TAG}"
fi

log "Installing ripgrep ${RIPGREP_VERSION}"
if has rg && rg --version | head -n1 | grep -qF "${RIPGREP_VERSION}"; then
  info "ripgrep ${RIPGREP_VERSION} already installed, skipping"
else
  case "${ARCH}" in
    x86_64)  RG_TARGET="x86_64-unknown-linux-musl" ;;
    aarch64) RG_TARGET="aarch64-unknown-linux-gnu" ;;
  esac
  RG_TARBALL="ripgrep-${RIPGREP_VERSION}-${RG_TARGET}.tar.gz"
  (
    cd "${BUILD_DIR}"
    curl -fsSL -O "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/${RG_TARBALL}"
    tar xzf "${RG_TARBALL}"
    install -m 0755 "${RG_TARBALL%.tar.gz}/rg" "${VS_PREFIX}/bin/rg"
    rm -rf "${RG_TARBALL%.tar.gz}" "${RG_TARBALL}"
  )
fi

log "Installing fzf ${FZF_VERSION}"
if has fzf && fzf --version 2>&1 | grep -qF "${FZF_VERSION}"; then
  info "fzf ${FZF_VERSION} already installed, skipping"
else
  case "${ARCH}" in
    x86_64)  FZF_ARCH=amd64 ;;
    aarch64) FZF_ARCH=arm64 ;;
  esac
  FZF_TARBALL="fzf-${FZF_VERSION}-linux_${FZF_ARCH}.tar.gz"
  (
    cd "${BUILD_DIR}"
    curl -fsSL -O "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/${FZF_TARBALL}"
    tar xzf "${FZF_TARBALL}"
    install -m 0755 fzf "${VS_PREFIX}/bin/fzf"
    rm -f fzf "${FZF_TARBALL}"
  )
fi

# nvm refuses to run if $PREFIX is set in the environment.  Unset it in case
# a parent shell or base image exports one.
unset PREFIX npm_config_prefix || true

log "Installing nvm ${NVM_VERSION} + Node ${NODE_LTS_MAJOR} LTS"
if [[ ! -s "${HOME}/.nvm/nvm.sh" ]]; then
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | PROFILE=/dev/null bash
fi
export NVM_DIR="${HOME}/.nvm"
# shellcheck source=/dev/null
. "${NVM_DIR}/nvm.sh"
if ! nvm ls "${NODE_LTS_MAJOR}" &>/dev/null; then
  nvm install "${NODE_LTS_MAJOR}" --lts
fi
nvm alias default "${NODE_LTS_MAJOR}"

info "Installing neovim npm provider"
npm install -g neovim --silent

# Python tooling - uses the modern Python picked above (NOT system pip3).
#   pynvim/neovim - nvim's Python host
#   jinja2        - templated code-gen workflow
#   ruff, black   - Python lint/format
#   compiledb     - generates compile_commands.json from `make`;
#                   portable alternative to `bear` (unavailable in EPEL 8)
log "Bootstrapping pip for ${PYTHON}"
"${PYTHON}" -m ensurepip --upgrade 2>/dev/null || true
PIP_FLAGS="--user"
if "${PYTHON}" -m pip install --help 2>&1 | grep -q -- '--break-system-packages'; then
  PIP_FLAGS="${PIP_FLAGS} --break-system-packages"
fi
# shellcheck disable=SC2086
"${PYTHON}" -m pip install ${PIP_FLAGS} --upgrade pip setuptools wheel

log "Installing Python tooling (pynvim, neovim, jinja2, ruff, black, compiledb)"
# shellcheck disable=SC2086
"${PYTHON}" -m pip install ${PIP_FLAGS} --upgrade \
  pynvim neovim jinja2 ruff black compiledb

log "Installing OpenCode ${OPENCODE_VERSION}"
if [[ -x "${HOME}/.opencode/bin/opencode" ]]; then
  info "OpenCode already installed, skipping"
else
  curl -fsSL https://opencode.ai/install | bash -s -- --version "${OPENCODE_VERSION}"
fi

echo
log "User tools installed."
echo
echo -e "  Add to your ${BOLD}~/.bashrc${NC} or ${BOLD}~/.zshrc${NC}:"
echo -e "    ${CYAN}source ${ENV_FILE}${NC}"
echo
echo -e "  Or source it for this shell:"
echo -e "    ${CYAN}source ${ENV_FILE}${NC}"
echo
echo -e "  Next:  ${CYAN}./install-lazyvim-config.sh${NC}  (sets up ~/.config/nvim)"
