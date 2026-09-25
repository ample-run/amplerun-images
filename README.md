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

## Sandbox contract

Every image runs:
- as user `10001:10001`, the tenant;
- with a read-only root filesystem and a writable `/work`;
- with no capabilities and `no-new-privileges`.

Model weights are not baked into the images. They are mounted or pulled at runtime.

## Build

A push to `main` builds every engine on GitHub-hosted runners (`.github/workflows/build.yml`). Each build uploads a `digest-<engine>` artifact.

This repository is a published snapshot. Changes come from AmpleRun maintainers.
