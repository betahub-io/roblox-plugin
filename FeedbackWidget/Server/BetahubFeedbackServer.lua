--[[ CONFIGURATION ]]

API_BASE_URL="https://app.betahub.io"
RATE_LIMIT = 20 -- In seconds
RESET_RATE_LIMIT_ON_FAILURE = false -- Recommended to keep this false

--[[ Code ]]
type Data = {
	ReportingType: "bug" | "suggestion",
	ReportDetails: {["ReproSteps" | "Description"]: string},
	Logs: string?
}

type RequestData = {
	ReportingType: "bug" | "suggestion",
	Body: {[string]: string}
}

local rateLimit : {[number]: number} = {}

local HttpService = game:GetService("HttpService")
local PROJECT_ID = HttpService:GetSecret("BH_PROJECT_ID")
local AUTH_TOKEN = HttpService:GetSecret("BH_AUTH_TOKEN")

local ENDPOINT_MAP = {
	["bug"] = "issues",
	["suggestion"] = "feature_requests"
}

local function submitRequest(data: RequestData)
	local endpoint = ENDPOINT_MAP[data.ReportingType]
	local url
	if type(PROJECT_ID) == "string" then
		url = API_BASE_URL .. "/projects/" .. PROJECT_ID .. "/" .. endpoint .. ".json"
	else
		url = PROJECT_ID:AddPrefix(API_BASE_URL .. "/projects/"):AddSuffix("/" .. endpoint .. ".json")
	end

	local function urlEncode(toEncode)
		local chunks = {}
		for key, entry in toEncode do
			table.insert(chunks, HttpService:UrlEncode(key) .. "=" .. HttpService:UrlEncode(entry))
		end
		return table.concat(chunks, "&")
	end

	local postBody = urlEncode(data.Body)

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/x-www-form-urlencoded",
				["Authorization"] = type(AUTH_TOKEN) == "string" and ("FormUser " .. AUTH_TOKEN) or AUTH_TOKEN:AddPrefix("FormUser "),
				["BetaHub-Project-ID"] = PROJECT_ID
			},
			Body = postBody
		})
	end)

	if success then
		if response.Success then
			local parseOk, parsed = pcall(function()
				return HttpService:JSONDecode(response.Body)
			end)
			if parseOk and parsed and parsed.url then
				print("Betahub Feedback submitted:", parsed.url)
			end
			return true, parseOk and parsed or nil
		else
			warn("Betahub Feedback Request Failure!", response.StatusCode, response.StatusMessage)
			local errorMsg = nil
			local parseOk, parsed = pcall(function()
				return HttpService:JSONDecode(response.Body)
			end)
			if parseOk and parsed then
				errorMsg = parsed.message or parsed.error or parsed.errors
				if type(errorMsg) == "table" then
					errorMsg = table.concat(errorMsg, ", ")
				end
			end
			return false, errorMsg
		end
	else
		warn("Betahub Feedback Request Failure - HTTP FAILURE")
		return false, "Could not connect to server. Please try again later."
	end
end

local function uploadLogs(issueId: number, jwtToken: string, logs: string)
	local url
	if type(PROJECT_ID) == "string" then
		url = API_BASE_URL .. "/projects/" .. PROJECT_ID .. "/issues/g-" .. tostring(issueId) .. "/log_files.json"
	else
		url = PROJECT_ID:AddPrefix(API_BASE_URL .. "/projects/"):AddSuffix("/issues/g-" .. tostring(issueId) .. "/log_files.json")
	end

	local function urlEncode(toEncode)
		local chunks = {}
		for key, entry in toEncode do
			table.insert(chunks, HttpService:UrlEncode(key) .. "=" .. HttpService:UrlEncode(entry))
		end
		return table.concat(chunks, "&")
	end

	local postBody = urlEncode({
		["log_file[contents]"] = logs,
		["log_file[name]"] = "roblox_console.log"
	})

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/x-www-form-urlencoded",
				["Authorization"] = type(AUTH_TOKEN) == "string" and ("FormUser " .. AUTH_TOKEN .. "," .. jwtToken) or AUTH_TOKEN:AddPrefix("FormUser "):AddSuffix("," .. jwtToken),
				["BetaHub-Project-ID"] = PROJECT_ID
			},
			Body = postBody
		})
	end)

	if success and response.Success then
		return true
	else
		warn("Betahub Feedback - Log upload failed")
		return false
	end
end


local Replicated = game:GetService("ReplicatedStorage")

local Remote = Replicated:WaitForChild("BetahubFeedback")

Remote.OnServerInvoke = function(plr, data: Data)
	--Commented out prints are for testing, no normal user should hit these circumstances

	if not (data.ReportingType and data.ReportDetails) then
		--print("Betahub Feedback - Missing data")
		return false
	end

	if data.ReportingType ~= "bug" and data.ReportingType ~= "suggestion" then
		--print("Betahub Feedback - Invalid Reporting Type")
		return false
	end

	if not (data.ReportDetails.Description and data.ReportDetails.Description ~= "") then
		--print("Betahub Feedback - Missing Description")
		return false
	end

	if data.ReportingType == "bug" and
		not (data.ReportDetails.ReproSteps and data.ReportDetails.ReproSteps ~= "")
	then
		--print("Betahub Feedback - Missing Reproduction steps")
		return false
	end

	if rateLimit[plr.UserId] and os.difftime(os.time(), rateLimit[plr.UserId]) < RATE_LIMIT then return false end

	rateLimit[plr.UserId] = os.time()

	local res
	local errorMsg

	if data.ReportingType == "bug" then
		local bodyToSend = {
			["issue[description]"] = data.ReportDetails.Description,
			["issue[unformatted_steps_to_reproduce]"] = data.ReportDetails.ReproSteps,
			["issue[source]"] = "in-game",
			["issue[custom][roblox_id]"] = tostring(plr.UserId)
		}

		local responseData
		res, responseData = submitRequest({
			["ReportingType"] = data.ReportingType,
			["Body"] = bodyToSend
		})

		if res and responseData and data.Logs and data.Logs ~= "" then
			local issueId = responseData.id
			local jwtToken = responseData.token
			if issueId and jwtToken then
				uploadLogs(issueId, jwtToken, data.Logs)
			end
		elseif not res then
			errorMsg = responseData
		end
	end

	if data.ReportingType == "suggestion" then
		local bodyToSend = {
			["feature_request[description]"] = data.ReportDetails.Description,
			["feature_request[custom][roblox_id]"] = tostring(plr.UserId)
		}

		local responseData
		res, responseData = submitRequest({
			["ReportingType"] = data.ReportingType,
			["Body"] = bodyToSend
		})

		if not res then
			errorMsg = responseData
		end
	end

	-- reset ratelimit for user if it fails so they can try again
	-- this is dangerous as players can spam requests if betahub is down,
	-- maxing out http requests for the game or expereince (i forgot what the rate limits are)
	if not res and RESET_RATE_LIMIT_ON_FAILURE then rateLimit[plr.UserId] = nil end

	return res, RATE_LIMIT - os.difftime(os.time(), rateLimit[plr.UserId]), errorMsg
end

game.Players.PlayerRemoving:Connect(function(plr)
	rateLimit[plr.UserId] = nil
end)
