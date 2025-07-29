-- SuggestionReportServer using the extracted logic
local SuggestionReportLogic = require(script.SuggestionReportLogic)

local remoteEvent = game.ReplicatedStorage:FindFirstChild("SubmitSuggestionEvent")
local HttpService = game:GetService("HttpService")

local function onSuggestionReportSubmit(player, description, steps)
    print("Received suggestion report from:", player.Name)
    
    local success, message = SuggestionReportLogic.processSuggestionReport(
        player, 
        description, 
        steps, 
        HttpService, 
        remoteEvent
    )
    
    if success then
        print("Suggestion submitted successfully!")
    else
        warn("Failed to send suggestion: " .. message)
    end
end

remoteEvent.OnServerEvent:Connect(onSuggestionReportSubmit)