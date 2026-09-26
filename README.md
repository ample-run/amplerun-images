# AmpleRun engine images

Container images that [AmpleRun](https://amplerun.com) GPU rentals run on.

- **Public:** `ghcr.io/ample-run/amplerun-<engine>`
- **Pinned by digest:** hosts run an exact `@sha256:…`, never a tag.
- **Checked before tagging:** the Jupyter image must pass its auth check before it gets a tag.

| Engine | Serves |
|---|---|
| `vllm` | OpenAI-compatible LLM API |
| `llamacpp` | GGUF models |
| `ollama` | Ollama models |
| `comfyui` | Image generation |
| `faster-whisper` | Speech to text |
| `pytorch` | SSH workspace |
| `jupyter` | Notebooks |
| `workspace` | One wrapper, many images: each name in `variants.json` pins an upstream base and the app it runs |

## Sandbox contract

Every image runs:
- as user `10001:10001`, the tenant;
- with a read-only root filesystem and a writable `/work`;
- with no capabilities and `no-new-privileges`.

Model weights are not baked into the images. They are mounted or pulled at runtime.

## Build

Builds run on GitHub-hosted runners when dispatched (`.github/workflows/build.yml`, input `images` = names from `variants.json`). Each build uploads a `digest-<name>` artifact.

This repository is a published snapshot. Changes come from AmpleRun maintainers.
