# Apex Remote LLM
One-liner setup for running Ollama on CMKL University's Apex GPU cluster and reaching it remotely over Tailscale.

## What it does
- Installs Ollama and starts the server
- Installs and authenticates Tailscale, then exposes port `11434` on your tailnet

## Usage
Run directly from GitHub (no download needed):
```bash
curl -fsSL https://raw.githubusercontent.com/EtienneMueller/apex-remote-llm/main/install.sh | bash
```

During the run, Tailscale will print a login URL: open it in a browser to authenticate the machine.

## Install Models
You can install any [Ollama model](https://ollama.com/library) (as long as it fits into the 40GB VRAM of Apex' A100 GPUs), e.g.:
```bash
ollama pull qwen3.6:35b-a3b
```

Ollama defaults to small context windows, to create your own version with 256K context run:
```bash
ollama show qwen3.6:35b-a3b --modelfile > Modelfile
grep -v '^PARAMETER num_ctx' Modelfile > Modelfile.tmp && mv Modelfile.tmp Modelfile
echo 'PARAMETER num_ctx 262144' >> Modelfile
ollama create qwen3.6-35b-a3b-256k -f Modelfile
```

## On your local machine

(Tested with Mac)

```bash
brew install --cask tailscale
curl http://<tailscale-ip>:11434/api/tags
```

Get your box's Tailscale IP from the script's output, or with `tailscale ip -4` on the cluster machine.

To get it to work inside the OpenCode coding harness add the following to `~/.config/opencode.jsonc`:
```zsh
"apex": {
  "npm": "@ai-sdk/openai-compatible",
  "name": "Apex",
  "options": {
	"baseURL": "http://100.x.x.x:11434/v1"
  },
  "models": {
	"qwen3.6-35b-a3b-256k": {
	  "name": "Qwen3.6 35B A3B (256K ctx)"
	}
  }
}
```
