--[[

Sliding
Wallrunning
Safety Rolls
Vaulting done

FUCK SPRINTING

--]]

-- Services

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Animate = {}

Animate.__index = Animate

function Animate:HandleInputs()
	--|| SLIDE INPUTS ||--
	local function SlideLogic()
		local RayDirection = -self.HumanoidRootPart.CFrame.UpVector * 5
		local GroundRay = workspace:Raycast(self.HumanoidRootPart.Position, RayDirection, self.SlideRaycastParameters)

	
		if not self.CanSlide or self.State == "Sliding" or not GroundRay or not GroundRay.Instance then return end
		if self.Humanoid.FloorMaterial == Enum.Material.Air then return end

		self.State = "Sliding"
		self.CanSlide = false
		self.LoadedAnimations.Slide:Play(0.15)

		self:Slide()
	end

	UserInputService.InputBegan:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.C or Input.KeyCode == Enum.KeyCode.LeftControl or Input.KeyCode == Enum.KeyCode.ButtonR3 then
			SlideLogic()
		end
	end)

	--|| JUMP REQUESTS ||--

	UserInputService.JumpRequest:Connect(function(Input)
		if self.State == "Sliding" then
			local CancelMultiplier = self.SlideCurrentMultiplier
			self:StopSliding()
			if self.Settings.PushOnCancel == true then
				local PushVelocity = Instance.new("BodyVelocity")
				PushVelocity.Name = "PushVelocity"
				PushVelocity.Parent = self.HumanoidRootPart
				PushVelocity.MaxForce = Vector3.new(40000, 40000, 40000)
				PushVelocity.Velocity = (self.HumanoidRootPart.CFrame.LookVector * (self.Settings.PushVelocity.Forward * CancelMultiplier)) + (self.HumanoidRootPart.CFrame.UpVector * self.Settings.PushVelocity.Up)
				Debris:AddItem(PushVelocity, 0.2)
			end
		end
	end)
	
	
	self.Humanoid.Jumping:Connect(function(Active)
		if Active then
			local VaultConnection
			
			VaultConnection = UserInputService.InputBegan:Connect(function(Input, IsTyping)
				if Input.KeyCode == Enum.KeyCode.Space or Input.KeyCode == Enum.KeyCode.ButtonA then
					if self.VaultPartDetected and self.VaultAvailable then
						print("Vault attempted")
						self.VaultAvailable = false
						self.VaultPartDetected = false

						local Velocity = Instance.new("BodyVelocity")
						Velocity.Parent = self.HumanoidRootPart
						Velocity.Velocity = Vector3.new(0, 0, 0)
						Velocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
						Velocity.Velocity = self.HumanoidRootPart.CFrame.LookVector * 10 + Vector3.new(0, 20, 0)

						if self.Humanoid.FloorMaterial == Enum.Material.Air then
							-- Wall hop animation (uncomment when implemented)
							-- self.WH:Play()
						else
							-- Climb animation (uncomment when implemented)
							-- self.CA:Play()
						end

						Debris:AddItem(Velocity, 0.15)
						repeat task.wait() until self.Humanoid.FloorMaterial ~= Enum.Material.Air
						self.VaultAvailable = true
					end
				end
				
			end)
			
			
		end
	end)
	
end

