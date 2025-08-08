local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Debug = {}
Debug.__index = Debug

local ScreenGui
local FPSLabel
local FPSGraph
local ModulePerfFrame
local IsEnabled = false
local FrameBuffer = {}
local MaxFPS = 100

local GraphPointCount = 60 -- number of bars in graph
local GraphBars = {}

local function CreateUI()
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "Debug"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.Enabled = false
	ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local Background = Instance.new("Frame")
	Background.Name = "Background"
	Background.Size = UDim2.new(0.25, 0, 0.3, 0)
	Background.Position = UDim2.new(0.01, 0, 0.01, 0)
	Background.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	Background.BackgroundTransparency = 0.2
	Background.BorderSizePixel = 0
	Background.Parent = ScreenGui

	FPSLabel = Instance.new("TextLabel")
	FPSLabel.Name = "FPSLabel"
	FPSLabel.Size = UDim2.new(1, 0, 0.1, 0)
	FPSLabel.Position = UDim2.new(0, 0, 0, 0)
	FPSLabel.BackgroundTransparency = 1
	FPSLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	FPSLabel.TextScaled = true
	FPSLabel.Font = Enum.Font.SourceSans
	FPSLabel.Text = "FPS: ..."
	FPSLabel.Parent = Background

	FPSGraph = Instance.new("Frame")
	FPSGraph.Name = "FPSGraph"
	FPSGraph.Size = UDim2.new(1, 0, 0.5, 0)
	FPSGraph.Position = UDim2.new(0, 0, 0.1, 0)
	FPSGraph.BackgroundTransparency = 1
	FPSGraph.Parent = Background

	for i = 1, GraphPointCount do
		local Bar = Instance.new("Frame")
		Bar.Name = "Bar" .. i
		Bar.Size = UDim2.new(1 / GraphPointCount, 0, 0.1, 0)
		Bar.Position = UDim2.new((i - 1) / GraphPointCount, 0, 0.9, 0)
		Bar.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
		Bar.BorderSizePixel = 0
		Bar.Parent = FPSGraph
		table.insert(GraphBars, Bar)
	end

	ModulePerfFrame = Instance.new("TextLabel")
	ModulePerfFrame.Name = "ModulePerf"
	ModulePerfFrame.Size = UDim2.new(1, 0, 0.4, 0)
	ModulePerfFrame.Position = UDim2.new(0, 0, 0.6, 0)
	ModulePerfFrame.BackgroundTransparency = 1
	ModulePerfFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
	ModulePerfFrame.Font = Enum.Font.Code
	ModulePerfFrame.TextXAlignment = Enum.TextXAlignment.Left
	ModulePerfFrame.TextYAlignment = Enum.TextYAlignment.Top
	ModulePerfFrame.TextScaled = false
	ModulePerfFrame.TextWrapped = true
	ModulePerfFrame.TextSize = 14
	ModulePerfFrame.Text = "Module Performance:\n..."
	ModulePerfFrame.Parent = Background
end

local function UpdateFPSGraph(FPS)
	table.insert(FrameBuffer, FPS)
	if #FrameBuffer > GraphPointCount then
		table.remove(FrameBuffer, 1)
	end

	for i, Bar in ipairs(GraphBars) do
		local FpsValue = FrameBuffer[i] or 0
		local Height = math.clamp(FpsValue / MaxFPS, 0, 1)
		Bar.Size = UDim2.new(1 / GraphPointCount, 0, Height * 0.9, 0)
		Bar.Position = UDim2.new((i - 1) / GraphPointCount, 0, 1 - Height * 0.9, 0)

		if FpsValue > 50 then
			Bar.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
		elseif FpsValue > 30 then
			Bar.BackgroundColor3 = Color3.fromRGB(200, 200, 0)
		else
			Bar.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
		end
	end
end

local function UpdateModulePerformance()
	local Modules = ReplicatedStorage:FindFirstChild("Modules")
	if not Modules then return end

	local Start = os.clock()
	local Lines = {}

	for _, Folder in ipairs(Modules:GetDescendants()) do
		if Folder:IsA("ModuleScript") then
			local Begin = os.clock()
			pcall(require, Folder)
			local Duration = math.floor((os.clock() - Begin) * 100000) / 100
			table.insert(Lines, Folder.Name .. ": " .. Duration .. " ms")
		end
	end

	local Total = math.floor((os.clock() - Start) * 100000) / 100
	table.insert(Lines, "\nTotal Time: " .. Total .. " ms")

	if ModulePerfFrame then
		ModulePerfFrame.Text = "Module Performance:\n" .. table.concat(Lines, "\n")
	end
end

local function ToggleDebug()
	IsEnabled = not IsEnabled
	if ScreenGui then
		ScreenGui.Enabled = IsEnabled
	end
end

function Debug.Init()
	CreateUI()

	local LastTime = tick()
	RunService.RenderStepped:Connect(function()
		if not IsEnabled then return end

		local CurrentTime = tick()
		local Delta = CurrentTime - LastTime
		LastTime = CurrentTime

		local FPS = math.floor(1 / Delta)
		FPSLabel.Text = "FPS: " .. FPS
		UpdateFPSGraph(FPS)
	end)

	UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if GameProcessed then return end
		if Input.KeyCode == Enum.KeyCode.Backspace then
			ToggleDebug()
			if IsEnabled then
				UpdateModulePerformance()
			end
		end
	end)
end

return Debug
