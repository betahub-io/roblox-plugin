# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Testing Commands

This project uses Busted for local testing outside of Roblox Studio:

```bash
# Run all tests
busted tests/

# Run specific test file
busted tests/BugReportLogic_spec.lua
```

Tests are comprehensive (17 test cases) covering validation, HTTP handling, error parsing, and full workflow scenarios.

## Architecture Overview

### Hybrid Development Model
This codebase supports both **local development** and **Roblox Studio integration**:

- **Local Testing**: Use `tests/` with mock services for rapid development cycles
- **Roblox Integration**: `Server/BugReportServer.lua` requires `BugReportLogic` as a child ModuleScript

### Core Components

**Server/BugReportServer.lua**: Main server script that handles RemoteEvent connections and delegates to business logic.

**Server/BugReportLogic.lua**: Extracted business logic module containing all validation, HTTP handling, and error parsing. This file serves dual purposes:
- As a standard Lua module for local testing
- As a Roblox ModuleScript (child of BugReportServer) in Studio

**mocks/**: Complete mock implementations of Roblox services:
- `MockHttpService`: Configurable HTTP responses for testing different API scenarios
- `MockRemoteEvent`: Simulates client-server RemoteEvent communication
- `MockPlayer`: Simple player object simulation

### Bug Report Workflow
1. Validates issue description (40+ character minimum)
2. Formats log entries with timestamps
3. Creates HTTP request to BetaHub API
4. Handles success/error responses via RemoteEvent

## Development Patterns

### Roblox Studio Integration
For the modular approach to work in Roblox Studio:
1. `BugReportLogic.lua` must be a **ModuleScript** (not Script)
2. Must be a **child** of the `BugReportServer` script in the Studio hierarchy
3. The `require(script.BugReportLogic)` pattern expects this parent-child relationship

### Mock Configuration
Mock services support configurable responses for testing various scenarios:

```lua
local mockHttp = MockHttpService:new({
    shouldSucceed = false,
    responseBody = '{"error":"Custom error message"}'
})
```

### API Integration
The system connects to BetaHub API with:
- Authentication via FormUser token
- JSON payload with issue description, reproduction steps, and formatted logs
- Error handling with JSON response parsing

## Key Constraints

- Issue descriptions must be minimum 40 characters
- Log entries require `timestamp`, `messageType`, and `message` fields
- HTTP requests use dependency injection pattern for testability
- RemoteEvent communication follows "success"/"error" status pattern