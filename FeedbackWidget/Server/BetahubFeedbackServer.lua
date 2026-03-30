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
local LogService = game:GetService("LogService")

local PROJECT_ID, AUTH_TOKEN

local okId, resultId = pcall(function() return HttpService:GetSecret("BH_PROJECT_ID") end)
local okToken, resultToken = pcall(function() return HttpService:GetSecret("BH_AUTH_TOKEN") end)

if okId and okToken then
	PROJECT_ID = resultId
	AUTH_TOKEN = resultToken
else
	warn("")
	warn("========================================")
	warn("  BETAHUB FEEDBACK - CONFIGURATION ERROR")
	warn("========================================")
	if not okId then
		warn("  Missing secret: BH_PROJECT_ID")
	end
	if not okToken then
		warn("  Missing secret: BH_AUTH_TOKEN")
	end
	warn("")
	warn("  Go to File > Experience Settings > Security > Secrets")
	warn("  and add both BH_PROJECT_ID and BH_AUTH_TOKEN.")
	warn("")
	warn("  Get these from your BetaHub project:")
	warn("  Settings > Integrations > Auth Tokens")
	warn("========================================")
	warn("")
end

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

local function uploadLogs(issueId: number, jwtToken: string, logs: string, fileName: string, developerPrivate: boolean?)
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

	local body = {
		["log_file[contents]"] = logs,
		["log_file[name]"] = fileName
	}
	if developerPrivate then
		body["log_file[developer_private]"] = "true"
	end
	local postBody = urlEncode(body)

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

		if res and responseData then
			local issueId = responseData.id
			local jwtToken = responseData.token
			if issueId and jwtToken then
				-- Upload client logs
				if data.Logs and data.Logs ~= "" then
					uploadLogs(issueId, jwtToken, data.Logs, "roblox_client_console.log")
				end

				-- Upload server logs (best-effort, may be empty in production)
				local ok, logHistory = pcall(function()
					return LogService:GetLogHistory()
				end)
				if ok and logHistory and #logHistory > 0 then
					local entries = {}
					for _, entry in logHistory do
						local ts = entry.timestamp and os.date("%Y-%m-%d %H:%M:%S", entry.timestamp) or "?"
						table.insert(entries, string.format("[%s] (%s): %s", ts, tostring(entry.messageType), entry.message))
					end
					uploadLogs(issueId, jwtToken, table.concat(entries, "\n"), "roblox_server_console.log", true)
				end
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
