local CliMocks = {}

-- Simple player mock for CLI usage
function CliMocks.createPlayer(name)
    return {
        Name = name or "CLIUser"
    }
end

-- Simple RemoteEvent mock that prints responses instead of firing to client
function CliMocks.createRemoteEvent()
    return {
        FireClient = function(self, player, status, message)
            if status == "success" then
                print("✅ SUCCESS: Suggestion submitted successfully!")
            elseif status == "error" then
                print("❌ ERROR: " .. (message or "Unknown error"))
            end
        end
    }
end

return CliMocks