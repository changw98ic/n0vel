# OpenAI-compatible provider examples

Novel Writer can connect to any model service that exposes an OpenAI-compatible chat API. The exact values come from your provider account; do not paste a real API key into issues, screenshots, or commits.

## Example provider settings

| Provider | Base URL example | Model example | Notes |
| --- | --- | --- | --- |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` | Use an OpenAI API key from your OpenAI dashboard. |
| OpenRouter | `https://openrouter.ai/api/v1` | `anthropic/claude-3.5-sonnet` | Use an OpenRouter API key and one of the model IDs listed in OpenRouter. |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` | Use a DeepSeek API key. Some accounts may expose additional model IDs. |
| Local LM Studio | `http://localhost:1234/v1` | model shown in LM Studio | Start the local server in LM Studio first, then copy the loaded model ID. |

## How to fill Settings

1. Open **Settings** in the app.
2. Set **Model service** to a friendly name, for example `OpenRouter` or `Local LM Studio`.
3. Paste the provider's **Base URL**. Many OpenAI-compatible services require the `/v1` suffix.
4. Enter the exact **Model** ID from the provider.
5. Enter your own **API key**. For local providers that do not require a key, follow that provider's instructions.
6. Run the connection test before saving.

No provider above is required or endorsed as the only option. Pick the service that matches your budget, privacy needs, and model availability.
