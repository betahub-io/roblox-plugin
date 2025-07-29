local MockHttpService = {}

local dkjson = require("dkjson")

function MockHttpService:new(config)
    local service = {
        responses = config and config.responses or {},
        shouldSucceed = config and config.shouldSucceed or true,
        responseBody = config and config.responseBody or "",
        responseCode = config and config.responseCode or 200
    }
    setmetatable(service, self)
    self.__index = self
    return service
end

function MockHttpService:JSONEncode(data)
    return dkjson.encode(data)
end

function MockHttpService:JSONDecode(jsonString)
    return dkjson.decode(jsonString)
end

function MockHttpService:RequestAsync(requestOptions)
    local url = requestOptions.Url
    local method = requestOptions.Method
    local headers = requestOptions.Headers
    local body = requestOptions.Body
    
    -- Check if we have a specific response configured for this URL
    if self.responses[url] then
        local response = self.responses[url]
        return {
            Success = response.Success,
            StatusCode = response.StatusCode or 200,
            StatusMessage = response.StatusMessage or "OK",
            Headers = response.Headers or {},
            Body = response.Body or ""
        }
    end
    
    -- Default behavior
    if self.shouldSucceed then
        return {
            Success = true,
            StatusCode = self.responseCode,
            StatusMessage = "OK",
            Headers = {},
            Body = self.responseBody
        }
    else
        return {
            Success = false,
            StatusCode = 400,
            StatusMessage = "Bad Request",
            Headers = {},
            Body = self.responseBody
        }
    end
end

-- Helper method to configure responses for specific URLs
function MockHttpService:setResponse(url, response)
    self.responses[url] = response
end

return MockHttpService