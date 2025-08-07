-- Services

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Constants

-- Events

local RemoteFunctions = ReplicatedStorage.RemoteFunctions
local RemoteEvents = ReplicatedStorage.RemoteEvents

local GetPlayerStats = RemoteFunctions.GetPlayerStats

local SetPlayerStat = RemoteEvents.SetPlayerStat

local Loop 
local FlashingIndicator = false

-- Variables

local ActiveTweens = {}


local Player = Players.LocalPlayer

local ElectricalBoxes = {}

ElectricalBoxes.__index = ElectricalBoxes

function ElectricalBoxes:SetPositionalValues()
	-- Max Position is 0.9, Minimum Position is 0.1

	local function CalculateNumber()
		return (math.random(100, 750) / 1000)

	end

	for i = 1, 4 do
		local NewXPosition = CalculateNumber()
		local Bar = self.Panel.Container[i]
		Bar.Hit.Position = UDim2.fromScale(NewXPosition, 0)
		if self.Difficulty == "Easy" then
			Bar.Hit.Size = UDim2.fromScale(0.13, 1)
		elseif self.Difficulty == "Normal" then
			Bar.Hit.Size = UDim2.fromScale(0.1, 1)
		elseif self.Difficulty == "Hard" then
			Bar.Hit.Size = UDim2.fromScale(0.083, 1)


		end
	end
	
end


