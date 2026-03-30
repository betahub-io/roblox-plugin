local function AddTextBox(object: TextBox)
	local firstSize = object.Size.Y.Offset

	object:GetPropertyChangedSignal("TextFits"):Connect(function()
		while not object.TextFits do
			object.Size = object.Size + UDim2.fromOffset(0, object.TextSize)
		end
	end)

	object:GetPropertyChangedSignal("TextBounds"):Connect(function()
		if not object.TextFits then return end

		if (object.TextBounds.Y + 10) > firstSize then
			object.Size = UDim2.new(1, 0, 0, 10 + object.TextBounds.Y)
		else
			object.Size = UDim2.new(1, 0, 0, firstSize)
		end
	end)
end

return AddTextBox
