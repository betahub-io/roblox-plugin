#!/usr/bin/env lua

-- CLI runner for SuggestionReportLogic with real HTTP requests
local function addToPath(path)
    package.path = package.path .. ";" .. path .. "/?.lua"
end

-- Add paths for our modules
addToPath("../Server")
addToPath("../mocks")
addToPath(".")

-- Load required modules
local SuggestionReportLogic = require("SuggestionReportLogic")
local RealHttpService = require("RealHttpService")
local CliMocks = require("CliMocks")

-- Parse command line arguments
local function parseArgs(args)
    if #args < 1 then
        print("Usage: lua run_suggestion_report.lua \"<description>\" [\"<steps>\"]")
        print("")
        print("Description must be at least 80 characters.")
        print("Steps are optional reproduction steps.")
        print("")
        print("Example:")
        print("  lua run_suggestion_report.lua \"Add a dark mode toggle to the settings menu. This would allow users to switch between light and dark themes for better accessibility and user preference.\"")
        os.exit(1)
    end
    
    local description = args[1]
    local steps = args[2] or ""
    
    return description, steps
end

-- Main execution
local function main()
    local description, steps = parseArgs(arg)
    
    print("🚀 Submitting suggestion to BetaHub...")
    print("Description: " .. description)
    if steps ~= "" then
        print("Steps: " .. steps)
    end
    print("")
    
    -- Get credentials from environment variables or use fallbacks
    local projectId = os.getenv("BH_PROJECT_ID") or "pr-6790810205"
    local authToken = os.getenv("BH_AUTH_TOKEN") or "tkn-1b36c81e73cfe0281b24ec860d262908cf9ffdba804b985164016fbe84b72fab"
    
    -- Create services and mocks
    local httpService = RealHttpService:new()
    local player = CliMocks.createPlayer("CLIUser")
    local remoteEvent = CliMocks.createRemoteEvent()
    
    -- Process the suggestion report
    local success, message = SuggestionReportLogic.processSuggestionReport(
        player,
        description,
        steps,
        httpService,
        remoteEvent,
        projectId,
        authToken
    )
    
    -- Print final result
    print("")
    if success then
        print("🎉 Suggestion submitted successfully to BetaHub!")
    else
        print("💥 Failed to submit suggestion: " .. message)
        os.exit(1)
    end
end

-- Run the main function
main()