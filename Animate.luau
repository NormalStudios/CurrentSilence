--[[

MAIN FEATURES:

1. Vaulting ✅
2. Sprinting
3. Jumping (Physics-based with different types)
4. Climbing (side to side and vertical)
5. Sliding

SMALL FEATURES:

1. Lerping walk speed, slowly speed up, and slow down ✅
2. Lerping FOV (Lerp dynamically on footstep)
3. Stamina, if you run out of stamina, security breach inspired system 
4. Directional walking ✅
5. Slower when walking backwards ✅
6. Stamina bar goes red when low, flashes red when fully out 
7. Footstep sound speed dependent on walking direction and state
8. Being able to hear the clothes rustle
9. Physics-based smooth movement with CustomPhysicalProperties ✅
10. Camera shake on landing ✅

--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService") -- FIX: proper tag API


local Footsteps = require(script.Footsteps)
local SoundModule = require(ReplicatedStorage.Modules.Shared.SoundModule)
local CameraShaker = require(ReplicatedStorage.Modules.Shared.CameraShaker)

local Player = Players.LocalPlayer

local PlayerGUI = Player.PlayerGui
local Vitals = PlayerGUI.NewVitals
local SprintBar = Vitals.Main.Bar.InsideBar

local Rate = 1
local DelayTime = .075
local DepleteTime = .035	
local Max = 100

-- Physics constants for grounded movement
local PHYSICS_CONSTANTS = {
	-- Ground movement
	WalkSpeed = 16,
	SprintSpeed = 28,
	CrouchSpeed = 8,
	BackwardMultiplier = 0.7,

	-- Acceleration rates (increased for less floaty feel)
	GroundAccel = 4.5,        -- Increased from 2.5
	GroundDecel = 12,         -- Increased from 6
	AirAccel = 0.8,           -- Decreased from 1.2 (less air control)
	AirDecel = 1.5,           -- Increased air decel

	-- Jump properties
	WalkJumpPower = 30,       -- You increased this to 50
	SprintJumpPower = 45,     -- Reduced from 24 for better arc (was too low)
	SprintJumpForwardBoost = 120, -- Increased from 35 for more forward reach

	-- Floaty jump settings
	JumpGravityScale = 0.6,   -- Reduced gravity while jumping (more floaty)
	FallGravityScale = 1.2,   -- Normal gravity when falling
	MaxFallSpeed = 35,        -- Terminal velocity cap

	-- Physical properties (less bouncy)
	Density = 1.2,            -- Increased from 0.7 (heavier feel)
	Friction = 0.8,           -- Increased from 0 (more grip)
	Elasticity = 0.1,         -- Increased from 0 (slight bounce)
	ElasticityWeight = 100,
	FrictionWeight = 100,

	-- Landing detection
	LandingVelocityThreshold = 20,  -- Reduced from 30
	HardLandingThreshold = 35,      -- Reduced from 50

	-- LinearVelocity settings
	MaxForce = 30000,         -- Increased from 25500

	-- Wall climbing prevention
	MaxClimbAngle = 50,       -- Maximum angle for climbable surfaces (degrees)
	WallCheckDistance = 3,    -- Distance to check for walls

	-- Vaulting properties
	VaultRayDistance = 15,    -- How far to check for vaultable surfaces
	VaultMinHeight = 3,       -- Minimum height to vault over
	VaultMaxHeight = 12,      -- Maximum height to vault over
	VaultHeightOffset = 5,    -- How high above the surface to start vault animation
	-- Sliding tuning
	SlideInitialBoost = 26,
	SlideFriction = 18,         -- higher = stops sooner
	SlideMinSpeed = 6,          -- auto-exit when slower than this
	SlideControl = 0.20,        -- % of input that can steer the slide
	SlideDurationMax = 2.2,     -- hard cap
	SlideHipHeight = 0.6,

	-- Vault tuning
	VaultTravelTime = 0.45,     -- seconds across the arc
	VaultOverForward = 2.5,     -- land a bit beyond the ledge
	VaultUpClearance = 4.5,     -- headroom check at landing

}

local FieldOfViewInfos = {
	Sprint = TweenInfo.new(1, Enum.EasingStyle.Cubic),
	Walk = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
	Crouch = TweenInfo.new(1.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
}

local CrouchIcon = "rbxassetid://101513478891645"
local SprintIcon = "rbxassetid://115387700013616"
local WalkIcon = "rbxassetid://117677233122476"

local CameraShakePresets = require(ReplicatedStorage.Modules.Shared.CameraShaker.CameraShakePresets)
local CameraShakeInstance = require(ReplicatedStorage.Modules.Shared.CameraShaker.CameraShakeInstance)

local Animate = {}
Animate.__index = Animate

function Animate:SetupPhysics()
	-- Expose state to camera system
	_G.AnimateState = self.State or "Walking"

	local rootPart = self.Character.HumanoidRootPart

	-- Setup LinearVelocity for movement control
	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Parent = rootPart
	linearVelocity.Attachment0 = rootPart:WaitForChild("RootAttachment")
	linearVelocity.MaxForce = PHYSICS_CONSTANTS.MaxForce
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	linearVelocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	linearVelocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	linearVelocity.PlaneVelocity = Vector2.new(0, 0)

	self.LinearVelocity = linearVelocity
	self.PlayerVelocity = Vector3.new(0, 0, 0)

	-- Initialize global shake offsets (but don't create duplicate CameraShaker)
	_G.CameraShakeOffset = _G.CameraShakeOffset or CFrame.new()
	_G.LightningCameraShakeOffset = _G.LightningCameraShakeOffset or CFrame.new()
	_G.BobbleCameraShakeOffset = _G.BobbleCameraShakeOffset or CFrame.new()

	-- ONLY create CameraShaker if it doesn't exist (camera script will handle bobble shaker)
	if not _G.MainCameraShaker then
		local camera = workspace.CurrentCamera
		if not camera then
			warn("No camera found!")
			return
		end

		-- Create main camera shaker for landing effects only
		self.CameraShaker = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
			_G.CameraShakeOffset = shakeCFrame
		end)

		if self.CameraShaker then
			self.CameraShaker:Start()
			_G.MainCameraShaker = self.CameraShaker -- Store globally to prevent duplicates
		else
			warn("Failed to create CameraShaker!")
		end
	else
		-- Use existing main camera shaker
		self.CameraShaker = _G.MainCameraShaker
	end

	-- Physics state tracking
	self.LastVelocity = Vector3.new(0, 0, 0)
	self.IsGrounded = true
	self.JumpType = "None"
	self.LandingBuffer = 0
	self.JumpDebounce = false
	self.SprintJumpLandingDebounce = false

	-- Vaulting state
	self.IsVaulting = false
	self.VaultStarted = false

	-- Jump animation state tracking
	self.JumpState = "None" -- "Jumping", "Falling", "Landing", "None"
	self.LastJumpState = "None"

	-- Optimization: Only need wall check caching now since ground check is instant
	self.WallCheckCache = {
		canClimb = false,
		lastCheck = 0,
		checkInterval = 1/15, -- Check walls 15 times per second
		lastHumanoidState = Enum.HumanoidStateType.Running
	}

	-- Setup humanoid properties for physics movement
	self.Humanoid.WalkSpeed = 0
	self.Humanoid.UseJumpPower = false
	self.Humanoid.JumpPower = 0
	self.Humanoid.JumpHeight = 0

	-- Disable automatic climbing
	self.Humanoid.AutoRotate = true  -- Keep auto-rotate
	-- We'll handle climbing prevention manually
end

function Animate:ApplyCustomPhysicalProperties()
	-- Apply custom physical properties to all parts for grounded feel
	for _, part in pairs(self.Character:GetChildren()) do
		if part:IsA("BasePart") then
			part.CustomPhysicalProperties = PhysicalProperties.new(
				PHYSICS_CONSTANTS.Density,
				PHYSICS_CONSTANTS.Friction,
				PHYSICS_CONSTANTS.Elasticity,
				PHYSICS_CONSTANTS.ElasticityWeight,
				PHYSICS_CONSTANTS.FrictionWeight
			)
		end
	end
end

function Animate:GetCurrentSpeed()
	if self.State == "Walking" then
		return PHYSICS_CONSTANTS.WalkSpeed
	elseif self.State == "Sprinting" then
		return PHYSICS_CONSTANTS.SprintSpeed
	elseif self.State == "Crouching" then
		return PHYSICS_CONSTANTS.CrouchSpeed
	end
	return PHYSICS_CONSTANTS.WalkSpeed
end

-- Enhanced ground movement with better responsiveness
function Animate:GroundMove(direction, speed, accel, decel)
	local currentVel = self.PlayerVelocity
	local targetVel = direction * speed
	local velDiff = targetVel - currentVel

	-- Use different rates for acceleration vs deceleration
	local rate
	if direction.Magnitude > 0.1 and currentVel:Dot(direction) < speed then
		rate = accel  -- Accelerating
	else
		rate = decel  -- Decelerating or changing direction
	end

	local deltaTime = RunService.Heartbeat:Wait()
	self.PlayerVelocity = self.PlayerVelocity + (velDiff * rate * deltaTime)

	-- Clamp to prevent excessive speeds
	if self.PlayerVelocity.Magnitude > speed * 1.1 then
		self.PlayerVelocity = self.PlayerVelocity.Unit * speed * 1.1
	end
end

-- Reduced air movement for grounded feel
function Animate:AirMove(wishDir, wishSpeed, accel)
	local currentSpeed = self.PlayerVelocity:Dot(wishDir)
	local addSpeed = wishSpeed - currentSpeed

	if addSpeed <= 0 then
		return
	end

	local deltaTime = RunService.Heartbeat:Wait()
	local accelSpeed = math.min(addSpeed * deltaTime * accel, addSpeed)

	self.PlayerVelocity = self.PlayerVelocity + (accelSpeed * wishDir)
end

function Animate:CheckGrounded()
	-- FIX: When PlatformStand or physics suppressed, we are not grounded.
	if self.Humanoid.PlatformStand or self.SuppressPhysics then
		return false
	end

	local humanoid = self.Humanoid

	-- Ultra-fast check
	if humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end

	-- Extra state check
	local s = humanoid:GetState()
	local stateGrounded = (s ~= Enum.HumanoidStateType.Freefall
		and s ~= Enum.HumanoidStateType.Flying
		and s ~= Enum.HumanoidStateType.Jumping
		and s ~= Enum.HumanoidStateType.Physics) -- treat Physics (PlatformStand) as NOT grounded
	return stateGrounded
end

-- Optimized wall climbing prevention with caching
function Animate:CheckWallClimbing()
	local currentTime = tick()
	local humanoid = self.Humanoid
	local cache = self.WallCheckCache
	local currentState = humanoid:GetState()

	-- Only check if we're actually climbing AND enough time passed OR state changed
	if currentState ~= Enum.HumanoidStateType.Climbing then
		cache.lastHumanoidState = currentState
		return true
	end

	local timeSinceLastCheck = currentTime - cache.lastCheck
	local stateChanged = currentState ~= cache.lastHumanoidState

	-- Use cached result if recent and state unchanged
	if timeSinceLastCheck < cache.checkInterval and not stateChanged then
		if not cache.canClimb then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			return false
		end
		return true
	end

	-- Update cache timing and state
	cache.lastCheck = currentTime
	cache.lastHumanoidState = currentState

	-- Do expensive raycast check
	local rootPart = self.Character.HumanoidRootPart
	local rayOrigin = rootPart.Position
	local rayDirection = rootPart.CFrame.LookVector * PHYSICS_CONSTANTS.WallCheckDistance

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {self.Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if result then
		-- Calculate angle between wall normal and up vector
		local wallNormal = result.Normal
		local upVector = Vector3.new(0, 1, 0)
		local angle = math.deg(math.acos(wallNormal:Dot(upVector)))

		-- Cache the result
		cache.canClimb = angle <= PHYSICS_CONSTANTS.MaxClimbAngle

		-- If wall is too steep, prevent climbing
		if not cache.canClimb then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			return false
		end
	else
		cache.canClimb = true
	end

	return cache.canClimb
end

-- FIXED Jump animation management with slide protection
function Animate:UpdateJumpAnimations()
	local rootPart = self.Character.HumanoidRootPart
	local currentVelocity = rootPart.AssemblyLinearVelocity
	local newJumpState = "None"

	-- Don't update jump animations during vaulting or sliding
	if self.IsVaulting or self.State == "Sliding" then
		print("🎭 JUMP: Skipping jump animations - vaulting or sliding")
		return
	end

	-- Determine current jump state
	if not self.IsGrounded then
		if currentVelocity.Y > 2 then
			newJumpState = "Jumping"  -- Going up
		elseif currentVelocity.Y < -2 then
			newJumpState = "Falling"  -- Falling down
		else
			newJumpState = "Falling"  -- Neutral air time, treat as falling
		end
	else
		-- Just landed - FIXED: Check if coming from any airborne state
		if (self.LastJumpState == "Falling" or self.LastJumpState == "Jumping") and self.JumpState ~= "Landing" then
			newJumpState = "Landing"
		elseif self.JumpState == "Landing" then
			-- Stay in landing state until the animation cleanup finishes
			newJumpState = "Landing"
		else
			newJumpState = "None"
		end
	end

	-- Handle animation transitions with proper weighting
	if newJumpState ~= self.JumpState then
		-- Stop conflicting jump animations (no waiting - instant transitions)
		if newJumpState == "Jumping" then
			if self.FallAnim and self.FallAnim.IsPlaying then
				self.FallAnim:AdjustWeight(0, 0.1)
				self.FallAnim:Stop(0.1)
			end
			if self.LandAnim and self.LandAnim.IsPlaying then
				self.LandAnim:AdjustWeight(0, 0.1)
				self.LandAnim:Stop(0.1)
			end
		elseif newJumpState == "Falling" then
			if self.JumpAnim and self.JumpAnim.IsPlaying then
				self.JumpAnim:AdjustWeight(0, 0.1)
				self.JumpAnim:Stop(0.1)
			end
			if self.LandAnim and self.LandAnim.IsPlaying then
				self.LandAnim:AdjustWeight(0, 0.1)
				self.LandAnim:Stop(0.1)
			end
		elseif newJumpState == "Landing" then
			-- IMMEDIATE stop of air animations for instant landing
			if self.JumpAnim and self.JumpAnim.IsPlaying then
				self.JumpAnim:Stop(0)
			end
			if self.FallAnim and self.FallAnim.IsPlaying then
				self.FallAnim:Stop(0)
			end
		end

		-- Start new animation with proper weighting - NO DELAYS
		if newJumpState == "Jumping" then
			self.JumpAnim:Play(0.1, 0.5, 1) -- Start with medium weight
			self.JumpAnim.Priority = Enum.AnimationPriority.Action
			self.JumpAnim:AdjustWeight(1, 0.2) -- Fade to full weight
			print("🎭 JUMP: Jump animation playing with weight")
		elseif newJumpState == "Falling" then
			self.FallAnim:Play(0.2, 0.5, 1) -- Start with medium weight
			self.FallAnim.Priority = Enum.AnimationPriority.Action
			self.FallAnim:AdjustWeight(1, 0.3) -- Fade to full weight
			print("🎭 JUMP: Fall animation playing with weight")
		elseif newJumpState == "Landing" and self.JumpState ~= "Landing" then
			-- IMMEDIATE landing animation - no delay
			self.LandAnim:Play(0.05, 1, 1) -- Start with full weight immediately
			self.LandAnim.Priority = Enum.AnimationPriority.Action2
			print("🎭 JUMP: Land animation playing IMMEDIATELY with full weight")

			-- Auto-stop landing animation after short duration
			task.spawn(function()
				task.wait(0.6) -- Duration for landing animation
				if self.LandAnim and self.LandAnim.IsPlaying then
					self.LandAnim:AdjustWeight(0, 0.3) -- Fade out weight
					task.wait(0.3)
					self.LandAnim:Stop()
				end
				-- Reset to None state after landing animation
				if self.JumpState == "Landing" then
					self.JumpState = "None"
					self.LastJumpState = "None"
				end
			end)
		end

		-- Update states AFTER starting new animation
		if newJumpState ~= "Landing" or self.JumpState ~= "Landing" then
			self.LastJumpState = self.JumpState
			self.JumpState = newJumpState
		end
	end
end

-- Enhanced gravity control for floaty jumps
function Animate:ApplyJumpGravity()
	local rootPart = self.Character.HumanoidRootPart
	local currentVelocity = rootPart.AssemblyLinearVelocity

	-- Don't apply custom gravity during vaulting
	if self.IsVaulting then
		return
	end

	if not self.IsGrounded then
		local gravityForce = 0

		-- Apply different gravity based on jump phase
		if currentVelocity.Y > 0 and self.JumpState == "Jumping" then
			-- Ascending - reduced gravity for floaty feel
			gravityForce = -workspace.Gravity * PHYSICS_CONSTANTS.JumpGravityScale
		else
			-- Falling - normal or slightly increased gravity
			gravityForce = -workspace.Gravity * PHYSICS_CONSTANTS.FallGravityScale
		end

		-- Apply gravity force
		local bodyVelocity = rootPart.AssemblyLinearVelocity
		local newY = bodyVelocity.Y + (gravityForce * RunService.Heartbeat:Wait())

		-- Cap falling speed
		newY = math.max(newY, -PHYSICS_CONSTANTS.MaxFallSpeed)

		rootPart.AssemblyLinearVelocity = Vector3.new(bodyVelocity.X, newY, bodyVelocity.Z)
	end
end

function Animate:UpdatePhysics(deltaTime)
	-- Do nothing during vault interpolation
	if self.SuppressPhysics or self.IsVaulting then
		return
	end

	-- SLIDE PATH: the slide system owns velocity/animations while active
	if self.State == "Sliding" then
		self:UpdateSlideSystem(deltaTime) -- NEW core slide solver
		self.LastVelocity = self.Character.HumanoidRootPart.AssemblyLinearVelocity
		return
	end

	-- Store
	local rootPart = self.Character.HumanoidRootPart
	local currentVelocity = rootPart.AssemblyLinearVelocity

	-- Custom physical properties each tick (your choice)
	self:ApplyCustomPhysicalProperties()

	-- Prevent wall climb
	self:CheckWallClimbing()

	-- Ground state
	local wasGrounded = self.IsGrounded
	self.IsGrounded = self:CheckGrounded()

	-- Landing detection
	if not wasGrounded and self.IsGrounded then
		local landingVelocity = math.abs(self.LastVelocity.Y)
		if landingVelocity > 5 then
			if self.LandAnim then
				self.JumpState = "Landing"
				self.LandAnim:Play(0.05)
				self.LandAnim.Priority = Enum.AnimationPriority.Action2
			end
			self:OnLanding()

			-- Debounce after sprint jump
			if self.JumpType == "Sprint" then
				self.SprintJumpLandingDebounce = true
				task.spawn(function()
					task.wait(0.5)
					self.SprintJumpLandingDebounce = false
				end)
			end
		end
	end

	-- Update jump anims & gravity
	self:UpdateJumpAnimations()
	self:ApplyJumpGravity()

	-- Movement input
	local moveDirection = self.Humanoid.MoveDirection
	local currentSpeed = self:GetCurrentSpeed()

	-- Backwards penalty
	if moveDirection.Magnitude > 0 then
		local relative = rootPart.CFrame:VectorToObjectSpace(moveDirection)
		if relative.Z > 0.1 then
			currentSpeed *= PHYSICS_CONSTANTS.BackwardMultiplier
		end
	end

	-- Ground vs air
	if self.IsGrounded and not self.Humanoid.Jump then
		self:GroundMove(moveDirection, currentSpeed, PHYSICS_CONSTANTS.GroundAccel, PHYSICS_CONSTANTS.GroundDecel)
	else
		self:AirMove(moveDirection, currentSpeed * 0.3, PHYSICS_CONSTANTS.AirAccel)
	end

	-- Apply plane velocity (unless climbing)
	if self.Humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
		self.LinearVelocity.PlaneVelocity = Vector2.new(self.PlayerVelocity.X, self.PlayerVelocity.Z)
	else
		self.LinearVelocity.PlaneVelocity = Vector2.new(0, 0)
	end

	self.LastVelocity = currentVelocity
end


-- ENHANCED OnLanding function with improved roll detection
function Animate:OnLanding()
	local landingVelocity = math.abs(self.LastVelocity.Y)

	print("🌍 LANDING: Landing detected with velocity:", landingVelocity, "JumpType:", self.JumpType)

	-- Check for queued slide first (highest priority)
	if self.SlideQueued then
		print("🎿 LANDING: Executing queued slide")
		self.SlideQueued = false

		-- Small delay to ensure landing is processed, then slide
		task.spawn(function()
			task.wait(0.1)
			if not self.SlideDebounce then -- Check debounce before executing
				self:Slide()
			else
				print("❌ LANDING: Cannot execute queued slide - debounce active")
			end
		end)

		-- Still do landing camera shake but skip roll animation
		self:DoLandingEffects(landingVelocity)
		return
	end

	-- IMPROVED: Check for roll animation on high falls (no queued slide)
	local rollThreshold = 35 -- Lower threshold for more responsive rolling
	-- Roll should trigger for ANY high-velocity landing, regardless of jump type
	if landingVelocity > rollThreshold and self.RollAnim then
		print("🤸 LANDING: High fall detected, playing roll animation")
		self:PlayRollAnimation()
		-- Still do landing effects
		self:DoLandingEffects(landingVelocity)
		return
	else
		print("🤸 LANDING: No roll - velocity:", landingVelocity, "threshold:", rollThreshold, "rollAnim exists:", self.RollAnim ~= nil)
	end

	-- Normal landing - play regular landing animation and effects
	self:PlayNormalLanding()
	self:DoLandingEffects(landingVelocity)
end

-- ENHANCED: Play roll animation for high falls
function Animate:PlayRollAnimation()
	-- Stop ALL conflicting animations
	if self.LandAnim and self.LandAnim.IsPlaying then
		self.LandAnim:Stop(0)
	end
	if self.FallAnim and self.FallAnim.IsPlaying then
		self.FallAnim:Stop(0)
	end
	if self.JumpAnim and self.JumpAnim.IsPlaying then
		self.JumpAnim:Stop(0)
	end

	-- Play roll animation
	self.RollAnim:Play(0.05, 1, 1) -- Start with full weight immediately
	self.RollAnim.Priority = Enum.AnimationPriority.Action4 -- Highest priority
	print("🤸 ROLL: Roll animation started with Action4 priority")

	-- Auto-stop roll animation after it completes
	task.spawn(function()
		local rollLength = self.RollAnim.Length > 0 and self.RollAnim.Length or 1.5 -- Default length
		print("🤸 ROLL: Roll animation length:", rollLength)

		task.wait(rollLength + 0.1) -- Wait for animation plus small buffer

		if self.RollAnim and self.RollAnim.IsPlaying then
			self.RollAnim:AdjustWeight(0, 0.3) -- Fade out
			task.wait(0.3)
			self.RollAnim:Stop()
			print("🤸 ROLL: Roll animation completed")
		end
	end)
end

-- NEW: Play normal landing animation
function Animate:PlayNormalLanding()
	-- Force landing animation before other effects
	if self.LandAnim then
		self.JumpState = "Landing"
		self.LandAnim:Play(0.05, 1, 1)
		self.LandAnim.Priority = Enum.AnimationPriority.Action2

		-- Enhanced cleanup with proper state management
		task.spawn(function()
			task.wait(0.8) -- Longer wait to ensure full animation
			if self.LandAnim and self.LandAnim.IsPlaying then
				self.LandAnim:Stop(0.4) -- Slower fade out
			end

			-- Wait for fade out to complete then clear states
			task.wait(0.4)
			if self.JumpState == "Landing" then
				self.JumpState = "None"
				self.LastJumpState = "None"

				-- Double check no jump animations are playing
				if self.FallAnim and self.FallAnim.IsPlaying then
					self.FallAnim:Stop(0)
				end
				if self.JumpAnim and self.JumpAnim.IsPlaying then
					self.JumpAnim:Stop(0)
				end
			end
		end)
	end
end

-- NEW: Separated landing effects (camera shake, etc.)
function Animate:DoLandingEffects(landingVelocity)
	-- FORCE STOP all jump-related animations immediately
	if self.FallAnim and self.FallAnim.IsPlaying then
		self.FallAnim:Stop(0) -- Immediate stop
	end
	if self.JumpAnim and self.JumpAnim.IsPlaying then
		self.JumpAnim:Stop(0) -- Immediate stop
	end

	-- Camera shake logic with MORE INTENSIVE effects
	if not self.CameraShaker then
		return
	end

	-- ENHANCED camera shake intensity for more dramatic landing feel
	local shakeInstance
	if landingVelocity > PHYSICS_CONSTANTS.HardLandingThreshold then
		-- Hard landing - very intense shake
		shakeInstance = CameraShakePresets.Explosion
		shakeInstance:SetScaleMagnitude(1.5)  -- Increased from 0.5 to 1.5
	elseif landingVelocity > PHYSICS_CONSTANTS.LandingVelocityThreshold then
		-- Medium landing - intense shake
		shakeInstance = CameraShakePresets.Bump
		shakeInstance:SetScaleMagnitude(1.0)  -- Increased from 0.3 to 1.0
	else
		-- Light landing - noticeable shake
		shakeInstance = CameraShakeInstance.new(1.2, 8, 0, 0.6)  -- Increased intensity and duration
		shakeInstance.PositionInfluence = Vector3.new(0.15, 0.2, 0.15)  -- Much more position shake
		shakeInstance.RotationInfluence = Vector3.new(0.8, 0.6, 0.8)    -- Much more rotation shake
	end

	self.CameraShaker:Shake(shakeInstance)
	self.JumpType = "None"
end

function Animate:UpdateGlobalState()
	_G.AnimateState = self.State

	-- Provide detailed state info for camera bobble system
	if self.State == "Sliding" then
		_G.AnimateState = "Sliding" -- Camera should handle this specially
	elseif self.State == "Sprinting" then
		_G.AnimateState = "Sprinting"
	elseif self.State == "Crouching" then
		_G.AnimateState = "Crouching" -- Might want reduced bobble
	else
		_G.AnimateState = "Walking"
	end
end

function Animate:WalkJump()
	print("🚶 WALK JUMP: Function called")

	if not self.IsGrounded then 
		print("❌ WALK JUMP: Not grounded, cannot walk jump")
		return 
	end

	print("✅ WALK JUMP: Player is grounded, executing walk jump")

	local rootPart = self.Character.HumanoidRootPart
	local jumpVector = Vector3.new(0, PHYSICS_CONSTANTS.WalkJumpPower, 0)

	if self.Humanoid.MoveDirection.Magnitude > 0.1 then
		local forward = rootPart.CFrame.LookVector
		jumpVector += forward * 8
	end

	rootPart:ApplyImpulse(jumpVector * rootPart.AssemblyMass)

	self.JumpType = "Walk"
	self.IsGrounded = false
	self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	print("🎭 WALK JUMP: Setting jump state and playing animation")
	-- Start jump animation immediately
	self.JumpState = "Jumping"
	self.JumpAnim:Play(0.1)
	self.JumpAnim.Priority = Enum.AnimationPriority.Action

	-- Light camera shake on jump
	if self.CameraShaker then
		local shake = CameraShakeInstance.new(0.3, 6, 0, 0.2)
		shake.PositionInfluence = Vector3.new(0.02, 0.02, 0.02)
		shake.RotationInfluence = Vector3.new(0.2, 0.2, 0.2)
		self.CameraShaker:Shake(shake)
	end

	print("✅ WALK JUMP: Walk jump completed")
end

function Animate:SprintJump()
	print("🏃 SPRINT JUMP: Function called")

	if not self.IsGrounded then 
		print("❌ SPRINT JUMP: Not grounded, cannot sprint jump")
		return 
	end

	print("✅ SPRINT JUMP: Player is grounded, executing sprint jump")

	local rootPart = self.Character.HumanoidRootPart

	-- ENHANCED SPRINT JUMP: Create natural arc motion
	local verticalForce = PHYSICS_CONSTANTS.SprintJumpPower
	local forwardForce = PHYSICS_CONSTANTS.SprintJumpForwardBoost

	-- Always apply forward force when sprint jumping (even if not moving)
	local forwardDirection = rootPart.CFrame.LookVector
	if self.Humanoid.MoveDirection.Magnitude > 0.1 then
		-- Use actual movement direction if moving
		forwardDirection = self.Humanoid.MoveDirection.Unit
	end

	-- Create the arc motion: combine vertical and forward forces
	local jumpVector = Vector3.new(0, verticalForce, 0) + (forwardDirection * forwardForce)

	-- Apply the combined impulse for natural arc
	rootPart:ApplyImpulse(jumpVector * rootPart.AssemblyMass)

	-- Add slight upward angle for better arc feel
	local additionalLift = forwardDirection * (forwardForce * 0.3) + Vector3.new(0, verticalForce * 0.2, 0)
	task.wait(0.05) -- Small delay for natural feeling
	rootPart:ApplyImpulse(additionalLift * rootPart.AssemblyMass)

	self.JumpType = "Sprint"
	self.IsGrounded = false
	self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	print("🎭 SPRINT JUMP: Setting jump state and playing animation")
	-- Start jump animation immediately
	self.JumpState = "Jumping"
	self.JumpAnim:Play(0.1)
	self.JumpAnim.Priority = Enum.AnimationPriority.Action

	self:TweenFOV(TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), _G.DefaultFOV + 15)

	-- Moderate camera shake on sprint jump
	if self.CameraShaker then
		local shake = CameraShakeInstance.new(0.8, 8, 0, 0.4)
		shake.PositionInfluence = Vector3.new(0.06, 0.06, 0.06)
		shake.RotationInfluence = Vector3.new(0.4, 0.4, 0.4)
		self.CameraShaker:Shake(shake)
	end

	task.spawn(function()
		task.wait(0.8)
		if self.State == "Sprinting" then
			self:TweenFOV(FieldOfViewInfos.Sprint, _G.DefaultFOV + 10)
		else
			self:TweenFOV(FieldOfViewInfos.Walk, _G.DefaultFOV)
		end
	end)

	print("✅ SPRINT JUMP: Sprint jump completed")
end

-- NEW: Vaulting system
function Animate:CheckVaultable()
	print("🔍 VAULT DEBUG: Checking if vault is possible...")

	local rootPart = self.Character.HumanoidRootPart
	local humanoidRootPartPos = rootPart.Position
	local forwardDirection = rootPart.CFrame.LookVector

	print("🔍 VAULT DEBUG: Player position:", humanoidRootPartPos)
	print("🔍 VAULT DEBUG: Forward direction:", forwardDirection)

	-- Create raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {self.Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Check for wall in front
	local wallRayOrigin = humanoidRootPartPos
	local wallRayDirection = forwardDirection * PHYSICS_CONSTANTS.VaultRayDistance
	local wallResult = workspace:Raycast(wallRayOrigin, wallRayDirection, raycastParams)

	print("🔍 VAULT DEBUG: Wall raycast origin:", wallRayOrigin)
	print("🔍 VAULT DEBUG: Wall raycast direction:", wallRayDirection)
	print("🔍 VAULT DEBUG: Wall raycast result:", wallResult)

	if not wallResult then
		print("❌ VAULT DEBUG: No wall found in front")
		return false, nil, nil
	end

	print("✅ VAULT DEBUG: Wall found at:", wallResult.Position)

	-- Get the wall part and check for "Vaultable" tag
	local wallPart = wallResult.Instance
	print("🔍 VAULT DEBUG: Wall part:", wallPart.Name)
	print("🔍 VAULT DEBUG: Wall part type:", wallPart.ClassName)

	-- Check if the wall has the "Vaultable" tag
	local hasVaultableTag = wallPart:HasTag("Vaultable")
	print("🔍 VAULT DEBUG: Has 'Vaultable' tag:", hasVaultableTag)

	if not hasVaultableTag then
		print("❌ VAULT DEBUG: Wall does not have 'Vaultable' tag")
		return false, nil, nil
	end

	print("✅ VAULT DEBUG: Wall has 'Vaultable' tag!")

	local wallSize = wallPart.Size
	local wallCFrame = wallPart.CFrame

	print("🔍 VAULT DEBUG: Wall size:", wallSize)
	print("🔍 VAULT DEBUG: Wall CFrame:", wallCFrame)

	-- Calculate vault position: hug the wall, Y at half the wall's height
	local wallTopY = wallCFrame.Position.Y + (wallSize.Y / 2)
	local vaultY = wallCFrame.Position.Y -- Half the wall's height (center Y)

	-- Position to hug the wall surface
	local wallSurfacePosition = wallResult.Position
	local vaultPosition = Vector3.new(
		wallSurfacePosition.X,
		vaultY,
		wallSurfacePosition.Z
	)

	print("🔍 VAULT DEBUG: Wall top Y:", wallTopY)
	print("🔍 VAULT DEBUG: Calculated vault position (wall center Y):", vaultPosition)

	-- Check if there's space for the player at vault position
	local spaceCheckOrigin = vaultPosition + Vector3.new(0, 3, 0)
	local spaceCheckDirection = Vector3.new(0, -6, 0)
	local spaceResult = workspace:Raycast(spaceCheckOrigin, spaceCheckDirection, raycastParams)

	print("🔍 VAULT DEBUG: Space check from:", spaceCheckOrigin)
	print("🔍 VAULT DEBUG: Space check result:", spaceResult)

	-- More lenient space check - just make sure we're not inside something
	if spaceResult and spaceResult.Instance == wallPart then
		print("❌ VAULT DEBUG: Would vault inside the wall")
		return false, nil, nil
	end

	print("✅ VAULT DEBUG: All checks passed! Vault is possible")
	return true, vaultPosition, wallResult.Normal
end

function Animate:Vault()
	print("🚀 VAULT: Vault function called")

	if self.IsVaulting then
		print("❌ VAULT: Already vaulting, ignoring")
		return
	end

	if self.IsGrounded then
		print("❌ VAULT: Player is grounded, cannot vault")
		return
	end

	print("🔍 VAULT: Checking if vault is possible...")
	local canVault, vaultPosition, surfaceNormal = self:CheckVaultable()
	if not canVault then
		print("❌ VAULT: Vault not possible")
		return
	end

	print("🎯 VAULT: Starting vault to position:", vaultPosition)
	print("🎯 VAULT: Surface normal:", surfaceNormal)

	-- Set vaulting state
	self.IsVaulting = true
	self.VaultStarted = true

	local rootPart = self.Character.HumanoidRootPart
	local humanoid = self.Humanoid

	-- Store original camera script state
	local cameraScript = self.Character:FindFirstChild("Camera")
	local originalCameraScriptEnabled = false
	if cameraScript and cameraScript.Enabled then
		originalCameraScriptEnabled = true
		cameraScript.Enabled = false
		print("📷 VAULT: Disabled camera script")
	end

	-- Use PlatformStand to disable player control
	humanoid.PlatformStand = true
	print("🔒 VAULT: PlatformStand enabled - player control disabled")

	-- Create BodyPosition to hold character in place against gravity
	local bodyPosition = Instance.new("BodyPosition")
	bodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
	bodyPosition.Position = vaultPosition
	bodyPosition.D = 500  -- Damping
	bodyPosition.P = 3000 -- Power
	bodyPosition.Parent = rootPart
	self.VaultBodyPosition = bodyPosition
	print("⚓ VAULT: BodyPosition created to hold character in place")

	-- Create BodyAngularVelocity to prevent rotation
	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
	bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
	bodyAngularVelocity.Parent = rootPart
	self.VaultBodyAngularVelocity = bodyAngularVelocity
	print("🔄 VAULT: BodyAngularVelocity created to prevent rotation")

	-- Stop all movement animations
	if self.JumpAnim and self.JumpAnim.IsPlaying then
		self.JumpAnim:Stop(0.1)
		print("🎭 VAULT: Stopped jump animation")
	end
	if self.FallAnim and self.FallAnim.IsPlaying then
		self.FallAnim:Stop(0.1)
		print("🎭 VAULT: Stopped fall animation")
	end

	-- Stop physics updates
	if self.LinearVelocity then
		self.LinearVelocity.PlaneVelocity = Vector2.new(0, 0)
		print("⚡ VAULT: Stopped linear velocity")
	end

	-- Position player at vault start position (hugging the wall)
	local vaultStartCFrame = CFrame.new(vaultPosition, vaultPosition + Vector3.new(surfaceNormal.X, 0, surfaceNormal.Z))
	rootPart.CFrame = vaultStartCFrame
	bodyPosition.Position = vaultPosition
	print("📍 VAULT: Character positioned at vault start (hugging wall)")

	-- Lock camera to head
	local camera = workspace.CurrentCamera
	local head = self.Character:FindFirstChild("Head")
	local cameraConnection

	if head and camera then
		camera.CameraType = Enum.CameraType.Scriptable
		print("📷 VAULT: Camera locked to head")

		cameraConnection = RunService.RenderStepped:Connect(function()
			if head and head.Parent then
				camera.CFrame = head.CFrame
			end
		end)
	end

	-- Play vault animation
	if self.VaultAnim then
		print("🎭 VAULT: Playing vault animation")
		self.VaultAnim:Play(0.1)
		self.VaultAnim.Priority = Enum.AnimationPriority.Action4

		-- Set up animation marker system for precise ending
		self.VaultAnim:GetMarkerReachedSignal("AnimationOver"):Once(function()
			print("🎯 VAULT: AnimationOver marker reached, stopping animation")

			-- Stop the animation at current position
			self.VaultAnim:AdjustSpeed(0)
			print("🎭 VAULT: Animation speed set to 0 (paused)")

			-- Get the current HumanoidRootPart position from the animation
			local finalPosition = rootPart.CFrame
			print("📍 VAULT: Final animation position:", finalPosition)

			-- Update BodyPosition to hold character at final position
			if self.VaultBodyPosition then
				self.VaultBodyPosition.Position = finalPosition.Position
				print("⚓ VAULT: BodyPosition updated to final position")
			end

			-- Ensure character stays in place
			rootPart.CFrame = finalPosition
			print("📍 VAULT: Character positioned at final location")

			-- Clean up the animation and end vault
			task.wait(0.3) -- Longer delay to ensure position is locked
			self:EndVault(cameraConnection, cameraScript, originalCameraScriptEnabled)
		end)

		-- Backup timer in case AnimationOver marker doesn't exist
		task.spawn(function()
			-- Get animation length or use default
			local animLength = 2 -- Default vault animation length
			if self.VaultAnim.Length > 0 then
				animLength = self.VaultAnim.Length
				print("🎭 VAULT: Animation length:", animLength, "seconds")
			else
				print("🎭 VAULT: Using default animation length:", animLength, "seconds")
			end

			print("⏰ VAULT: Backup timer waiting for animation...")
			task.wait(animLength + 1) -- Extra buffer time

			-- Only end if animation hasn't already ended
			if self.IsVaulting then
				print("⚠️ VAULT: Backup timer triggered - AnimationOver marker may be missing")
				warn("VAULT: Consider adding 'AnimationOver' marker to your vault animation")

				-- Get current position and update BodyPosition
				local finalPosition = rootPart.CFrame
				if self.VaultBodyPosition then
					self.VaultBodyPosition.Position = finalPosition.Position
				end
				rootPart.CFrame = finalPosition
				print("📍 VAULT: Character positioned at final location (backup)")

				self:EndVault(cameraConnection, cameraScript, originalCameraScriptEnabled)
			end
		end)
	else
		-- No vault animation found, end immediately
		warn("❌ VAULT: Vault animation not found!")
		self:EndVault(cameraConnection, cameraScript, originalCameraScriptEnabled)
	end
end

function Animate:EndVault(cameraConnection, cameraScript, originalCameraScriptEnabled)
	if not self.IsVaulting then
		print("⚠️ VAULT: EndVault called but not vaulting")
		return -- Already ended
	end

	print("🏁 VAULT: Ending vault sequence")

	-- Clean up the vault animation completely
	if self.VaultAnim and self.VaultAnim.IsPlaying then
		print("🎭 VAULT: Stopping and cleaning up vault animation")
		self.VaultAnim:Stop(0.2) -- Fade out over 0.2 seconds
	end

	-- Get final position one more time before cleanup
	local rootPart = self.Character.HumanoidRootPart
	local finalPosition = rootPart.CFrame
	print("📍 VAULT: Final position before cleanup:", finalPosition)

	-- Clean up BodyPosition and BodyAngularVelocity FIRST
	if self.VaultBodyPosition then
		self.VaultBodyPosition:Destroy()
		self.VaultBodyPosition = nil
		print("⚓ VAULT: BodyPosition destroyed")
	end

	if self.VaultBodyAngularVelocity then
		self.VaultBodyAngularVelocity:Destroy()
		self.VaultBodyAngularVelocity = nil
		print("🔄 VAULT: BodyAngularVelocity destroyed")
	end

	-- Now set final position one more time
	rootPart.CFrame = finalPosition
	print("📍 VAULT: Character positioned at final location after cleanup")

	-- Zero out any velocities one final time
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	print("⚡ VAULT: Final velocity zero")

	-- Small delay to ensure position is set before re-enabling physics
	task.wait(0.1)

	-- Re-enable player control by disabling PlatformStand
	self.Humanoid.PlatformStand = false
	print("🔓 VAULT: PlatformStand disabled - player control re-enabled")

	-- Restore camera
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	print("📷 VAULT: Camera restored to custom")

	-- Disconnect camera lock
	if cameraConnection then
		cameraConnection:Disconnect()
		print("📷 VAULT: Camera connection disconnected")
	end

	-- Re-enable camera script if it was originally enabled
	if cameraScript and originalCameraScriptEnabled then
		cameraScript.Enabled = true
		print("📷 VAULT: Camera script re-enabled")
	end

	-- Reset vaulting state
	self.IsVaulting = false
	self.VaultStarted = false
	print("🔄 VAULT: States reset")

	-- Reset jump states to prevent animation conflicts
	self.JumpState = "None"
	self.LastJumpState = "None"
	print("🎭 VAULT: Jump states reset")

	-- Small delay before allowing normal physics again
	task.wait(0.1)

	-- Force grounded check
	self.IsGrounded = true
	print("🌍 VAULT: Forced grounded state")

	print("🎉 VAULT: Vault completed successfully! Character positioned using BodyPosition system.")
end

function Animate:UpdateDirectionalWalk()
	-- Use the velocity from our physics system instead of AssemblyLinearVelocity
	local Direction = self.Character.HumanoidRootPart.CFrame:VectorToObjectSpace(self.PlayerVelocity)
	local Humanoid = self.Humanoid
	local baseSpeed = self:GetCurrentSpeed()

	-- Expose velocity info for camera bobble system
	_G.PlayerHorizontalSpeed = Vector3.new(self.PlayerVelocity.X, 0, self.PlayerVelocity.Z).Magnitude
	_G.PlayerMovementDirection = self.Humanoid.MoveDirection

	local Forward = math.abs(math.clamp(Direction.Z / baseSpeed, -1, -0.001))
	local Backwards = math.abs(math.clamp(Direction.Z / baseSpeed, 0.001, 1))
	local Right = math.abs(math.clamp(Direction.X / baseSpeed, 0.001, 1))
	local Left = math.abs(math.clamp(Direction.X / baseSpeed, -1, -0.001))

	local SpeedMultiplier = Direction.Z > 0.1 and 0.7 or 1

	if Direction.Z / baseSpeed < 0.1 then
		self.WalkForward:AdjustWeight(Forward)
		self.WalkRight:AdjustWeight(Right)
		self.WalkLeft:AdjustWeight(Left)

		self.WalkForward:AdjustSpeed((Direction.Magnitude / baseSpeed) * SpeedMultiplier)
		self.WalkRight:AdjustSpeed((Direction.Magnitude / baseSpeed) * SpeedMultiplier)
		self.WalkLeft:AdjustSpeed((Direction.Magnitude / baseSpeed) * SpeedMultiplier)
	else
		self.WalkForward:AdjustWeight(Backwards)
		self.WalkRight:AdjustWeight(Left)
		self.WalkLeft:AdjustWeight(Right)

		self.WalkForward:AdjustSpeed((Direction.Magnitude / baseSpeed) * -SpeedMultiplier)
		self.WalkRight:AdjustSpeed((Direction.Magnitude / baseSpeed) * -SpeedMultiplier)
		self.WalkLeft:AdjustSpeed((Direction.Magnitude / baseSpeed) * -SpeedMultiplier)
	end
end

function Animate:ReApplyDirectionalWalk(AnimationsToStop)
	for Index, Value : AnimationTrack in pairs(AnimationsToStop) do
		Value:AdjustWeight(0.001, 0.125)
		Value:AdjustSpeed(0)
		Value:Stop(0.125)
	end

	self.WalkForward:Play(0.125, 0.001, 0)
	self.WalkRight:Play(0.125, 0.001, 0)
	self.WalkLeft:Play(0.125, 0.001, 0)
end

function Animate:UpdateCrouch()
	local Speed = self.Humanoid.MoveDirection.Magnitude

	if Speed > 0 then
		self.CrouchAnim:AdjustWeight(1, 0.125)
		self.CrouchAnim:AdjustSpeed(1)
	else
		self.CrouchAnim:AdjustSpeed(0)
	end
end

-- LEGACY: Compatibility function for UpdateSlide
function Animate:UpdateSlide()
	print("⚠️ SLIDE: Using legacy UpdateSlide - this should not happen in new system")
	-- Don't do anything - new system handles slide updates differently
end

function Animate:UpdateSprint()
	local Speed = self.Humanoid.MoveDirection.Magnitude
	if Speed > 0 then
		self.SprintAnim:AdjustWeight(1, .125)
		self.SprintAnim:AdjustSpeed(1)
	else
		self.SprintAnim:AdjustWeight(0.001, .125)
		self.SprintAnim:AdjustSpeed(0)
	end
end

function Animate:PlayFootstep(Foot, Material)
	if not Foot then return end

	local Sounds = Footsteps.sounds[Material]
	if not Sounds then return end

	local RandomNumber = Random.new()
	local SoundID = Sounds[RandomNumber:NextInteger(1, #Sounds)]

	if SoundID and SoundID ~= self.LastFootstepSound then
		self.LastFootstepSound = SoundID
		local Volume
		if self.State == "Walking" then
			Volume = 0.65
		elseif self.State == "Crouching" then
			Volume = 0.275
		elseif self.State == "Sprinting" then
			Volume = 1.1
		end
		SoundModule.PlaySoundFromID(SoundID, self.Character.PrimaryPart, Volume)
	else
		self:PlayFootstep(Foot, Material)
	end
end

function Animate:OnFootstep(Side)
	local Foot = self.Character:FindFirstChild(Side.."Foot")
	local FloorMaterial = self.Humanoid.FloorMaterial
	local Material = Footsteps.materialMap[FloorMaterial]

	self:PlayFootstep(Foot, Material)

	-- NEW: Trigger camera footstep shake
	if _G.TriggerFootstepShake then
		_G.TriggerFootstepShake(Side)
	end
end

function Animate:TweenHipHeight(Value, Time)
	local Info = TweenInfo.new(Time, Enum.EasingStyle.Bounce)
	local Tween = TweenService:Create(self.Humanoid, Info, {HipHeight = Value})
	Tween:Play()

	Tween.Completed:Once(function()
		Tween:Destroy()
		Tween = nil
	end)
end

function Animate:CheckHeadCrouching()
	local RayOrigin = self.Character and self.Character.Head.Position
	local RayDirection = Vector3.new(0, 2, 0)

	local CastParams = RaycastParams.new()
	CastParams.FilterDescendantsInstances = self.Character:GetDescendants()
	CastParams.FilterType = Enum.RaycastFilterType.Exclude
	local RaycastResult = workspace:Raycast(RayOrigin, RayDirection, CastParams)

	if RaycastResult then
		return false
	else
		return true
	end
end

function Animate:TweenBarOnOff(Transparency)
	local QuickInfo = TweenInfo.new(.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	local StrokeTransparency 

	if Transparency == 1 then
		StrokeTransparency = Transparency
	elseif Transparency == 0 then 
		StrokeTransparency = 0.5
	end

	for Index, Value in pairs(SprintBar.Parent:GetChildren()) do
		if Value:IsA("UIStroke") then
			local Tween = TweenService:Create(Value, QuickInfo, {Transparency = StrokeTransparency})
			Tween:Play()
		elseif Value:IsA("GuiObject") then
			local Tween = TweenService:Create(Value, QuickInfo, {BackgroundTransparency = Transparency})
			Tween:Play()
		end
	end
	local BackgroundTween = TweenService:Create(SprintBar.Parent, QuickInfo, {BackgroundTransparency = StrokeTransparency})
	BackgroundTween:Play()
end

function Animate:ResetDirectionalWalk(AnimationsToPlayAfter)
	if self.MovementConnections.DirectionalWalkingConnection then 
		self.MovementConnections.DirectionalWalkingConnection:Disconnect() 
		self.MovementConnections.DirectionalWalkingConnection = nil 
	end
	if self.MovementConnections.CrouchAnimateUpdate and self.State ~= "Crouching" then 
		self.MovementConnections.CrouchAnimateUpdate:Disconnect() 
		self.MovementConnections.CrouchAnimateUpdate = nil 
	end

	self.WalkForward:AdjustWeight(0.001, .125)
	self.WalkRight:AdjustWeight(0.001, .125)
	self.WalkLeft:AdjustWeight(0.001, .125)

	self.WalkForward:Stop(0.125)
	self.WalkRight:Stop(0.125)
	self.WalkLeft:Stop(0.125)

	local Direction = self.Humanoid.MoveDirection.Magnitude
	for Index, Value in pairs(AnimationsToPlayAfter) do
		Value:Play(0, 0.001, 0)

		if Value.Name == "Crouch" then
			if Direction < 0.1 then
				Value:AdjustWeight(1)
				Value:AdjustSpeed(1, .125)
			end
		end
	end
end

function Animate:Regenerate()
	task.spawn(function()
		repeat 
			if self.State == "Sprinting" then
				DelayTime = .075
				break
			elseif self.State == "Walking" or self.State == "Crouching" then
				DelayTime = .075
			end
			task.wait(DelayTime)

			if self.Stamina == Max then
				break
			end
			self.Stamina += Rate
			self:TweenStamina()
		until self.Stamina == Max
	end)
end

function Animate:TweenStamina()
	local SprintInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic)
	local StaminaRatio = self.Stamina / Max
	local BarColor = Color3.new(1, 1, 1)

	if self.Stamina <= 25 then
		BarColor = Color3.fromRGB(255, 0, 0)
	elseif self.Stamina <= 50 then
		BarColor = Color3.fromRGB(255, 165, 0)
	elseif self.Stamina <= 75 then
		BarColor = Color3.fromRGB(255, 255, 0)
	end

	local TweenSize = TweenService:Create(SprintBar, SprintInfo, {Size = UDim2.new(StaminaRatio, 0, 1, 0)})
	local TweenColor = TweenService:Create(SprintBar, SprintInfo, {BackgroundColor3 = BarColor})

	TweenSize:Play()
	TweenColor:Play()

	TweenSize.Completed:Once(function()
		TweenSize:Destroy()
		TweenColor:Destroy()
	end)
end

function Animate:TweenFOV(Info, FOV)
	TweenService:Create(workspace.CurrentCamera, Info, {FieldOfView = FOV}):Play()
end

function Animate:TweenVignette(Info, Transparency)
	TweenService:Create(PlayerGUI.Vignette.BlackVignette, Info, {ImageTransparency = Transparency}):Play()
end

function Animate:Deplete()
	local function ReturnToNormal()
		self:TweenFOV(FieldOfViewInfos.Walk, (_G.DefaultFOV))
		self:TweenVignette(FieldOfViewInfos.Walk, 1)
		PlayerGUI.NewVitals.Main.MovementIcon.Image = WalkIcon
		self:Regenerate()
		self:TweenBarOnOff(1)

		self:DisconnectFunction(self.MovementConnections.SprintAnimateUpdate)

		self:ReApplyDirectionalWalk({self.SprintAnim})
		self.MovementConnections.DirectionalWalkingConnection = RunService.RenderStepped:Connect(function()
			self:UpdateDirectionalWalk()
		end)
	end

	task.spawn(function()
		while task.wait(DepleteTime) do
			if self.State == "Walking" then
				break
			end
			local RelativeDirection = self.Character.HumanoidRootPart.CFrame:VectorToObjectSpace(self.Humanoid.MoveDirection)
			if self.Humanoid.MoveDirection.Magnitude < 0.1 or RelativeDirection.Z > 0.1 then
				self.State = "Walking"
				ReturnToNormal()
				break
			end
			if self.Stamina == 0 then
				self.State = "Walking"
				ReturnToNormal()
				break
			end
			self.Stamina -= Rate
			self:TweenStamina()
		end
	end)
end

function Animate:Sprint()
	print("🏃 SPRINT: Sprint input detected")

	-- Prevent sprinting when sliding
	if self.State == "Sliding" then
		print("❌ SPRINT: Cannot sprint while sliding")
		return
	end

	if self.State == "Crouching" then 
		print("❌ SPRINT: Cannot sprint while crouching")
		return warn("Already crouching, can't sprint") 
	elseif self.State == "Walking" then
		local RelativeDirection = self.Character.HumanoidRootPart.CFrame:VectorToObjectSpace(self.Humanoid.MoveDirection)
		if self.Humanoid.MoveDirection.Magnitude < 0.1 or RelativeDirection.Z > 0.1 then
			print("❌ SPRINT: Cannot sprint while standing still or moving backwards")
			warn("Cannot sprint while standing still or moving backwards")
			return 
		end

		print("✅ SPRINT: Starting sprint")
		self:TweenFOV(FieldOfViewInfos.Sprint, (_G.DefaultFOV + 10))
		self:Deplete()
		PlayerGUI.NewVitals.Main.MovementIcon.Image = SprintIcon

		self:TweenBarOnOff(0)
		self.State = "Sprinting"
		self:UpdateGlobalState()
		self:ResetDirectionalWalk({self.SprintAnim})

		self.MovementConnections.SprintAnimateUpdate = RunService.RenderStepped:Connect(function()
			self:UpdateSprint()
		end)

	elseif self.State == "Sprinting" then
		print("🔄 SPRINT: Stopping sprint, returning to walking")
		self.State = "Walking"
		self:UpdateGlobalState()

		self:TweenFOV(FieldOfViewInfos.Walk, (_G.DefaultFOV))
		self:TweenVignette(FieldOfViewInfos.Walk, 1)
		PlayerGUI.NewVitals.Main.MovementIcon.Image = WalkIcon
		self:Regenerate()
		self:TweenBarOnOff(1)

		self:DisconnectFunction(self.MovementConnections.SprintAnimateUpdate)

		self:ReApplyDirectionalWalk({self.SprintAnim})
		self.MovementConnections.DirectionalWalkingConnection = RunService.RenderStepped:Connect(function()
			self:UpdateDirectionalWalk()
		end)
	end
end

function Animate:Crouch()
	print("🎮 CROUCH: Crouch input detected")

	-- Check slide debounce
	if self.SlideDebounce then
		print("❌ CROUCH: Slide is on cooldown")
		return
	end

	-- Handle sliding when sprinting
	if self.State == "Sprinting" then
		-- Check if grounded for immediate slide
		if self.IsGrounded then
			print("🎿 SLIDE: Converting sprint to slide")
			self:Slide()
		else
			-- Queue slide for when player lands
			print("🎿 SLIDE: Queuing slide for landing (in air)")
			self.SlideQueued = true
		end
		return
	end

	-- Prevent crouching in air
	if not self.IsGrounded then
		print("❌ CROUCH: Cannot crouch while in air")
		return
	end

	-- Prevent crouching when sliding
	if self.State == "Sliding" then
		print("❌ CROUCH: Cannot crouch while sliding")
		return
	end

	if self:CheckHeadCrouching() then
		if self.State == "Crouching" then
			print("🔄 CROUCH: Exiting crouch to walking")
			self.State = "Walking"
			self:UpdateGlobalState()
			self:TweenHipHeight(2, .5)
			self:DisconnectFunction(self.MovementConnections.CrouchAnimateUpdate)
			self:ReApplyDirectionalWalk({self.CrouchAnim, self.SprintAnim})

			self:TweenFOV(FieldOfViewInfos.Walk, (_G.DefaultFOV))
			self:TweenVignette(FieldOfViewInfos.Walk, 1)
			PlayerGUI.NewVitals.Main.MovementIcon.Image = WalkIcon
			self:Regenerate()
			self:TweenBarOnOff(1)
			self:DisconnectFunction(self.MovementConnections.SprintAnimateUpdate)

			self.MovementConnections.DirectionalWalkingConnection = RunService.RenderStepped:Connect(function()
				self:UpdateDirectionalWalk()
			end)

		elseif self.State == "Walking" then
			print("🔄 CROUCH: Entering crouch from walking")
			self.State = "Crouching"
			self:UpdateGlobalState()
			self:TweenHipHeight(1, 1)

			self:TweenFOV(FieldOfViewInfos.Sprint, (_G.DefaultFOV - 10))
			self:TweenVignette(FieldOfViewInfos.Crouch, 0)
			PlayerGUI.NewVitals.Main.MovementIcon.Image = CrouchIcon

			self:ResetDirectionalWalk({self.CrouchAnim})

			self.MovementConnections.CrouchAnimateUpdate = RunService.RenderStepped:Connect(function()
				self:UpdateCrouch() -- Make sure this calls the right function
			end)
		end
	end
end
function Animate:UpdateSlideSystem(deltaTime)
	-- This is called from the camera script's UpdatePhysics
	if self.State ~= "Sliding" then
		return
	end

	-- Handle slide physics here
	local rootPart = self.Character.HumanoidRootPart
	local currentVelocity = rootPart.AssemblyLinearVelocity
	local slideDirection = Vector3.new(currentVelocity.X, 0, currentVelocity.Z).Unit

	-- Apply slide friction
	local slideFriction = PHYSICS_CONSTANTS.SlideFriction or 18
	local slideControl = PHYSICS_CONSTANTS.SlideControl or 0.20
	local slideMinSpeed = PHYSICS_CONSTANTS.SlideMinSpeed or 6

	-- Get input direction for steering
	local inputDirection = self.Humanoid.MoveDirection
	local steerForce = inputDirection * slideControl * 10

	-- Apply friction and steering
	local horizontalVel = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
	local frictionForce = -horizontalVel.Unit * slideFriction * deltaTime

	-- Combine forces
	local newHorizontalVel = horizontalVel + frictionForce + steerForce

	-- Check if slide should end due to low speed
	if newHorizontalVel.Magnitude < slideMinSpeed then
		self:RequestSlideExit()
		return
	end

	-- Apply the new velocity
	rootPart.AssemblyLinearVelocity = Vector3.new(newHorizontalVel.X, currentVelocity.Y, newHorizontalVel.Z)

	-- Update slide animation speed based on velocity
	if self.SlideAnim and self.SlideAnim.IsPlaying then
		local speedFactor = math.clamp(newHorizontalVel.Magnitude / 15, 0.3, 1.5)
		self.SlideAnim:AdjustSpeed(speedFactor)
	end
end
function Animate:RequestSlideExit()
	if self.State == "Sliding" then
		self.SlideExitRequested = true
		self:ExitSlide()
	end
end
-- NEW: Enhanced Sliding system with proper debounce and animation isolation
function Animate:Slide()
	if self.SlideDebounce then
		print("❌ SLIDE: Slide is on cooldown")
		return
	end

	print("🎿 SLIDE: Starting slide")

	-- Set slide debounce
	self.SlideDebounce = true
	print("⏰ SLIDE: Slide debounce activated")

	-- Set sliding state
	self.State = "Sliding"
	self:UpdateGlobalState()

	-- Give momentum boost when starting slide
	local rootPart = self.Character.HumanoidRootPart
	local slideDirection = self.Humanoid.MoveDirection
	if slideDirection.Magnitude > 0.1 then
		local momentumBoost = slideDirection * 25 -- Forward momentum boost
		rootPart:ApplyImpulse(momentumBoost * rootPart.AssemblyMass)
		print("🚀 SLIDE: Applied momentum boost:", momentumBoost)
	end

	-- Visual changes for sliding
	self:TweenHipHeight(0.5, 0.3) -- Lower than crouch
	self:TweenFOV(FieldOfViewInfos.Sprint, (_G.DefaultFOV + 5)) -- Slight FOV increase
	PlayerGUI.NewVitals.Main.MovementIcon.Image = CrouchIcon -- Use crouch icon for now

	-- CRITICAL: Stop ALL movement connections and animations to prevent conflicts
	self:DisconnectFunction(self.MovementConnections.SprintAnimateUpdate)
	self:DisconnectFunction(self.MovementConnections.DirectionalWalkingConnection)
	self:DisconnectFunction(self.MovementConnections.CrouchAnimateUpdate)
	self:DisconnectFunction(self.MovementConnections.FootstepWeightMonitor)

	-- Stop ALL directional walking animations
	self.WalkForward:Stop(0)
	self.WalkRight:Stop(0)
	self.WalkLeft:Stop(0)

	-- Stop ALL other movement animations
	if self.SprintAnim.IsPlaying then
		self.SprintAnim:Stop(0)
		print("🎭 SLIDE: Stopped sprint animation")
	end
	if self.CrouchAnim.IsPlaying then
		self.CrouchAnim:Stop(0)
		print("🎭 SLIDE: Stopped crouch animation")
	end

	-- Stop ALL jump/fall/land animations that might interfere
	if self.JumpAnim and self.JumpAnim.IsPlaying then
		self.JumpAnim:Stop(0)
		print("🎭 SLIDE: Stopped jump animation")
	end
	if self.FallAnim and self.FallAnim.IsPlaying then
		self.FallAnim:Stop(0)
		print("🎭 SLIDE: Stopped fall animation")
	end
	if self.LandAnim and self.LandAnim.IsPlaying then
		self.LandAnim:Stop(0)
		print("🎭 SLIDE: Stopped land animation")
	end
	if self.RollAnim and self.RollAnim.IsPlaying then
		self.RollAnim:Stop(0)
		print("🎭 SLIDE: Stopped roll animation")
	end

	-- Play slide animation as looping action animation
	if self.SlideAnim then
		print("🎭 SLIDE: Playing slide animation")
		self.SlideAnim:Play(0.2) -- Slightly longer fade in
		self.SlideAnim.Priority = Enum.AnimationPriority.Action4 -- Highest priority to override everything
		self.SlideAnim.Looped = true -- Ensure it loops
		print("🎭 SLIDE: Slide animation started with Action4 priority and looping")
	else
		warn("🎿 SLIDE: Slide animation not found! Make sure 'Slide' animation exists in MovementAnimations")
	end

	-- Set up slide animation update (for speed control) - REMOVED OLD REFERENCE
	self.MovementConnections.SlideAnimateUpdate = RunService.RenderStepped:Connect(function()
		self:UpdateSlideSystem() -- Fixed: was calling UpdateSlide
	end)

	-- Set up slide monitoring to ensure it ends properly
	self.MovementConnections.SlideMonitor = RunService.RenderStepped:Connect(function()
		self:MonitorSlide()
	end)

	print("🎿 SLIDE: Slide started, player locked in sliding state")

	-- Store slide start info for exit conditions
	self.SlideStartTime = tick()
	self.SlideExitRequested = false

	-- Auto-exit slide with better conditions
	task.spawn(function()
		while self.State == "Sliding" and not self.SlideExitRequested do
			task.wait(0.1)

			local currentTime = tick()
			local slideTime = currentTime - self.SlideStartTime
			local isMoving = self.Humanoid.MoveDirection.Magnitude > 0.1

			-- Exit slide if 2 seconds reached OR player stopped moving
			if slideTime >= 2.0 or not isMoving then
				print("🎿 SLIDE: Auto-exiting slide - Time:", slideTime, "Moving:", isMoving)
				self:ExitSlide()
				break
			end
		end
	end)
end

-- NEW: Monitor slide to prevent indefinite sliding
function Animate:MonitorSlide()
	if self.State ~= "Sliding" then
		return
	end

	-- Force exit if slide has been going too long
	if self.SlideStartTime and (tick() - self.SlideStartTime) > 3.0 then
		print("⚠️ SLIDE: Force-exiting slide after 3 seconds")
		self:ExitSlide()
	end

	-- Force exit if player becomes airborne for too long during slide
	if not self.IsGrounded then
		if not self.SlideAirTime then
			self.SlideAirTime = tick()
		elseif (tick() - self.SlideAirTime) > 1.0 then
			print("⚠️ SLIDE: Force-exiting slide - airborne too long")
			self:ExitSlide()
		end
	else
		self.SlideAirTime = nil
	end
end

function Animate:ExitSlide()
	if self.State ~= "Sliding" then
		return
	end

	print("🎿 SLIDE: Exiting slide to walking")

	-- Stop slide animation with proper weight fadeout
	if self.SlideAnim and self.SlideAnim.IsPlaying then
		print("🎭 SLIDE: Stopping slide animation")
		self.SlideAnim:AdjustWeight(0, 0.2) -- Fade out weight first
		task.wait(0.1)
		self.SlideAnim:Stop(0.2) -- Then stop
	end

	-- Clean up slide connections FIRST
	self:DisconnectFunction(self.MovementConnections.SlideAnimateUpdate)
	self:DisconnectFunction(self.MovementConnections.SlideMonitor)

	-- Clear slide state variables
	self.SlideStartTime = nil
	self.SlideExitRequested = false
	self.SlideAirTime = nil

	-- Return to walking state
	self.State = "Walking"
	self:UpdateGlobalState()

	-- Reset visual changes
	self:TweenHipHeight(2, 0.5)
	self:TweenFOV(FieldOfViewInfos.Walk, (_G.DefaultFOV))
	self:TweenVignette(FieldOfViewInfos.Walk, 1)
	PlayerGUI.NewVitals.Main.MovementIcon.Image = WalkIcon
	self:Regenerate()
	self:TweenBarOnOff(1)

	-- Return to normal directional walking
	self.WalkForward:Play(0.2, 0.001, 0)
	self.WalkRight:Play(0.2, 0.001, 0)
	self.WalkLeft:Play(0.2, 0.001, 0)

	-- Reconnect all necessary movement connections
	self.MovementConnections.DirectionalWalkingConnection = RunService.RenderStepped:Connect(function()
		self:UpdateDirectionalWalk()
	end)

	self.MovementConnections.FootstepWeightMonitor = RunService.RenderStepped:Connect(function()
		if self.Humanoid and self.Humanoid.MoveDirection.Magnitude > 0.1 then
			self:UpdateFootstepConnections()
		end
	end)

	-- Start slide debounce cooldown
	task.spawn(function()
		task.wait(1.5) -- 1.5 second cooldown
		self.SlideDebounce = false
		print("✅ SLIDE: Slide debounce cleared")
	end)

	print("🎿 SLIDE: Slide exit completed")
end

function Animate:DisconnectFunction(Function)
	if Function and Function.Connected then
		Function:Disconnect()
		Function = nil
	end
end

function Animate:UpdateFootstepConnections()
	local ForwardWeight = self.WalkForward.WeightCurrent
	local LeftWeight = self.WalkLeft.WeightCurrent
	local RightWeight = self.WalkRight.WeightCurrent
	local Connections = self.MovementConnections

	local function SetFootstepConnection(ConnectionKey, AnimationTrack)
		if not Connections[ConnectionKey] then
			Connections[ConnectionKey] = AnimationTrack:GetMarkerReachedSignal("Footstep"):Connect(function(Side)
				self:OnFootstep(Side)
			end)
		end
	end

	local function DisconnectUnusedConnections(ActiveConnections)
		local AllKeys = {
			WalkForwardFootstepConnection = self.WalkForward,
			WalkLeftFootstepConnection = self.WalkLeft,
			WalkRightFootstepConnection = self.WalkRight
		}
		for Key in pairs(AllKeys) do
			if not ActiveConnections[Key] then
				self:DisconnectFunction(Connections[Key])
				Connections[Key] = nil
			end
		end
	end

	local Active = {}

	if ForwardWeight > 0.3 then
		SetFootstepConnection("WalkForwardFootstepConnection", self.WalkForward)
		Active.WalkForwardFootstepConnection = true
	end

	if RightWeight > 0.3 then
		SetFootstepConnection("WalkRightFootstepConnection", self.WalkRight)
		Active.WalkRightFootstepConnection = true
	end

	if LeftWeight > 0.3 then
		SetFootstepConnection("WalkLeftFootstepConnection", self.WalkLeft)
		Active.WalkLeftFootstepConnection = true
	end

	DisconnectUnusedConnections(Active)
end

function Animate:IsJumpAllowed()
	-- Add sprint jump landing debounce check and prevent air jumping
	-- ALSO prevent jumping when very close to walls to avoid phasing
	local tooCloseToWall = self:CheckWallProximity()
	return self.IsGrounded and not self.JumpDebounce and not self.SprintJumpLandingDebounce and not self.IsVaulting and not tooCloseToWall
end

-- NEW: Check if player is too close to a wall to prevent phasing
function Animate:CheckWallProximity()
	local rootPart = self.Character.HumanoidRootPart
	local humanoidRootPartPos = rootPart.Position

	-- Check in multiple directions around the player
	local directions = {
		rootPart.CFrame.LookVector,      -- Forward
		-rootPart.CFrame.LookVector,     -- Backward
		rootPart.CFrame.RightVector,     -- Right
		-rootPart.CFrame.RightVector,    -- Left
	}

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {self.Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	for _, direction in pairs(directions) do
		local rayOrigin = humanoidRootPartPos
		local rayDirection = direction * 3 -- Check 3 studs in each direction
		local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if result then
			print("🚫 JUMP: Too close to wall, preventing jump to avoid phasing")
			return true
		end
	end

	return false
end

function Animate:HandleJump()
	print("🎮 JUMP: HandleJump called")

	-- NEW: If sliding, exit slide and allow jump
	if self.State == "Sliding" then
		print("🎿 JUMP: Exiting slide to allow jump")
		self:RequestSlideExit()
		-- Small delay to let slide exit, then allow jump
		task.wait(0.1)
	end

	if not self:IsJumpAllowed() then
		print("❌ JUMP: Jump not allowed - IsGrounded:", self.IsGrounded, "JumpDebounce:", self.JumpDebounce, "SprintDebounce:", self.SprintJumpLandingDebounce, "IsVaulting:", self.IsVaulting)
		return
	end

	print("✅ JUMP: Jump allowed, setting debounce and jumping")
	self.JumpDebounce = true

	if self.State == "Sprinting" then
		self:SprintJump()
	else
		self:WalkJump()
	end

	-- Wait until grounded again to reset debounce
	coroutine.wrap(function()
		repeat task.wait() until self.IsGrounded
		print("🔄 JUMP: Player landed, waiting additional 0.3s before allowing next jump")
		task.wait(0.3) -- Additional debounce after landing
		self.JumpDebounce = false
		print("✅ JUMP: Jump debounce cleared")
	end)()
end

-- NEW: Handle vault input (jump while airborne)
function Animate:HandleVaultInput()
	print("🎮 VAULT INPUT: Vault input detected while airborne")
	print("🔍 VAULT INPUT: Current state - IsGrounded:", self.IsGrounded, "IsVaulting:", self.IsVaulting)

	if not self.IsGrounded and not self.IsVaulting then
		print("✅ VAULT INPUT: Conditions met, attempting vault")
		self:Vault()
	else
		if self.IsGrounded then
			print("❌ VAULT INPUT: Cannot vault - player is grounded")
		end
		if self.IsVaulting then
			print("❌ VAULT INPUT: Cannot vault - already vaulting")
		end
	end
end

function Animate:ConnectFunctions()
	-- Main physics update connection
	self.MovementConnections.PhysicsUpdate = RunService.Heartbeat:Connect(function(deltaTime)
		self:UpdatePhysics(deltaTime)
	end)

	-- Animation updates
	self.MovementConnections.FootstepWeightMonitor = RunService.RenderStepped:Connect(function()
		if self.Humanoid and self.Humanoid.MoveDirection.Magnitude > 0.1 then
			self:UpdateFootstepConnections()
		end
	end)

	self.MovementConnections.DirectionalWalkingConnection = RunService.RenderStepped:Connect(function()
		self:UpdateDirectionalWalk()
	end)

	-- Static footstep connections
	self.MovementConnections.SprintFootstepConnection = self.SprintAnim:GetMarkerReachedSignal("Footstep"):Connect(function(Side)
		self:OnFootstep(Side)
	end)

	self.MovementConnections.CrouchFootstepConnection = self.CrouchAnim:GetMarkerReachedSignal("Footstep"):Connect(function(Side)
		self:OnFootstep(Side)
	end)

	-- NEW: Slide footstep connection
	if self.SlideAnim then
		self.MovementConnections.SlideFootstepConnection = self.SlideAnim:GetMarkerReachedSignal("Footstep"):Connect(function(Side)
			self:OnFootstep(Side)
		end)
		print("🎭 SETUP: Slide footstep connection established")
	end

	-- Input connections
	self.ConnectionsTable.Crouch = UserInputService.InputBegan:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.ButtonB or Input.KeyCode == Enum.KeyCode.LeftControl or Input.KeyCode == Enum.KeyCode.C then
			self:Crouch()
		end
	end)

	self.ConnectionsTable.Sprint = UserInputService.InputBegan:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.LeftShift or Input.KeyCode == Enum.KeyCode.ButtonL3 then
			self:Sprint()
		end	
	end)

	-- Jump connections - UPDATED to use only JumpRequest for both jumping and vaulting
	local jumpRequestDebounce = false
	self.ConnectionsTable.Jump = UserInputService.JumpRequest:Connect(function()
		print("🎮 INPUT: JumpRequest detected")

		-- Prevent rapid JumpRequest spam from held button
		if jumpRequestDebounce then
			print("🎮 INPUT: JumpRequest debounced, ignoring")
			return
		end

		jumpRequestDebounce = true

		-- Reset debounce after short delay
		task.spawn(function()
			task.wait(0.2) -- 200ms debounce for jump requests
			jumpRequestDebounce = false
			print("🎮 INPUT: JumpRequest debounce cleared")
		end)

		if self:IsJumpAllowed() then
			print("🎮 INPUT: JumpRequest - Jump allowed, handling jump")
			self:HandleJump()
		elseif not self.IsGrounded and not self.IsVaulting then
			print("🎮 INPUT: JumpRequest - Not grounded, trying vault")
			-- Try to vault if in air
			self:HandleVaultInput()
		else
			print("🎮 INPUT: JumpRequest - Jump/Vault not allowed")
			print("🔍 DEBUG: IsGrounded:", self.IsGrounded, "IsVaulting:", self.IsVaulting, "JumpDebounce:", self.JumpDebounce)
		end
	end)

	-- REMOVED: SpaceJump connection - now using only JumpRequest

	-- REMOVED old vault input (E key) since it's now triggered by jump while airborne
end

function Animate:DisconnectFunctions()
	-- Disconnect all movement connections
	for key, connection in pairs(self.MovementConnections) do
		self:DisconnectFunction(connection)
		self.MovementConnections[key] = nil
	end

	-- Disconnect all input connections
	for key, connection in pairs(self.ConnectionsTable) do
		self:DisconnectFunction(connection)
		self.ConnectionsTable[key] = nil
	end

	-- Stop camera shaker (but don't clear global reference if others are using it)
	if self.CameraShaker and self.CameraShaker ~= _G.MainCameraShaker then
		self.CameraShaker:Stop()
	end

	-- Clean up physics objects
	if self.LinearVelocity then
		self.LinearVelocity:Destroy()
		self.LinearVelocity = nil
	end

	-- Clean up global state
	_G.AnimateState = nil
	_G.PlayerHorizontalSpeed = nil
	_G.PlayerMovementDirection = nil
end

function Animate:DeleteCharacterSounds()
	local CharacterSounds = Player.PlayerScripts:FindFirstChild("RbxCharacterSounds")
	if CharacterSounds then
		CharacterSounds:Destroy()
	end
end

function Animate:SetupMovementAnimations()
	for Index, Animation : AnimationTrack in pairs(self.LoadedAnimations) do
		Animation:Play(0, 0.01, 0)
		Animation.Priority = Enum.AnimationPriority.Movement
	end

	-- Make sure slide animation is set up properly
	if self.SlideAnim then
		print("🎭 SETUP: Slide animation loaded successfully")
	else
		warn("🎭 SETUP: Slide animation not found!")
	end
end

function Animate.new(Character)
	local self = setmetatable({
		ConnectionsTable = {},
		Character = Character,
		Humanoid = Character:WaitForChild("Humanoid"),
		MovementConnections = {},
		State = "Walking",
		LastFootstepSound = nil,
		Stamina = Max,

		-- Physics properties
		PlayerVelocity = Vector3.new(0, 0, 0),
		LastVelocity = Vector3.new(0, 0, 0),
		IsGrounded = true,
		JumpType = "None",
		LandingBuffer = 0,
		JumpDebounce = false,
		SprintJumpLandingDebounce = false, -- NEW: Sprint jump landing debounce
		LinearVelocity = nil,
		CameraShaker = nil,

		-- Vaulting properties
		IsVaulting = false,
		VaultStarted = false,
		VaultBodyPosition = nil,      -- Store BodyPosition reference
		VaultBodyAngularVelocity = nil, -- Store BodyAngularVelocity reference

		-- Sliding properties
		SlideStartTime = nil,         -- Track when slide started
		SlideExitRequested = false,   -- Track manual slide exit requests
		SlideQueued = false,          -- Track if slide is queued for landing
		SlideDebounce = false,        -- Prevent slide spam
		SlideAirTime = nil            -- Track how long player has been airborne during slide

	}, Animate)

	local PlayerAnimations = ReplicatedStorage.PlayerAnimations:Clone()
	PlayerAnimations.Parent = Character

	local MovementAnimations = PlayerAnimations.Movement

	self.Animator = self.Humanoid:WaitForChild("Animator")

	self.LoadedAnimations = {
		WalkForward = self.Animator:LoadAnimation(MovementAnimations.Forward),
		WalkLeft = self.Animator:LoadAnimation(MovementAnimations.Left),
		WalkRight = self.Animator:LoadAnimation(MovementAnimations.Right),
		Crouch = self.Animator:LoadAnimation(MovementAnimations.Crouch),
		Sprint = self.Animator:LoadAnimation(MovementAnimations.Sprint),
		Jump = self.Animator:LoadAnimation(MovementAnimations.Jump),
		Fall = self.Animator:LoadAnimation(MovementAnimations.Fall),
		Land = self.Animator:LoadAnimation(MovementAnimations.Land),
		Vault = self.Animator:LoadAnimation(MovementAnimations.Vault), -- NEW: Load vault animation
		Slide = self.Animator:LoadAnimation(MovementAnimations.Slide), -- NEW: Load slide animation
		Roll = self.Animator:LoadAnimation(MovementAnimations.Roll), -- NEW: Load roll animation
	}

	self.WalkForward = self.LoadedAnimations.WalkForward
	self.WalkRight = self.LoadedAnimations.WalkRight
	self.WalkLeft = self.LoadedAnimations.WalkLeft
	self.CrouchAnim = self.LoadedAnimations.Crouch
	self.SprintAnim = self.LoadedAnimations.Sprint
	self.JumpAnim = self.LoadedAnimations.Jump
	self.FallAnim = self.LoadedAnimations.Fall
	self.LandAnim = self.LoadedAnimations.Land
	self.VaultAnim = self.LoadedAnimations.Vault -- NEW: Vault animation reference
	self.SlideAnim = self.LoadedAnimations.Slide -- NEW: Slide animation reference
	self.RollAnim = self.LoadedAnimations.Roll -- NEW: Roll animation reference

	-- Setup physics before other initialization
	self:SetupPhysics()

	self:DeleteCharacterSounds()
	self:SetupMovementAnimations()
	self:ConnectFunctions()
	self:UpdateGlobalState()

	-- Setup idle animation
	local IdleAnim : AnimationTrack = self.Animator:LoadAnimation(MovementAnimations.Idle)
	IdleAnim.Looped = true
	IdleAnim.Priority = Enum.AnimationPriority.Idle
	IdleAnim:Play()

	-- Setup death connection for cleanup
	local diedConnection
	diedConnection = self.Humanoid.Died:Connect(function()
		self:DisconnectFunctions()
		diedConnection:Disconnect()
	end)

	return self
end

function Animate.Init(Character)
	_G.WalkSettings = {
		WalkSpeed = 10.5, 
		CrouchSpeed = 5,
		SprintSpeed = 18
	}

	_G.DefaultFOV = 80

	return Animate.new(Character)
end

return Animate
