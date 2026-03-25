FROM registry.access.redhat.com/ubi8/ubi:latest

RUN dnf update -y && \
    dnf install -y \
        curl \
        wget \
        python3 \
        python3-pip \
        gcc \
        gcc-c++ \
        make \
        git \
        cmake \
        lua \
        lua-devel \
        unzip \
        findutils \
        tar \
        gzip && \
    dnf clean all

# install ripgrep (not available in default UBI repos)
RUN curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz && \
    tar xzf ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz && \
    cp ripgrep-14.1.1-x86_64-unknown-linux-musl/rg /usr/local/bin/ && \
    rm -rf ripgrep-14.1.1-x86_64-unknown-linux-musl*

# install neovim python support
RUN pip3 install pynvim

# install nvim
RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz && \
    rm -rf /opt/nvim-linux-x86_64 && \
    tar -C /opt -xzf nvim-linux-x86_64.tar.gz && \
    rm nvim-linux-x86_64.tar.gz
ENV PATH="$PATH:/opt/nvim-linux-x86_64/bin"

# install luarocks
RUN wget https://luarocks.org/releases/luarocks-3.13.0.tar.gz && \
    tar zxpf luarocks-3.13.0.tar.gz && \
    cd luarocks-3.13.0 && \
    ./configure && make && make install && \
    cd ../ && \
    rm -rf luarocks-3.13.0 luarocks-3.13.0.tar.gz

# install lazy.nvim configuration
COPY init.lua /root/.config/nvim/
COPY lua/ /root/.config/nvm/

WORKDIR /workspace
