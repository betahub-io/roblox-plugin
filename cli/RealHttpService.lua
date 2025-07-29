local RealHttpService = {}

local dkjson = require("dkjson")

function RealHttpService:new()
    local service = {}
    setmetatable(service, self)
    self.__index = self
    return service
end

function RealHttpService:JSONEncode(data)
    return dkjson.encode(data)
end

function RealHttpService:JSONDecode(jsonString)
    return dkjson.decode(jsonString)
end

function RealHttpService:RequestAsync(requestOptions)
    local url = requestOptions.Url
    local method = requestOptions.Method or "GET"
    local headers = requestOptions.Headers or {}
    local body = requestOptions.Body or ""
    
    -- Build curl command
    local curlCmd = "curl -s -w '\\n%{http_code}' -X " .. method
    
    -- Add headers
    for key, value in pairs(headers) do
        curlCmd = curlCmd .. " -H '" .. key .. ": " .. value .. "'"
    end
    
    -- Add body for POST requests
    if method == "POST" and body ~= "" then
        curlCmd = curlCmd .. " -d '" .. body:gsub("'", "'\"'\"'") .. "'"
    end
    
    -- Add URL
    curlCmd = curlCmd .. " '" .. url .. "'"
    
    -- Execute curl
    local handle = io.popen(curlCmd)
    local result = handle:read("*a")
    local success = handle:close()
    
    if not result then
        return {
            Success = false,
            StatusCode = 0,
            StatusMessage = "Network Error",
            Headers = {},
            Body = "Failed to execute HTTP request"
        }
    end
    
    -- Parse response body and status code
    local lines = {}
    for line in result:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    local statusCode = tonumber(lines[#lines]) or 0
    table.remove(lines, #lines) -- Remove status code from body
    local responseBody = table.concat(lines, "\n")
    
    -- Determine success based on status code
    local isSuccess = statusCode >= 200 and statusCode < 300
    
    return {
        Success = isSuccess,
        StatusCode = statusCode,
        StatusMessage = isSuccess and "OK" or "HTTP Error",
        Headers = {},
        Body = responseBody
    }
end

return RealHttpService