function ElectricalBoxes:PlayMinigameBar(Index)
	
	local Indicator = self.Indicators[tostring(Index)]
	local OriginalColor = Color3.fromRGB(86, 21, 21)
	local FailedColor = Color3.fromRGB(255, 85, 85)
	local FlashedColor = Color3.fromRGB(165, 137, 25)
	local FinishedColor = Color3.fromRGB(0, 255, 0)
	
	local Bar = self.Panel.Container[tostring(Index)]
	local Hit = Bar.Hit
	local Cursor : Frame = Bar.Cursor

	local function FlashIndicator(Color)
		FlashingIndicator = true
		if Color == FailedColor then
			local OriginalCursorColor = Cursor.BackgroundColor3
			for i = 1, 3 do
				Cursor.BackgroundColor3 = FailedColor
				Indicator.Color = Color
				task.wait(.2) 
				Indicator.Color = OriginalColor
				Cursor.BackgroundColor3 = OriginalCursorColor
				task.wait(.2)
			end
		else
			for i = 1, 3 do
				Indicator.Color = Color
				task.wait(.2) 
				Indicator.Color = OriginalColor
				task.wait(.2)
			end
		end
		FlashingIndicator = false

	end

	
	Cursor.Position = UDim2.fromScale(0.1,0)


	

	local CorrectlyTimedIt = false
	local MissedTimedIt = false
	local BreakLoop = false

	local Info = TweenInfo.new(1.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

	FlashIndicator(FlashedColor)
	task.wait(.5)

	local function CalculateTiming(Input)
		warn("pressed", Input)
		if Input.KeyCode == Enum.KeyCode.Space or Input.KeyCode == Enum.KeyCode.ButtonA or Input.KeyCode == Enum.KeyCode.MouseLeftButton then
			warn("Correct b")
			local CursorPosition = Cursor.Position.X.Scale
			local HitMinimum = Hit.Position.X.Scale
			local HitMax = (HitMinimum + Hit.Size.X.Scale) - Cursor.Size.X.Scale

			if CursorPosition >= HitMinimum and CursorPosition <= HitMax then
				CorrectlyTimedIt = true
			else
				MissedTimedIt = true
			end
			
		end

	end
	
	local InputConnection 
	InputConnection = UserInputService.InputBegan:Connect(CalculateTiming)
	
	task.spawn(function()
		while task.wait() do
			if CorrectlyTimedIt or MissedTimedIt then
				warn("Attempting to pause tweens")
				for Index, Tween in pairs(ActiveTweens) do
					Tween:Pause()
					Tween:Destroy()
				end
				
				BreakLoop = true
				break
			end
		end
	end)
	Loop = coroutine.create(function()
		while true do

			local Tween1 = TweenService:Create(Cursor, Info, {Position = UDim2.fromScale(.9, 0)})
			Tween1:Play()
			table.insert(ActiveTweens, Tween1)

			Tween1.Completed:Wait()


			Tween1:Destroy()

			if CorrectlyTimedIt or MissedTimedIt or BreakLoop then break end

			local Tween2 = TweenService:Create(Cursor, Info, {Position = UDim2.fromScale(.05, 0)})
			Tween2:Play()

			table.insert(ActiveTweens, Tween2)

			Tween2.Completed:Wait()

			Tween2:Destroy()


		end
	end)
	
	coroutine.resume(Loop)
	
	repeat task.wait() until CorrectlyTimedIt or MissedTimedIt or BreakLoop
	
	
	coroutine.close(Loop)
	
	if InputConnection then
		InputConnection:Disconnect()
		InputConnection = nil
	end
	warn("Loop over")
	if CorrectlyTimedIt then
		Indicator.Color = FinishedColor
	elseif MissedTimedIt then
		FlashIndicator(FailedColor)
		self:PlayMinigameBar(Index)
	
	end

end

function ElectricalBoxes:Setup()
	-- Connect proximity prompt



	self.ProximityPrompt.Triggered:Connect(function()
		local PlayerStats = GetPlayerStats:InvokeServer()
		print(PlayerStats)
		if PlayerStats.Hiding or PlayerStats.InElectricalPuzzle then return warn("Already doing a more important action") end
		SetPlayerStat:FireServer("InElectricityPuzzle", true)

		self:HandleDoor("Open")
		self:TweenCamera(true)
		self.ProximityPrompt.Enabled = false 
		local ExitConnections = {}
		ExitConnections["PCXbox"] = UserInputService.InputBegan:Connect(function(Input)
			if Input.KeyCode == Enum.KeyCode.Tab or Input.KeyCode == Enum.KeyCode.ButtonB then
				if FlashingIndicator then return end
				if self.Panel.Progress.Text == "4/4" then
					self.WonPuzzle = true
					RemoteEvents.WonElectricalPuzzle:FireServer(self.Model)
				end
				self:ExitPuzzle()
				ExitConnections["PCXbox"]:Disconnect()
				ExitConnections["PCXbox"] = nil
				self.Panel.Progress.Text = "0/4"

			end
		end)

		for i = 1, 4 do
			self:PlayMinigameBar(i)
			self.Panel.Progress.Text = tostring(i).."/4"
		end
	end)
end

function ElectricalBoxes:ExitPuzzle()
	self:HandleDoor("Close")
	self:TweenCamera(false)
	SetPlayerStat:FireServer("InElectricityPuzzle", false)
	for Index, Tween in pairs(ActiveTweens) do
		Tween:Pause()
		Tween:Destroy()
	end
	coroutine.close(Loop)

	if not self.WonPuzzle then
		self:PlayerExittedMidPuzzle()
	end
end

function ElectricalBoxes:PlayerExittedMidPuzzle()

	-- Cleanup practically
	
	local OriginalColor = Color3.fromRGB(86, 21, 21)
	
	
	for i = 1,4 do
		local Indicator = self.Indicators[tostring(i)]
		local Bar = self.Panel.Container[tostring(i)]
		local Cursor : Frame = Bar.Cursor
		Indicator.Color = OriginalColor
		Cursor.Position = UDim2.fromScale(0.1,0)

	end
	self.ProximityPrompt.Enabled = true

end

function ElectricalBoxes:HandleDoor(Status)
	local TargetCFrame 
	if Status == "Open" then
		TargetCFrame = self.OriginalHingeCFrame * CFrame.Angles(0, math.rad(210), 0)
	else
		TargetCFrame = self.OriginalHingeCFrame
	end

	local Info = TweenInfo.new(.7, Enum.EasingStyle.Back)
	local Tween = TweenService:Create(self.Hinge, Info, {CFrame = TargetCFrame})

	Tween:Play()

	Tween.Completed:Once(function()
		Tween:Destroy()
		Tween = nil
	end)
end

function ElectricalBoxes:TweenCamera(IntoPuzzle)
	local Camera = workspace.CurrentCamera
	local Info = TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

	if IntoPuzzle then
		Camera.CameraType = Enum.CameraType.Scriptable

		local CameraTween = TweenService:Create(Camera, Info, {CFrame = self.CameraCFrame})
		CameraTween:Play()

		CameraTween.Completed:Once(function()
			CameraTween:Destroy()
			CameraTween = nil
		end)
	else
		if Player.Character == nil then return warn("Character is nil, can't tween camera") end

		local CameraTween = TweenService:Create(Camera, Info, {CFrame = Player.Character.Head.CFrame})
		CameraTween:Play()

		CameraTween.Completed:Once(function()
			Camera.CameraType = Enum.CameraType.Custom
			CameraTween:Destroy()
			CameraTween = nil
		end)
	end

end



function ElectricalBoxes.new(Model)
	local self = setmetatable({
		Model = Model,
		Difficulty = Model:GetAttribute("Difficulty"), -- Easy, Normal, Hard, Very Hard
		Panel = Model.PrimaryPart:FindFirstChildOfClass("SurfaceGui").Main, -- Set the primary part to the panel where the GUI is

		ProximityPrompt = Model:FindFirstChild("ProximityPrompt", true),
		Hinge = Model:FindFirstChild("Hinge"),
		CameraCFrame = Model:FindFirstChild("Camera").CFrame,
		Indicators = Model:FindFirstChild("Indicators"),
		WonPuzzle = false,
	}, ElectricalBoxes)

	self.OriginalHingeCFrame = self.Hinge.CFrame
	self:SetPositionalValues()
	self:Setup()

	return self
end

function ElectricalBoxes.Init()

	for Index, ElectricalBox in pairs(CollectionService:GetTagged("ElectricalBox")) do
		ElectricalBoxes.new(ElectricalBox)
	end
end

return ElectricalBoxes