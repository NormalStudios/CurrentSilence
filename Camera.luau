local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Import CameraShaker for bobble effects
local CameraShaker = require(ReplicatedStorage.Modules.Shared.CameraShaker)

-- Original settings
local Sensitivity = 0.2
local TouchSensitivity = 3
local GamepadSensitivity = 0.07
local SmoothSpeed = 0.15
local Deadzone = 0.1
local MinPitch = math.rad(-60)
local MaxPitch = math.rad(60)

-- ENHANCED CAMERA BOBBLE SETTINGS
local BobbleSettings = {
	-- Main Controls
	Enabled = true,
	UseCameraShaker = true,  -- Use CameraShaker for smoother bobble

	-- Intensity Settings (increased for more noticeable effect)
	WalkIntensity = 0.15,     -- Base bobble intensity while walking
	RunIntensity = 0.25,      -- Base bobble intensity while running
	SprintIntensity = 0.35,   -- Base bobble intensity while sprinting

	-- Frequency Settings (how fast the bobble cycles)
	WalkFrequency = 6,        -- Bobble cycles per second while walking
	RunFrequency = 8,         -- Bobble cycles per second while running  
	SprintFrequency = 10,     -- Bobble cycles per second while sprinting

	-- Movement Response
	VelocitySmoothing = 0.2,  -- How quickly bobble responds to velocity changes
	IntensitySmoothing = 0.15, -- How quickly intensity changes smooth out

	-- Axis Controls
	VerticalScale = 1.0,      -- Full vertical movement (Y-axis)
	HorizontalScale = 0.2,    -- Horizontal movement (X-axis)
	RollScale = 0.05,         -- Roll effect

	-- Physics Feel
	BounceMultiplier = 1.6,   -- Makes the bobble feel more bouncy
	SineVariation = 0.8,      -- Adds complexity to the sine wave

	-- Frame Rate Compensation
	TargetFrameRate = 60,     -- Reference frame rate
	MaxDeltaTime = 1/20,      -- Cap for very low FPS
	MinDeltaTime = 1/300,     -- Support for very high FPS

	-- Velocity Thresholds
	MinVelocity = 2.0,        -- Minimum velocity to start bobbling
	MaxVelocity = 25,         -- Velocity at which bobble intensity caps
}

-- Landing Shake Settings
local LandingSettings = {
	Enabled = true,
	LightLandingThreshold = 15,   -- Minimum fall velocity for light landing shake
	MediumLandingThreshold = 25,  -- Threshold for medium landing shake
	HardLandingThreshold = 40,    -- Threshold for hard landing shake

	-- Shake intensities
	LightIntensity = 1.2,
	MediumIntensity = 2.5,
	HardIntensity = 4.0,

	-- Shake durations
	LightDuration = 0.3,
	MediumDuration = 0.6,
	HardDuration = 1.0,
}

-- Footstep Shake Settings
local FootstepSettings = {
	Enabled = true,

	-- Intensities by movement state
	WalkIntensity = 0.08,
	SprintIntensity = 0.18,
	CrouchIntensity = 0.04,
	SlideIntensity = 0.12,

	-- Shake properties
	Duration = 0.12,
	Roughness = 15,

	-- Side-to-side variation
	SideVariation = 0.015,
}

-- Breathing Effects Settings
local BreathingSettings = {
	Enabled = true,

	-- Breathing cycle timing
	IdleBreathRate = 4.0,      -- Breaths per minute when idle
	WalkBreathRate = 8.0,      -- Breaths per minute when walking
	SprintBreathRate = 20.0,   -- Breaths per minute when sprinting

	-- Breathing intensity
	IdleIntensity = 0.02,      -- Very subtle when idle
	WalkIntensity = 0.04,      -- Light when walking
	SprintIntensity = 0.08,    -- Noticeable when sprinting

	-- Breathing pattern
	InhaleRatio = 0.4,         -- 40% of cycle is inhaling
	ExhaleRatio = 0.4,         -- 40% of cycle is exhaling
	PauseRatio = 0.2,          -- 20% of cycle is pause between breaths

	-- Visual effects
	VerticalScale = 0.8,       -- How much breathing affects Y movement
	RollScale = 0.3,           -- How much breathing affects roll
}

