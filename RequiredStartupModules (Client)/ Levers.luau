local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Info = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

local SoundModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("SoundModule"))

local Levers = {}

Levers.__index = Levers

function Levers:PullDown()
	
	if not self.Debounce then
		self.Debounce = true
		
		self.Prompt.Enabled = false
		SoundModule.PlaySound(ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("ObjectSounds"):WaitForChild("Button"))

		local Tween = TweenService:Create(self.Grip.PrimaryPart, Info, {CFrame = self.OriginalCFrame - Vector3.new(0, 1, 0)})
		Tween:Play()
		
		Tween.Completed:Once(function()
			self.Debounce = false
		end)
	end
end

function Levers.new(Lever)
	local self = setmetatable({
		Debounce = false,
		Lever = Lever,
		Event = Lever:FindFirstChildOfClass("RemoteEvent"),
		Grip = Lever:FindFirstChild("Grip"),
		Prompt = Lever:FindFirstChild("ProximityPrompt", true)
	}, Levers)
	
	self.OriginalCFrame = self.Grip.PrimaryPart.CFrame
	self.Event.OnClientEvent:Connect(function(EventLever)
		if EventLever == self.Lever then
			self:PullDown()

		end
	end)

	return self
end

function Levers.Init()
	for Index, Lever in pairs(CollectionService:GetTagged("Levers")) do
		Levers.new(Lever)
	end
end

return Levers

 
