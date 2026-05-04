ARG UBUNTU_VERSION="latest"
from ubuntu:${UBUNTU_VERSION}

ARG RUST_VERSION="1.95"
ARG NEOVIM_TAG="v0.12.2"
ARG LAZYGIT_TAG="v0.61.1"

# Install packages
RUN apt update -y && \
    apt install -y git fzf ripgrep curl npm wget clang golang cmake && \
    apt clean

# Install fd-find
RUN npm install -g fd-find

# Install rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . ~/.cargo/env $$ \
    rustup toolchain install ${RUST_VERSION} && \
    rustup default ${RUST_VERSION}

ENV PATH="/root/.cargo/bin:${PATH}"

# Install tree-sitter
RUN cargo install --locked tree-sitter-cli

# Install neovim
RUN git clone https://github.com/neovim/neovim.git && \
    cd neovim && \
    git checkout ${NEOVIM_TAG} && \
    make CMAKE_BUILD_TYPE=Release && \
    make install && \
    cd ../ && \
    rm -rf neovim

# Install lazygit
RUN git clone https://github.com/jesseduffield/lazygit.git && \
    cd lazygit && \
    git checkout ${LAZYGIT_TAG} && \
    go install && \
    cd ../ && \
    rm -rf lazygit && \
    git clone https://github.com/LazyVim/starter ~/.config/nvim && \
    rm -rf ~/.config/nvim/.git

# Add lazygit to path
ENV PATH=$PATH:/root/go/bin

