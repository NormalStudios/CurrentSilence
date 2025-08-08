-- ClientHeadTrackerModule

local ClientHeadTrackerModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UpdateHead = ReplicatedStorage.RemoteEvents.UpdateHead

-- Tracks each character's most recent desired rotation
local TargetRotations = {}

local function GetNeck(Character)
	local Head = Character:FindFirstChild("Head")
	local Neck = Head and Head:FindFirstChild("Neck")
	return Neck
end

local function ComputeTargetC0(Neck, Head, UpperTorso, TargetPosition)
	local Direction = (TargetPosition - Head.Position).Unit
	local LookCFrame = CFrame.lookAt(Head.Position, Head.Position + Direction)
	local RelativeCFrame = UpperTorso.CFrame:ToObjectSpace(LookCFrame)

	local X, Y, _ = RelativeCFrame:ToOrientation()
	local ClampedY = math.clamp(Y, math.rad(-75), math.rad(75))
	local ClampedX = math.clamp(X, math.rad(-45), math.rad(45))

	local OriginalC0 = Neck.C0
	local TargetRotation = CFrame.new(OriginalC0.Position) * CFrame.Angles(ClampedX, ClampedY, 0)
	return TargetRotation
end

function ClientHeadTrackerModule.Init()
	-- Send updates every 0.25 seconds
	task.spawn(function()
		while true do
			task.wait(0.25)
			local Character = Player.Character
			if Character and Character:FindFirstChild("Head") then
				Character:FindFirstChild("Head").CanCollide = true
				local HeadPos = Camera.CFrame.Position
				local LookVector = Camera.CFrame.LookVector
				local TargetPos = HeadPos + LookVector * 10
				UpdateHead:FireServer(TargetPos)
			end
		end
	end)
	
	task.spawn(function()
		while true do
			task.wait()
			local Character = Player.Character
			local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
			local Humanoid = Character and Character:FindFirstChild("Humanoid")

			if Character and HumanoidRootPart and Humanoid then
				Humanoid.AutoRotate = false

				local LookVector = -Camera.CFrame.LookVector
				local Yaw = math.atan2(LookVector.X, LookVector.Z)

				local TargetRotation = CFrame.new(HumanoidRootPart.Position) * CFrame.Angles(0, Yaw, 0)
				HumanoidRootPart.CFrame = HumanoidRootPart.CFrame:Lerp(TargetRotation, 0.15)
			end
		end
	end)
	

	-- Update targets when received from server
	UpdateHead.OnClientEvent:Connect(function(Sender, TargetPosition)
		local Character = Sender.Character
		if not Character then return end

		local Head = Character:FindFirstChild("Head")
		local UpperTorso = Character:FindFirstChild("UpperTorso")
		local Neck = GetNeck(Character)

		if Head and UpperTorso and Neck then
			TargetRotations[Character] = ComputeTargetC0(Neck, Head, UpperTorso, TargetPosition)
		end
	end)

	-- Smooth rotation interpolation
	RunService.RenderStepped:Connect(function()
		for Character, TargetC0 in pairs(TargetRotations) do
			local Neck = GetNeck(Character)
			if Neck then
				Neck.C0 = Neck.C0:Lerp(TargetC0, 0.15)
			end
		end
	end)
end

return ClientHeadTrackerModule