function Animate:Slide()	
	self.Humanoid.HipHeight = 0

	self.SlideVelocity = Instance.new("BodyVelocity")
	self.SlideVelocity.Parent = self.HumanoidRootPart
	self.SlideVelocity.MaxForce = Vector3.new(40000, 0, 40000)
	self.SlideVelocity.Velocity = self.HumanoidRootPart.CFrame.LookVector * self.Settings.BaseSpeed
	self.SlideVelocity.Name = "SlideVelocity"
	
	self.SlideGyro = Instance.new("BodyGyro")
	self.SlideGyro.Parent = self.HumanoidRootPart
	self.SlideGyro.MaxTorque = Vector3.new(3e5, 3e5, 3e5)
	self.SlideGyro.P = 10000
	self.SlideGyro.Name = "SlideGyro"

	local PreviousY = 0
	self.SlideCurrentMultiplier = 1
	self.Connections.SlidePositionalCheck = RunService.Heartbeat:Connect(function(Delta)

		local CurrentY = self.HumanoidRootPart.Position.Y
		local VerticalChange = (CurrentY - PreviousY)
		PreviousY = CurrentY

		local RayDirection = -self.HumanoidRootPart.CFrame.UpVector * 10
		local GroundRay = workspace:Raycast(self.HumanoidRootPart.Position, RayDirection, self.SlideRaycastParameters)

		--// Align Character to the slope
		if GroundRay then
			local CurrentRightVector = self.HumanoidRootPart.CFrame.RightVector
			local UpVector = GroundRay.Normal
			local NewFacialVector = CurrentRightVector:Cross(UpVector)
			self.SlideGyro.CFrame = CFrame.fromMatrix(self.HumanoidRootPart.Position, CurrentRightVector, UpVector, NewFacialVector)
		end

		self.SlideVelocity.Velocity = self.HumanoidRootPart.CFrame.LookVector * (self.Settings.BaseSpeed * self.SlideCurrentMultiplier)

		if VerticalChange < 0.1 and VerticalChange > -0.1 then
			if self.SlideCurrentMultiplier > 1 then
				self.SlideCurrentMultiplier = math.clamp(self.SlideCurrentMultiplier - (self.Settings.SlideSpeedChangeRate.Forward * 2) * Delta, 0, self.Settings.SlideMaxMultiplier)

			end
			self.SlideCurrentMultiplier = math.clamp(self.SlideCurrentMultiplier - self.Settings.SlideSpeedChangeRate.Forward * Delta, 0, self.Settings.SlideMaxMultiplier)
		elseif VerticalChange > 0 then
			if self.SlideCurrentMultiplier > 1 then
				self.SlideCurrentMultiplier = math.clamp(self.SlideCurrentMultiplier - (self.Settings.SlideSpeedChangeRate.Upward * 2) * Delta, 0, self.Settings.SlideMaxMultiplier)

			end
			self.SlideCurrentMultiplier = math.clamp(self.SlideCurrentMultiplier - self.Settings.SlideSpeedChangeRate.Upward * Delta, 0, self.Settings.SlideMaxMultiplier)
		else
			self.SlideCurrentMultiplier = math.clamp(self.SlideCurrentMultiplier + self.Settings.SlideSpeedChangeRate.Downward * Delta, 0, self.Settings.SlideMaxMultiplier)
		end

		self.SlideCurrentMultiplier = math.clamp(self.SlideCurrentMultiplier, 0, self.Settings.SlideMaxMultiplier)

		if self.SlideCurrentMultiplier < 0.1 or not GroundRay then
			self:StopSliding()
		end 
	end)


end

function Animate:StopSliding()
	self.Humanoid.HipHeight = 2

	self.State = "Walking"
	self.SlideVelocity:Destroy()
	self.SlideGyro:Destroy()
	self.Connections.SlidePositionalCheck:Disconnect()
	self.LoadedAnimations.Slide:Stop(0.15)


	task.delay(self.Settings.SlideCooldown, function()
		-- This WILL cause issues later.

		self.CanSlide = true
	end)

end

function Animate:SafetyRoll()
	self.Humanoid.FreeFalling:Connect(function(Active)
		if Active and not self.RollDebounce then
			local StartedFallingTime = tick()
			local StartedYPosition = self.HumanoidRootPart.Position.Y
			local Connection 
			Connection = self.Humanoid.StateChanged:Connect(function(OldState, NewState)
				if NewState == Enum.HumanoidStateType.Landed and OldState ~= Enum.HumanoidStateType.Landed then
					
					
					Connection:Disconnect()
			
					local EndYPosition  = self.HumanoidRootPart.Position.Y
					print(StartedYPosition - EndYPosition)
					if (tick() - StartedFallingTime) > 1 and (StartedYPosition - EndYPosition) > 3  then
						print("Can roll")
						self.RollDebounce = true

						self.LoadedAnimations.Roll:Play(0.15)
						
						task.delay(1, function()
							self.RollDebounce = false
						end)

						
					else
						print("Can't roll")
					end
					
					
				end
			end)
		
		end
	end)
end

function Animate:PreventLandingBounce()
	-- Another thing that will definetely cause issues later.
	
	self.Humanoid.StateChanged:Once(function(OldState, NewState)
		if NewState.Name == "Landed" then
			local Velocity = self.HumanoidRootPart.AssemblyLinearVelocity
			self.HumanoidRootPart.AssemblyLinearVelocity = Velocity * Vector3.new(1,0,1)

			local RayDirection = -self.HumanoidRootPart.CFrame.UpVector * 10

			local Raycast = workspace:Raycast(self.HumanoidRootPart.Position, RayDirection, self.SlideRaycastParameters)
			local Position = Raycast and Raycast.Position

			if Position then
				local HipHeight = self.Humanoid.HipHeight
				local NewPosition = Position + Vector3.new(0, HipHeight, 0)
				self.Character:SetPrimaryPartCFrame(self.HumanoidRootPart.CFrame - self.HumanoidRootPart.Position + NewPosition)
			end
		end
		
		
		
	end)
end

function Animate:WallRunAnimationLoop(Side)
	if self.CurrentMovementAnimationLoop then
		self.CurrentMovementAnimationLoop:Disconnect()
	end
	
	if Side == "Right" then
		self.LoadedAnimations.LeftWallRun:Play(0.15)
	else
		self.LoadedAnimations.RightWallRun:Play(0.15)
	end
