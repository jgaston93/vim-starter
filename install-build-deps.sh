#!/usr/bin/env bash
# install-build-deps.sh
# Installs the system packages required to build and run the vim-starter
# toolchain. Detects the distro from /etc/os-release and uses the matching
# package manager. Must be run as root.
#
# Supported families:
#   - Debian / Ubuntu                (apt-get)
#   - RHEL / CentOS / Rocky / Alma   (dnf, with EPEL on RHEL 8/9)
#   - Fedora                         (dnf)
#
# Package selection targets feature parity across distros: the same set of
# user-facing tools is installed on every supported OS, even when a distro
# requires extra repos (EPEL) or differently-named packages.

set -euo pipefail

if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; CYAN=''; BOLD=''; NC=''
fi
log()  { echo -e "${GREEN}==>${NC}${BOLD} $*${NC}"; }
info() { echo -e "${CYAN}   $*${NC}"; }
warn() { echo -e "${YELLOW}  ! $*${NC}"; }
die()  { echo -e "${RED}ERROR:${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Must run as root.  Try: sudo $0"

[[ -r /etc/os-release ]] || die "Cannot read /etc/os-release — unknown distro."
# shellcheck disable=SC1091
. /etc/os-release
OS_ID="${ID:-unknown}"
OS_LIKE="${ID_LIKE:-}"

case " ${OS_ID} ${OS_LIKE} " in
  *" ubuntu "*|*" debian "*)
    FAMILY=debian ;;
  *" rhel "*|*" centos "*|*" rocky "*|*" almalinux "*|*" fedora "*)
    FAMILY=rhel ;;
  *)
    die "Unsupported distro '${OS_ID}'. Supported: ubuntu, debian, rhel, centos, rocky, alma, fedora." ;;
esac

log "Detected ${PRETTY_NAME:-$OS_ID}  (family: $FAMILY)"

# ─── Debian / Ubuntu ──────────────────────────────────────────────────────────
install_debian() {
  export DEBIAN_FRONTEND=noninteractive

  info "Updating apt cache"
  apt-get update -y

  info "Installing packages"
  apt-get install -y --no-install-recommends \
    ca-certificates git curl wget gnupg \
    build-essential cmake ninja-build gettext pkg-config \
    autoconf automake libtool libtool-bin m4 \
    clang clangd clang-format clang-tidy lldb \
    gcc g++ gdb \
    bear \
    unzip tar gzip xz-utils \
    xclip \
    python3 python3-pip python3-dev python3-venv \
    golang-go \
    locales

  info "Generating en_US.UTF-8 locale"
  locale-gen en_US.UTF-8 || true
  update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 || true

  apt-get clean
  rm -rf /var/lib/apt/lists/*
}

# ─── RHEL / CentOS / Rocky / Alma / Fedora ────────────────────────────────────
install_rhel() {
  local major="${VERSION_ID%%.*}"

  # EPEL provides ninja-build, bear, etc. on RHEL/CentOS/Rocky/Alma 8 and 9.
  # Fedora has these in the main repos, so skip EPEL there.
  if [[ "$OS_ID" != "fedora" ]]; then
    if ! dnf -q repolist enabled 2>/dev/null | grep -qi epel; then
      info "Enabling EPEL for major=${major}"
      case "$major" in
        8) dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm" || true ;;
        9) dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm" || true ;;
        *) warn "Unrecognized RHEL major '${major}'; skipping EPEL." ;;
      esac
    fi
  fi

  info "Installing packages"
  dnf install -y \
    ca-certificates git curl wget gnupg2 \
    gcc gcc-c++ make cmake ninja-build gettext pkgconfig \
    autoconf automake libtool m4 \
    clang clang-tools-extra lldb \
    gdb \
    bear \
    unzip tar gzip xz \
    xclip \
    python3 python3-pip python3-devel \
    golang \
    glibc-langpack-en

  dnf clean all
}

case "$FAMILY" in
  debian) install_debian ;;
  rhel)   install_rhel ;;
esac

log "Build dependencies installed."
info "Next:  ./install-user-tools.sh  (run as your normal user)"
