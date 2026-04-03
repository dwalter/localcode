# localcode

Run LLMs fully locally on Apple Silicon via llama.cpp, with OpenCode as a coding agent. No cloud, no telemetry, no API keys.

Supports **Gemma 4** and **Qwen3.5** model families including Qwopus (Qwen3.5 fine-tuned on Claude 4.6 Opus reasoning). Benchmarked on a Mac Studio M3 Ultra (512GB).

---

## What's included

- **llama.cpp** built from source with Metal acceleration
- **run.sh** — one-command chat or server for any model variant
- **oc.sh** — OpenCode coding agent with auto-managed llama-server
- **TurboQuant+ KV cache compression** — reduces KV cache size at long context with minimal quality loss
- **TQ4_1S weight compression** — shrinks Gemma 4 31B from 30.4GB → 18.9GB at identical generation speed (experimental)

---

## Hardware requirements

| Model | Size on disk | Approx RAM needed |
|-------|-------------|-------------------|
| Qwen3.5-9B Q8 | 9.5G | ~12GB |
| Gemma 4 26B MoE Q4 | 15.7G | ~18GB |
| Qwen3.5-27B Q4 / Qwopus Q4 | 16.5–16.7G | ~20GB |
| Gemma 4 26B MoE Q8 | 25.0G | ~28GB |
| Qwen3.5-35B-A3B MoE Q4 | 21.4G | ~24GB |
| Gemma 4 31B TQ4_1S (compressed) | 18.9G | ~22GB |
| Gemma 4 31B Dense Q8 | 30.4G | ~34GB |

On Apple Silicon, RAM = unified memory. An M3 Max (96GB) or Ultra is ideal for 30B+ models. The Qwen3.5-35B-A3B MoE only activates ~3B parameters per token so it runs much faster than its 21GB size suggests.

---

## Prerequisites

- **macOS Sequoia** (14+) on Apple Silicon
- **Xcode** with Command Line Tools: `xcode-select --install`
  - If Sequoia complains: `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
- **Homebrew**: [brew.sh](https://brew.sh)
- **CMake**: `brew install cmake`
- **Python 3.11** (arm64): `brew install python@3.11`
- **Node.js** (for OpenCode): `brew install node`

---

## Setup

Clone this repo:

```bash
git clone https://github.com/dwalter/localcode.git ~/localcode
cd ~/localcode
```

> All commands below assume you're in `~/localcode`. Adjust if you clone elsewhere.

### 1. Build llama.cpp from source

The Homebrew stable build does not support Gemma 4. Must build from HEAD.

```bash
git clone --depth 1 https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(sysctl -n hw.logicalcpu) \
  --target llama-bench llama-cli llama-speculative
cd ..
```

### 2. Build llama-cpp-turboquant

This fork adds TurboQuant+ KV cache compression and `llama-server` (the API endpoint OpenCode connects to). Also required for TQ4_1S weight compression on Gemma 4 31B.

```bash
git clone https://github.com/TheTom/llama-cpp-turboquant.git
cd llama-cpp-turboquant
git checkout pr/tq4-weight-compression
cmake -B build -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(sysctl -n hw.logicalcpu) \
  --target llama-server llama-quantize llama-bench
cd ..
```

### 3. Python venv for Gemma model downloads

Gemma 4 is a gated model requiring a HuggingFace account. Qwen3.5 is Apache 2.0 and can be downloaded without login.

```bash
/opt/homebrew/bin/python3.11 -m venv venv
source venv/bin/activate
pip install -U pip huggingface_hub
```

### 4. Download models

**Gemma 4** (gated — accept license at [huggingface.co/google/gemma-4-27b-it](https://huggingface.co/google/gemma-4-27b-it) first, then `huggingface-cli login`):

```bash
source venv/bin/activate

# 26B MoE Q8 — recommended for coding agent (25GB, 82 tok/s)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/gemma-4-26B-A4B-it-GGUF', 'gemma-4-26B-A4B-it-Q8_0.gguf', local_dir='.')"

# 26B MoE Q4 — faster, smaller (15.7GB, 85 tok/s)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/gemma-4-26B-A4B-it-GGUF', 'gemma-4-26B-A4B-it-UD-Q4_K_M.gguf', local_dir='.')"

