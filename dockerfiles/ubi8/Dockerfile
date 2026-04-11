FROM registry.access.redhat.com/ubi8/ubi:latest

RUN dnf update -y && \
    dnf install -y \
        curl \
        wget \
        python3.12 \
        python3.12-pip \
        python3.12-devel \
        gcc \
        gcc-c++ \
        make \
        git \
        cmake \
        unzip \
        findutils \
        tar \
        gzip \
        ncurses-devel \
        libtool \
        autoconf \
        automake \
        golang \
        clang-tools-extra \
        pkgconfig && \
    dnf clean all

# Install Lua from source (since lua-devel is not available in UBI8)
RUN wget https://www.lua.org/ftp/lua-5.4.6.tar.gz && \
    tar zxf lua-5.4.6.tar.gz && \
    cd lua-5.4.6 && \
    make -j64 linux && \
    make install && \
    cd .. && \
    rm -rf lua-5.4.6 lua-5.4.6.tar.gz

# install ripgrep (not available in default UBI repos)
RUN curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz && \
    tar xzf ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz && \
    cp ripgrep-14.1.1-x86_64-unknown-linux-musl/rg /usr/local/bin/ && \
    rm -rf ripgrep-14.1.1-x86_64-unknown-linux-musl*

# install neovim python support
RUN pip3 install pynvim

# Build and install neovim from source (compatible with UBI8 glibc)
RUN git clone https://github.com/neovim/neovim.git --depth 1 --branch stable && \
    cd neovim && \
    make -j64 CMAKE_BUILD_TYPE=Release && \
    make install && \
    cd .. && \
    rm -rf neovim

# install luarocks
RUN wget https://luarocks.org/releases/luarocks-3.13.0.tar.gz && \
    tar zxpf luarocks-3.13.0.tar.gz && \
    cd luarocks-3.13.0 && \
    ./configure && make -j64 && make install && \
    cd ../ && \
    rm -rf luarocks-3.13.0 luarocks-3.13.0.tar.gz

# install lazygit
RUN git clone https://github.com/jesseduffield/lazygit.git && \
    cd lazygit && \
    go install && \
    cd ../ && \
    rm -rf lazygit && \
    ln -s /root/go/bin/lazygit /usr/local/bin/lazygit

# install lazy.nvim configuration
COPY init.lua /root/.config/nvim/
COPY lua/ /root/.config/nvim/lua/

WORKDIR /workspace
