# localcode

Run Gemma 4 fully locally on Apple Silicon via llama.cpp, with OpenCode as a coding agent. No cloud, no telemetry, no API keys.

Benchmarked on a Mac Studio M3 Ultra (512GB). Most of the setup applies to any Apple Silicon Mac — see [hardware requirements](#hardware-requirements) for memory guidance by model.

---

## What's included

- **llama.cpp** built from source with Metal acceleration
- **run.sh** — one-command chat for any model variant
- **oc.sh** — OpenCode coding agent with auto-managed llama-server (starts on first use, stops when last session exits)
- **TurboQuant+ weight compression** — shrinks 31B Q8 (30.4GB) to 18.9GB with identical generation speed
- Benchmark results across all model/quant combinations

---

## Hardware requirements

| Model | VRAM needed | Tested on |
|-------|------------|-----------|
| 26B MoE Q4 | ~18GB | M3 Ultra 512GB |
| 26B MoE Q8 | ~28GB | M3 Ultra 512GB |
| 31B Dense Q4 | ~20GB | M3 Ultra 512GB |
| 31B Dense Q8 | ~34GB | M3 Ultra 512GB |
| 31B TQ4_1S (compressed) | ~22GB | M3 Ultra 512GB |

On Apple Silicon, VRAM = unified memory. An M2/M3 Max (96GB+) or Ultra is ideal. M3 Pro (36GB) can run the 26B MoE Q8 comfortably.

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

Clone this repo and set it as your working directory:

```bash
git clone https://github.com/dwalter/localcode.git ~/localcode
cd ~/localcode
```

> All commands below assume you're in `~/localcode`. Adjust the path if you clone elsewhere.

### 1. Build llama.cpp from source

The Homebrew stable build does not support Gemma 4 — must build from HEAD.

```bash
git clone --depth 1 https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(sysctl -n hw.logicalcpu) --target llama-bench llama-cli llama-speculative
cd ..
```

### 2. Build llama-cpp-turboquant (for llama-server + TQ4_1S compression)

This fork adds TurboQuant+ KV cache compression and the experimental TQ4_1S weight compression. It's also the build used for `llama-server` (the API server that OpenCode connects to).

```bash
git clone https://github.com/TheTom/llama-cpp-turboquant.git
cd llama-cpp-turboquant
git checkout pr/tq4-weight-compression
cmake -B build -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(sysctl -n hw.logicalcpu) --target llama-server llama-quantize llama-bench
cd ..
```

### 3. Python venv for model downloads

Must use an arm64 Python — the system or Rosetta Python may fail:

```bash
/opt/homebrew/bin/python3.11 -m venv venv
source venv/bin/activate
pip install -U pip huggingface_hub
```

### 4. Accept the Gemma 4 license

Gemma 4 is a gated model. Accept the license at [huggingface.co/google/gemma-4-27b-it](https://huggingface.co/google/gemma-4-27b-it), then log in:

```bash
source venv/bin/activate
huggingface-cli login
```

### 5. Download models

Download whichever models you need. The 26B MoE Q8 is recommended as a starting point.

```bash
source venv/bin/activate

# 26B MoE Q8 — recommended (25GB, 82 tok/s)
huggingface-cli download unsloth/gemma-4-26B-A4B-it-GGUF \
  gemma-4-26B-A4B-it-Q8_0.gguf --local-dir .

# 26B MoE Q4 — faster, smaller (15.7GB, 85 tok/s)
huggingface-cli download unsloth/gemma-4-26B-A4B-it-GGUF \
  gemma-4-26B-A4B-it-UD-Q4_K_M.gguf --local-dir .

# 31B Dense Q8 — highest quality (30.4GB, 18 tok/s)
huggingface-cli download unsloth/gemma-4-31B-it-GGUF \
  gemma-4-31B-it-Q8_0.gguf --local-dir .

# 31B Dense Q4 — good with speculative decoding (17.1GB, 28 tok/s)
huggingface-cli download unsloth/gemma-4-31B-it-GGUF \
  gemma-4-31B-it-Q4_K_M.gguf --local-dir .

# E2B draft model — required for speculative decoding (5GB)
huggingface-cli download unsloth/gemma-4-E2B-it-GGUF \
  gemma-4-E2B-it-Q8_0.gguf --local-dir .
```

---

## Chat

```bash
./run.sh              # 26B MoE Q8 — recommended
./run.sh q4           # 26B MoE Q4
./run.sh 31b-q8       # 31B Dense Q8
./run.sh 31b-q4       # 31B Dense Q4
./run.sh 31b-tq4      # 31B TQ4_1S compressed (see below)
./run.sh 31b-spec-q8  # 31B Q8 + speculative decoding (~31 tok/s)
./run.sh 31b-spec-q4  # 31B Q4 + speculative decoding (~39 tok/s)
```

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
opencode
```

`oc.sh` starts llama-server automatically on first use, shares it across concurrent sessions, and shuts it down when the last session exits. The 26B MoE Q8 is used by default (best for agentic loops — 82 tok/s matters when the agent is making many tool calls).

To use the 31B model instead, edit `~/.config/opencode/opencode.json` and change `"model"` to:
```
"llama.cpp/gemma-4-31B-it-TQ4_1S-config-i.gguf"
```
You'll also need the TQ4_1S compressed model (see below).

---

## TQ4_1S weight compression (experimental)

Shrinks the 31B Q8 model from 30.4GB to 18.9GB with identical generation speed and minimal quality loss (~+1-4% perplexity predicted). Requires `llama-cpp-turboquant` built above.

```bash
# Generate the tensor type map
python3 -c "
n_layers = 60
for i in range(2, n_layers - 2):
    for t in ['attn_q', 'attn_k', 'attn_v', 'attn_output', 'ffn_gate', 'ffn_up']:
        print(f'blk.{i}.{t}.weight=tq4_1s')
    print(f'blk.{i}.ffn_down.weight=q4_k')
" > gemma4-31b-config-i.txt

# Compress (requires the Q8_0 source model)
llama-cpp-turboquant/build/bin/llama-quantize \
  --allow-requantize \
  --tensor-type-file gemma4-31b-config-i.txt \
  gemma-4-31B-it-Q8_0.gguf \
  gemma-4-31B-it-TQ4_1S-config-i.gguf \
  Q8_0
```

A pre-generated `gemma4-31b-config-i.txt` is included in this repo.

---

## Benchmark results (M3 Ultra, 512GB)

Flash attention enabled, 512-token prompt, 200-token generation.

| Model | Quant | Size | Gen (tok/s) | Prompt (tok/s) | Notes |
|-------|-------|------|-------------|----------------|-------|
| 26B MoE | Q4_K_M | 15.7G | **85.6** | 2372 | Best speed |
| 26B MoE | Q8_0 | 25.0G | **82.1** | 2421 | **Recommended** |
| 31B Dense | Q4_K_M | 17.1G | 27.6 | 356 | — |
| 31B Dense | Q8_0 | 30.4G | 18.3 | 375 | Best quality |
| 31B Dense Q4 | +Spec | +5G | **38.9** | — | 1.4x gen speedup |
| 31B Dense Q8 | +Spec | +5G | **31.2** | — | 1.7x gen speedup |
| 31B Dense | TQ4_1S | 18.9G | 18.5 | 320 | 38% smaller, same gen speed (experimental) |

### TQ4_1S detail

| | Q8_0 (source) | TQ4_1S | TQ4_1S + turbo4 KV |
|---|---|---|---|
| Size | 30.38G | 18.87G | 18.87G |
| Gen (tok/s) | 18.3 | **18.5** | 17.5 |
| Prompt (tok/s) | 375 | 320 | 316 |

### Key findings

- **26B MoE is ~4.5x faster than 31B Dense** — only ~4B active params per token
- **Speculative decoding on MoE is slower** — already so fast that draft+verify overhead is net negative
- **Speculative decoding helps 31B Dense** — 1.4x on Q4 (38.9 tok/s), 1.7x on Q8 (31.2 tok/s)
- **TQ4_1S**: same generation speed as Q8_0, 38% smaller, ~15% slower prompt processing
- **26B MoE Q8 is the best choice for an agentic coding loop** — throughput matters more than peak quality when the agent is calling tools in tight sequences

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
└── *.gguf                                 # Model files (not committed)
```

---

## Related projects

- [llama.cpp](https://github.com/ggml-org/llama.cpp) — inference engine
- [TurboQuant+](https://github.com/TheTom/turboquant_plus) — KV cache + weight compression
- [OpenCode](https://github.com/sst/opencode) — local coding agent
- [Claw Code](https://github.com/ultraworkers/claw-code-parity) — open-source Claude Code rewrite (early stage)
- [Unsloth Gemma 4 GGUFs](https://huggingface.co/unsloth) — quantized model files
