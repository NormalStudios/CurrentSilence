local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local ItemsClient = {}

function ItemsClient.ViabilityCheck()
	local Humanoid = Player.Character and Player.Character:FindFirstChild("Humanoid")

	if Humanoid and Humanoid.Health > 0 then
		return Humanoid
	end
end

function ItemsClient.StimActivated(Stim)
	local Humanoid = ItemsClient.ViabilityCheck()
	if not Humanoid then return end

	local Camera = workspace.CurrentCamera
	local Tweens = {}

	local function PlayTweens()
		for Index, Tween in pairs(Tweens) do
			Tween:Play()
			Tween.Completed:Once(function()
				Tween:Destroy()
				Tweens[Index] = nil
			end)
		end
	end

	local DefaultInfo = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	local NewFOV = _G.DefaultFOV + 7.5
	_G.DefaultFOV = NewFOV

	Tweens.FOV = TweenService:Create(Camera, DefaultInfo, {FieldOfView = Camera.FieldOfView + 7.5})
	Humanoid.WalkSpeed = Humanoid.WalkSpeed + 5

	for Index, Speed in pairs(_G.WalkSettings) do
		_G.WalkSettings[Index] = Speed + 5
	end

	PlayTweens()

	task.delay(15, function()
		for Index, Speed in pairs(_G.WalkSettings) do
			_G.WalkSettings[Index] = Speed - 5
		end

		Humanoid.WalkSpeed = Humanoid.WalkSpeed - 5
		Tweens.FOV = TweenService:Create(Camera, DefaultInfo, {FieldOfView = Camera.FieldOfView + 7.5})

		PlayTweens()
	end)
end

function ItemsClient.ThreatSensorActivated(Model)
	local Humanoid = ItemsClient.ViabilityCheck()
	if not Humanoid then return end

	local FlashDuration = 9
	local FlashInterval = 0.5
	local AITaggedModels = CollectionService:GetTagged("AI")

	local Highlights = {}

	for _, AIModel in ipairs(AITaggedModels) do
		local Highlight = Instance.new("Highlight")
		Highlight.FillColor = Color3.new(1, 0, 0)
		Highlight.OutlineColor = Color3.new(0, 0, 0)
		Highlight.OutlineTransparency = 1
		Highlight.FillTransparency = 0.5
		Highlight.Adornee = AIModel
		Highlight.Parent = AIModel
		table.insert(Highlights, Highlight)
	end

	local TotalFlashes = math.floor(FlashDuration / FlashInterval)
	for i = 0, TotalFlashes - 1 do
		task.delay(i * FlashInterval, function()
			for _, Highlight in ipairs(Highlights) do
				Highlight.Enabled = (i % 2 == 0)
			end
		end)
	end

	task.delay(FlashDuration, function()
		for _, Highlight in ipairs(Highlights) do
			Highlight:Destroy()
		end
		ReplicatedStorage.RemoteEvents.Items.ThreatSensorActivated:FireServer(Model)
	end)
end

function ItemsClient.Init()
	local ItemEvents = ReplicatedStorage.RemoteEvents.Items

	ItemEvents.StimActivated.OnClientEvent:Connect(function(Stim)
		print("Client activated stim")
		ItemsClient.StimActivated(Stim)
	end)

	ItemEvents.ThreatSensorActivated.OnClientEvent:Connect(function(Model)
		ItemsClient.ThreatSensorActivated(Model)
	end)
end

return ItemsClient
