-- This is a ModuleScript to BugReportServer.lua
local BugReportLogic = {}


function BugReportLogic.validateIssueDescription(issue)
    if not issue or type(issue) ~= "string" then
        return false, "Issue description must be a string"
    end
    
    if #issue < 40 then
        return false, "Bug description must be at least 40 characters."
    end
    
    return true, nil
end

function BugReportLogic.formatLogs(logs)
    if not logs or type(logs) ~= "table" then
        return ""
    end
    
    local logsString = ""
    for _, log in pairs(logs) do
        if log.timestamp and log.messageType and log.message then
            logsString = logsString .. string.format("[%s] (%s): %s\n", 
                os.date("%Y-%m-%d %H:%M:%S", log.timestamp), 
                log.messageType, 
                log.message)
        end
    end
    return logsString
end

function BugReportLogic.createRequestData(issue, steps, logs)
    local logsString = BugReportLogic.formatLogs(logs)
    
    return {
        issue = {
            description = issue,
            unformatted_steps_to_reproduce = steps,
            logs = logsString
        }
    }
end

function BugReportLogic.createHttpRequest(data, httpService, projectId, authToken)
    local jsonData = httpService:JSONEncode(data)
    
    local apiUrl
    if type(projectId) == "string" then
        apiUrl = "https://app.betahub.io/projects/" .. projectId .. "/issues"
    else
        -- In real Roblox, Secret objects work directly in URLs for RequestAsync
        apiUrl = projectId:AddPrefix("https://app.betahub.io/projects/"):AddSuffix("/issues")
    end
    
    local authorization
    if type(authToken) == "string" then
        -- For string tokens, add FormUser prefix
        authorization = "FormUser " .. authToken
    else
        -- For Secret objects, use AddPrefix method
        authorization = authToken:AddPrefix("FormUser ")
    end
    
    local headers = {
        ["Authorization"] = authorization,
        ["Accept"] = "application/json",
        ["Content-Type"] = "application/json"
    }
    
    return {
        Url = apiUrl,
        Method = "POST",
        Headers = headers,
        Body = jsonData
    }
end

function BugReportLogic.parseErrorResponse(response, httpService)
    local errorMessage
    local successParse, errorJson = pcall(function()
        return httpService:JSONDecode(response.Body)
    end)
    
    if successParse and errorJson and errorJson.error then
        errorMessage = errorJson.error
    else
        errorMessage = "Failed to submit report. Error Code: " .. tostring(response.StatusCode or "unknown")
    end
    
    return errorMessage
end

function BugReportLogic.processBugReport(player, issue, steps, logs, httpService, remoteEvent, projectId, authToken)
    -- Validate input
    local isValid, validationError = BugReportLogic.validateIssueDescription(issue)
    if not isValid then
        remoteEvent:FireClient(player, "error", validationError)
        return false, validationError
    end
    
    -- Create request data
    local data = BugReportLogic.createRequestData(issue, steps, logs)
    local requestOptions = BugReportLogic.createHttpRequest(data, httpService, projectId, authToken)
    
    -- Make HTTP request
    local response = httpService:RequestAsync(requestOptions)
    
    if response.Success then
        remoteEvent:FireClient(player, "success")
        return true, "Bug report submitted successfully!"
    else
        local errorMessage = BugReportLogic.parseErrorResponse(response, httpService)
        remoteEvent:FireClient(player, "error", errorMessage)
        return false, errorMessage
    end
end

return BugReportLogic