-- Camera angles
local CurrentYaw = 0
local CurrentPitch = 0
local TargetYaw = 0
local TargetPitch = 0

-- Rotation shifting variables
local ShiftIntensity = 0.5
local ShiftSmooth = 0.2
local MaxShift = math.rad(30)
local CurrentShiftZ = 0
local CurrentShiftX = 0
local TargetShiftZ = 0
local TargetShiftX = 0
local PreviousYaw = 0
local PreviousPitch = 0

-- BOBBLE SYSTEM VARIABLES
local BobbleTime = 0
local CurrentIntensity = 0
local TargetIntensity = 0
local CurrentFrequency = BobbleSettings.WalkFrequency
local TargetFrequency = BobbleSettings.WalkFrequency

-- CameraShaker for bobble
local bobbleCameraShaker = nil
local currentBobbleShake = nil

-- Landing shake tracking
local lastVelocityY = 0
local wasGrounded = true

-- Footstep shake tracking
local lastFootstepTime = 0
local footstepCooldown = 0.3

-- Breathing effect variables
local breathingTime = 0
local currentBreathRate = BreathingSettings.IdleBreathRate
local targetBreathRate = BreathingSettings.IdleBreathRate
local currentBreathIntensity = BreathingSettings.IdleIntensity
local targetBreathIntensity = BreathingSettings.IdleIntensity

-- Velocity tracking
local PreviousPosition = nil
local CurrentVelocity = Vector3.new(0, 0, 0)
local SmoothedVelocity = Vector3.new(0, 0, 0)
local HorizontalSpeed = 0

-- Frame rate compensation
local FrameRateMultiplier = 1.0

-- CAMERA SHAKE INTEGRATION
_G.CameraShakeOffset = _G.CameraShakeOffset or CFrame.new()
_G.LightningCameraShakeOffset = _G.LightningCameraShakeOffset or CFrame.new()
_G.BobbleCameraShakeOffset = _G.BobbleCameraShakeOffset or CFrame.new()
_G.LandingCameraShakeOffset = _G.LandingCameraShakeOffset or CFrame.new()
_G.FootstepCameraShakeOffset = _G.FootstepCameraShakeOffset or CFrame.new()
_G.BreathingCameraShakeOffset = _G.BreathingCameraShakeOffset or CFrame.new()

-- Platform detection
local IsMobile = UserInputService.TouchEnabled
local IsGamepad = false
local LastTouchPosition = nil
local GamepadDelta = Vector2.new()

UserInputService.MouseIconEnabled = false

if not IsMobile then
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

-- INITIALIZE BOBBLE CAMERA SHAKER
local landingCameraShaker = nil
local footstepCameraShaker = nil

local function InitializeBobbleCameraShaker()
	if not bobbleCameraShaker and BobbleSettings.UseCameraShaker then
		print("Initializing Bobble CameraShaker...") -- Debug
		bobbleCameraShaker = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
			_G.BobbleCameraShakeOffset = shakeCFrame
		end)
		bobbleCameraShaker:Start()
		print("Bobble CameraShaker started") -- Debug
	end

	-- Initialize landing camera shaker
	if not landingCameraShaker and LandingSettings.Enabled then
		print("Initializing Landing CameraShaker...")
		landingCameraShaker = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
			_G.LandingCameraShakeOffset = shakeCFrame
		end)
		landingCameraShaker:Start()
		print("Landing CameraShaker started")
	end

	-- Initialize footstep camera shaker
	if not footstepCameraShaker and FootstepSettings.Enabled then
		print("Initializing Footstep CameraShaker...")
		footstepCameraShaker = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
			_G.FootstepCameraShakeOffset = shakeCFrame
		end)
		footstepCameraShaker:Start()
		print("Footstep CameraShaker started")
	end
