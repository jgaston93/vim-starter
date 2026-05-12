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

[[ -r /etc/os-release ]] || die "Cannot read /etc/os-release - unknown distro."
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

install_debian() {
  export DEBIAN_FRONTEND=noninteractive

  info "Updating apt cache"
  apt-get update -y

  info "Installing packages"
  apt-get install -y --no-install-recommends \
    ca-certificates git curl wget gnupg \
    build-essential cmake ninja-build gettext pkg-config \
    autoconf automake libtool libtool-bin m4 gperf patch \
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

install_rhel() {
  local major="${VERSION_ID%%.*}"

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

  # UBI 9 (and some other slim images) ship `curl-minimal` preinstalled,
  # which conflicts with the full `curl` package.  --allowerasing tells dnf
  # to swap them.  Harmless on UBI 8 / RHEL 8 / Fedora where there is no
  # conflict (it becomes a normal install).
  info "Installing curl (allowing curl-minimal swap on UBI9)"
  dnf install -y --allowerasing curl

  info "Installing packages"
  dnf install -y \
    ca-certificates git wget gnupg2 \
    gcc gcc-c++ make cmake ninja-build gettext pkgconfig \
    autoconf automake libtool m4 patch \
    clang clang-tools-extra lldb \
    gdb \
    unzip tar gzip xz \
    xclip \
    python3 python3-pip python3-devel \
    golang \
    glibc-langpack-en

  # gperf lives in CRB/CodeReady-Builder on RHEL 8 and is not in every UBI 8
  # variant.  Treat it as a soft dependency - neovim's deps build works
  # without it in most cases.
  if ! dnf install -y gperf; then
    warn "gperf not available - skipping (neovim's deps build may still succeed)."
  fi

  # RHEL 8 ships python3 = 3.6 (EOL).  Install python3.11 alongside so
  # install-user-tools.sh can pip-install modern wheels (ruff, black, ...).
  # RHEL 9 and Fedora already ship a recent-enough python3 by default.
  if [[ "$major" == "8" ]]; then
    info "Installing python3.11 (RHEL 8 default python3 is 3.6, too old for modern wheels)"
    dnf install -y python3.11 python3.11-pip python3.11-devel || \
      warn "python3.11 not available - install-user-tools.sh may fail on pip installs."
  fi

  # bear is in EPEL 9 / Fedora but NOT in EPEL 8.  Try to install it; if
  # unavailable, install-user-tools.sh installs compiledb (pip) instead.
  if ! dnf install -y bear; then
    warn "bear not available on this release - compiledb (pip) will be used instead."
  fi

  dnf clean all
}

case "$FAMILY" in
  debian) install_debian ;;
  rhel)   install_rhel ;;
esac

log "Build dependencies installed."
info "Next:  ./install-user-tools.sh  (run as your normal user)"
