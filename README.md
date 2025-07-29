# BetaHub Roblox Integration

A robust reporting system that enables Roblox games to submit bug reports and feature suggestions to the BetaHub platform. This project supports both local development with comprehensive testing and seamless Roblox Studio integration.

## Features

- **Bug Reporting**: Submit detailed bug reports with log collection and validation
- **Feature Suggestions**: Submit feature requests and improvements  
- **Hybrid Development**: Test locally with mocks or integrate directly into Roblox Studio
- **Comprehensive Testing**: 38 test cases covering validation, HTTP handling, and workflows
- **CLI Tools**: Command-line interface for testing and development
- **Robust Error Handling**: JSON response parsing and user-friendly error messages

## Quick Start

### Prerequisites

- **Busted**: Lua testing framework for local development
  ```bash
  luarocks install busted
  ```

- **dkjson**: JSON library for CLI tools
  ```bash
  luarocks install dkjson
  ```

### Basic Usage

#### Bug Reports
```lua
-- In Roblox Studio
local BugReportLogic = require(script.BugReportLogic)

local success, message = BugReportLogic.processBugReport(
    player,
    "Detailed bug description (minimum 40 characters)",
    "Steps to reproduce the issue",
    logs,
    HttpService,
    remoteEvent,
    projectId,
    authToken
)
```

#### Feature Suggestions
```lua
-- In Roblox Studio
local SuggestionReportLogic = require(script.SuggestionReportLogic)

local success, message = SuggestionReportLogic.processSuggestionReport(
    player,
    "Feature description (minimum 80 characters)",
    "Optional implementation steps",
    HttpService,
    remoteEvent,
    projectId,
    authToken
)
```

#### CLI Testing
```bash
# Test feature suggestions
./run_suggestion_cli.sh "Add a dark mode toggle to the settings menu for better accessibility"

# With environment variables
BH_PROJECT_ID=pr-custom-123 ./run_suggestion_cli.sh "Custom project suggestion"
```

## Architecture

### Hybrid Development Model

This codebase supports two deployment scenarios:

- **Local Testing**: Use `tests/` directory with mock services for rapid development cycles
- **Roblox Integration**: Deploy `Server/` scripts directly into Roblox Studio

### Core Components

```
Server/
├── BugReportServer.lua       # Main bug report server script
├── BugReportLogic.lua        # Bug report business logic (ModuleScript)
├── SuggestionReportServer.lua # Main suggestion server script
└── SuggestionReportLogic.lua  # Suggestion business logic (ModuleScript)

mocks/
├── MockHttpService.lua       # Configurable HTTP responses
├── MockRemoteEvent.lua       # Client-server communication simulation
├── MockPlayer.lua           # Player object simulation
├── MockSecret.lua           # Secret management simulation
└── MockSecretsService.lua    # Secrets service simulation

tests/
├── BugReportLogic_spec.lua   # 17 comprehensive bug report tests
└── SuggestionReportLogic_spec.lua # 21 comprehensive suggestion tests

cli/
├── run_suggestion_report.lua # CLI suggestion submission
├── RealHttpService.lua      # Real HTTP implementation
└── CliMocks.lua            # CLI-specific mocks
```

### Workflows

#### Bug Report Workflow
1. **Validation**: Ensures issue description ≥ 40 characters
2. **Log Formatting**: Converts log entries with timestamps
3. **API Request**: POST to BetaHub issues endpoint
4. **Response Handling**: Success/error via RemoteEvent

#### Suggestion Workflow  
1. **Validation**: Ensures description ≥ 80 characters
2. **API Request**: POST to BetaHub feature requests endpoint
3. **Response Handling**: Success/error via RemoteEvent
4. **No Log Processing**: Suggestions don't include logs

## Development

### Local Testing

Run all tests:
```bash
busted tests/
```

Run specific test files:
```bash
busted tests/BugReportLogic_spec.lua
busted tests/SuggestionReportLogic_spec.lua
```

### Roblox Studio Integration

For proper integration in Roblox Studio:

1. **BugReportLogic.lua** must be a **ModuleScript** (not Script)
2. Must be a **child** of the `BugReportServer` script in Studio hierarchy
3. **SuggestionReportLogic.lua** must be a **ModuleScript** (not Script)  
4. Must be a **child** of the `SuggestionReportServer` script in Studio hierarchy

The `require(script.BugReportLogic)` pattern depends on this parent-child relationship.

### Mock Configuration

Configure mock responses for testing different scenarios:

```lua
local mockHttp = MockHttpService:new({
    shouldSucceed = false,
    responseBody = '{"error":"Custom error message"}'
})
```

## Testing

### Test Coverage

- **Bug Reports**: 17 test cases covering validation, HTTP handling, error parsing, and full workflows
- **Suggestions**: 21 test cases covering validation, API integration, and response handling
- **Mock Services**: Complete simulation of Roblox services for isolated testing

### Example Test Scenarios

- Input validation (string types, character limits)
- HTTP request construction and headers
- Success and error response parsing
- RemoteEvent communication
- Log formatting and timestamp handling

## Configuration

### Environment Variables

- `BH_PROJECT_ID`: BetaHub project identifier
- `BH_AUTH_TOKEN`: Authentication token for API requests

### API Constraints

- **Bug Reports**: Issue description minimum 40 characters
- **Feature Suggestions**: Description minimum 80 characters
- **Log Entries**: Must include `timestamp`, `messageType`, and `message` fields
- **Authentication**: Uses `FormUser` token format
- **Response Format**: JSON with success/error status

### API Integration

The system connects to BetaHub API with:

- **Authentication**: FormUser token via Authorization header
- **Content-Type**: application/json
- **Bug Reports Endpoint**: `https://app.betahub.io/projects/{projectId}/issues`
- **Feature Requests Endpoint**: `https://app.betahub.io/projects/{projectId}/feature_requests`
- **Error Handling**: JSON response parsing with fallback messages

## Security

- Secrets are managed through Roblox HttpService:GetSecret()
- Authentication tokens are properly formatted with FormUser prefix
- Input validation prevents malformed requests
- No sensitive data is logged or exposed in error messages

## Contributing

1. Follow existing code patterns and conventions
2. Add tests for new functionality
3. Use dependency injection pattern for testability
4. Maintain separation between server scripts and business logic
5. Test both locally with mocks and in Roblox Studio

## License

This project is part of the BetaHub platform integration suite.