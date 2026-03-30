local Replicated = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")

local Remote = Replicated:WaitForChild("BetahubFeedback")

local logBuffer: {string} = {}
local MAX_LOG_ENTRIES = 200

LogService.MessageOut:Connect(function(message, messageType)
	local entry = string.format("[%s] (%s): %s", os.date("%Y-%m-%d %H:%M:%S"), tostring(messageType), message)
	table.insert(logBuffer, entry)
	if #logBuffer > MAX_LOG_ENTRIES then
		table.remove(logBuffer, 1)
	end
end)

local selectedFeedBackType: string? = nil

local MIN_CHARS = {
	["Bug"] = 50,
	["Suggestion"] = 80
}

local AutoTextBoxScaler = require(script.AutoTextBoxScaler)
local ButtonColourer = require(script.ButtonColourer)

local content = script.Parent.MainFrame.Content

local FeedbackInput = content.FeedbackInput
local FeedbackType = content.FeedbackType.Selection
local StepsToRepro = content.StepsToReproInput
local SubmitFeedback = content.SubmitFeedback

local descCounter = FeedbackInput:WaitForChild("CharCounter")
local stepsCounter = StepsToRepro:WaitForChild("CharCounter")

local COLOR_MET = Color3.fromRGB(87, 166, 96)
local COLOR_UNMET = Color3.fromRGB(148, 155, 164)

AutoTextBoxScaler(FeedbackInput.InputBox)
AutoTextBoxScaler(StepsToRepro.InputBox)

ButtonColourer.AddButton(FeedbackType.Suggestion, "MainSelection")
ButtonColourer.AddButton(FeedbackType.Bug, "MainSelection")

FeedbackType.Suggestion.MouseButton1Click:Connect(function()
	selectedFeedBackType = "Suggestion"
	SubmitFeedback.Visible = true
	StepsToRepro.Visible = false
	FeedbackInput.Visible = true
	SubmitFeedback.Visible = true
	script.Parent.MainFrame.Content.Bar.Visible = true
	updateCounters()
	checkIfCanSubmit()
end)

FeedbackType.Bug.MouseButton1Click:Connect(function()
	selectedFeedBackType = "Bug"
	StepsToRepro.Visible = true
	FeedbackInput.Visible = true
	SubmitFeedback.Visible = true
	script.Parent.MainFrame.Content.Bar.Visible = true
	updateCounters()
	checkIfCanSubmit()
end)

function disableSubmit()
	SubmitFeedback.Submit.Active = false
	SubmitFeedback.Submit.Selectable = false
	SubmitFeedback.Submit.Interactable = false

	SubmitFeedback.Submit.BackgroundColor3 = Color3.fromRGB(58, 60, 66)
	SubmitFeedback.Submit.TextColor3 = Color3.fromRGB(90, 93, 100)
end

function enableSubmit()
	SubmitFeedback.Submit.Active = true
	SubmitFeedback.Submit.Selectable = true
	SubmitFeedback.Submit.Interactable = true

	SubmitFeedback.Submit.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	SubmitFeedback.Submit.TextColor3 = Color3.fromRGB(255, 255, 255)
end

function updateCounters()
	local minChars = MIN_CHARS[selectedFeedBackType] or 50
	local descLen = #FeedbackInput.InputBox.Text
	local remaining = minChars - descLen

	if remaining > 0 then
		if descLen == 0 then
			descCounter.Text = minChars .. " chars min"
		else
			descCounter.Text = remaining .. " more"
		end
		descCounter.TextColor3 = COLOR_UNMET
		descCounter.Visible = true
	else
		descCounter.Text = "\u{2713}"
		descCounter.TextColor3 = COLOR_MET
		descCounter.Visible = true
	end

	if selectedFeedBackType == "Bug" then
		local stepsLen = #StepsToRepro.InputBox.Text
		if stepsLen > 0 then
			stepsCounter.Text = "\u{2713}"
			stepsCounter.TextColor3 = COLOR_MET
		else
			stepsCounter.Text = "Required"
			stepsCounter.TextColor3 = COLOR_UNMET
		end
		stepsCounter.Visible = true
	else
		stepsCounter.Visible = false
	end
end

