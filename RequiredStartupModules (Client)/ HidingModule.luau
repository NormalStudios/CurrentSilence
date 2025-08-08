-- Services

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")


-- Events

local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local ExitHidingSpot = RemoteFunctions:WaitForChild("ExitHidingSpot")

local IsHiding = false


-- Variables

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Head : MeshPart = Character:WaitForChild("Head")

local Camera = workspace.CurrentCamera

local MoveInConnection 
local CurrentCameraConnection


local ClosedLockerOrientation = Vector3.new(0, -3, 0)
local OpenedLockerOrientation = Vector3.new(0, -103, 0)

local CurrentInput = "Keyboard"

local OriginalDOFSettings = {}


-- Modules

local SoundModule = require(ReplicatedStorage.Modules.Shared.SoundModule)


local HidingModule = {}

-- Main


function HidingModule.ToggleVignette(enable: boolean)
	local gui = Player:FindFirstChild("PlayerGui")
	if not gui then return end

	local vignette = gui:FindFirstChild("Vignette") and gui.Vignette:FindFirstChild("BlackVignette")
	if not vignette or not vignette:IsA("ImageLabel") then return end

	local tweenInfo
	local goal = {}

	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if not dof then
		warn("No DepthOfFieldEffect found in Lighting")
		return
	end

	if enable then
		goal.ImageTransparency = 0
		tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

		-- Store current DOF settings
		OriginalDOFSettings = {
			InFocusRadius = dof.InFocusRadius,
			NearIntensity = dof.NearIntensity,
			FarIntensity = dof.FarIntensity
		}

		-- Apply dramatic DOF
		dof.InFocusRadius = 5
		dof.NearIntensity = 1
		dof.FarIntensity = 1

		-- Play breathing sound
		local BreathingSound = ReplicatedStorage.Sounds.ObjectSounds:FindFirstChild("Breathing")
		if BreathingSound then
			SoundModule.PlaySound(BreathingSound, game:GetService("SoundService"))
		else
			warn("Missing Breathing sound in ObjectSounds")
		end
	else
		goal.ImageTransparency = 1
		tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

		-- Restore DOF settings
		if OriginalDOFSettings and next(OriginalDOFSettings) then
			dof.InFocusRadius = OriginalDOFSettings.InFocusRadius
			dof.NearIntensity = OriginalDOFSettings.NearIntensity
			dof.FarIntensity = OriginalDOFSettings.FarIntensity
		end

		-- Stop breathing sound
		SoundModule.StopSound("Breathing")
	end

	TweenService:Create(vignette, tweenInfo, goal):Play()
end



function HidingModule.LockerAnimation(Status, HidingSpot, ClosedCFrameLeft, ClosedCFrameRight)

	local LeftHinge = HidingSpot:FindFirstChild("LeftDoor").PrimaryPart
	local RightHinge = HidingSpot:FindFirstChild("RightDoor").PrimaryPart
	local Info = TweenInfo.new(.7, Enum.EasingStyle.Back)
	local PlayerHidingAnimation = RemoteEvents:WaitForChild("PlayerHidingAnimation")

	if Status == "OpenLocker" then
		warn("Reached open")
		local LeftDoorTween = TweenService:Create(LeftHinge, Info, {CFrame = LeftHinge.CFrame * CFrame.Angles(0, math.rad(180), 0)})
		LeftDoorTween:Play()
		local RightDoorTween = TweenService:Create(RightHinge, Info, {CFrame = RightHinge.CFrame * CFrame.Angles(0, math.rad(180), 0)})
		RightDoorTween:Play()
	elseif Status == "CloseLocker" then
		warn("Reached close")

		local LeftDoorTween = TweenService:Create(LeftHinge, Info, {CFrame = ClosedCFrameLeft})
		LeftDoorTween:Play()
		local RightDoorTween = TweenService:Create(RightHinge, Info, {CFrame = ClosedCFrameRight})
		RightDoorTween:Play()

	end
end

function HidingModule.LockCameraToPlayer(Enable)
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Head = Character:FindFirstChild("Head")
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")

	if Enable == true then
		if CurrentCameraConnection then
			CurrentCameraConnection:Disconnect()
		end
		Player.PlayerScripts.LimitCamera.Enabled = false

		warn("Locking camera to player’s head...")
		Camera.CameraType = Enum.CameraType.Scriptable

		CurrentCameraConnection = RunService.RenderStepped:Connect(function()
			if Head and Camera then
				Camera.CFrame = Camera.CFrame:Lerp(Head.CFrame, 0.15)
			end
		end)
	elseif Enable == "StillInLocker" then
		if CurrentCameraConnection then
			CurrentCameraConnection:Disconnect()
			CurrentCameraConnection = nil
		end
		Player.PlayerScripts.LimitCamera.Enabled = true
	else
		if CurrentCameraConnection then
			CurrentCameraConnection:Disconnect()
			CurrentCameraConnection = nil
		end

		Camera.CameraType = Enum.CameraType.Custom
		Humanoid.AutoRotate = true
		warn("Camera reset to default")
		Player.PlayerScripts.LimitCamera.Enabled = false

	end
