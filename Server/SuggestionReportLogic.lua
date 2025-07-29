-- This is a ModuleScript to SuggestionReportServer.lua
local SuggestionReportLogic = {}

local API_URL = "https://app.betahub.io/projects/pr-6790810205/feature_requests"
local AUTH_TOKEN = "FormUser tkn-1b36c81e73cfe0281b24ec860d262908cf9ffdba804b985164016fbe84b72fab"

function SuggestionReportLogic.validateSuggestionDescription(description)
    if not description or type(description) ~= "string" then
        return false, "Suggestion description must be a string"
    end
    
    if #description < 80 then
        return false, "Suggestion description must be at least 80 characters."
    end
    
    return true, nil
end

function SuggestionReportLogic.createRequestData(description, steps)
    return {
        feature_request = {
            description = description,
            unformatted_steps_to_reproduce = steps
        }
    }
end

function SuggestionReportLogic.createHttpRequest(data, httpService)
    local jsonData = httpService:JSONEncode(data)
    
    local headers = {
        ["Authorization"] = AUTH_TOKEN,
        ["Accept"] = "application/json",
        ["Content-Type"] = "application/json"
    }
    
    return {
        Url = API_URL,
        Method = "POST",
        Headers = headers,
        Body = jsonData
    }
end

function SuggestionReportLogic.parseErrorResponse(response, httpService)
    local errorMessage
    local successParse, errorJson = pcall(function()
        return httpService:JSONDecode(response.Body)
    end)
    
    if successParse and errorJson and errorJson.error then
        errorMessage = errorJson.error
    else
        errorMessage = "Failed to submit suggestion. Error Code: " .. tostring(response.StatusCode or "unknown")
    end
    
    return errorMessage
end

function SuggestionReportLogic.processSuggestionReport(player, description, steps, httpService, remoteEvent)
    -- Validate input
    local isValid, validationError = SuggestionReportLogic.validateSuggestionDescription(description)
    if not isValid then
        remoteEvent:FireClient(player, "error", validationError)
        return false, validationError
    end
    
    -- Create request data
    local data = SuggestionReportLogic.createRequestData(description, steps)
    local requestOptions = SuggestionReportLogic.createHttpRequest(data, httpService)
    
    -- Make HTTP request
    local response = httpService:RequestAsync(requestOptions)
    
    if response.Success then
        remoteEvent:FireClient(player, "success")
        return true, "Suggestion submitted successfully!"
    else
        local errorMessage = SuggestionReportLogic.parseErrorResponse(response, httpService)
        remoteEvent:FireClient(player, "error", errorMessage)
        return false, errorMessage
    end
end

return SuggestionReportLogic