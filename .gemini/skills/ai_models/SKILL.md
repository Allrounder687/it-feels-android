---
name: "AI Budget Models (2026)"
description: "Rules for interacting with the AI Provider integrations in the IT Feels project, enforcing the use of mid-2026 budget tier models."
---

# AI Budget Models (2026)

When working on or modifying the `backend/src/ai.ts` proxy or `lib/core/ai/providers/` in the IT Feels project, you **MUST** use the following highly cost-efficient budget tier models. 

Do **NOT** use legacy models (like `gpt-4o-mini`, `gemini-1.5-flash`) or expensive flagship models (`claude-sonnet-5`, `gpt-5.6-sol`) unless explicitly authorized by the user.

## Enforced 2026 Model Identifiers
- **OpenAI (ChatGPT):** `gpt-5.6-luna`
  - *Context:* This is OpenAI's fastest and most cost-efficient GPT-5.6 series model, serving as the 2026 successor to the old "mini" and "nano" tiers.
- **Anthropic (Claude):** `claude-haiku-4-5-20251001`
  - *Context:* As of July 2026, there is no "Haiku 5" model. The Haiku 4.5 snapshot remains the cheapest tier for Anthropic.
- **Google (Gemini):** `gemini-3.5-flash-lite`
  - *Context:* This is Google's ultra-low-latency, highly cost-effective model optimized for high-volume tasks, sitting below the standard 3.6-flash tier.

## Rules
1. **Never hardcode API Keys** in the Dart client code. All API keys must remain inside the Cloudflare Worker environment (`backend/`).
2. When creating new AI prompts or tasks in the edge proxy, double-check that the `fetch` URLs and JSON schemas match the exact strings above.
