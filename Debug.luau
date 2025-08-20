-- Debug Module
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Debug = {}
Debug.__index = Debug

function Debug.new()
	local self = setmetatable({}, Debug)

	-- Create debug visuals folder
	local folder = Instance.new("Folder")
	folder.Name = "DebugVisuals"
	folder.Parent = workspace
	self.VisualFolder = folder

	return self
end

function Debug:CreateDebugUI()
	local Player = Players.LocalPlayer
	if not Player then return end

	local Gui = Instance.new("ScreenGui")
	Gui.Name = "AIDebugUI"
	Gui.ResetOnSpawn = false
	Gui.IgnoreGuiInset = true
	Gui.Parent = Player:WaitForChild("PlayerGui")

	local Label = Instance.new("TextLabel")
	Label.Name = "StateLabel"
	Label.Size = UDim2.new(0.15, 0, 0.05, 0)
	Label.Position = UDim2.new(0.02, 0, 0.02, 0)
	Label.BackgroundColor3 = Color3.new(0, 0, 0)
	Label.BackgroundTransparency = 0.4
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.TextScaled = true
	Label.Text = "State: N/A"
	Label.Parent = Gui

	local TargetLabel = Instance.new("TextLabel")
	TargetLabel.Name = "TargetLabel"
	TargetLabel.Size = UDim2.new(0.15, 0, 0.035, 0)
	TargetLabel.Position = UDim2.new(0.02, 0, 0.08, 0)
	TargetLabel.BackgroundTransparency = 1
	TargetLabel.TextColor3 = Color3.new(1, 1, 1)
	TargetLabel.TextScaled = true
	TargetLabel.Text = "Target: None"
	TargetLabel.Parent = Gui

	local PathIndexLabel = Instance.new("TextLabel")
	PathIndexLabel.Name = "PathIndexLabel"
	PathIndexLabel.Size = UDim2.new(0.15, 0, 0.035, 0)
	PathIndexLabel.Position = UDim2.new(0.02, 0, 0.12, 0)
	PathIndexLabel.BackgroundTransparency = 1
	PathIndexLabel.TextColor3 = Color3.new(1, 1, 1)
	PathIndexLabel.TextScaled = true
	PathIndexLabel.Text = "Path Index: -"
	PathIndexLabel.Parent = Gui
end

function Debug:UpdateDebugUI(state)
	local Player = Players.LocalPlayer
	if not Player then return end
	local Gui = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("AIDebugUI")
	if Gui then
		local Label = Gui:FindFirstChild("StateLabel")
		if Label then
			Label.Text = "State: " .. state
		end
	end
end

function Debug:UpdateTargetInfo(name)
	local Player = Players.LocalPlayer
	if not Player then return end
	local Gui = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("AIDebugUI")
	if Gui then
		local Label = Gui:FindFirstChild("TargetLabel")
		if Label then
			Label.Text = "Target: " .. (name or "None")
		end
	end
end

function Debug:UpdatePathIndex(index)
	local Player = Players.LocalPlayer
	if not Player then return end
	local Gui = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("AIDebugUI")
	if Gui then
		local Label = Gui:FindFirstChild("PathIndexLabel")
		if Label then
			Label.Text = "Path Index: " .. tostring(index or "-")
		end
	end
end

function Debug:DrawDebugSphere(Position, Radius, Color)
	local Sphere = Instance.new("Part")
	Sphere.Shape = Enum.PartType.Ball
	Sphere.Anchored = true
	Sphere.CanCollide = false
	Sphere.Material = Enum.Material.Neon
	Sphere.Color = Color or Color3.fromRGB(0, 170, 255)
	Sphere.Transparency = 0.5
	Sphere.Size = Vector3.new(Radius * 2, Radius * 2, Radius * 2)
	Sphere.Position = Position
	Sphere.Parent = self.VisualFolder

	Debris:AddItem(Sphere, 1.5)
end

function Debug:VisualizePath(Waypoints)
	for i, wp in ipairs(Waypoints) do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Size = Vector3.new(1, 1, 1)
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Transparency = 0.5
		part.Position = wp.Position
		part.Color = (i == #Waypoints) and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
		part.Parent = self.VisualFolder
		Debris:AddItem(part, 2)
	end
end

return Debug