end

-- FRAME RATE COMPENSATION
local function UpdateFrameRateCompensation(deltaTime)
	local currentFPS = 1 / deltaTime
	FrameRateMultiplier = BobbleSettings.TargetFrameRate / currentFPS
	FrameRateMultiplier = math.clamp(FrameRateMultiplier, 0.5, 2.0)
end

-- VELOCITY CALCULATION WITH LANDING DETECTION
local function UpdateVelocityTracking(headPosition, deltaTime)
	if PreviousPosition then
		-- Calculate raw velocity
		CurrentVelocity = (headPosition - PreviousPosition) / deltaTime

		-- Smooth the velocity with frame rate compensation
		local lerpSpeed = BobbleSettings.VelocitySmoothing * FrameRateMultiplier
		SmoothedVelocity = SmoothedVelocity:lerp(CurrentVelocity, lerpSpeed)

		-- Get horizontal speed for bobble calculations
		local horizontalVelocity = Vector3.new(SmoothedVelocity.X, 0, SmoothedVelocity.Z)
		HorizontalSpeed = horizontalVelocity.Magnitude

		-- Landing detection
		if LandingSettings.Enabled and landingCameraShaker then
			local Character = Player.Character
			local Humanoid = Character and Character:FindFirstChild("Humanoid")
			if Humanoid then
				local isCurrentlyGrounded = Humanoid.FloorMaterial ~= Enum.Material.Air

				-- Detect landing: was falling and now grounded
				if not wasGrounded and isCurrentlyGrounded and lastVelocityY < -LandingSettings.LightLandingThreshold then
					local fallVelocity = math.abs(lastVelocityY)
					print("Landing detected with velocity:", fallVelocity)

					-- Determine shake intensity based on fall velocity
					local shakeIntensity = LandingSettings.LightIntensity
					local shakeDuration = LandingSettings.LightDuration
					local shakeType = "Light"

					if fallVelocity > LandingSettings.HardLandingThreshold then
						shakeIntensity = LandingSettings.HardIntensity
						shakeDuration = LandingSettings.HardDuration
						shakeType = "Hard"
					elseif fallVelocity > LandingSettings.MediumLandingThreshold then
						shakeIntensity = LandingSettings.MediumIntensity
						shakeDuration = LandingSettings.MediumDuration
						shakeType = "Medium"
					end

					print("Applying", shakeType, "landing shake - Intensity:", shakeIntensity, "Duration:", shakeDuration)

					-- Create and apply landing shake
					local CameraShakeInstance = require(ReplicatedStorage.Modules.Shared.CameraShaker.CameraShakeInstance)
					local landingShake = CameraShakeInstance.new(shakeIntensity, 12, 0, shakeDuration)
					landingShake.PositionInfluence = Vector3.new(0.1, 0.15, 0.1)
					landingShake.RotationInfluence = Vector3.new(0.8, 0.4, 0.6)

					landingCameraShaker:Shake(landingShake)
				end

				-- Update tracking variables
				wasGrounded = isCurrentlyGrounded
				lastVelocityY = CurrentVelocity.Y
			end
		end
	end

	PreviousPosition = headPosition
end

-- MOVEMENT STATE DETECTION
local function GetMovementState()
	-- Use global state if available, otherwise calculate from velocity
	if _G.AnimateState then
		return _G.AnimateState
	else
		if HorizontalSpeed < 2 then
			return "Idle"
		elseif HorizontalSpeed < 10 then
			return "Walking"
		elseif HorizontalSpeed < 18 then
			return "Running"
		else
			return "Sprinting"
		end
	end
end

