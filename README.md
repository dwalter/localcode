# Gemma 4 on Mac Studio (M3 Ultra, 512GB)

Local LLM setup using llama.cpp with Metal acceleration. Benchmarked April 2026.

---

## Hardware

- **Mac Studio M3 Ultra, 512GB unified memory**
- Metal GPU acceleration via llama.cpp
- All models fit comfortably in memory

---

## Setup

### 1. Build llama.cpp from source

The Homebrew stable build (8610) does not support Gemma 4. Must build from HEAD.

```bash
cd ~/gemma4
git clone --depth 1 https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(sysctl -n hw.logicalcpu) --target llama-bench llama-cli llama-lookup
```

> If brew complains about Xcode/CLT on Sequoia, run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` first.

### 2. Python venv for model downloads

Must use an arm64 Python — the system/Rosetta Python will fail to install MLX packages.

```bash
/opt/homebrew/bin/python3.11 -m venv ~/gemma4/venv
source ~/gemma4/venv/bin/activate
pip install -U pip
pip install -U huggingface_hub mlx-lm
```

### 3. HuggingFace login (required for Gemma 4 gated models)

Accept the license at https://huggingface.co/google/gemma-4-27b-it, then:

```bash
source ~/gemma4/venv/bin/activate
huggingface-cli login
```

### 4. Download models

```bash
source ~/gemma4/venv/bin/activate
cd ~/gemma4

# Recommended: 26B MoE Q8 (best speed/quality balance)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/gemma-4-26B-A4B-it-GGUF', 'gemma-4-26B-A4B-it-Q8_0.gguf', local_dir='.')"

# 26B MoE Q4 (smaller, similar speed)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/gemma-4-26B-A4B-it-GGUF', 'gemma-4-26B-A4B-it-UD-Q4_K_M.gguf', local_dir='.')"

# 31B Dense Q8 (best quality, slower)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/gemma-4-31B-it-GGUF', 'gemma-4-31B-it-Q8_0.gguf', local_dir='.')"

# 31B Dense Q4 (smaller dense, good with speculative decoding)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/gemma-4-31B-it-GGUF', 'gemma-4-31B-it-Q4_K_M.gguf', local_dir='.')"

# E2B draft model (for speculative decoding with 31B Dense)
python3 -c "from huggingface_hub import hf_hub_download; hf_hub_download('unsloth/gemma-4-E2B-it-GGUF', 'gemma-4-E2B-it-Q8_0.gguf', local_dir='.')"
```

## OpenCode Setup

To use OpenCode as a coding agent with the local models:

### 1. Start the model server
In one terminal, start the server:
```bash
./run.sh server
```

### 2. Start OpenCode
In a second terminal, navigate to your project and run:
```bash
cd ~/your-project
opencode
```

**Note:** The configuration at `~/.config/opencode/opencode.json` is pre-configured for both models. The 26B MoE is the default (best for agentic loops). To use the 31B model for higher quality, run `./run.sh server-31b` instead.

### Recommended: 26B MoE Q8 (interactive chat)

```bash
./run.sh
```

Or manually:

```bash
~/gemma4/llama.cpp/build/bin/llama-cli \
  -m ~/gemma4/gemma-4-26B-A4B-it-Q8_0.gguf \
  -ngl 99 -fa \
  --chat-template gemma \
  -cnv
```

### 26B MoE Q4

```bash
~/gemma4/llama.cpp/build/bin/llama-cli \
  -m ~/gemma4/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf \
  -ngl 99 -fa \
  --chat-template gemma \
  -cnv
```

### 31B Dense Q8 (highest quality)

```bash
~/gemma4/llama.cpp/build/bin/llama-cli \
  -m ~/gemma4/gemma-4-31B-it-Q8_0.gguf \
  -ngl 99 -fa \
  --chat-template gemma \
  -cnv
```

### 31B Dense TQ4_1S (Q8 quality, 38% smaller — recommended)

Uses the TurboQuant+ experimental weight compression branch. Same generation speed as Q8_0,
11.5 GB smaller. See [TurboQuant+ PR #45](https://github.com/TheTom/llama-cpp-turboquant/pull/45).

```bash
~/gemma4/llama-cpp-turboquant/build/bin/llama-cli \
  -m ~/gemma4/gemma-4-31B-it-TQ4_1S-config-i.gguf \
  -ngl 99 -fa \
  --chat-template gemma \
  -cnv
```

With TurboQuant KV cache (useful at long context):

```bash
~/gemma4/llama-cpp-turboquant/build/bin/llama-cli \
  -m ~/gemma4/gemma-4-31B-it-TQ4_1S-config-i.gguf \
  -ngl 99 -fa \
  -ctk q8_0 -ctv turbo4 \
  --chat-template gemma \
  -cnv
```

### 31B Dense Q4 + Speculative Decoding (best 31B speed)

```bash
~/gemma4/llama.cpp/build/bin/llama-speculative \
  -m ~/gemma4/gemma-4-31B-it-Q4_K_M.gguf \
  -md ~/gemma4/gemma-4-E2B-it-Q8_0.gguf \
  -ngl 99 -ngld 99 \
  --chat-template gemma \
  -cnv