function checkIfCanSubmit()
	local minChars = MIN_CHARS[selectedFeedBackType] or 50

	updateCounters()

	if #FeedbackInput.InputBox.Text < minChars then
		disableSubmit()
		return
	end

	if selectedFeedBackType == "Bug" and StepsToRepro.InputBox.Text == "" then
		disableSubmit()
		return
	end

	enableSubmit()
end

FeedbackInput.InputBox:GetPropertyChangedSignal("Text"):Connect(function()
	checkIfCanSubmit()
end)

StepsToRepro.InputBox:GetPropertyChangedSignal("Text"):Connect(function()
	checkIfCanSubmit()
end)

SubmitFeedback.Submit.MouseButton1Click:Connect(function()
	if selectedFeedBackType == nil then return end

	disableSubmit()
	SubmitFeedback.Submit.Text = "Submitting..."

	local reportData = {
		ReportingType = string.lower(selectedFeedBackType),
		ReportDetails = {
			Description = FeedbackInput.InputBox.Text,
			ReproSteps = StepsToRepro.InputBox.Text -- ignored by server if report isnt bug
		}
	}

	if selectedFeedBackType == "Bug" then
		reportData.Logs = table.concat(logBuffer, "\n")
	end

	local res, rateLimit, errorMsg = Remote:InvokeServer(reportData)

	if rateLimit and rateLimit > 0 then
		SubmitFeedback.Submit.Text = `Wait {rateLimit}s..`
		disableSubmit()
		task.spawn(function()
			task.wait(rateLimit)
			enableSubmit()
			SubmitFeedback.Submit.Text = "Submit Feedback"
		end)
	else
		enableSubmit()
		SubmitFeedback.Submit.Text = "Submit Feedback"
	end

	if res then
		script.Parent.MainFrame.Visible = false
		script.Parent.ConfirmPrompt.Visible = true
	else
		local desc = script.Parent.ErrorPrompt.Content.Warning.Description
		if errorMsg and errorMsg ~= "" then
			desc.Text = errorMsg
		else
			desc.Text = "There was an error submitting your feedback. Report this to the developer or go back and try again."
		end
		script.Parent.MainFrame.Visible = false
		script.Parent.ErrorPrompt.Visible = true
	end


end)

script.Parent.ConfirmPrompt.Content.CloseSection.Close.MouseButton1Click:Connect(function()
	script.Parent.ConfirmPrompt.Visible = false
	script.Parent.MainFrame.Content.Bar.Visible = false
	ButtonColourer.ResetButtons("MainSelection")
	FeedbackInput.InputBox.Text = ""
	StepsToRepro.InputBox.Text = ""
	selectedFeedBackType = nil
	SubmitFeedback.Visible = false
	StepsToRepro.Visible = false
	FeedbackInput.Visible = false
	SubmitFeedback.Visible = false
end)

script.Parent.ErrorPrompt.Content.CloseSection.Close.MouseButton1Click:Connect(function()
	script.Parent.ErrorPrompt.Visible = false
	script.Parent.MainFrame.Content.Bar.Visible = false
	ButtonColourer.ResetButtons("MainSelection")
	FeedbackInput.InputBox.Text = ""
	StepsToRepro.InputBox.Text = ""
	selectedFeedBackType = nil
	SubmitFeedback.Visible = false
	StepsToRepro.Visible = false
	FeedbackInput.Visible = false
	SubmitFeedback.Visible = false
end)

script.Parent.ErrorPrompt.Content.CloseSection.GoBack.MouseButton1Click:Connect(function()
	script.Parent.ErrorPrompt.Visible = false
	script.Parent.MainFrame.Visible = true
end)

script.Parent.MainFrame.Content.SubmitFeedback.Cancel.MouseButton1Click:Connect(function()
	script.Parent.MainFrame.Visible = false
	script.Parent.MainFrame.Content.Bar.Visible = false
	ButtonColourer.ResetButtons("MainSelection")
	FeedbackInput.InputBox.Text = ""
	StepsToRepro.InputBox.Text = ""
	selectedFeedBackType = nil
	SubmitFeedback.Visible = false
	StepsToRepro.Visible = false
	FeedbackInput.Visible = false
	SubmitFeedback.Visible = false
end)
