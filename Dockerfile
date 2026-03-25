FROM ubuntu:24.04

RUN apt-get update && \
    apt-get -y install curl wget python3 python3-neovim build-essential git cmake lua5.1 liblua5.1-dev unzip ripgrep && \
    apt-get clean

# install nvim
RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz && \
    rm -rf /opt/nvim-linux-x86_64 && \
    tar -C /opt -xzf nvim-linux-x86_64.tar.gz
ENV PATH="$PATH:/opt/nvim-linux-x86_64/bin"

#install luarocks
RUN wget https://luarocks.org/releases/luarocks-3.13.0.tar.gz && \
    tar zxpf luarocks-3.13.0.tar.gz && \
    cd luarocks-3.13.0 && \
    ./configure && make && sudo make install && \
    cd ../ && \
    rm -rf luarocks-3.13.0

WORKDIR /workspace
