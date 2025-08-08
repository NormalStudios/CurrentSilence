-- Services
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Modules
local BootScenarios = require(script:WaitForChild("BootScenarios"))

-- Assets
local MonitorTextTemplate = ReplicatedStorage:WaitForChild("Misc"):WaitForChild("MonitorText")

local MonitorBoot = {}

local function typeText(textLabel, text, speed)
	for i = 1, #text do
		textLabel.Text = string.sub(text, 1, i) .. " |"
		task.wait(speed)
	end
	for i = 1, 4 do
		textLabel.Text = text
		task.wait(0.25)
		textLabel.Text = text .. " |"
		task.wait(0.25)
	end
	textLabel.Text = text -- finalize
end

local function clearFrame(frame)
	for _, child in pairs(frame:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

function MonitorBoot.RunBootSequence(monitorModel, scenario)
	local primary = monitorModel.PrimaryPart
	if not primary then return end

	local surfaceGui = primary:FindFirstChildOfClass("SurfaceGui")
	if not surfaceGui then return end

	local frame = surfaceGui:FindFirstChildOfClass("Frame")
	local icon = surfaceGui:FindFirstChild("Icon")
	if not frame or not icon then return end

	clearFrame(frame)

	-- Step 1: Rotate icon until it completes a full 360° rotation
	local spinning = true
	local rotation = 0
	local targetRotation = 360
	local spinSpeed = 2.4

	local spinConnection
	spinConnection = RunService.RenderStepped:Connect(function()
		if spinning then
			rotation += spinSpeed
			icon.Rotation = rotation % 360
			if rotation >= targetRotation then
				spinning = false
				spinConnection:Disconnect()
			end
		end
	end)

	repeat task.wait() until spinning == false

	-- Step 2: Start pulsing and spinning again for 2.5 seconds
	spinning = true
	spinConnection = RunService.RenderStepped:Connect(function()
		if spinning then
			rotation += spinSpeed
			icon.Rotation = rotation % 360
		end
	end)

	local pulseTweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local pulseTween = TweenService:Create(icon, pulseTweenInfo, {
		Size = UDim2.new(0.34, 0, 0.68, 0)
	})
	pulseTween:Play()
	task.wait(2.5)

	-- End pulse and spin
	spinning = false
	spinConnection:Disconnect()
	pulseTween:Cancel()

	-- Step 3: Shrink and disappear
	local shrinkTween = TweenService:Create(icon, TweenInfo.new(0.75), {
		Size = UDim2.new(0, 0, 0, 0)
	})
	shrinkTween:Play()
	shrinkTween.Completed:Wait()

	-- Begin Boot Sequence
	for _, line in ipairs(scenario) do
		local textClone = MonitorTextTemplate:Clone()
		textClone.Parent = frame
		textClone.Text = ""

		typeText(textClone, line, 0.03)
		task.wait(0.2)
	end

	task.wait(3)
	clearFrame(frame)
end


function MonitorBoot.Init()
	task.spawn(function()
		while true do
			local scenarios = BootScenarios:GetScenarios()
			for _, monitor in pairs(CollectionService:GetTagged("Monitor")) do
				local scenario = scenarios[math.random(1, #scenarios)]
				MonitorBoot.RunBootSequence(monitor, scenario)
			end
			task.wait(10) -- Delay between sequences
		end
	end)
end

return MonitorBoot