end





local HidingIntoTrack = nil
local PreLoadedExit = nil

function HidingModule.HidePlayer(HidingSpot)
	if IsHiding then return end
	IsHiding = true

	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Humanoid = Character:WaitForChild("Humanoid")
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	local DisableAnimate = ReplicatedStorage:WaitForChild("BindableEvents"):WaitForChild("DisableAnimate")

	local EnterLocker = Character:FindFirstChild("PlayerAnimations")
		:FindFirstChild("HidingSpots")
		:FindFirstChild("EnterLocker")

	if not EnterLocker or not Animator then
		warn("Missing animation or animator")
		return
	end
	DisableAnimate:Fire(false)
	game:GetService'RunService'.Heartbeat:Wait()
	Character.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

	-- Prepare character state

	Humanoid.WalkSpeed = 0
	Humanoid.AutoRotate = false
	Character.Head.CanCollide = false

	-- Move player to ExitSpot before animation (outside the locker)
	local ExitSpot = HidingSpot:FindFirstChild("ExitSpot")
	if ExitSpot then
		Character:PivotTo(ExitSpot.CFrame)
	end

	local Root = Character:FindFirstChild("HumanoidRootPart")

	-- Play animation
	local Track = Animator:LoadAnimation(EnterLocker)
	Track:Play()
	
	local LeftHinge = HidingSpot:FindFirstChild("LeftDoor").PrimaryPart
	local RightHinge = HidingSpot:FindFirstChild("RightDoor").PrimaryPart
	
	local ClosedCFrameLeft = LeftHinge.CFrame
	local ClosedCFrameRight = RightHinge.CFrame
	
	local Info = TweenInfo.new(.7, Enum.EasingStyle.Back)


	-- Door animation triggers
	Track:GetMarkerReachedSignal("Open"):Once(function()
		RemoteEvents.PlayerHidingAnimation:FireServer("OpenLocker", HidingSpot)
		

		local LeftDoorTween = TweenService:Create(LeftHinge, Info, {CFrame = LeftHinge.CFrame * CFrame.Angles(0, math.rad(180), 0)})
		LeftDoorTween:Play()
		local RightDoorTween = TweenService:Create(RightHinge, Info, {CFrame = RightHinge.CFrame * CFrame.Angles(0, math.rad(180), 0)})
		RightDoorTween:Play()
	end)

	Track:GetMarkerReachedSignal("Close"):Once(function()
		RemoteEvents.PlayerHidingAnimation:FireServer("CloseLocker", HidingSpot, ClosedCFrameLeft, ClosedCFrameRight)

		
		local LeftDoorTween = TweenService:Create(LeftHinge, Info, {CFrame = ClosedCFrameLeft})
		LeftDoorTween:Play()
		local RightDoorTween = TweenService:Create(RightHinge, Info, {CFrame = ClosedCFrameRight})
		RightDoorTween:Play()
	end)
	
	HidingModule.LockCameraToPlayer(true)
	

	HidingIntoTrack = Track
	
	local ExitLocker = Character:FindFirstChild("PlayerAnimations")
		:FindFirstChild("HidingSpots")
		:FindFirstChild("ExitLocker")
	
	local ExitTrack = Animator:LoadAnimation(ExitLocker)
	PreLoadedExit = ExitTrack
	
	-- After animation ends
	Track:GetMarkerReachedSignal("AnimationOver"):Once(function()
	
		Track:AdjustSpeed(0)

	--	Humanoid.HipHeight = 2.55
		Character.Head.CanCollide = true

		HidingModule.DetectForwardInput(HidingSpot)
		HidingModule.LockCameraToPlayer("StillInLocker")

		ReplicatedStorage.BindableEvents.LimitX:Fire(false)
		HidingModule.ToggleVignette(true)

		
		
	end)
	
		
	

end




