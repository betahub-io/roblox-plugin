-- Refactored BugReportServer using the extracted logic
local BugReportLogic = require(script.BugReportLogic)

local remoteEvent = game.ReplicatedStorage:FindFirstChild("SubmitBugEvent")
local HttpService = game:GetService("HttpService")

local function onBugReportSubmit(player, issue, steps, logs)
    print("Received bug report from:", player.Name)
    
    local projectId = HttpService:GetSecret("BH_PROJECT_ID")
    local authToken = HttpService:GetSecret("BH_AUTH_TOKEN")
    
    local success, message = BugReportLogic.processBugReport(
        player, 
        issue, 
        steps, 
        logs, 
        HttpService, 
        remoteEvent,
        projectId,
        authToken
    )
    
    if success then
        print("Bug report submitted successfully!")
    else
        warn("Failed to send bug report: " .. message)
    end
end

remoteEvent.OnServerEvent:Connect(onBugReportSubmit)