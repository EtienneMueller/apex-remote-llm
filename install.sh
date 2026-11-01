#!/usr/bin/env bash
set -euo pipefail

# Pin Ollama to v0.6.2 — last version with CUDA 11 fallback.
# Required for NVIDIA driver 535, which is below the 550+ minimum
# enforced by Ollama v0.7 and later.
OLLAMA_VERSION="v0.6.2"

echo "==> Installing Ollama ${OLLAMA_VERSION} + Tailscale..."

# --- Ollama --------------------------------------------------------------
if ! command -v ollama &>/dev/null; then
    echo "==> Downloading Ollama ${OLLAMA_VERSION}..."
    
    mkdir -p ~/ollama-install/bin

    # v0.6.x ships as a single binary + optional lib tarball
    curl -L -o ~/ollama-install/bin/ollama \
        "https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64"
    chmod +x ~/ollama-install/bin/ollama
 
    # Download bundled CUDA/runtime libs (needed for GPU support)
    if [ ! -d ~/ollama-install/lib ]; then
        echo "==> Downloading Ollama libs..."
        curl -L -o ~/ollama-libs.tgz \
            "https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64-libs.tgz" \
            || echo "WARN: libs tarball not found — GPU may still work if libs are bundled in the binary."
        if [ -f ~/ollama-libs.tgz ]; then
            mkdir -p ~/ollama-install/lib/ollama
            tar -xzf ~/ollama-libs.tgz -C ~/ollama-install/lib/ollama
            rm ~/ollama-libs.tgz
        fi
    fi
 
    export PATH="$HOME/ollama-install/bin:$PATH"
    LINE='export PATH=$HOME/ollama-install/bin:$PATH'
    touch ~/.bashrc
    grep -qxF "$LINE" ~/.bashrc || echo "$LINE" >> ~/.bashrc
 
    # Point Ollama at bundled libs if they exist
    if [ -d ~/ollama-install/lib/ollama ]; then
        export LD_LIBRARY_PATH="${HOME}/ollama-install/lib/ollama:${LD_LIBRARY_PATH:-}"
        LIBLINE='export LD_LIBRARY_PATH=$HOME/ollama-install/lib/ollama:${LD_LIBRARY_PATH:-}'
        grep -qxF "$LIBLINE" ~/.bashrc || echo "$LIBLINE" >> ~/.bashrc
    fi
fi


# --- Start the Ollama server ---------------------------------------------
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "==> Starting Ollama server..."
    OLLAMA_HOST=0.0.0.0:11434 OLLAMA_KEEP_ALIVE=-1 nohup ollama serve > ~/ollama.log 2>&1 &
    disown
    sleep 2
else
    echo "==> Ollama server already running, skipping."
fi

# --- Tailscale -------------------------------------------------------------
if [ ! -f ~/tailscale-install/tailscale ]; then
    echo "==> Downloading Tailscale..."
    curl -L -o ~/tailscale.tgz https://pkgs.tailscale.com/stable/tailscale_latest_amd64.tgz
    ls -lh ~/tailscale.tgz
    mkdir -p ~/tailscale-install
    tar -xzf ~/tailscale.tgz -C ~/tailscale-install --strip-components=1
    ls ~/tailscale-install

    export PATH="$HOME/tailscale-install:$PATH"
    LINE='export PATH=$HOME/tailscale-install:$PATH'
    grep -qxF "$LINE" ~/.bashrc || echo "$LINE" >> ~/.bashrc
fi

mkdir -p ~/.tailscale-state
TS_SOCK="$HOME/.tailscale-state/tailscaled.sock"

if ! pgrep -f "tailscaled" > /dev/null; then
    echo "==> Starting tailscaled..."
    nohup ~/tailscale-install/tailscaled \
        --tun=userspace-networking \
        --state="$HOME/.tailscale-state/tailscaled.state" \
        --socket="$TS_SOCK" \
        > ~/tailscaled.log 2>&1 &
    disown
    sleep 2
fi

echo "==> Authenticating with Tailscale (open the printed URL in a browser)..."
~/tailscale-install/tailscale --socket="$TS_SOCK" up

TS_IP="$(~/tailscale-install/tailscale --socket="$TS_SOCK" ip -4)"
echo "==> Tailscale IP: $TS_IP"

~/tailscale-install/tailscale --socket="$TS_SOCK" serve --bg --tcp=11434 tcp://localhost:11434
~/tailscale-install/tailscale --socket="$TS_SOCK" serve status

echo ""
echo "==============================================================="
echo " Setup complete."
echo " Tailscale IP: $TS_IP"
echo ""
echo " Next: pull a model, e.g.:"
echo "   ollama pull qwen3.6"
echo ""
echo "==============================================================="

exec bash -i
