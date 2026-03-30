# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a Roblox in-game feedback widget that submits bug reports and feature suggestions to the BetaHub API.

### Source of Truth
- **`BetaHubFeedbackWidget.rbxl`** — the Roblox place file containing the full widget (UI hierarchy + scripts). This is the authoritative source.
- **`FeedbackWidget/`** — exported Lua scripts for readable git diffs. These mirror what's in the `.rbxl` file.

### Roblox Studio Hierarchy

```
StarterGui/
├── BetahubFeedbackUi (ScreenGui)
│   ├── FeedbackUIHandler (LocalScript)
│   │   ├── AutoTextBoxScaler (ModuleScript)
│   │   └── ButtonColourer (ModuleScript)
│   ├── MainFrame (Frame) — the main feedback form
│   ├── ConfirmPrompt (Frame) — success confirmation
│   └── ErrorPrompt (Frame) — error display
├── ExampleOpenCloseButton (ScreenGui)
│   └── TextButton > LocalScript

ReplicatedStorage/
└── BetahubFeedback (RemoteFunction)

ServerScriptService/
└── BetahubFeedbackServer (Script)
```

### Communication Pattern
- Client uses `RemoteFunction:InvokeServer()` (not RemoteEvent)
- Server returns `(success, rateLimit, errorMessage)` tuple
- Bug reports include a second server-side request to upload console logs

## Development with Roblox Studio MCP

This project uses the Roblox Studio MCP server for direct Studio integration. Key tools:
- `script_read` / `multi_edit` — read and edit scripts in Studio
- `search_game_tree` / `inspect_instance` — explore the instance hierarchy
- `execute_luau` — run code to create UI elements or test
- `start_stop_play` / `screen_capture` / `get_console_output` — playtest and debug

### Workflow
1. Edit scripts via MCP `multi_edit`
2. Create UI elements via MCP `execute_luau`
3. Playtest via `start_stop_play`, capture screen, read console
4. Export scripts to `FeedbackWidget/` for git commits

## API Integration

- **Bug reports**: `POST /projects/{id}/issues.json` (url-encoded form data)
- **Suggestions**: `POST /projects/{id}/feature_requests.json` (url-encoded form data)
- **Log upload**: `POST /projects/{id}/issues/g-{issueId}/log_files.json` using `log_file[contents]`
- **Auth**: `FormUser {token}` header; log upload uses `FormUser {token},{jwt}`
- **Custom fields**: Use `issue[custom][field_ident]` format (not `custom_fields`)
- **Secrets**: `HttpService:GetSecret("BH_PROJECT_ID")` and `HttpService:GetSecret("BH_AUTH_TOKEN")`

## Key Constraints

- Bug description minimum: 50 characters
- Suggestion description minimum: 80 characters
- Rate limit: 20 seconds between submissions per player (configurable)
- Console log buffer: last 200 entries
- Log upload is non-blocking (bug report succeeds even if log upload fails)