# 31B Dense Q8 — highest quality (30.4GB, 18 tok/s)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/gemma-4-31B-it-GGUF', 'gemma-4-31B-it-Q8_0.gguf', local_dir='.')"

# 31B Dense Q4 — good with speculative decoding (17.1GB, 28 tok/s)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/gemma-4-31B-it-GGUF', 'gemma-4-31B-it-Q4_K_M.gguf', local_dir='.')"

# E2B draft model — required for speculative decoding (5GB)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/gemma-4-E2B-it-GGUF', 'gemma-4-E2B-it-Q8_0.gguf', local_dir='.')"
```

**Qwen3.5** (Apache 2.0 — no login required):

```bash
source venv/bin/activate

# Qwen3.5-9B Q8 — fast small model (9.5GB, ~80 tok/s)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/Qwen3.5-9B-GGUF', 'Qwen3.5-9B-Q8_0.gguf', local_dir='.')"

# Qwen3.5-27B Q4 — strong 27B reasoning model (16.7GB, ~28 tok/s)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/Qwen3.5-27B-GGUF', 'Qwen3.5-27B-Q4_K_M.gguf', local_dir='.')"

# Qwen3.5-35B-A3B MoE Q4 — 35B total, ~3B active per token (21.4GB, very fast)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/Qwen3.5-35B-A3B-GGUF', 'Qwen3.5-35B-A3B-Q4_K_M.gguf', local_dir='.')"
```

**Qwopus v2** — Qwen3.5-27B fine-tuned on Claude 4.6 Opus reasoning trajectories. Better at coding and math reasoning than base Qwen3.5-27B. No login required.

```bash
source venv/bin/activate

python3 -c "
import os
from huggingface_hub import hf_hub_download
path = hf_hub_download('Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF', 'Qwen3.5-27B.Q4_K_M.gguf', local_dir='.')
os.rename(path, 'Qwen3.5-27B-Qwopus-v2-Q4_K_M.gguf')
"
```

---

## Chat

```bash
# Gemma 4
./run.sh              # 26B MoE Q8 (default, recommended)
./run.sh q4           # 26B MoE Q4
./run.sh 31b-q8       # 31B Dense Q8
./run.sh 31b-q4       # 31B Dense Q4
./run.sh 31b-tq4      # 31B TQ4_1S compressed
./run.sh 31b-spec-q8  # 31B Q8 + speculative decoding
./run.sh 31b-spec-q4  # 31B Q4 + speculative decoding

# Qwen3.5
./run.sh qwen-9b          # Qwen3.5-9B Q8
./run.sh qwen-27b         # Qwen3.5-27B Q4 (thinking off — faster, better for tasks)
./run.sh qwen-27b-think   # Qwen3.5-27B Q4 (thinking on — deeper reasoning)
./run.sh qwen-35b-moe     # Qwen3.5-35B-A3B MoE Q4
./run.sh qwopus           # Qwopus v2 27B Q4 (Opus-distilled reasoning)
```

### Qwen3.5 thinking mode

Qwen3.5 27B has a built-in "thinking" mode (chain-of-thought reasoning). For general tasks and the coding agent, thinking is disabled by default (`qwen-27b`) — it's faster and better for tool-calling. Use `qwen-27b-think` or `qwopus` when you want deep reasoning on hard problems.

---

## OpenCode coding agent

OpenCode is a fully local, autonomous coding agent. It edits files, runs shell commands, reads errors, and loops — no human approval required at each step. Zero telemetry.

### 1. Install OpenCode

```bash
npm install -g opencode-ai@latest
```

### 2. Configure OpenCode for llama-server

Create `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "llama.cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "gemma-4-26B-A4B-it-Q8_0.gguf": {
          "name": "Gemma 4 26B MoE Q8 (local)",
          "limit": { "context": 131072, "output": 32768 }
        },
        "gemma-4-31B-it-TQ4_1S-config-i.gguf": {
          "name": "Gemma 4 31B TQ4_1S (local)",
          "limit": { "context": 131072, "output": 32768 }
        },
        "Qwen3.5-27B-Q4_K_M.gguf": {
          "name": "Qwen3.5-27B Q4 (local)",
          "limit": { "context": 131072, "output": 32768 }
        },
        "Qwen3.5-35B-A3B-Q4_K_M.gguf": {
          "name": "Qwen3.5-35B-A3B MoE Q4 (local)",
          "limit": { "context": 131072, "output": 32768 }
        },
        "Qwen3.5-27B-Qwopus-v2-Q4_K_M.gguf": {
          "name": "Qwopus v2 27B Q4 (local)",
          "limit": { "context": 131072, "output": 32768 }
        }
      }
    }
  },
  "model": "llama.cpp/gemma-4-26B-A4B-it-Q8_0.gguf"
}
```

### 3. Add the shell wrapper to auto-manage the server

Add this to your `~/.zshrc` (or `~/.bashrc`):

```bash
# Disable opencode outbound calls — fully local
export OPENCODE_DISABLE_AUTOUPDATE=true
export OPENCODE_DISABLE_MODELS_FETCH=true