-- FOOTSTEP SHAKE SYSTEM
local function TriggerFootstepShake(side)
	if not FootstepSettings.Enabled or not footstepCameraShaker then
		return
	end

	local currentTime = tick()
	if currentTime - lastFootstepTime < footstepCooldown then
		return -- Prevent footstep spam
	end

	lastFootstepTime = currentTime

	-- Get movement state for intensity
	local movementState = GetMovementState()
	local shakeIntensity = FootstepSettings.WalkIntensity

	if movementState == "Sprinting" then
		shakeIntensity = FootstepSettings.SprintIntensity
	elseif movementState == "Crouching" then
		shakeIntensity = FootstepSettings.CrouchIntensity
	elseif movementState == "Sliding" then
		shakeIntensity = FootstepSettings.SlideIntensity
	end

	print("Footstep shake triggered -", side, "foot, State:", movementState, "Intensity:", shakeIntensity)

	-- Create footstep shake with side variation
	local CameraShakeInstance = require(ReplicatedStorage.Modules.Shared.CameraShaker.CameraShakeInstance)
	local footstepShake = CameraShakeInstance.new(shakeIntensity, FootstepSettings.Roughness, 0, FootstepSettings.Duration)

	-- Add side-to-side variation
	local sideVariation = FootstepSettings.SideVariation
	if side == "Left" then
		footstepShake.PositionInfluence = Vector3.new(-sideVariation, 0.02, 0.01)
	else -- Right foot
		footstepShake.PositionInfluence = Vector3.new(sideVariation, 0.02, 0.01)
	end

	footstepShake.RotationInfluence = Vector3.new(0.1, 0.05, 0.1)

	footstepCameraShaker:Shake(footstepShake)
end

-- EXPOSE FOOTSTEP FUNCTION GLOBALLY
_G.TriggerFootstepShake = TriggerFootstepShake

-- BREATHING EFFECT SYSTEM
local function UpdateBreathingEffects(deltaTime)
	if not BreathingSettings.Enabled then
		_G.BreathingCameraShakeOffset = CFrame.new()
		return
	end

	-- Get movement state for breathing rate
	local movementState = GetMovementState()

	-- Set target breath rate and intensity based on movement
	if movementState == "Sprinting" then
		targetBreathRate = BreathingSettings.SprintBreathRate
		targetBreathIntensity = BreathingSettings.SprintIntensity
	elseif movementState == "Walking" or movementState == "Running" then
		targetBreathRate = BreathingSettings.WalkBreathRate
		targetBreathIntensity = BreathingSettings.WalkIntensity
	else -- Idle, Crouching, etc.
		targetBreathRate = BreathingSettings.IdleBreathRate
		targetBreathIntensity = BreathingSettings.IdleIntensity
	end

	-- Smooth transitions
	local lerpSpeed = 2.0 * deltaTime
	currentBreathRate = currentBreathRate + (targetBreathRate - currentBreathRate) * lerpSpeed
	currentBreathIntensity = currentBreathIntensity + (targetBreathIntensity - currentBreathIntensity) * lerpSpeed

	-- Update breathing time
	breathingTime = breathingTime + deltaTime * (currentBreathRate / 60) -- Convert breaths per minute to breaths per second

	-- Calculate breathing cycle (0 to 1)
	local breathCycle = breathingTime % 1
	local breathPhase = 0

	-- Determine which phase of breathing we're in
	if breathCycle < BreathingSettings.InhaleRatio then
		-- Inhaling phase - smooth rise
		local inhaleProgress = breathCycle / BreathingSettings.InhaleRatio
		breathPhase = math.sin(inhaleProgress * math.pi * 0.5) -- Smooth curve up
	elseif breathCycle < (BreathingSettings.InhaleRatio + BreathingSettings.ExhaleRatio) then
		-- Exhaling phase - smooth fall
		local exhaleProgress = (breathCycle - BreathingSettings.InhaleRatio) / BreathingSettings.ExhaleRatio
		breathPhase = math.cos(exhaleProgress * math.pi * 0.5) -- Smooth curve down
	else
		-- Pause phase
		breathPhase = 0
	end

	-- Apply breathing effect
	local breathingY = breathPhase * currentBreathIntensity * BreathingSettings.VerticalScale
	local breathingRoll = breathPhase * currentBreathIntensity * BreathingSettings.RollScale * 0.1

	-- Create breathing offset
	local breathingOffset = CFrame.new(0, breathingY, 0) * CFrame.Angles(0, 0, breathingRoll)
	_G.BreathingCameraShakeOffset = breathingOffset
