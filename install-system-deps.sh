#!/bin/bash
#
# install-system-deps.sh
# Phase 1: Install system dependencies for vim-starter environment (RHEL 8)
# Run this script with sudo: sudo ./install-system-deps.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}vim-starter System Dependencies Setup${NC}"
echo -e "${GREEN}Phase 1: System Package Installation${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Verify RHEL 8
if [ -f /etc/redhat-release ]; then
    RHEL_VERSION=$(cat /etc/redhat-release)
    echo -e "${GREEN}Detected: ${RHEL_VERSION}${NC}"
    if ! echo "$RHEL_VERSION" | grep -q "release 8"; then
        echo -e "${YELLOW}WARNING: This script is designed for RHEL 8. You're running a different version.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo -e "${RED}ERROR: Not a RHEL/CentOS system${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Installing EPEL repository...${NC}"
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || true

echo ""
echo -e "${YELLOW}Updating system packages...${NC}"
dnf update -y

echo ""
echo -e "${YELLOW}Installing build dependencies and development tools...${NC}"
dnf install -y \
    git \
    curl \
    wget \
    gcc \
    gcc-c++ \
    make \
    cmake \
    golang \
    tar \
    gzip \
    clang \
    clang-devel \
    llvm-devel \
    unzip \
    xclip \
    python3 \
    python3-pip \
    python3-devel \
    gdb \
    clang-tools-extra \
    gettext \
    libtool \
    autoconf \
    automake \
    pkgconfig

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}System dependencies installed!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Exit from sudo (if you used 'sudo su')"
echo -e "2. Run as your regular user: ${GREEN}./install-user-env.sh${NC}"
echo ""
