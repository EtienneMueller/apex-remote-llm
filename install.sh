#!/usr/bin/env bash
set -euo pipefail


echo "==> Installing Ollama + Tailscale..."

# --- Ollama --------------------------------------------------------------
if ! command -v ollama &>/dev/null; then
    echo "==> Downloading Ollama..."
    curl -L -o ~/ollama.tar.zst \
        "https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64.tar.zst"
    ls -lh ~/ollama.tar.zst

    pip3 install --user zstandard
    python3 -c "
import zstandard as zstd
with open('$HOME/ollama.tar.zst', 'rb') as ifh, open('$HOME/ollama.tar', 'wb') as ofh:
    dctx = zstd.ZstdDecompressor()
    dctx.copy_stream(ifh, ofh)
"

    mkdir -p ~/ollama-install
    tar -xf ~/ollama.tar -C ~/ollama-install
    ls ~/ollama-install

    export PATH="$HOME/ollama-install/bin:$PATH"
    LINE='export PATH=$HOME/ollama-install/bin:$PATH'
    grep -qxF "$LINE" ~/.bashrc || echo "$LINE" >> ~/.bashrc
fi

# --- Start the Ollama server ---------------------------------------------
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "==> Starting Ollama server..."
    OLLAMA_HOST=0.0.0.0:11434 OLLAMA_KEEP_ALIVE=24h nohup ollama serve > ~/ollama.log 2>&1 &
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
echo "   ollama pull qwen3.6:35b-a3b"
echo ""
echo "To create a 256K context variant:"
echo "   ollama show qwen3.6:35b-a3b --modelfile > Modelfile"
echo "   cat Modelfile"
echo "   echo 'PARAMETER num_ctx 262144' >> Modelfile"
echo "   ollama create qwen3.6-35b-a3b-256k -f Modelfile"
echo "==============================================================="