end
local function GetMovementState()
	-- Use global state if available, otherwise calculate from velocity
	if _G.AnimateState then
		return _G.AnimateState
	else
		if HorizontalSpeed < 2 then
			return "Idle"
		elseif HorizontalSpeed < 10 then
			return "Walking"
		elseif HorizontalSpeed < 18 then
			return "Running"
		else
			return "Sprinting"
		end
	end
end

-- ENHANCED BOBBLE INTENSITY CALCULATION
local function UpdateBobbleIntensity(deltaTime)
	if not BobbleSettings.Enabled then
		TargetIntensity = 0
		TargetFrequency = BobbleSettings.WalkFrequency

		-- Stop CameraShaker bobble if it's running
		if currentBobbleShake and bobbleCameraShaker then
			currentBobbleShake:StartFadeOut(0.2)
			currentBobbleShake = nil
		end
		return
	end

	-- Get current movement state
	local movementState = GetMovementState()

	-- Calculate base intensity and frequency based on state
	local baseIntensity = 0
	local baseFrequency = BobbleSettings.WalkFrequency

	if HorizontalSpeed < BobbleSettings.MinVelocity then
		-- Not moving enough to bobble
		baseIntensity = 0
		baseFrequency = BobbleSettings.WalkFrequency
	else
		-- Calculate intensity based on velocity with smooth transitions
		local speedFactor = math.min(HorizontalSpeed / BobbleSettings.MaxVelocity, 1)

		-- Use smoothstep for natural acceleration curves
		speedFactor = speedFactor * speedFactor * (3 - 2 * speedFactor)

		if movementState == "Walking" then
			baseIntensity = BobbleSettings.WalkIntensity * speedFactor
			baseFrequency = BobbleSettings.WalkFrequency
		elseif movementState == "Running" then
			baseIntensity = BobbleSettings.RunIntensity * speedFactor
			baseFrequency = BobbleSettings.RunFrequency
		elseif movementState == "Sprinting" then
			baseIntensity = BobbleSettings.SprintIntensity * speedFactor
			baseFrequency = BobbleSettings.SprintFrequency
		else -- Idle or other states
			baseIntensity = 0
			baseFrequency = BobbleSettings.WalkFrequency
		end
	end

	-- Set targets
	TargetIntensity = baseIntensity
	TargetFrequency = baseFrequency

	-- Smooth the transitions with frame rate compensation
	local intensityLerpSpeed = BobbleSettings.IntensitySmoothing * FrameRateMultiplier
	CurrentIntensity = math.lerp(CurrentIntensity, TargetIntensity, intensityLerpSpeed)
	CurrentFrequency = math.lerp(CurrentFrequency, TargetFrequency, intensityLerpSpeed)

	-- Handle CameraShaker bobble
	if BobbleSettings.UseCameraShaker and bobbleCameraShaker then
		if CurrentIntensity > 0.01 then
			-- Start or update bobble shake
			if not currentBobbleShake then
				-- Create CameraShakeInstance directly
				local CameraShakeInstance = require(ReplicatedStorage.Modules.Shared.CameraShaker.CameraShakeInstance)
				local bobbleShakeInstance = CameraShakeInstance.new(
					CurrentIntensity * 2, -- Multiply for more noticeable effect
					CurrentFrequency * 0.5, -- Lower roughness for smoother bobble
					0.1, -- Fade in time
					999 -- Sustained
				)
				bobbleShakeInstance.PositionInfluence = Vector3.new(
					BobbleSettings.HorizontalScale * 0.5,
					BobbleSettings.VerticalScale * 0.3,
					BobbleSettings.HorizontalScale * 0.3
				)
				bobbleShakeInstance.RotationInfluence = Vector3.new(
					BobbleSettings.RollScale * 5,
					BobbleSettings.RollScale * 3,
					BobbleSettings.RollScale * 8
				)

				currentBobbleShake = bobbleCameraShaker:ShakeSustain(bobbleShakeInstance)
				print("Started bobble shake - Intensity:", CurrentIntensity, "Speed:", HorizontalSpeed) -- Debug
			end
		else
			-- Stop bobble shake
			if currentBobbleShake then
				currentBobbleShake:StartFadeOut(0.2)
				currentBobbleShake = nil
				print("Stopped bobble shake") -- Debug
			end
		end
	end
