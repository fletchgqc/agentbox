# AgentBox - Simplified multi-language development environment for Claude
FROM debian:bookworm

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install system dependencies and essential tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Essential tools
        ca-certificates curl wget gnupg lsb-release sudo \
        # Development tools
        git vim nano tmux htop tree \
        # Build tools
        build-essential gcc g++ make cmake pkg-config \
        # Shell and utilities
        zsh bash-completion locales \
        # Network tools
        openssh-client netcat-openbsd socat dnsutils iputils-ping \
        # Archive tools
        zip unzip tar gzip bzip2 xz-utils \
        # JSON/YAML tools
        jq yq \
        # Process management
        procps psmisc \
        # Python build dependencies
        python3-dev python3-pip python3-venv \
        libssl-dev libffi-dev \
        # Java dependencies
        default-jdk maven gradle \
        # Search tools
        ripgrep fd-find && \
    # Setup locale
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod 644 /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y gh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install GitLab CLI
RUN ARCH=$(dpkg --print-architecture) && \
    GLAB_VERSION=$(curl -sL "https://gitlab.com/api/v4/projects/34675721/releases/permalink/latest" | sed -n 's/.*"tag_name":"v\?\([^"]*\)".*/\1/p') && \
    echo "Installing glab version ${GLAB_VERSION} for ${ARCH}" && \
    curl -fsSL -o /tmp/glab.deb \
        "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${ARCH}.deb" && \
    dpkg -i /tmp/glab.deb || apt-get install -f -y && \
    rm /tmp/glab.deb && \
    glab --version

# Create non-root user
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USERNAME=claude

RUN groupadd -g ${GROUP_ID} ${USERNAME} || true && \
    useradd -m -u ${USER_ID} -g ${GROUP_ID} -s /bin/zsh ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# Switch to user for language installations
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Install uv for Python package management
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# Install Node.js via NVM
ENV NVM_DIR="/home/${USERNAME}/.nvm"
RUN NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/') && \
    echo "Installing nvm version ${NVM_VERSION}" && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install --lts && \
    nvm alias default node && \
    nvm use default

# Setup NVM in bash only (zsh will be set up after oh-my-zsh)
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc

# Install Node.js global packages
RUN bash -c "source $NVM_DIR/nvm.sh && \
    npm install -g \
        typescript \
        @types/node \
        ts-node \
        eslint \
        prettier \
        nodemon \
        yarn \
        pnpm \
        @anthropic-ai/claude-code && \
    # Verify Claude CLI installation
    which claude && claude --version"

# Install SDKMAN for Java toolchain management
RUN curl -s "https://get.sdkman.io?rcupdate=false" | bash && \
    echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.bashrc && \
    echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.zshrc && \
    bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && \
        sdk install java 21.0.8-tem && \
        sdk install gradle"

# Setup Python tools
RUN /home/${USERNAME}/.local/bin/uv tool install black && \
    /home/${USERNAME}/.local/bin/uv tool install ruff && \
    /home/${USERNAME}/.local/bin/uv tool install mypy && \
    /home/${USERNAME}/.local/bin/uv tool install pytest && \
    /home/${USERNAME}/.local/bin/uv tool install ipython && \
    /home/${USERNAME}/.local/bin/uv tool install poetry && \
    /home/${USERNAME}/.local/bin/uv tool install pipenv

# Install oh-my-zsh for better shell experience and setup NVM for zsh
RUN sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    sed -i 's/ZSH_THEME=".*"/ZSH_THEME="robbyrussell"/' ~/.zshrc && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.zshrc

# Add terminal size handling for better TTY support (from ClaudeBox)
RUN cat >> ~/.zshrc <<'EOF'

if [[ -n "$PS1" ]] && command -v stty >/dev/null; then
  function _update_size {
    local rows cols
    { stty size } 2>/dev/null | read rows cols
    ((rows)) && export LINES=$rows COLUMNS=$cols
  }
  TRAPWINCH() { _update_size }
  _update_size
fi
EOF

# Configure git
RUN git config --global init.defaultBranch main && \
    git config --global pull.rebase false

# Setup tmux configuration
RUN cat > ~/.tmux.conf <<'EOF'
# Enable mouse support
set -g mouse on

# Better colors
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"

# Increase history
set -g history-limit 50000

# Better window/pane management
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Reload config
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"

# Status bar
set -g status-bg black
set -g status-fg white
set -g status-left '#[fg=green]#H '
set -g status-right '#[fg=yellow]%Y-%m-%d %H:%M'
EOF

# Create workspace directory
RUN mkdir -p /home/${USERNAME}/workspace

# Switch back to root for entrypoint setup
USER root

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set working directory
WORKDIR /workspace

# Set the user for runtime
USER ${USERNAME}

# Entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/zsh"]