# Wrap opencode to auto-start/stop llama-server
opencode() { "$HOME/localcode/oc.sh" "$@"; }
```

Then reload: `source ~/.zshrc`

### 4. Use it

```bash
cd ~/your-project
opencode                              # Gemma 4 26B MoE Q8 (default)
LOCALCODE_MODEL=qwen-27b opencode    # Qwen3.5-27B Q4
LOCALCODE_MODEL=qwen-35b-moe opencode
LOCALCODE_MODEL=qwopus opencode
LOCALCODE_MODEL=gemma-31b opencode
```

`oc.sh` starts llama-server automatically, shares it across concurrent sessions, and shuts it down when the last session exits. All Qwen3.5 server modes automatically disable thinking mode for better tool-calling reliability.

---

## TQ4_1S weight compression (Gemma 4 31B, experimental)

Shrinks 31B Q8 from 30.4GB → 18.9GB with identical generation speed. Requires `llama-cpp-turboquant` built above.

```bash
# A pre-generated tensor map is included in this repo (gemma4-31b-config-i.txt)
# Run the compression:
llama-cpp-turboquant/build/bin/llama-quantize \
  --allow-requantize \
  --tensor-type-file gemma4-31b-config-i.txt \
  gemma-4-31B-it-Q8_0.gguf \
  gemma-4-31B-it-TQ4_1S-config-i.gguf \
  Q8_0
```

To regenerate the tensor map for a different model:

```bash
python3 -c "
n_layers = 60  # Gemma 4 31B has 60 layers
for i in range(2, n_layers - 2):
    for t in ['attn_q', 'attn_k', 'attn_v', 'attn_output', 'ffn_gate', 'ffn_up']:
        print(f'blk.{i}.{t}.weight=tq4_1s')
    print(f'blk.{i}.ffn_down.weight=q4_k')
