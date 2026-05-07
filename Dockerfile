ARG UBUNTU_VERSION="latest"
FROM ubuntu:${UBUNTU_VERSION}

ARG RUST_VERSION="1.95"
ARG NEOVIM_TAG="v0.12.2"
ARG LAZYGIT_TAG="v0.61.1"

# Install packages
# ninja-build, gettext, build-essential are required to build neovim from source
RUN apt-get update -y && \
    apt-get install -y \
        git curl wget \
        clang cmake ninja-build gettext build-essential \
        golang \
        npm \
        python3-pip \
        fzf ripgrep \
        unzip xclip locales && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install neovim npm provider
# (fd-find is installed via cargo below — native binary, no npm shim needed)
RUN npm install -g neovim

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . ~/.cargo/env && \
    rustup toolchain install ${RUST_VERSION} && \
    rustup default ${RUST_VERSION}

ENV PATH="/root/.cargo/bin:${PATH}"

# Install pynvim (Python provider for neovim)
RUN pip install pynvim --break-system-packages

# Install cargo tools: tree-sitter, stylua (conform formatter), fd (replaces npm fd-find shim)
RUN cargo install --locked tree-sitter-cli stylua fd-find

# Build and install neovim from source (two-step: deps first, then neovim)
# Step 1 builds luv and other bundled deps into neovim/.deps/usr.
# Step 2 finds them automatically via CMAKE_SOURCE_DIR/.deps/usr.
RUN git clone --depth=1 --branch ${NEOVIM_TAG} https://github.com/neovim/neovim.git && \
    cmake -S neovim/cmake.deps -B neovim/.deps -DCMAKE_BUILD_TYPE=Release -G Ninja && \
    cmake --build neovim/.deps --parallel $(nproc) && \
    cmake -S neovim -B neovim/build -DCMAKE_BUILD_TYPE=Release -G Ninja && \
    cmake --build neovim/build --parallel $(nproc) && \
    cmake --install neovim/build && \
    rm -rf neovim

# Install lazygit
# go install with an explicit @tag fetches and builds in one step — no manual clone needed.
# GOBIN points directly at /usr/local/bin so no extra PATH entry is required.
# Wipe the module cache afterwards to keep the image lean.
RUN GOBIN=/usr/local/bin go install github.com/jesseduffield/lazygit@${LAZYGIT_TAG} && \
    rm -rf /root/go

# Set up LazyVim starter config
RUN git clone --depth=1 https://github.com/LazyVim/starter ~/.config/nvim && \
    rm -rf ~/.config/nvim/.git
