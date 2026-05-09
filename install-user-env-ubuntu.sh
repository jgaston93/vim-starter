#!/bin/bash
#
# install-user-env-ubuntu.sh
# Phase 2: Install vim-starter environment locally for current user (Ubuntu 24.04)
# Run this script as your regular user: ./install-user-env-ubuntu.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RUST_VERSION="1.95"
NEOVIM_TAG="v0.12.2"
LAZYGIT_TAG="v0.61.1"
OPENCODE_VERSION="1.14.33"

LOCAL_DIR="$HOME/.local"
LOCAL_BIN="$LOCAL_DIR/bin"
LOCAL_SHARE="$LOCAL_DIR/share"
BUILD_DIR="$LOCAL_DIR/src/vim-starter-build"
LOG_DIR="$BUILD_DIR/logs"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}vim-starter Local Environment Setup${NC}"
echo -e "${GREEN}Phase 2: User Installation${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}ERROR: Do NOT run this script as root or with sudo${NC}"
    echo -e "${RED}Run as your regular user: ./install-user-env-ubuntu.sh${NC}"
    exit 1
fi

echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "$LOCAL_BIN"
mkdir -p "$LOCAL_SHARE"
mkdir -p "$BUILD_DIR"
mkdir -p "$LOG_DIR"

echo ""
echo -e "${YELLOW}Checking system dependencies...${NC}"
MISSING_DEPS=()
for cmd in gcc g++ make cmake git curl wget go python3 pip3 clang; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}ERROR: Missing required system dependencies:${NC}"
    for dep in "${MISSING_DEPS[@]}"; do
        echo -e "${RED}  - $dep${NC}"
    done
    echo ""
    echo -e "${YELLOW}Please run the system dependencies script first:${NC}"
    echo -e "${GREEN}  sudo ./install-system-deps-ubuntu.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✓ All system dependencies found${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 1/9: Installing Rust ${RUST_VERSION}${NC}"
echo -e "${BLUE}========================================${NC}"
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
    if command -v rustc &> /dev/null; then
        CURRENT_RUST=$(rustc --version | awk '{print $2}')
        echo -e "${YELLOW}Rust already installed: $CURRENT_RUST${NC}"
        if [[ "$CURRENT_RUST" != "$RUST_VERSION"* ]]; then
            echo -e "${YELLOW}Installing Rust ${RUST_VERSION}...${NC}"
            rustup toolchain install ${RUST_VERSION}
            rustup default ${RUST_VERSION}
        fi
    fi
else
    echo -e "${YELLOW}Installing rustup and Rust ${RUST_VERSION}...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION}
    source "$HOME/.cargo/env"
fi
echo -e "${GREEN}✓ Rust installed: $(rustc --version)${NC}"

export PATH="$HOME/.cargo/bin:$PATH"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 2/9: Building fd-find, tree-sitter-cli, stylua${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}This may take 5-10 minutes...${NC}"

for tool in fd-find tree-sitter-cli stylua; do
    BINARY_NAME=$(echo $tool | sed 's/-cli//')
    if [ "$tool" = "fd-find" ]; then
        BINARY_NAME="fd"
    fi
    
    if command -v $BINARY_NAME &> /dev/null && [ "$BINARY_NAME" != "tree-sitter" ]; then
        echo -e "${GREEN}✓ $tool already installed${NC}"
    else
        echo -e "${YELLOW}Building $tool...${NC}"
        cargo install $tool --locked 2>&1 | tee "$LOG_DIR/cargo-$tool.log"
        echo -e "${GREEN}✓ $tool installed${NC}"
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 3/9: Building Neovim ${NEOVIM_TAG}${NC}"
echo -e "${BLUE}========================================${NC}"
if command -v "$LOCAL_BIN/nvim" &> /dev/null; then
    CURRENT_NVIM=$("$LOCAL_BIN/nvim" --version | head -n1)
    echo -e "${YELLOW}Neovim already installed: $CURRENT_NVIM${NC}"
    read -p "Rebuild Neovim? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ Skipping Neovim build${NC}"
    else
        REBUILD_NVIM=1
    fi