end

-- TRADITIONAL BOBBLE OFFSET CALCULATION (Backup method)
local function CalculateBobbleOffset(deltaTime)
	if CurrentIntensity <= 0.001 or BobbleSettings.UseCameraShaker then
		return CFrame.new(0, 0, 0)
	end

	-- Update bobble time with frame rate compensation
	local timeIncrement = deltaTime * CurrentFrequency * FrameRateMultiplier
	BobbleTime = BobbleTime + timeIncrement

	-- Create complex wave patterns for natural movement
	local primarySine = math.sin(BobbleTime)
	local secondarySine = math.sin(BobbleTime * 1.3 + math.pi/4) * BobbleSettings.SineVariation
	local bounce = math.sin(BobbleTime * 2) * BobbleSettings.BounceMultiplier

	-- Combine waves for vertical movement (Y-axis)
	local verticalComponent = (primarySine + secondarySine + bounce * 0.3) * CurrentIntensity * BobbleSettings.VerticalScale

	-- Minimal horizontal movement (X-axis) - alternating side to side
	local horizontalComponent = math.sin(BobbleTime * 0.5) * CurrentIntensity * BobbleSettings.HorizontalScale

	-- Very subtle roll effect
	local rollComponent = math.sin(BobbleTime * 0.7 + math.pi/6) * CurrentIntensity * BobbleSettings.RollScale

	-- Create the bobble offset
	local positionOffset = Vector3.new(horizontalComponent, verticalComponent, 0)

	-- Create rotation offset (minimal roll)
	local rotationOffset = CFrame.Angles(0, 0, rollComponent)

	-- Combine position and rotation
	return CFrame.new(positionOffset) * rotationOffset
end

-- CAMERA INPUT HANDLING
local function UpdateCameraInput()
	if IsMobile then
		return
	elseif IsGamepad then
		local delta = GamepadDelta
		if math.abs(delta.X) > Deadzone or math.abs(delta.Y) > Deadzone then
			TargetYaw -= delta.X * GamepadSensitivity
			TargetPitch -= -delta.Y * GamepadSensitivity
			TargetPitch = math.clamp(TargetPitch, MinPitch - 0.2, MaxPitch + 0.2)
		end
	else
		local Delta = UserInputService:GetMouseDelta()
		TargetYaw -= Delta.X * Sensitivity * 0.01
		TargetPitch -= Delta.Y * Sensitivity * 0.01
		TargetPitch = math.clamp(TargetPitch, MinPitch - 0.2, MaxPitch + 0.2)
	end
end

