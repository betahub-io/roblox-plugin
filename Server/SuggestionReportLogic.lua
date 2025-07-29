-- This is a ModuleScript to SuggestionReportServer.lua
local SuggestionReportLogic = {}


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

function SuggestionReportLogic.createHttpRequest(data, httpService, projectId, authToken)
    local jsonData = httpService:JSONEncode(data)
    local apiUrl = "https://app.betahub.io/projects/" .. projectId .. "/feature_requests"
    
    local headers = {
        ["Authorization"] = authToken,
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

function SuggestionReportLogic.processSuggestionReport(player, description, steps, httpService, remoteEvent, projectId, authToken)
    -- Validate input
    local isValid, validationError = SuggestionReportLogic.validateSuggestionDescription(description)
    if not isValid then
        remoteEvent:FireClient(player, "error", validationError)
        return false, validationError
    end
    
    -- Create request data
    local data = SuggestionReportLogic.createRequestData(description, steps)
    local requestOptions = SuggestionReportLogic.createHttpRequest(data, httpService, projectId, authToken)
    
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