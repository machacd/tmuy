FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    tmux \
    git \
    curl \
    vim \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and Claude Code
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

CMD ["bash"]