```

---

## Benchmark Results (M3 Ultra, 512GB)

All results use flash attention (`-fa`), 512-token prompt, 200-token generation.
Speculative decoding uses E2B Q8 as draft model.

| Model | Quant | Size | Gen (tok/s) | Prompt (tok/s) | Notes |
|-------|-------|------|-------------|----------------|-------|
| 26B MoE | Q4_K_M | 15.7G | **85.6** | 2372 | Best speed |
| 26B MoE | Q8_0 | 25.0G | **82.1** | 2421 | **Recommended** |
| 31B Dense | Q4_K_M | 17.1G | 27.6 | 356 | — |
| 31B Dense | Q8_0 | 30.4G | 18.3 | 375 | Best quality |
| 31B Dense Q4 | +Spec | +5G | **38.9** | — | 1.4x gen speedup |
| 31B Dense Q8 | +Spec | +5G | **31.2** | — | 1.7x gen speedup |
| 31B Dense | TQ4_1S | 18.9G | 18.5 | 320 | 38% smaller, same gen speed (experimental) |

### TurboQuant+ Weight Compression (TQ4_1S)

Experimental post-training weight compression via [TurboQuant+ PR #45](https://github.com/TheTom/llama-cpp-turboquant/pull/45).
Built from branch `pr/tq4-weight-compression` into `~/gemma4/llama-cpp-turboquant/`.

| Model | Quant | Size | Gen (tok/s) | Prompt (tok/s) | Notes |
|-------|-------|------|-------------|----------------|-------|
| 31B Dense | Q8_0 (baseline) | 30.38G | 18.3 | 375 | — |
| 31B Dense | TQ4_1S Config I | 18.87G | **18.5** | 320 | 38% smaller, identical gen speed |
| 31B Dense | TQ4_1S + turbo4 KV | 18.87G | 17.5 | 316 | Long context bonus |

Compression recipe ([gemma4-31b-config-i.txt](gemma4-31b-config-i.txt)): 56 middle layers (boundary 2+2),
attn+ffn_gate/up = TQ4_1S, ffn_down = Q4_K.

### Key findings

- **26B MoE** is ~4.5x faster than 31B Dense due to only ~4B active params per token
- **Speculative decoding hurts the MoE** — it's already so fast that draft+verify overhead makes it slower
- **Speculative decoding helps 31B Dense** — 1.4x on Q4 (38.9 tok/s), 1.7x on Q8 (31.2 tok/s)
- **Flash attention** gives a free ~3-5% boost with no downsides
- **Q4 vs Q8 on MoE** is nearly identical in speed (~3% difference) — use Q8 for quality
- **26B MoE Q8** runs at full Q8 quality in only 25GB — well within 512GB
- **TQ4_1S**: 31B Q8 → 18.9 GB with identical gen speed. Prompt speed -15% (dequant overhead). Quality predicted ~+1-4% PPL (not yet measured)

### Why 26B MoE over 31B Dense for coding

For interactive coding workflows, the MoE at 81 tok/s means fast iteration loops.
At 10x the generation speed vs the dense model, inference scaling (self-correction,
multiple attempts, longer chain-of-thought) is practical in real time.

---

## Next Steps

- [ ] Prompt lookup decoding (`llama-lookup`) for coding agent context — likely to significantly
      boost tok/s on code generation tasks where prompt patterns repeat in output
- [ ] llama-server setup for API-compatible endpoint
- [ ] MCP integration (web search, GitHub, HuggingFace)
- [ ] Coding agent workflow
- [ ] PPL benchmark: TQ4_1S vs Q8_0 baseline on wikitext-2 (expected ~+1-4% for Gemma)
- [ ] Test TQ4_1S + speculative decoding (E2B draft) for 31B gen speed
- [ ] Post results to TurboQuant+ [PR #45](https://github.com/TheTom/llama-cpp-turboquant/pull/45)

---

## File Layout

```
~/gemma4/
├── README.md
├── run.sh                          # Chat with recommended model
├── benchmark.sh                    # Run full benchmark suite
├── llama.cpp/                      # Built from source (HEAD)
│   └── build/bin/
│       ├── llama-cli
│       ├── llama-bench
│       ├── llama-speculative
│       └── llama-lookup            # For prompt lookup decoding (next step)
├── venv/                           # arm64 Python 3.11 venv
├── gemma-4-26B-A4B-it-Q8_0.gguf            # 25G — recommended
├── gemma-4-26B-A4B-it-UD-Q4_K_M.gguf      # 15.7G
├── gemma-4-31B-it-Q8_0.gguf               # 30.4G
├── gemma-4-31B-it-Q4_K_M.gguf             # 17.1G
├── gemma-4-31B-it-TQ4_1S-config-i.gguf   # 18.9G — compressed (experimental)
├── gemma4-31b-config-i.txt                # tensor type map for TQ4_1S compression
├── gemma-4-E2B-it-Q8_0.gguf              # 5G — draft model for speculative decoding
└── llama-cpp-turboquant/                  # TurboQuant+ fork, branch pr/tq4-weight-compression
```
