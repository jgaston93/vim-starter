#!/bin/bash
#
# install-system-deps-ubuntu.sh
# Phase 1: Install system dependencies for vim-starter environment (Ubuntu 24.04)
# Run this script with sudo: sudo ./install-system-deps-ubuntu.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}vim-starter System Dependencies Setup${NC}"
echo -e "${GREEN}Phase 1: System Package Installation${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
    exit 1
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${GREEN}Detected: ${NAME} ${VERSION}${NC}"
    if [[ "$ID" != "ubuntu" ]]; then
        echo -e "${YELLOW}WARNING: This script is designed for Ubuntu. You're running ${NAME}.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo -e "${RED}ERROR: Cannot detect OS${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Updating package lists...${NC}"
apt update -y

echo ""
echo -e "${YELLOW}Upgrading existing packages...${NC}"
apt upgrade -y

echo ""
echo -e "${YELLOW}Installing build dependencies and development tools...${NC}"
apt install -y \
    build-essential \
    git \
    curl \
    wget \
    gcc \
    g++ \
    make \
    cmake \
    golang-go \
    tar \
    gzip \
    clang \
    clang-format \
    clang-tools \
    llvm \
    unzip \
    xclip \
    python3 \
    python3-pip \
    python3-dev \
    gdb \
    gettext \
    libtool \
    libtool-bin \
    autoconf \
    automake \
    pkg-config \
    ninja-build

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}System dependencies installed!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Exit from sudo (if you used 'sudo su')"
echo -e "2. Run as your regular user: ${GREEN}./install-user-env-ubuntu.sh${NC}"
echo ""
