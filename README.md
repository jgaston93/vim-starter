# vim-starter

A reproducible Neovim / LazyVim development environment with the C/C++,
Rust, and Python toolchains pre-wired. Ships as both a parameterized
Dockerfile and a set of distro-detecting install scripts that drop your
editor into `$HOME` on a bare-metal workstation.

The same scripts power the Docker image and the local install, so any
Ubuntu / Debian / RHEL / Rocky / Alma / UBI / Fedora host (and Docker
images built on those bases) ends up with an identical user-facing tool
set.

---

## What gets installed

### System packages (`install-build-deps.sh`, root)

Compilers and core build tooling for C/C++, plus everything Neovim needs
to compile from source.

| Category    | Tools                                                                |
| ----------- | -------------------------------------------------------------------- |
| C/C++       | `gcc`, `g++`, `clang`, `clangd`, `clang-format`, `clang-tidy`, `lldb`, `gdb` |
| Build       | `make`, `cmake`, `ninja`, `pkg-config`, `autoconf`, `automake`, `libtool`, `gettext`, `bear` |
| Python      | `python3`, `pip`, dev headers (`python3-dev` / `python3-devel`)      |
| Go          | `golang` (used to build `lazygit`)                                   |
| Utilities   | `git`, `curl`, `wget`, `tar`, `gzip`, `xz`, `unzip`, `xclip`         |
| Locale      | `en_US.UTF-8` generated and set as default                           |
| Repos added | EPEL on RHEL/CentOS/Rocky/Alma 8 & 9 (Fedora skips it)               |

`bear` is included so Make-based C/C++ projects can produce
`compile_commands.json` for clangd via `bear -- make`.

### User tools (`install-user-tools.sh`, your user → `$HOME`)

Everything lands under `$HOME/.local`, `$HOME/.cargo`, `$HOME/.nvm`,
`$HOME/.opencode`. No system-wide writes.

| Tool                              | Version pin       | Source                       |
| --------------------------------- | ----------------- | ---------------------------- |
| Neovim                            | `NEOVIM_TAG`      | built from source            |
| lazygit                           | `LAZYGIT_TAG`     | `go install ...@TAG`         |
| Rust + cargo                      | `RUST_VERSION`    | `rustup` default toolchain   |
| `tree-sitter-cli`, `stylua`, `fd` | latest crates     | `cargo install --locked`     |
| ripgrep                           | `RIPGREP_VERSION` | pre-built binary             |
| fzf                               | `FZF_VERSION`     | pre-built binary             |
| Node.js LTS                       | `NODE_LTS_MAJOR`  | `nvm`                        |
| neovim npm provider               | latest            | `npm install -g neovim`      |
| pynvim, neovim, jinja2, ruff, black | latest          | `pip install --user`         |
| OpenCode                          | `OPENCODE_VERSION`| official install script      |

A shell init file is written to
`~/.local/share/vim-starter/env.sh`. Source it from your `~/.bashrc` or
`~/.zshrc` to put all of the above on `PATH`.

### LazyVim config (`install-lazyvim-config.sh`)