fi

if [ ! -f "$LOCAL_BIN/nvim" ] || [ "$REBUILD_NVIM" = "1" ]; then
    echo -e "${YELLOW}Building Neovim from source (this takes 5-10 minutes)...${NC}"
    cd "$BUILD_DIR"
    
    if [ -d "neovim" ]; then
        rm -rf neovim
    fi
    
    git clone --depth 1 --branch ${NEOVIM_TAG} https://github.com/neovim/neovim.git
    cd neovim
    
    echo -e "${YELLOW}Running make (parallel build with $(nproc) cores)...${NC}"
    make -j$(nproc) CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$LOCAL_DIR" 2>&1 | tee "$LOG_DIR/neovim-build.log"
    
    echo -e "${YELLOW}Installing to $LOCAL_DIR...${NC}"
    make install 2>&1 | tee -a "$LOG_DIR/neovim-install.log"
    
    cd ..
    rm -rf neovim
    
    echo -e "${GREEN}✓ Neovim installed: $("$LOCAL_BIN/nvim" --version | head -n1)${NC}"
else
    echo -e "${GREEN}✓ Using existing Neovim installation${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 4/9: Building lazygit ${LAZYGIT_TAG}${NC}"
echo -e "${BLUE}========================================${NC}"
if command -v "$LOCAL_BIN/lazygit" &> /dev/null; then
    echo -e "${YELLOW}lazygit already installed${NC}"
else
    echo -e "${YELLOW}Building lazygit from source...${NC}"
    cd "$BUILD_DIR"
    
    if [ -d "lazygit" ]; then
        rm -rf lazygit
    fi
    
    git clone --depth 1 --branch ${LAZYGIT_TAG} https://github.com/jesseduffield/lazygit.git
    cd lazygit
    
    echo -e "${YELLOW}Building with Go...${NC}"
    go build -o "$LOCAL_BIN/lazygit" 2>&1 | tee "$LOG_DIR/lazygit-build.log"
    
    cd ..
    rm -rf lazygit
    
    echo -e "${GREEN}✓ lazygit installed: $("$LOCAL_BIN/lazygit" --version)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 5/9: Installing ripgrep from apt${NC}"
echo -e "${BLUE}========================================${NC}"
if command -v rg &> /dev/null; then
    echo -e "${GREEN}✓ ripgrep already installed: $(rg --version | head -n1)${NC}"
else
    echo -e "${YELLOW}Installing ripgrep via apt...${NC}"
    sudo apt install -y ripgrep
    echo -e "${GREEN}✓ ripgrep installed: $(rg --version | head -n1)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 6/9: Installing fzf from apt${NC}"
echo -e "${BLUE}========================================${NC}"
if command -v fzf &> /dev/null; then
    echo -e "${GREEN}✓ fzf already installed: $(fzf --version)${NC}"
else
    echo -e "${YELLOW}Installing fzf via apt...${NC}"
    sudo apt install -y fzf
    echo -e "${GREEN}✓ fzf installed: $(fzf --version)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 7/9: Installing Node.js LTS via nvm${NC}"
echo -e "${BLUE}========================================${NC}"
if [ -d "$HOME/.nvm" ]; then
    echo -e "${YELLOW}nvm already installed${NC}"
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
else
    echo -e "${YELLOW}Installing nvm...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Installing Node.js LTS...${NC}"
    nvm install --lts
    nvm use --lts
fi
echo -e "${GREEN}✓ Node.js installed: $(node --version)${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 8/9: Installing OpenCode ${OPENCODE_VERSION}${NC}"
echo -e "${BLUE}========================================${NC}"
if [ -f "$HOME/.opencode/bin/opencode" ]; then
    echo -e "${YELLOW}OpenCode already installed${NC}"