end

function Animate:WallRun()
	RunService.PreRender:Connect(function()
		if self.State ~= "Wallrunning" then
			-- Raycast left/right from the player using HRP.RightVector
			local LeftRaycast = workspace:Raycast(
				self.HumanoidRootPart.Position,
				-(self.HumanoidRootPart.CFrame.RightVector) * 5,
				self.SlideRaycastParameters
			)

			local RightRaycast = workspace:Raycast(
				self.HumanoidRootPart.Position,
				self.HumanoidRootPart.CFrame.RightVector * 5,
				self.SlideRaycastParameters
			)

			local WallrunPart
			local IsLeftWall = false
			local RaycastResult

			if LeftRaycast and LeftRaycast.Instance and RightRaycast and RightRaycast.Instance then
				local LeftDistance = LeftRaycast.Distance
				local RightDistance = RightRaycast.Distance
				if LeftDistance <= RightDistance then
					WallrunPart = LeftRaycast.Instance
					IsLeftWall = true
					RaycastResult = LeftRaycast
				else
					WallrunPart = RightRaycast.Instance
					IsLeftWall = false
					RaycastResult = RightRaycast
				end
			elseif LeftRaycast and LeftRaycast.Instance then
				WallrunPart = LeftRaycast.Instance
				IsLeftWall = true
				RaycastResult = LeftRaycast
			elseif RightRaycast and RightRaycast.Instance then
				WallrunPart = RightRaycast.Instance
				IsLeftWall = false
				RaycastResult = RightRaycast
			end

			if WallrunPart then
				self.State = "Wallrunning"

				local PlayerPosition = self.HumanoidRootPart.Position
				local WallCFrame = WallrunPart.CFrame
				local HalfX = WallrunPart.Size.X / 2
				local HalfZ = WallrunPart.Size.Z / 2
				local Margin = 3

				local LocalPlayerPosition = WallCFrame:PointToObjectSpace(PlayerPosition)
				local OnRightSide = LocalPlayerPosition.X > 0
				local LocalZ = math.clamp(LocalPlayerPosition.Z, -HalfZ + 0.1, HalfZ - 0.1)

				local StartX = (OnRightSide and ( HalfX + Margin)) or (-(HalfX + Margin))
				local EndX   = (OnRightSide and (-(HalfX + Margin))) or (  HalfX + Margin)

				local StartCFrame = WallCFrame * CFrame.new(StartX, 0, LocalZ)
				local EndCFrame   = WallCFrame * CFrame.new(EndX,   0, LocalZ)

				if self.WallrunPart and self.WallrunPart:IsA("BasePart") then
					self.WallrunPart.CFrame = StartCFrame
				end

				self:WallRunAnimationLoop(OnRightSide and "Right" or "Left")

				self.WallrunAlignPosition = Instance.new("AlignPosition")
				self.WallrunAlignPosition.ApplyAtCenterOfMass = true

				local RootAttachment = self.HumanoidRootPart:FindFirstChild("RootAttachment")
				if RootAttachment then
					self.WallrunAlignPosition.Parent = RootAttachment
					self.WallrunAlignPosition.Attachment0 = RootAttachment
				else
					self.WallrunAlignPosition.Parent = self.HumanoidRootPart
				end

				local GuideAttachment = self.WallrunPart and self.WallrunPart:FindFirstChildOfClass("Attachment")
				if GuideAttachment then
					self.WallrunAlignPosition.Attachment1 = GuideAttachment
				end

				local BreakLoop = false
				local InputConnection
				InputConnection = UserInputService.JumpRequest:Connect(function()
					BreakLoop = true
					if self.Humanoid then
						self.Humanoid.Jump = true
					end
				end)

				-- === Speed formula based on wall length (Z) ===
				-- Distance we will travel (across thickness, X):
				local Distance = math.abs(EndX - StartX) -- studs
				-- Make speed scale with wall length (longer wall => faster traverse across X):
				local WallLength = math.max(WallrunPart.Size.Z, 0.01) -- studs
				local SpeedPerStudOfLength = 0.5 -- studs/sec per stud of Z-length (tune to taste)
				local Speed = math.max(WallLength * SpeedPerStudOfLength, 1) -- studs/sec, clamp min
				local Duration = Distance / Speed -- seconds
				Duration = math.clamp(Duration, 0.2, 1.5) -- optional clamp for gameplay feel

				local GuideTween
				if self.WallrunPart then
					GuideTween = TweenService:Create(
						self.WallrunPart,
						TweenInfo.new(Duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
						{ CFrame = EndCFrame }
					)
					GuideTween:Play()
				end

				local TweenDone = false
				if GuideTween then
					GuideTween.Completed:Connect(function()
						TweenDone = true
					end)
				end

				while true do
					if BreakLoop or TweenDone then
						if InputConnection then
							InputConnection:Disconnect()
							InputConnection = nil
						end
						if GuideTween then
							GuideTween:Cancel()
						end
						if self.WallrunVelocity then
							self.WallrunVelocity:Destroy()
							self.WallrunVelocity = nil
						end
						if self.WallrunAlignPosition then
							self.WallrunAlignPosition:Destroy()
							self.WallrunAlignPosition = nil
						end

						self.State = "None"
						break
					end
					task.wait()
				end
			end
		end
	end)
end

function Animate:Vault()
 

	RunService.PreRender:Connect(function()
		local Raycast = workspace:Raycast(
			self.HumanoidRootPart.Position,
			self.HumanoidRootPart.CFrame.LookVector * 10 + self.HumanoidRootPart.CFrame.UpVector * -5, self.SlideRaycastParameters
		)
		local Part = Raycast and Raycast.Instance

		if Part and self.VaultAvailable then
			if Part:HasTag("Vaultable") then
				-- Check if player is above the part
				local PartTopY = Part.Position.Y + (Part.Size.Y / 2)
				local PlayerBottomY = self.HumanoidRootPart.Position.Y - (self.HumanoidRootPart.Size.Y / 2)

				-- If player's bottom is above the part's top, don't allow vaulting
				if PlayerBottomY > PartTopY then
					self.VaultPartDetected = false
				else
					self.VaultPartDetected = true
				end
			else
				self.VaultPartDetected = false
			end
		else
			self.VaultPartDetected = false
		end
	end)
end

function Animate.new(Character)
	local self = setmetatable({
		State = "Walking",
		CanSlide = true,
		Settings = {
			SlideCooldown = 0.1,
			BaseSpeed = 55,
			SlideSpeedChangeRate = {
				Forward = 1,
				Upward = 2,
				Downward = 1,
			},
			SlideMaxMultiplier = 2,
			PushOnCancel = true,
			PushVelocity = {
				Forward = 50,
				Up = 50
			}
		},
		Character = Character,
		HumanoidRootPart = Character.HumanoidRootPart,
		Humanoid = Character.Humanoid,
		SlideVelocity = nil,
		SlideGyro = nil,
		Connections = {},
		Animator = Character:FindFirstChild("Animator", true),
		LoadedAnimations = {},
		SlideCurrentMultiplier = 1,
		SlideRaycastParameters = RaycastParams.new(),
		VaultAvailable = true,
		VaultPartDetected = false,
		RollDebounce = false,
		WallrunVelocity = nil,
		WallrunAlignPosition = nil,
		CurrentMovementAnimationLoop = nil
	}, Animate)
	
	for Index, Descendant : BasePart in pairs(self.Character:GetDescendants()) do
		if Descendant:IsA("MeshPart") or Descendant:IsA("BasePart") then
			Descendant.CollisionGroup = "Player"
		end
	end

	self.AnimationsFolder = ReplicatedStorage.PlayerAnimations:Clone()
	self.AnimationsFolder.Parent = Character

	self.SlideRaycastParameters.FilterDescendantsInstances = {self.Character}
	self.SlideRaycastParameters.FilterType = Enum.RaycastFilterType.Exclude

	self.LoadedAnimations.Slide = self.Animator:LoadAnimation(self.AnimationsFolder.Movement.Slide)
	self.LoadedAnimations.Roll = self.Animator:LoadAnimation(self.AnimationsFolder.Movement.Roll)
	self.LoadedAnimations.LeftWallRun = self.Animator:LoadAnimation(self.AnimationsFolder.Movement.LeftWallRun)

	self.LoadedAnimations.RightWallRun = self.Animator:LoadAnimation(self.AnimationsFolder.Movement.RightWallRun)
	
	self.WallrunPart = Instance.new("Part")
	self.WallrunPart.Name = "WallrunPart"
	self.WallrunPart.Parent = workspace.CurrentCamera
	self.WallrunPart.Size = Vector3.new(1,1,1)
	self.WallrunPart.Anchored = true
	self.WallrunPart.CanCollide = false
	self.WallrunPart.CanQuery = false
	self.WallrunPart.CanTouch = false
	self.WallrunPart.Material = Enum.Material.Neon
	self.WallrunPart.Color = Color3.fromRGB(0,255,0)
	self.WallrunPart.CollisionGroup = "NoCollideWithPlayer"
	
	local Attachment = Instance.new("Attachment")
	Attachment.Parent = self.WallrunPart
	Attachment.WorldCFrame = self.WallrunPart.CFrame
	
	self:HandleInputs()
	self:PreventLandingBounce()
	self:Vault()
	self:SafetyRoll()
	self:WallRun()

	return self
end

return Animate