local function UpdateRotationShift()
	local yawVelocity = TargetYaw - PreviousYaw
	local pitchVelocity = TargetPitch - PreviousPitch

	TargetShiftZ = -yawVelocity * ShiftIntensity
	TargetShiftZ = math.clamp(TargetShiftZ, -MaxShift, MaxShift)

	TargetShiftX = pitchVelocity * ShiftIntensity * 0.5
	TargetShiftX = math.clamp(TargetShiftX, -MaxShift * 0.5, MaxShift * 0.5)

	CurrentShiftZ = CurrentShiftZ + (TargetShiftZ - CurrentShiftZ) * ShiftSmooth
	CurrentShiftX = CurrentShiftX + (TargetShiftX - CurrentShiftX) * ShiftSmooth

	if math.abs(yawVelocity) < 0.001 then
		TargetShiftZ = TargetShiftZ * 0.95
	end
	if math.abs(pitchVelocity) < 0.001 then
		TargetShiftX = TargetShiftX * 0.95
	end

	PreviousYaw = TargetYaw
	PreviousPitch = TargetPitch
end

local function ClampAndSmoothAngles()
	if TargetPitch > MaxPitch then
		TargetPitch = TargetPitch + (MaxPitch - TargetPitch) * 0.1
	elseif TargetPitch < MinPitch then
		TargetPitch = TargetPitch + (MinPitch - TargetPitch) * 0.1
	end
	CurrentYaw = CurrentYaw + (TargetYaw - CurrentYaw) * SmoothSpeed
	CurrentPitch = CurrentPitch + (TargetPitch - CurrentPitch) * SmoothSpeed
end

-- Mobile touch input
if IsMobile then
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch and not gameProcessed then
			if LastTouchPosition then
				local delta = input.Position - LastTouchPosition
				TargetYaw -= delta.X * TouchSensitivity * 0.002
				TargetPitch -= delta.Y * TouchSensitivity * 0.002
				TargetPitch = math.clamp(TargetPitch, MinPitch - 0.2, MaxPitch + 0.2)
			end
			LastTouchPosition = input.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			LastTouchPosition = nil
		end
	end)
end

-- Gamepad input
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
		GamepadDelta = input.Position
	end
end)

-- Input type switching
UserInputService.LastInputTypeChanged:Connect(function(inputType)
	if inputType == Enum.UserInputType.Gamepad1 then
		IsGamepad = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	elseif inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Keyboard then
		IsGamepad = false
		if not IsMobile then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end
end)

-- Character spawn handling
local function onCharacterAdded(character)
	-- Reset bobble state on character spawn
	BobbleTime = 0
	CurrentIntensity = 0
	TargetIntensity = 0
	PreviousPosition = nil
	CurrentVelocity = Vector3.new(0, 0, 0)
	SmoothedVelocity = Vector3.new(0, 0, 0)
	HorizontalSpeed = 0

	-- Stop any existing bobble shake
	if currentBobbleShake and bobbleCameraShaker then
		currentBobbleShake:StartFadeOut(0.1)
		currentBobbleShake = nil
	end

	print("Enhanced camera: Character spawned")
end

if Player.Character then
	onCharacterAdded(Player.Character)
end
Player.CharacterAdded:Connect(onCharacterAdded)

-- Initialize bobble camera shaker
InitializeBobbleCameraShaker()

