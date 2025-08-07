-- Also handles death, not just cutscenes

local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Cutscenes = {}

Cutscenes.__index = Cutscenes

function Cutscenes:LockCamera()
	self.Camera.CameraType = Enum.CameraType.Scriptable
	self.Humanoid.AutoRotate = false
	self.LockedCameraConnection = RunService.PreRender:Connect(function()
		self.Camera.CFrame = self.Character.Head

	end)
end

function Cutscenes:DisconnectCamera()
	if self.LockedCameraConnection then
		self.LockedCameraConnection:Disconnect()
		self.LockedCameraConnection = nil

		self.Camera.CameraType = Enum.CameraType.Custom
		self.Humanoid.AutoRotate = true
	end
end

function Cutscenes:DeathCutscene()
end


function Cutscenes:PlayParasiteKill(Victim, Parasite)


	local IsLocalPlayerVictim = (Victim == self.Character)

	local ParasiteAnimator = Parasite:FindFirstChild("Animator", true)
	local VictimAnimator = Victim:FindFirstChild("Animator", true)

	if not (ParasiteAnimator and VictimAnimator) then return end

	local ParasiteAnim = ParasiteAnimator:LoadAnimation(Replicated.Assets.Animations.Parasite.Kill)
	local VictimAnim : AnimationTrack = VictimAnimator:LoadAnimation(Replicated.Assets.Animations.Victim.Death)

	-- Positional setup needs to be here

	RunService.Heartbeat:Wait()



	ParasiteAnim:Play()
	VictimAnim:Play()

	if IsLocalPlayerVictim then
		self.Character.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		Parasite.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		local Root = Victim:FindFirstChild("HumanoidRootPart") and Victim:FindFirstChild("Head")
		if Root then
			self:LockCamera()
		end

		VictimAnim.Stopped:Once(function()
			task.wait(1)
			self:DisconnectCamera()
			self.Events.ParasiteKill:FireServer()
		end)
	end
end

function Cutscenes.new()
	local self = setmetatable({
		Camera = workspace.CurrentCamera,
		LockedCameraConnection = nil,
		Player = Players.LocalPlayer,
		Events = {
			ParasiteKill = Replicated.RemoteEvents.ParasiteKillEvent,
			Death = Replicated.RemoteEvents.Death,
		},
		LimitCameraConnections = {}

	}, Cutscenes)
	self.Character = self.Player.Character or self.Player.CharacterAdded:Wait()
	self.Humanoid = self.Character.Humanoid
	self.Player.CharacterRemoving:Connect(function()
		self.Character = nil
		self.Humanoid = nil
	end)
	self.Player.CharacterAdded:Connect(function(Character)
		self.Character = Character
		self.Humanoid = self.Character.Humanoid
	end)

	self.Events.Death.OnClientEvent:Connect(function()
		self:DeathCutscene()
	end)


	self.Events.ParasiteKill.OnClientEvent:Connect(function(Victim, Parasite)
		self:PlayParasiteKill(Victim, Parasite)
	end)
	
	

	return self
end

function Cutscenes.Init()
	Cutscenes.new()
end

return Cutscenes
