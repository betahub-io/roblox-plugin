script.Parent.MouseButton1Click:Connect(function()
	local betahubUi = game.Players.LocalPlayer.PlayerGui:WaitForChild("BetahubFeedbackUi")

	if betahubUi.ConfirmPrompt.Visible == true then
		warn("Confirm Prompt is still open")
		return
	end

	betahubUi.MainFrame.Visible = not betahubUi.MainFrame.Visible
end)
