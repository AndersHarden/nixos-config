# Model Routing Design

## Goal
Route simple background tasks to qwen2.5-coder:14b (via Ollama htpc) while keeping gemini-3-flash-preview as the main reasoning model.

## Architecture
Hermes built-in `auxiliary.<task>` system routes 7 task types to the cheap model:

| Task | Purpose | Model |
|------|---------|-------|
| `web_extract` | Web page summarization | qwen2.5-coder:14b |
| `compression` | Conversation context compression | qwen2.5-coder:14b |
| `approval` | Command approval classification | qwen2.5-coder:14b |
| `title_generation` | Session title summaries | qwen2.5-coder:14b |
| `session_search` | Past session search | qwen2.5-coder:14b |
| `skills_hub` | Skill search/discovery | qwen2.5-coder:14b |
| `mcp` | MCP helper operations | qwen2.5-coder:14b |

Vision (image analysis) remains on Gemini — qwen2.5-coder lacks multimodal support.

## Routing
- `OPENAI_BASE_URL=http://htpc:11434/v1` → `openai-api` provider → Ollama
- All auxiliary tasks use `provider: openai-api`, `model: qwen2.5-coder:14b`
- Main model stays `provider: gemini`, `model: gemini-3-flash-preview`

## Config
Set via `services.hermes-agent.settings.auxiliary` in Nix configuration.nix.
