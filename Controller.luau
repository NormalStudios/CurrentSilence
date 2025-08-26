-- When getting chased by the monster, all audio is cut off except for his footsteps

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local Debug = require(script.Parent.Debug)
local Animate = require(script.Parent.Animate)
local Drooper = require(script.Parent.Drooper)

local Controller = {}




Controller.__index = Controller

function Controller:DetectSpecificPlayer(Player)
	local DetectedPlayer = self:DetectPlayers()
	if DetectedPlayer and DetectedPlayer == Player then
		return true
	else
		return false
	end
end

function Controller:DetectPlayers(directions)
	local OriginPosition = self.HumanoidRootPart.Position
	local Radius = 30
	local Distance = 150

	-- Default directions if none provided (forward, left 30°, right 30°)
	directions = directions or {0, 30, -30}

	local DetectedPlayers = {}
	local Colors = {
		Color3.new(1, 0, 1), -- Magenta
		Color3.new(0, 1, 1), -- Cyan
		Color3.new(1, 0.5, 0), -- Orange
		Color3.new(0.5, 1, 0.5), -- Light Green
		Color3.new(1, 0.5, 1), -- Pink
		Color3.new(0.5, 0.5, 1), -- Light Blue
		Color3.new(1, 1, 0.5), -- Light Yellow
		Color3.new(1, 0.2, 0.2), -- Light Red
	}

	-- Cast rays for each direction
	for i, angleDegrees in ipairs(directions) do
		-- Calculate direction vector based on angle
		local Direction = self.HumanoidRootPart.CFrame:VectorToWorldSpace(
			CFrame.Angles(0, math.rad(angleDegrees), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
		)

		local RaycastResult = workspace:Spherecast(OriginPosition, Radius, Direction * Distance)
		local Color = Color3.new(1, 0, 0) -- Default red for no detection

		if RaycastResult and RaycastResult.Instance and RaycastResult.Instance.Parent then
			local Player = Players:GetPlayerFromCharacter(RaycastResult.Instance.Parent)
			if Player then
				-- Use color from array, cycling if more directions than colors
				Color = Colors[((i - 1) % #Colors) + 1]
				table.insert(DetectedPlayers, {
					Player = Player,
					Distance = RaycastResult.Distance,
					Position = RaycastResult.Position
				})
			end
		end

		-- Draw debug sphere for each ray
		self.Debug:DrawDebugSphere(OriginPosition + Direction * (Distance / 2), Radius, Color)
	end

	-- Return the closest player if any were detected
	if #DetectedPlayers > 0 then
		-- Sort by distance and return the closest
		table.sort(DetectedPlayers, function(a, b)
			return a.Distance < b.Distance
		end)

		return DetectedPlayers[1].Player
	end

	-- If no visual detection, try hearing detection
	local HearingRange = 25 -- Distance within which monster can hear players
	local MovementThreshold = 2 -- Minimum speed to be considered "moving"
	local HeardPlayers = {}

	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local PlayerPosition = player.Character.HumanoidRootPart.Position
			local DistanceToPlayer = (OriginPosition - PlayerPosition).Magnitude

			-- Check if player is within hearing range
			if DistanceToPlayer <= HearingRange then
				-- Check if player is moving (has velocity)
				local PlayerVelocity = player.Character.HumanoidRootPart.AssemblyLinearVelocity
				local PlayerSpeed = PlayerVelocity.Magnitude

				if PlayerSpeed >= MovementThreshold then
					table.insert(HeardPlayers, {
						Player = player,
						Distance = DistanceToPlayer,
						Speed = PlayerSpeed
					})
				end
			end
		end
	end

	-- Return the closest heard player if any
	if #HeardPlayers > 0 then
		table.sort(HeardPlayers, function(a, b)
			return a.Distance < b.Distance
		end)

		-- Draw debug indicator for heard player
		local HeardPlayer = HeardPlayers[1]
		self.Debug:DrawDebugSphere(
			HeardPlayer.Player.Character.HumanoidRootPart.Position, 
			3, 
			Color3.new(1, 0.8, 0) -- Golden color for hearing detection
		)

		return HeardPlayer.Player
	end

	return nil
end
function Controller:MoveHead()
	task.spawn(function()
		while true do
			if self.Patrolling and not self.TargetingPlayer and not self.LoadedAnimations.MoveHead.IsPlaying then
				self.LoadedAnimations.MoveHead:Play()
			end
			task.wait(math.random(20, 80) / 10)
		end
	end)
end

function Controller:GetNewDestination()
	local CurrentPosition = self.HumanoidRootPart.Position
	local MinDistance = 30

	local ValidDestinations = {}

	for _, Waypoint in ipairs(self.WaypointLibrary) do
		if Waypoint:IsA("BasePart") then
			local Distance = (Waypoint.Position - CurrentPosition).Magnitude
			if Distance >= MinDistance then
				table.insert(ValidDestinations, Waypoint)
			end
		end
	end

	if #ValidDestinations > 0 then
		local ChosenWaypoint = ValidDestinations[math.random(1, #ValidDestinations)]
		return ChosenWaypoint.Position
	else
		local AllWaypoints = self.WaypointLibrary
		if #AllWaypoints > 0 then
			local ChosenWaypoint = AllWaypoints[math.random(1, #AllWaypoints)]
			return ChosenWaypoint.Position
		end
	end
end

function Controller:CalculatePath(Location)
	local Path : Path = PathfindingService:CreatePath({
		AgentRadius = self.Model:GetExtentsSize().X / 2,
		AgentHeight = self.Model:GetExtentsSize().Y,
		AgentCanJump = false,
		AgentCanClimb = true,
		WaypointSpacing = 3,
	})
	Path:ComputeAsync(self.HumanoidRootPart.Position, Location)

	if Path.Status ~= Enum.PathStatus.Success then
		return self:CalculatePath(Location)
	else
		return Path
	end
end





function Controller:MoveTo(Location)  

	self.Debug:UpdateDebugUI("Patrolling")

	local Path : Path = self:CalculatePath(Location)
	local Waypoints = Path:GetWaypoints()

	self.Debug:VisualizePath(Waypoints) 
	self.Debug:UpdateTargetInfo("None")

	self.Patrolling = true
	
	local WaypointLoop
	local BreakLoop
	local Player
	local CurrentWaypoint = 1
	
	local function ValidateLoopContinuing()

		if not self.Patrolling then return false end
		if BreakLoop then return false end
		if self.TargetingPlayer then return false end
		
		return true

	end
	
	
	
	self.RaycastLoop = coroutine.create(function()
		while true do
			print("loop")
			local PlayerDetected = self:DetectPlayers()

			if Player then
				Player = PlayerDetected

				BreakLoop = true
				break

			end
			task.wait(math.random(125, 250) / 1000)
		end
		
	end)
	
	

	coroutine.resume(self.RaycastLoop)
	for i = 1, #Waypoints do
		if not ValidateLoopContinuing() then break end
		CurrentWaypoint = i


		self.Debug:UpdatePathIndex(i) -- Place inside the loop before MoveTo
		
		
		

		local Waypoint = Waypoints[i]
		
		self.Humanoid:MoveTo(Waypoint.Position)
		self.Humanoid.MoveToFinished:Wait()
		
		if Waypoints[i].Action == Enum.PathWaypointAction.Jump then
			self.Humanoid.Jump = true
			self.Humanoid.Jumped:Wait()
		
		
		end
	end 
	
	if BreakLoop and Player then
		
		coroutine.close(self.RaycastLoop)
		self.Patrolling = false
		self:MoveToPlayer(Player)
		self.LookAtLoop = RunService.PostSimulation:Connect(function()
			self:FollowPosition(Player.Character and Player.Character.PrimaryPart.Position)
		end)
	end
end

function Controller:KillPlayer(Player)
	-- Blood splatter just like FNAF bonnie from that one game
	-- Fire all clients a remote event
	if Player == nil or Player.Character == nil then return warn("Bad things are happening") end

	ReplicatedStorage.RemoteEvents.DisableMovement:FireClient(Player)
	ReplicatedStorage.RemoteEvents.ParasiteKillEvent:FireAllClients(Player.Character, self.Model)
	local Connection
	Connection = ReplicatedStorage.RemoteEvents.ParasiteKillEvent.OnServerEvent:Connect(function(NewPlayer)
		if NewPlayer == Player and NewPlayer.Character then
			NewPlayer.Character.Humanoid:TakeDamage(300)
			ReplicatedStorage.RemoteEvents.Death:FireClient(Player)

			Connection:Disconnect()
			Connection = nil
		end
	end)

	task.wait(8)




end

function Controller:FollowPosition(Position)
	local Head = self.Model.HumanoidRootPart["mixamorig:Hips"]["mixamorig:Spine"]["mixamorig:Spine1"]["mixamorig:Spine2"]["mixamorig:Neck"]["mixamorig:Head"] 
	local Target = Position
	
	if Head and Target then     
		local HeadWorldCFrame = Head.WorldCFrame     
		local LookAt = CFrame.lookAt(HeadWorldCFrame.Position, Target)     
		local RotationOnly = CFrame.new(HeadWorldCFrame.Position) * LookAt.Rotation     
		local LocalTransform = HeadWorldCFrame:ToObjectSpace(RotationOnly)     
		Head.Transform = LocalTransform 
	end


end

function Controller:DisconnectFunction(Function)
	if Function and Function.Connected then
		Function:Disconnect()
		Function = nil
	end
end


function Controller:MoveToPlayer(Player)
	if not Player or not Player.Character or not (Player.Character.Humanoid.Health > 0) then return end

	self.Debug:UpdateDebugUI("Chasing")
	self.TargetingPlayer = Player

	local function ValidateLoopContinuing()
		-- Only check if player is alive and we're still targeting them
		-- Don't require detection - keep chasing even if we lose sight temporarily
		if Player.Character and Player.Character.Humanoid.Health > 0 and self.TargetingPlayer then
			return true
		else
			print("STOPPING CHASE - Player dead or target cleared")
			self.TargetingPlayer = nil
			return false
		end
	end

	-- Chase loop with dynamic pathfinding
	while ValidateLoopContinuing() do

		-- Recalculate path periodically or if we don't have waypoints
		
		if Player.Character and Player.Character.PrimaryPart then
			local Path = self:CalculatePath(Player.Character.PrimaryPart.Position)
			local Waypoints = Path:GetWaypoints()

			self.Debug:VisualizePath(Waypoints)
			self.Debug:UpdateTargetInfo(Player.Name)

			-- Move towards player using updated path
			if #Waypoints > 1 then
				-- Use waypoint 2-4 depending on path length to stay aggressive but not overshoot
				local targetWaypoint = Waypoints[math.min(3, #Waypoints)]
				self.Humanoid:MoveTo(targetWaypoint.Position)
				self.Debug:UpdatePathIndex(math.min(3, #Waypoints))
			end

		end
		

		-- Check if close enough to kill
		if Player.Character and Player.Character.HumanoidRootPart then
			local Distance = (Player.Character.HumanoidRootPart.Position - self.HumanoidRootPart.Position).Magnitude
			if Distance <= 5 then
				self:KillPlayer(Player)
				break
			end
		end

		task.wait(.1)
	end
end

function Controller:DetectionLoop()
	
	
	self.DetectionLoop = coroutine.create(function()
		while true do
			
			if self.RaycastLoop then
				coroutine.close(self.RaycastLoop)
			end
			
			if self.LookAtLoop then
				self:DisconnectFunction(self.LookAtLoop)
			end
			
			local Player = self:DetectPlayers()
			
			if Player then
				self.Patrolling = false
				self:MoveToPlayer(Player)
				self.LookAtLoop = RunService.PostSimulation:Connect(function()
					self:FollowPosition(Player.Character and Player.Character.PrimaryPart.Position)
				end)
			else
				task.wait(math.random(20, 60) / 10)
				self:MoveTo(self:GetNewDestination())
			end

		end
	end)

	coroutine.resume(self.DetectionLoop)
end

function Controller.new(Model, WaypointLibrary)   
	local self = setmetatable({
		Model = Model,
		Humanoid = Model.Humanoid,
		HumanoidRootPart = Model.PrimaryPart,
		Patrolling = false,
		TargetingPlayer = false,
		DetectionLoop = nil,
		RaycastLoop = nil,
		LookAtLoop = nil,
		WaypointLibrary = WaypointLibrary:GetChildren(),
		Debug = Debug.new(),
		Animate = Animate.new(Model),
		Drooper = Drooper.new(Model),
		
	}, Controller)
	self.Debug:CreateDebugUI(self.HumanoidRootPart)
	self.Drooper:Start()  
	
	local AnimationFolder = Model.Animations
	local Animator : Animator = Model:FindFirstChild("Animator", true)
	
	self.LoadedAnimations = {
		MoveHead = Animator:LoadAnimation(AnimationFolder.MoveHead)
	}
	
	


	

	self:DetectionLoop()
	self:MoveHead()

	return self
end

return Controller
