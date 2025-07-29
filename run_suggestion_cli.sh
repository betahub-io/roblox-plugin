#!/bin/bash

# Convenience script to run suggestion reports from CLI
# Usage: ./run_suggestion_cli.sh "description" ["steps"]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="$SCRIPT_DIR/cli"

# Check if description is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 \"<description>\" [\"<steps>\"]"
    echo ""
    echo "Description must be at least 80 characters."
    echo "Steps are optional reproduction steps."
    echo ""
    echo "Example:"
    echo "  $0 \"Add a dark mode toggle to the settings menu. This would allow users to switch between light and dark themes for better accessibility and user preference.\""
    exit 1
fi

# Check if dkjson is available
if ! lua -e "require('dkjson')" 2>/dev/null; then
    echo "❌ Error: dkjson library is required but not found."
    echo ""
    echo "Install with: luarocks install dkjson"
    echo "Or on macOS with Homebrew: brew install lua && luarocks install dkjson"
    exit 1
fi

# Change to CLI directory and run the Lua script
cd "$CLI_DIR"
lua run_suggestion_report.lua "$1" "$2"