Clones the [LazyVim starter](https://github.com/LazyVim/starter) into
`~/.config/nvim`. If a `nvim/` directory exists alongside the script
(i.e. you ship a personal config in this repo), its contents are copied
on top of the starter — so you can keep upstream files and override only
what you customise.

---

## Quick start

### Bare-metal install

```sh
git clone https://github.com/jgaston93/vim-starter.git
cd vim-starter

# Each stage individually:
sudo ./install.sh --system    # apt/dnf packages
     ./install.sh --user      # neovim, lazygit, rust, node, python, opencode → $HOME
     ./install.sh --config    # LazyVim → ~/.config/nvim

# …or the lot in one go (sudo is invoked internally for --system):
./install.sh --all

# Enable the tools in your current shell:
source ~/.local/share/vim-starter/env.sh

# Persist:
echo 'source ~/.local/share/vim-starter/env.sh' >> ~/.bashrc
```

Re-running any stage is safe — every step checks for the version it
expects and skips if already present.

### Docker

```sh
# Default: Ubuntu 24.04
docker build -t vim-starter:ubuntu .

# Other supported bases
docker build -t vim-starter:ubi8   --build-arg BASE_IMAGE=registry.access.redhat.com/ubi8/ubi .
docker build -t vim-starter:ubi9   --build-arg BASE_IMAGE=registry.access.redhat.com/ubi9/ubi .
docker build -t vim-starter:fedora --build-arg BASE_IMAGE=fedora:40 .
docker build -t vim-starter:debian --build-arg BASE_IMAGE=debian:12 .

# Run with your project mounted in
docker run --rm -it \
    -v "$(pwd)":/workspace \
    -v vim-starter-opencode:/root/.config/opencode \
    vim-starter:ubuntu
```

The image puts `/root/.local/bin`, `/root/.cargo/bin`, and
`/root/.opencode/bin` on `PATH` and sources `env.sh` from `/root/.bashrc`,
so interactive shells have everything ready.

---

## Reusing the toolchain in another dev image

Two patterns, depending on whether your other project already has its
own carefully-tuned base image.

### Pattern A — copy the prebuilt toolchain in (fast)

If you already have `vim-starter:latest` built, no rebuild is required:

```dockerfile
FROM your-project-base:latest

COPY --from=vim-starter:latest /root/.local       /root/.local
COPY --from=vim-starter:latest /root/.cargo       /root/.cargo
COPY --from=vim-starter:latest /root/.nvm         /root/.nvm
COPY --from=vim-starter:latest /root/.opencode    /root/.opencode
COPY --from=vim-starter:latest /root/.config/nvim /root/.config/nvim

ENV PATH=/root/.local/bin:/root/.cargo/bin:/root/.opencode/bin:$PATH
RUN echo 'source /root/.local/share/vim-starter/env.sh' >> /root/.bashrc
```

Bakes the editor in for the cost of a `COPY`. Works as long as your base
image has compatible glibc (any modern Ubuntu/Debian/RHEL release).

### Pattern B — re-run the installers (works on any supported base)

Slower because Neovim recompiles, but doesn't require a pre-built
`vim-starter` image:

```dockerfile
FROM your-project-base:latest

COPY versions.env \
     install-build-deps.sh \
     install-user-tools.sh \
     install-lazyvim-config.sh \
     /tmp/vs/

RUN chmod +x /tmp/vs/*.sh && \
    /tmp/vs/install-build-deps.sh && \
    /tmp/vs/install-user-tools.sh && \
    /tmp/vs/install-lazyvim-config.sh && \
    rm -rf /tmp/vs

ENV PATH=/root/.local/bin:/root/.cargo/bin:/root/.opencode/bin:$PATH
RUN echo 'source /root/.local/share/vim-starter/env.sh' >> /root/.bashrc
```

Use this when your base image is something `vim-starter` doesn't build
on top of directly (a custom RHEL UBI image with extra layers, an Alpine
derivative with glibc shimmed in, etc.) but is part of one of the
supported distro families.

---

## Repository layout

```
vim-starter/
├── versions.env                  one place to bump every pinned tool
├── install.sh                    orchestrator: --system | --user | --config | --all
├── install-build-deps.sh         root: detects distro, installs system packages
├── install-user-tools.sh         user: installs everything to $HOME
├── install-lazyvim-config.sh     clones LazyVim starter (+ optional ./nvim/ overlay)
├── Dockerfile                    single image, parameterized by --build-arg BASE_IMAGE
├── nvim/                         (optional) personal LazyVim overrides — overlaid on the starter
└── README.md
```

### Files in detail

`versions.env` — `KEY=VALUE` shell-sourceable file. The single source of
truth for every pinned version. `install-user-tools.sh` sources it
directly; the Dockerfile relies on the same file being present in the
build context.

`install-build-deps.sh` — distro-detecting via `/etc/os-release`,
dispatches to either the Debian/Ubuntu branch (`apt-get`) or the
RHEL/Fedora branch (`dnf`). Adds EPEL on RHEL/CentOS/Rocky/Alma 8 and
9 to pick up `ninja-build` and `bear`. Must run as root.

`install-user-tools.sh` — runs as your user (or as root inside a
container — it detects `/.dockerenv` and allows UID 0 there only).
Idempotent: every step checks the installed version and skips if it
already matches. Builds Neovim with the two-step `cmake.deps` ➝ main
build pattern. Architectures supported: `x86_64`, `aarch64`.

`install-lazyvim-config.sh` — defaults to refusing to overwrite an
existing `~/.config/nvim`; pass `--force` to back it up to
`~/.config/nvim.backup.<timestamp>` and replace. If a `nvim/` directory
exists alongside the script and contains any files other than
`.gitkeep`, those files are copied on top of the starter.

`install.sh` — thin wrapper that calls the three scripts above. Use it
for tab-completion ergonomics and `--all`; the underlying scripts work
fine called directly.

`Dockerfile` — single image. `ARG BASE_IMAGE` picks the base; the
`COPY` + three-`RUN` body is identical across distros because the
install scripts handle the differences.

---

## Bumping versions

Edit `versions.env` and rebuild:

```sh
# Example: try Neovim nightly
sed -i 's/^NEOVIM_TAG=.*/NEOVIM_TAG=nightly/' versions.env

# Local: re-run the user stage (idempotent, will rebuild only if pin changed)
./install.sh --user

# Docker: just rebuild the image
docker build -t vim-starter:ubuntu .
```

Nothing else needs touching — every script and the Dockerfile pulls its
versions from `versions.env`.

---

## Notes for C/C++ / CMake / Make work

`clangd`, `clang-format`, `clang-tidy`, and `gdb` are installed at the
system level on every supported distro, so they're on `PATH` and ready
for LSP / formatter / debugger configuration in Neovim without leaning
on Mason.

For LazyVim, enable the bundled language extras for a first-class
experience:

```lua
-- ~/.config/nvim/lua/config/lazy.lua
{ import = "lazyvim.plugins.extras.lang.clangd" },
{ import = "lazyvim.plugins.extras.lang.cmake"  },
{ import = "lazyvim.plugins.extras.lang.rust"   },
{ import = "lazyvim.plugins.extras.lang.python" },
```

For Make projects that don't emit `compile_commands.json` natively,
generate one with `bear` (installed by `install-build-deps.sh`):

```sh
bear -- make
```

CMake projects can produce one directly:

```sh
cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

clangd picks up either form automatically from the project root.

---

## Uninstall

```sh
rm -rf ~/.local/bin/{nvim,lazygit,rg,fzf,fd,tree-sitter,stylua} \
       ~/.local/share/{vim-starter,nvim} \
       ~/.local/src/vim-starter-build \
       ~/.cargo ~/.rustup ~/.nvm ~/.opencode \
       ~/.config/nvim
```

System packages installed by `install-build-deps.sh` are left alone —
remove via your package manager if you don't want them.
