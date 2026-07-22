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

1. Open “设置” in the app.
2. Set “模型服务” to a friendly name, for example `OpenRouter` or `Local LM Studio`.
3. Paste the provider's “接口地址”. Many OpenAI-compatible services require the `/v1` suffix.
4. Enter the exact “模型” ID from the provider.
5. Enter your own “密钥”. For local providers that do not require a key, follow that provider's instructions.
6. Run the connection test before saving.

The Settings page also supports “多模型服务配置” and “路由规则”. For a first run, configure only the default model; add routing when different tasks need different providers.

No provider above is required or endorsed as the only option. Pick the service that matches your budget, privacy needs, and model availability.
