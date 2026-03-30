local CONFIG: {[string]: {["Enabled" | "Disabled" | "CustomByName"]: any}} = {
	["MainSelection"] = {
		["Enabled"] = {
			["BaseObject"] = {
				["BackgroundColor3"] = Color3.fromRGB(59, 165, 93),
				["TextColor3"] = Color3.fromRGB(255, 255, 255)
			},
			["UIStroke"] = {
				["Color"] = Color3.fromRGB(59, 165, 93)
			}
		},
		["Disabled"] = {
			["BaseObject"] = {
				["BackgroundColor3"] = Color3.fromRGB(43, 45, 49),
				["TextColor3"] = Color3.fromRGB(148, 155, 164)
			},
			["UIStroke"] = {
				["Color"] = Color3.fromRGB(58, 60, 66)
			}
		},
		["CustomByName"] = {
			["Suggestion"] = {
				["Enabled"] = {
					["BaseObject"] = {
						["BackgroundColor3"] = Color3.fromRGB(59, 165, 93),
						["TextColor3"] = Color3.fromRGB(255, 255, 255)
					},
					["UIStroke"] = {
						["Color"] = Color3.fromRGB(59, 165, 93)
					}
				},
			},
			["Bug"] = {
				["Enabled"] = {
					["BaseObject"] = {
						["BackgroundColor3"] = Color3.fromRGB(237, 66, 69),
						["TextColor3"] = Color3.fromRGB(255, 255, 255)
					},
					["UIStroke"] = {
						["Color"] = Color3.fromRGB(237, 66, 69)
					}
				},
			},
			["Support"] = {
				["Enabled"] = {
					["BaseObject"] = {
						["BackgroundColor3"] = Color3.fromRGB(88, 101, 242),
						["TextColor3"] = Color3.fromRGB(255, 255, 255)
					},
					["UIStroke"] = {
						["Color"] = Color3.fromRGB(88, 101, 242)
					}
				},
			}
		}
	}
}


local ButtonColourer = {}

local Buttons: {[string]: {TextButton | ImageButton}} = {}

function ButtonColourer.AddButton(object: Instance, group: string)
	if not group then group = "Any" end

	if not CONFIG[group] then return end

	if not (object:IsA("TextButton") or object:IsA("ImageButton")) then return end

	if not Buttons[group] then
		Buttons[group] = {}
	end

	table.insert(Buttons[group], object)

	object.MouseButton1Click:Connect(function()
		local config = CONFIG[group]
		local custConfig = config


		-- Only runs for enabled, disabled has no unique customisations rn
		if config["CustomByName"] and config["CustomByName"][object.Name] then
			custConfig = config["CustomByName"][object.Name]
		end

		for objectToEffect, propertysToChange in custConfig["Enabled"] do
			if objectToEffect == "BaseObject" then
				for property, newvalue in propertysToChange do
					object[property] = newvalue
				end
				continue
			end
			if object[objectToEffect] then
				for property, newvalue in propertysToChange do
					object[objectToEffect][property] = newvalue
				end
			end
		end

		for _, button in Buttons[group] do
			if button ~= object then
				for objectToEffect, propertysToChange in config["Disabled"] do
					if objectToEffect == "BaseObject" then
						for property, newvalue in propertysToChange do
							button[property] = newvalue
						end
						continue
					end
					if button[objectToEffect] then
						for property, newvalue in propertysToChange do
							button[objectToEffect][property] = newvalue
						end
					end
				end
			end
		end
	end)
end

function ButtonColourer.ResetButtons(group)
	local config = CONFIG[group]

	for _, button in Buttons[group] do
		for objectToEffect, propertysToChange in config["Disabled"] do
			if objectToEffect == "BaseObject" then
				for property, newvalue in propertysToChange do
					button[property] = newvalue
				end
				continue
			end
			if button[objectToEffect] then
				for property, newvalue in propertysToChange do
					button[objectToEffect][property] = newvalue
				end
			end
		end
	end
end

return ButtonColourer
