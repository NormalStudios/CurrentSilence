-- Services
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- Settings
local FAN_ROTATION_SPEED = 145 -- degrees per second

local Fans = {}

function Fans.LoopThroughFans()
	

	-- Main loop
	RunService.Heartbeat:Connect(function(deltaTime)
		for _, fan in pairs(CollectionService:GetTagged("Fan")) do
			if fan:IsA("BasePart") or fan:IsA("MeshPart") then
				local currentCFrame = fan.CFrame
				local rotation = CFrame.Angles(0, 0, math.rad(FAN_ROTATION_SPEED * deltaTime))
				fan.CFrame = currentCFrame * rotation
			end
		end
	end)

end

function Fans.Init()
	Fans.LoopThroughFans()
end

return Fans