" > gemma4-31b-config-i.txt
```

---

## Benchmark results (M3 Ultra, 512GB)

Flash attention enabled, 512-token prompt, 200-token generation.

### Gemma 4

| Model | Quant | Size | Gen (tok/s) | Prompt (tok/s) | Notes |
|-------|-------|------|-------------|----------------|-------|
| 26B MoE | Q4_K_M | 15.7G | **85.6** | 2372 | Best speed |
| 26B MoE | Q8_0 | 25.0G | **82.1** | 2421 | **Recommended for coding agent** |
| 31B Dense | Q4_K_M | 17.1G | 27.6 | 356 | — |
| 31B Dense | Q8_0 | 30.4G | 18.3 | 375 | Best quality |
| 31B Dense Q4 | +Spec | +5G | **38.9** | — | 1.4x gen speedup |
| 31B Dense Q8 | +Spec | +5G | **31.2** | — | 1.7x gen speedup |
| 31B Dense | TQ4_1S | 18.9G | 18.5 | 320 | 38% smaller, same gen speed |

### Qwen3.5

| Model | Quant | Size | Gen (tok/s) | Prompt (tok/s) | Notes |
|-------|-------|------|-------------|----------------|-------|
| 35B-A3B MoE | Q4_K_M | 20.5G | **78.3** | 2215 | 3B active params, near-Gemma-MoE speed |
| 9B Dense | Q8_0 | 8.9G | **58.4** | 1484 | Fast, small |
| 27B Dense Q4 | +Spec | +0.8G | **59.6** | — | 2.2x speedup via 0.8B draft |
| Qwopus v2 Q4 | +Spec | +0.8G | **60.2** | — | 2.2x speedup via 0.8B draft |
| 27B Dense | Q4_K_M | 15.6G | 26.8 | 399 | Strong reasoning |
| Qwopus v2 27B | Q4_K_M | 15.4G | 27.2 | 402 | Opus-distilled, best for coding/math |

### Key findings

- **Qwen3.5-35B-A3B MoE is remarkably fast** — 78 tok/s at 21GB, nearly matches Gemma 4 26B MoE (82 tok/s). Only ~3B active params per token despite 35B total
- **Gemma 4 26B MoE vs Qwen3.5-35B-A3B MoE**: Gemma is 5% faster, Qwen is the stronger reasoning model — both are excellent choices for the coding agent
- **Qwen3.5-27B + speculative decoding (0.8B draft)**: 60 tok/s — 2.2x speedup. Makes Qwopus practical for interactive use
- **Qwopus v2 vs base Qwen3.5-27B**: identical speed (~27 tok/s baseline, ~60 tok/s with spec), better coding/math quality from Opus distillation
- **Gemma 4 26B MoE is ~4.5x faster than 31B Dense** — only ~4B active params per token
- **Speculative decoding on MoE is slower** — already so fast that draft+verify overhead is net negative
- **Speculative decoding helps 31B Dense** — 1.4x on Q4, 1.7x on Q8
- **TQ4_1S**: same gen speed as Q8_0, 38% smaller, ~15% slower prompt processing
- **For an agentic coding loop**: throughput matters most — 78-82 tok/s (MoE) vs 27 tok/s (dense) is a meaningful UX difference

---

## File layout

```
~/localcode/
├── README.md
├── run.sh                                 # Chat modes + manual server start
├── oc.sh                                  # OpenCode wrapper: auto-manages llama-server
├── benchmark.sh                           # Reproduce benchmark results
├── gemma4-31b-config-i.txt               # TQ4_1S tensor type map (pre-generated)
├── llama.cpp/                             # Built from source (not committed)
│   └── build/bin/llama-cli, llama-bench, llama-speculative
├── llama-cpp-turboquant/                  # TurboQuant+ fork (not committed)
│   └── build/bin/llama-server, llama-quantize, llama-bench
├── claw-code/                             # Claw Code source reference (not committed)
├── opencode/                              # OpenCode source reference (not committed)
├── venv/                                  # Python venv for downloads (not committed)
│
├── # Gemma 4 models (not committed)
├── gemma-4-26B-A4B-it-Q8_0.gguf         # 25G — default for opencode
├── gemma-4-26B-A4B-it-UD-Q4_K_M.gguf   # 15.7G
├── gemma-4-31B-it-Q8_0.gguf             # 30.4G
├── gemma-4-31B-it-Q4_K_M.gguf           # 17.1G
├── gemma-4-31B-it-TQ4_1S-config-i.gguf  # 18.9G — compressed
├── gemma-4-E2B-it-Q8_0.gguf             # 5G — draft model for speculative decoding
│
└── # Qwen3.5 models (not committed)
    ├── Qwen3.5-9B-Q8_0.gguf                      # 9.5G
    ├── Qwen3.5-27B-Q4_K_M.gguf                   # 16.7G
    ├── Qwen3.5-35B-A3B-Q4_K_M.gguf              # 21.4G
    └── Qwen3.5-27B-Qwopus-v2-Q4_K_M.gguf       # 16.5G
```

---

## Related projects

- [llama.cpp](https://github.com/ggml-org/llama.cpp) — inference engine
- [TurboQuant+](https://github.com/TheTom/turboquant_plus) — KV cache + weight compression
- [OpenCode](https://github.com/sst/opencode) — local coding agent
- [Claw Code](https://github.com/ultraworkers/claw-code-parity) — open-source Claude Code rewrite (early stage)
- [Unsloth Gemma 4 GGUFs](https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF) — quantized Gemma 4
- [Unsloth Qwen3.5 GGUFs](https://huggingface.co/unsloth/Qwen3.5-27B-GGUF) — quantized Qwen3.5
- [Qwopus v2](https://huggingface.co/Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF) — Opus-distilled Qwen3.5-27B