function HidingModule.Exit(HidingSpot)
	if HidingSpot == nil then return warn("HidingSpot doesn't exist?") end
	
	IsHiding = false
	
	if HidingIntoTrack then
		HidingIntoTrack:AdjustWeight(0.001)
	end
	ReplicatedStorage.BindableEvents.LimitX:Fire(false)

	HidingModule.LockCameraToPlayer(true)


	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local animator = Humanoid:FindFirstChildOfClass("Animator")

	local track = PreLoadedExit
	

	if not track or not animator then return end

	-- Start exit animation

	HidingModule.ToggleVignette(false)


	track:Play()

	local LeftHinge = HidingSpot:FindFirstChild("LeftDoor").PrimaryPart
	local RightHinge = HidingSpot:FindFirstChild("RightDoor").PrimaryPart

	local ClosedCFrameLeft = LeftHinge.CFrame
	local ClosedCFrameRight = RightHinge.CFrame

	local Info = TweenInfo.new(.7, Enum.EasingStyle.Back)


	-- Door animation triggers
	track:GetMarkerReachedSignal("Open"):Once(function()
		RemoteEvents.PlayerHidingAnimation:FireServer("OpenLocker", HidingSpot)


		local LeftDoorTween = TweenService:Create(LeftHinge, Info, {CFrame = LeftHinge.CFrame * CFrame.Angles(0, math.rad(180), 0)})
		LeftDoorTween:Play()
		local RightDoorTween = TweenService:Create(RightHinge, Info, {CFrame = RightHinge.CFrame * CFrame.Angles(0, math.rad(180), 0)})
		RightDoorTween:Play()
	end)

	track:GetMarkerReachedSignal("Close"):Once(function()
		RemoteEvents.PlayerHidingAnimation:FireServer("CloseLocker", HidingSpot, ClosedCFrameLeft, ClosedCFrameRight)


		local LeftDoorTween = TweenService:Create(LeftHinge, Info, {CFrame = ClosedCFrameLeft})
		LeftDoorTween:Play()
		local RightDoorTween = TweenService:Create(RightHinge, Info, {CFrame = ClosedCFrameRight})
		RightDoorTween:Play()
	end)

	-- Finish
	track:GetMarkerReachedSignal("AnimationOver"):Once(function()
		HidingModule.LockCameraToPlayer(false)
		Humanoid.WalkSpeed = 10.5
		ReplicatedStorage.BindableEvents.DisableAnimate:Fire(true)

		-- Clean character
		Humanoid.AutoRotate = true
	--	Humanoid.HipHeight = 2
		Character.Head.CanCollide = true
		
		track:AdjustSpeed(0)
		Character:PivotTo(HidingSpot:FindFirstChild("ExitSpot", true).CFrame)
		task.wait(.05)
		track:Stop()
		
		if HidingIntoTrack then
			HidingIntoTrack:Stop()
		end
	end)
end


function HidingModule.DetectForwardInput(HidingSpot)
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")

	local Input





	if CurrentInput == "Mobile" then
		MoveInConnection = UserInputService.TouchMoved:Connect(function(InputObject)
			print("Mobile attempt to exit")
			local PlayerExitStatus = ExitHidingSpot:InvokeServer()
			if PlayerExitStatus == true then
				MoveInConnection:Disconnect()
				HidingModule.Exit(HidingSpot)
			end
		end)
	elseif CurrentInput == "Keyboard" or CurrentInput == "Gamepad" then
		MoveInConnection = UserInputService.InputBegan:Connect(function(Input)

			if Input.KeyCode == Enum.KeyCode.W or Input.KeyCode == Enum.KeyCode.Space or Input.KeyCode == Enum.KeyCode.ButtonB or Input.KeyCode == Enum.KeyCode.ButtonA then
				print("Keyboard attempt to exit")
				local PlayerExitStatus = ExitHidingSpot:InvokeServer()
				if PlayerExitStatus == true then
					MoveInConnection:Disconnect()
					HidingModule.Exit(HidingSpot)
				end
			end
		end)


	end
end

function HidingModule.Init()	

	for Index, HidingSpot in pairs(CollectionService:GetTagged("HidingSpot")) do
		local ProximityPrompt = HidingSpot:FindFirstChild("ProximityPrompt", true)
		if ProximityPrompt then
			ProximityPrompt.Triggered:Connect(function()
				local Status = RemoteFunctions:WaitForChild("AttemptedToHide"):InvokeServer(HidingSpot)

				if Status == true then
					HidingModule.HidePlayer(HidingSpot)
				end
			end)
		else
			continue
		end
	end
	
	RemoteEvents:WaitForChild("PlayerHidingAnimation").OnClientEvent:Connect(function(Status, HidingSpot, ClosedCFrameLeft, ClosedCFrameRight)
		HidingModule.LockerAnimation(Status, HidingSpot, ClosedCFrameLeft, ClosedCFrameRight)

	end)
end

return HidingModule
