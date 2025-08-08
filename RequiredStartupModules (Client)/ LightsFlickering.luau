local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local FlickeringLightsClient = {}
FlickeringLightsClient.__index = FlickeringLightsClient

local LightTag = "Light"

local FlickerSettings = {
	LooseWire = {Min = 0.05, Max = 0.2},
	Frequent = {Min = 1.5, Max = 3},
	Occasional = {Min = 5, Max = 8},
}

local FlickerWeights = {
	LooseWire = 1,
	Frequent = 4,
	Occasional = 5,
}

local WeightedTypes = {}
do
	for FlickerType, Weight in pairs(FlickerWeights) do
		for _ = 1, Weight do
			table.insert(WeightedTypes, FlickerType)
		end
	end
end

local function AssignRandomFlickerType(Model)
	if not Model:GetAttribute("FlickerType") then
		local RandomType = WeightedTypes[math.random(1, #WeightedTypes)]
		Model:SetAttribute("FlickerType", RandomType)
	end
end

local function GetNeonParts(Model)
	local NeonParts = {}
	for _, Descendant in ipairs(Model:GetDescendants()) do
		if Descendant:IsA("BasePart") and Descendant.Material == Enum.Material.Neon then
			table.insert(NeonParts, Descendant)
		end
	end
	return NeonParts
end

local function GetEmitters(Model)
	local Emitters = {}
	for _, Descendant in ipairs(Model:GetDescendants()) do
		if Descendant:IsA("Light") or Descendant:IsA("ParticleEmitter") or Descendant:IsA("Beam") then
			table.insert(Emitters, Descendant)
		end
	end
	return Emitters
end

local function LerpColor3(A, B, T)
	return Color3.new(
		A.R + (B.R - A.R) * T,
		A.G + (B.G - A.G) * T,
		A.B + (B.B - A.B) * T
	)
end

local function SmoothFlicker(NeonParts, Emitters, OriginalColors)
	for t = 0, 1, 0.2 do
		for _, Part in ipairs(NeonParts) do
			if Part:IsDescendantOf(game) and OriginalColors[Part] then
				Part.Color = LerpColor3(OriginalColors[Part], Color3.new(0, 0, 0), t)
			end
		end
		RunService.RenderStepped:Wait()
	end

	for _, Emitter in ipairs(Emitters) do
		if Emitter:IsDescendantOf(game) then
			Emitter.Enabled = false
		end
	end

	task.wait(0.05)

	for t = 0, 1, 0.2 do
		for _, Part in ipairs(NeonParts) do
			if Part:IsDescendantOf(game) and OriginalColors[Part] then
				Part.Color = LerpColor3(Color3.new(0, 0, 0), OriginalColors[Part], t)
			end
		end
		RunService.RenderStepped:Wait()
	end

	for _, Emitter in ipairs(Emitters) do
		if Emitter:IsDescendantOf(game) then
			Emitter.Enabled = true
		end
	end
end

local function FlickerLight(FlickerType, NeonParts, Emitters)
	local Settings = FlickerSettings[FlickerType]
	if not Settings then return end

	local OriginalColors = {}
	for _, Part in ipairs(NeonParts) do
		if Part:IsDescendantOf(game) then
			OriginalColors[Part] = Part.Color
		end
	end

	coroutine.wrap(function()
		while true do
			task.wait(math.random(Settings.Min * 100, Settings.Max * 100) / 100)

			local BurstCount = math.random(1, 4)
			for _ = 1, BurstCount do
				SmoothFlicker(NeonParts, Emitters, OriginalColors)
				task.wait(math.random(5, 15) / 100) -- 0.05–0.15s between bursts
			end
		end
	end)()
end

function FlickeringLightsClient.Init()
	for _, Model in ipairs(CollectionService:GetTagged(LightTag)) do
		if Model:IsA("Model") then
			AssignRandomFlickerType(Model)
			local FlickerType = Model:GetAttribute("FlickerType")

			local NeonParts = GetNeonParts(Model)
			local Emitters = GetEmitters(Model)

			FlickerLight(FlickerType, NeonParts, Emitters)
		end
	end
end

return FlickeringLightsClient
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local FlickeringLightsClient = {}
FlickeringLightsClient.__index = FlickeringLightsClient

local LightTag = "Light"

local FlickerSettings = {
	LooseWire = {Min = 0.05, Max = 0.2},
	Frequent = {Min = 1.5, Max = 3},
	Occasional = {Min = 5, Max = 8},
}

local FlickerWeights = {
	LooseWire = 1,
	Frequent = 4,
	Occasional = 5,
}

local WeightedTypes = {}
do
	for FlickerType, Weight in pairs(FlickerWeights) do
		for _ = 1, Weight do
			table.insert(WeightedTypes, FlickerType)
		end
	end
end

local function AssignRandomFlickerType(Model)
	if not Model:GetAttribute("FlickerType") then
		local RandomType = WeightedTypes[math.random(1, #WeightedTypes)]
		Model:SetAttribute("FlickerType", RandomType)
	end
end

local function GetNeonParts(Model)
	local NeonParts = {}
	for _, Descendant in ipairs(Model:GetDescendants()) do
		if Descendant:IsA("BasePart") and Descendant.Material == Enum.Material.Neon then
			table.insert(NeonParts, Descendant)
		end
	end
	return NeonParts
end

local function GetEmitters(Model)
	local Emitters = {}
	for _, Descendant in ipairs(Model:GetDescendants()) do
		if Descendant:IsA("Light") or Descendant:IsA("ParticleEmitter") or Descendant:IsA("Beam") then
			table.insert(Emitters, Descendant)
		end
	end
	return Emitters
end

local function LerpColor3(A, B, T)
	return Color3.new(
		A.R + (B.R - A.R) * T,
		A.G + (B.G - A.G) * T,
		A.B + (B.B - A.B) * T
	)
end

local function SmoothFlicker(NeonParts, Emitters, OriginalColors)
	for t = 0, 1, 0.2 do
		for _, Part in ipairs(NeonParts) do
			if Part:IsDescendantOf(game) and OriginalColors[Part] then
				Part.Color = LerpColor3(OriginalColors[Part], Color3.new(0, 0, 0), t)
			end
		end
		RunService.RenderStepped:Wait()
	end

	for _, Emitter in ipairs(Emitters) do
		if Emitter:IsDescendantOf(game) then
			Emitter.Enabled = false
		end
	end

	task.wait(0.05)

	for t = 0, 1, 0.2 do
		for _, Part in ipairs(NeonParts) do
			if Part:IsDescendantOf(game) and OriginalColors[Part] then
				Part.Color = LerpColor3(Color3.new(0, 0, 0), OriginalColors[Part], t)
			end
		end
		RunService.RenderStepped:Wait()
	end

	for _, Emitter in ipairs(Emitters) do
		if Emitter:IsDescendantOf(game) then
			Emitter.Enabled = true
		end
	end
end

local function FlickerLight(FlickerType, NeonParts, Emitters)
	local Settings = FlickerSettings[FlickerType]
	if not Settings then return end

	local OriginalColors = {}
	for _, Part in ipairs(NeonParts) do
		if Part:IsDescendantOf(game) then
			OriginalColors[Part] = Part.Color
		end
	end

	coroutine.wrap(function()
		while true do
			task.wait(math.random(Settings.Min * 100, Settings.Max * 100) / 100)

			local BurstCount = math.random(1, 4)
			for _ = 1, BurstCount do
				SmoothFlicker(NeonParts, Emitters, OriginalColors)
				task.wait(math.random(5, 15) / 100) -- 0.05–0.15s between bursts
			end
		end
	end)()
end

function FlickeringLightsClient.Init()
	for _, Model in ipairs(CollectionService:GetTagged(LightTag)) do
		if Model:IsA("Model") then
			AssignRandomFlickerType(Model)
			local FlickerType = Model:GetAttribute("FlickerType")

			local NeonParts = GetNeonParts(Model)
			local Emitters = GetEmitters(Model)

			FlickerLight(FlickerType, NeonParts, Emitters)
		end
	end
end

return FlickeringLightsClient
