FROM ubuntu:24.04

RUN apt-get update && \
    apt-get -y install curl wget python3 build-essential git cmake lua5.1 liblua5.1-dev unzip ripgrep golang-go clangd clang-format && \
    apt-get clean

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:$PATH"
RUN rustup component add rust-analyzer

# install nvim
RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz && \
    rm -rf /opt/nvim-linux-x86_64 && \
    tar -C /opt -xzf nvim-linux-x86_64.tar.gz
ENV PATH="$PATH:/opt/nvim-linux-x86_64/bin"

# install luarocks
RUN wget https://luarocks.org/releases/luarocks-3.13.0.tar.gz && \
    tar zxpf luarocks-3.13.0.tar.gz && \
    cd luarocks-3.13.0 && \
    ./configure && make && make install && \
    cd ../ && \
    rm -rf luarocks-3.13.0

# install lazygit
RUN git clone https://github.com/jesseduffield/lazygit.git && \
    cd lazygit && \
    go install && \
    cd ../ && \
    rm -rf lazygit && \
    ln -s /root/go/bin/lazygit /usr/local/bin/lazygit
ENV PATH="$PATH:/root/go/bin"

# install lazy.nvim configuration
COPY init.lua /root/.config/nvim/
COPY lua/ /root/.config/nvim/lua/

WORKDIR /workspace
