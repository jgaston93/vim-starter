# Single parameterized Dockerfile for the vim-starter dev environment.
#
# Pick any supported base image with --build-arg BASE_IMAGE.  The install
# scripts detect the distro internally, so the same Dockerfile produces a
# working image on Ubuntu, Debian, RHEL/UBI, Rocky/Alma, or Fedora.
#
# Examples:
#   docker build -t vim-starter:ubuntu --build-arg BASE_IMAGE=ubuntu:24.04 .
#   docker build -t vim-starter:ubi8   --build-arg BASE_IMAGE=registry.access.redhat.com/ubi8/ubi .
#   docker build -t vim-starter:ubi9   --build-arg BASE_IMAGE=registry.access.redhat.com/ubi9/ubi .
#   docker build -t vim-starter:fedora --build-arg BASE_IMAGE=fedora:40 .
#
# To layer this onto an existing project dev image, you have two clean options:
#
#   1.  Copy the toolchain artifacts in (fastest, no rebuild):
#         FROM your-project-base:latest
#         COPY --from=vim-starter:latest /root/.local  /root/.local
#         COPY --from=vim-starter:latest /root/.cargo  /root/.cargo
#         COPY --from=vim-starter:latest /root/.nvm    /root/.nvm
#         COPY --from=vim-starter:latest /root/.opencode /root/.opencode
#         COPY --from=vim-starter:latest /root/.config/nvim /root/.config/nvim
#         ENV PATH=/root/.local/bin:/root/.cargo/bin:/root/.opencode/bin:$PATH
#         RUN echo 'source /root/.local/share/vim-starter/env.sh' >> /root/.bashrc
#
#   2.  Re-run the install scripts on top of your base (works against any
#       supported distro, slower because it rebuilds neovim from source):
#         FROM your-project-base:latest
#         COPY versions.env install-build-deps.sh install-user-tools.sh \
#              install-lazyvim-config.sh /tmp/vim-starter/
#         RUN chmod +x /tmp/vim-starter/*.sh && \
#             /tmp/vim-starter/install-build-deps.sh && \
#             /tmp/vim-starter/install-user-tools.sh && \
#             /tmp/vim-starter/install-lazyvim-config.sh && \
#             rm -rf /tmp/vim-starter

ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="vim-starter"
LABEL org.opencontainers.image.description="Neovim/LazyVim dev environment with C/C++/Rust/Python(Jinja2) toolchains"
LABEL org.opencontainers.image.source="https://github.com/jgaston93/vim-starter"

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# Copy installers + version pins.  Keep these in the same directory so
# install-user-tools.sh can source versions.env from $SCRIPT_DIR.
COPY versions.env \
     install-build-deps.sh \
     install-user-tools.sh \
     install-lazyvim-config.sh \
     /tmp/vim-starter/

RUN chmod +x /tmp/vim-starter/*.sh && \
    /tmp/vim-starter/install-build-deps.sh && \
    /tmp/vim-starter/install-user-tools.sh && \
    /tmp/vim-starter/install-lazyvim-config.sh && \
    rm -rf /tmp/vim-starter /root/.local/src/vim-starter-build

# Put user-installed binaries on PATH for non-login shells too.
ENV PATH="/root/.local/bin:/root/.cargo/bin:/root/.opencode/bin:${PATH}"

# Login shells (and `docker run -it ... bash -l`) source the env file.
RUN echo 'source /root/.local/share/vim-starter/env.sh' >> /root/.bashrc

WORKDIR /workspace
VOLUME ["/workspace", "/root/.config/opencode"]

CMD ["/bin/bash"]
