-- Handles all server side logic with the buttons
-- Any animations/sounds should be and will be played on the client

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Info = TweenInfo.new(.2, Enum.EasingStyle.Exponential)

local SoundModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("SoundModule"))

local Buttons = {}

Buttons.__index = Buttons

function Buttons:Press()
	task.spawn(function()
		if not self.Debounce then
			self.Debounce = true
			self.Prompt.Enabled = false
			
			local Tween = TweenService:Create(self.Button.PrimaryPart, Info, {Position = self.Button.PrimaryPart.Position - Vector3.new(0, 0, 0.14)})
			Tween:Play()

			Tween.Completed:Once(function()
				task.wait(0.05)

				local Tween2 = TweenService:Create(self.Button.PrimaryPart, Info, {Position = self.Button.PrimaryPart.Position + Vector3.new(0,0,0.14)})
				Tween2:Play()

				Tween2.Completed:Once(function()
					Tween2:Destroy()
					Tween:Destroy()
					
					self.Debounce = false
					self.Prompt.Enabled = true

				end)
			end)
		end
		
	end)
end

function Buttons:ChangeWiring()
	local Material
	
	if self.Button:GetAttribute("Power") == true then
		Material = Enum.Material.Neon
	else
		Material = Enum.Material.Foil
	end
	
	for Index, Descendant in pairs(self.Wires:GetDescendants()) do
		if Descendant:IsA("BasePart") or Descendant:IsA("MeshPart") then
			Descendant.Material = Material
		end
	end
end

function Buttons.new(Button : Model)
	local self = setmetatable({
		Debounce = false,
		Button = Button,
		Prompt = Button:FindFirstChild("ProximityPrompt", true),
		Wires = Button:FindFirstChild("Wires")
	}, Buttons)
	
	
	
	self.Prompt.Triggered:Connect(function()
		warn(self.Button, self, self.Button)
		SoundModule.PlaySound(ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("ObjectSounds"):WaitForChild("Button"))
		self:Press()
	end)
	
	self:ChangeWiring()
	
	self.Button:GetAttributeChangedSignal("Power"):Connect(function()
		self:ChangeWiring()
	end)

	return self
end

function Buttons.Init()
	for Index, Button in pairs(CollectionService:GetTagged("Button")) do
		Buttons.new(Button)
	end
end

return Buttons
