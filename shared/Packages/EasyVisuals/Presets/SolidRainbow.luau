local TextEffects = require(script.Parent.Parent);

return function(Gradient, speed, size, customColor, customTransparency)
	-- speed controls cycle speed (lower = faster)
	-- size controls spread (lower = more solid)

	local cycleSpeed = speed or 0.5
	local spread = (size or 1) * 0.1 -- Convert size to spread (1-10 -> 0.1-1.0)

	Gradient:SetOffsetSpeed(0) -- We don't use offset for this effect

	-- Custom update loop for hue cycling
	local RunService = game:GetService("RunService")
	local hue = 0

	-- Store the connection on the gradient for cleanup
	local connection = RunService.RenderStepped:Connect(function(dt)
		hue = (hue + dt * cycleSpeed) % 1

		if spread <= 0.05 then
			Gradient:SetColor(ColorSequence.new(Color3.fromHSV(hue, 1, 1)))
		else
			local keypoints = {}
			for i = 0, 4 do
				local t = i / 4
				local hueOffset = (t - 0.5) * spread
				local color = Color3.fromHSV((hue + hueOffset) % 1, 1, 1)
				table.insert(keypoints, ColorSequenceKeypoint.new(t, color))
			end
			Gradient:SetColor(ColorSequence.new(keypoints))
		end
	end)

	return connection -- Return for cleanup
end