else
    echo -e "${YELLOW}Installing OpenCode...${NC}"
    curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION}
    echo -e "${GREEN}✓ OpenCode installed${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 9/9: Setting up LazyVim${NC}"
echo -e "${BLUE}========================================${NC}"
if [ -d "$HOME/.config/nvim" ]; then
    echo -e "${YELLOW}Neovim config already exists at ~/.config/nvim${NC}"
    read -p "Backup and replace with LazyVim starter? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_DIR="$HOME/.config/nvim.backup.$(date +%Y%m%d-%H%M%S)"
        echo -e "${YELLOW}Backing up to $BACKUP_DIR${NC}"
        mv "$HOME/.config/nvim" "$BACKUP_DIR"
        git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
        rm -rf "$HOME/.config/nvim/.git"
        echo -e "${GREEN}✓ LazyVim starter installed${NC}"
    else
        echo -e "${YELLOW}Keeping existing Neovim configuration${NC}"
    fi
else
    echo -e "${YELLOW}Installing LazyVim starter...${NC}"
    git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
    echo -e "${GREEN}✓ LazyVim starter installed${NC}"
fi

echo ""
echo -e "${YELLOW}Installing Python packages for Neovim...${NC}"
pip3 install --user neovim pynvim 2>&1 | tee "$LOG_DIR/python-packages.log"
echo -e "${GREEN}✓ Python packages installed${NC}"

echo ""
echo -e "${YELLOW}Generating environment setup file...${NC}"
ENV_FILE="$HOME/.vim-starter-env"

cat > "$ENV_FILE" << 'ENVEOF'
# vim-starter environment setup
# Source this file in your ~/.bashrc or ~/.bash_profile:
#   echo 'source ~/.vim-starter-env' >> ~/.bashrc

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export MANPATH="$HOME/.local/share/man:$MANPATH"
ENVEOF

echo -e "${GREEN}✓ Environment file created: $ENV_FILE${NC}"

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${YELLOW}Installed tools:${NC}"
echo -e "  • Neovim ${NEOVIM_TAG} → $LOCAL_BIN/nvim"
echo -e "  • lazygit ${LAZYGIT_TAG} → $LOCAL_BIN/lazygit"
echo -e "  • ripgrep → system package"
echo -e "  • fzf → system package"
echo -e "  • fd-find → $HOME/.cargo/bin/fd"
echo -e "  • tree-sitter-cli → $HOME/.cargo/bin/tree-sitter"
echo -e "  • stylua → $HOME/.cargo/bin/stylua"
echo -e "  • OpenCode ${OPENCODE_VERSION} → $HOME/.opencode/bin/opencode"
echo -e "  • Node.js LTS → via nvm"
echo -e "  • LazyVim starter → ~/.config/nvim"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Add environment to your shell:"
echo -e "   ${GREEN}echo 'source ~/.vim-starter-env' >> ~/.bashrc${NC}"
echo -e ""
echo -e "2. Reload your shell:"
echo -e "   ${GREEN}source ~/.bashrc${NC}"
echo -e "   ${YELLOW}OR${NC}"
echo -e "   ${GREEN}source ~/.vim-starter-env${NC} ${YELLOW}(for this session only)${NC}"
echo -e ""
echo -e "3. Start Neovim (LazyVim will auto-install plugins):"
echo -e "   ${GREEN}nvim${NC}"
echo -e ""
echo -e "4. Configure OpenCode (run once):"
echo -e "   ${GREEN}opencode${NC}"
echo -e "   Then run ${GREEN}/connect${NC} and follow the prompts"
echo -e ""
echo -e "${BLUE}Build logs saved to: $LOG_DIR${NC}"
echo -e "${BLUE}To uninstall: Remove ~/.local/bin/{nvim,lazygit}, ~/.cargo, ~/.nvm, ~/.opencode, ~/.config/nvim${NC}"
echo ""