-- DEBUG: Manual bobble test (T key)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.T then
		print("=== CAMERA DEBUG INFO ===")
		print("Bobble - Intensity:", CurrentIntensity, "Frequency:", CurrentFrequency, "Speed:", HorizontalSpeed, "State:", GetMovementState())
		print("Bobble - UseCameraShaker:", BobbleSettings.UseCameraShaker, "BobbleShaker exists:", bobbleCameraShaker ~= nil)
		print("Bobble - Current shake active:", currentBobbleShake ~= nil)
		print("Bobble - Enabled:", BobbleSettings.Enabled)
		print("Landing - Enabled:", LandingSettings.Enabled, "Shaker exists:", landingCameraShaker ~= nil)
		print("Footstep - Enabled:", FootstepSettings.Enabled, "Shaker exists:", footstepCameraShaker ~= nil)
		print("Breathing - Enabled:", BreathingSettings.Enabled, "Rate:", currentBreathRate, "Intensity:", currentBreathIntensity)
		print("Global AnimateState:", _G.AnimateState)
		print("Character exists:", Player.Character ~= nil)
		if Player.Character then
			local humanoid = Player.Character:FindFirstChild("Humanoid")
			if humanoid then
				print("Humanoid MoveDirection:", humanoid.MoveDirection, "Magnitude:", humanoid.MoveDirection.Magnitude)
			end
		end
		print("========================")
	elseif input.KeyCode == Enum.KeyCode.Y then
		-- Test footstep shake
		print("Testing footstep shake...")
		TriggerFootstepShake("Left")
	elseif input.KeyCode == Enum.KeyCode.U then
		-- Test landing shake
		print("Testing landing shake...")
		if landingCameraShaker then
			local CameraShakeInstance = require(ReplicatedStorage.Modules.Shared.CameraShaker.CameraShakeInstance)
			local testLanding = CameraShakeInstance.new(2.0, 12, 0, 0.6)
			testLanding.PositionInfluence = Vector3.new(0.1, 0.15, 0.1)
			testLanding.RotationInfluence = Vector3.new(0.8, 0.4, 0.6)
			landingCameraShaker:Shake(testLanding)
		end
	elseif input.KeyCode == Enum.KeyCode.I then
		-- Test bobble shake manually
		print("Testing bobble shake manually...")
		if bobbleCameraShaker then
			-- Force start a bobble shake
			CurrentIntensity = 0.3
			HorizontalSpeed = 15
			print("Forcing bobble - Intensity:", CurrentIntensity, "Speed:", HorizontalSpeed)
		end
	end
end)

-- MAIN CAMERA UPDATE LOOP
local lastFrameTime = tick()
RunService.RenderStepped:Connect(function()
	local currentTime = tick()
	local rawDeltaTime = currentTime - lastFrameTime
	local deltaTime = math.clamp(rawDeltaTime, BobbleSettings.MinDeltaTime, BobbleSettings.MaxDeltaTime)
	lastFrameTime = currentTime

	-- Update frame rate compensation
	UpdateFrameRateCompensation(deltaTime)

	-- Update camera input and movement
	UpdateCameraInput()
	UpdateRotationShift()
	ClampAndSmoothAngles()

	-- Update breathing effects
	UpdateBreathingEffects(deltaTime)

	local Character = Player.Character
	local Head = Character and Character:FindFirstChild("Head")
	if Head then
		local Position = Head.Position

		-- Update velocity tracking and bobble intensity
		UpdateVelocityTracking(Position, deltaTime)
		UpdateBobbleIntensity(deltaTime)

		-- Calculate bobble offset (only used if not using CameraShaker)
		local bobbleOffset = CalculateBobbleOffset(deltaTime)

		-- Create camera transforms
		local BaseRotation = CFrame.Angles(0, CurrentYaw, 0) * CFrame.Angles(CurrentPitch, 0, 0)
		local ShiftRotation = CFrame.Angles(CurrentShiftX, 0, CurrentShiftZ)

		-- Get all camera shake offsets
		local shakeOffset = _G.CameraShakeOffset or CFrame.new()
		local lightningShake = _G.LightningCameraShakeOffset or CFrame.new()
		local bobbleShake = _G.BobbleCameraShakeOffset or CFrame.new()
		local landingShake = _G.LandingCameraShakeOffset or CFrame.new()
		local footstepShake = _G.FootstepCameraShakeOffset or CFrame.new()
		local breathingShake = _G.BreathingCameraShakeOffset or CFrame.new()

		-- Apply all transforms
		Camera.CFrame = CFrame.new(Position) 
			* BaseRotation 
			* ShiftRotation 
			* CFrame.new(0, 0.75, 0) 
			* bobbleOffset    -- Traditional bobble (if not using CameraShaker)
			* shakeOffset     -- General camera shake
			* lightningShake  -- Lightning-specific shake
			* bobbleShake     -- CameraShaker bobble
			* landingShake    -- Landing shake
			* footstepShake   -- Footstep shake
			* breathingShake  -- Breathing effects
	end
end)
