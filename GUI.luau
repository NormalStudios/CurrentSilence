local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")


local Player = Players.LocalPlayer

local PlayerGui = Player.PlayerGui

local GUI = {}



function GUI.Init()
	local speed = 1

	RunService.PreRender:Connect(function(dt)

		for Index, GradientParent in pairs(CollectionService:GetTagged("RotateColor")) do

			local FindGradient = GradientParent:FindFirstChildOfClass("UIGradient")
			if FindGradient == nil then continue end
			FindGradient.Offset = Vector2.new(FindGradient.Offset.X + (speed*dt), 0)
			if FindGradient.Offset.X >= 1 then
				local isRotated = (FindGradient.Rotation == 180)
				FindGradient.Rotation = isRotated and 0 or 180; FindGradient.Offset = Vector2.new(-1, 0) --isRotated and -0.5 or -1
			end
		end

	end)

end

return GUI
