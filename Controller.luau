-- When getting chased by the monster, all audio is cut off except for his footsteps

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Debug = require(script.Parent.Debug)

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

function Controller:DetectPlayers()
	local OriginPosition = self.HumanoidRootPart.Position
	local Radius = 10
	local Direction = self.HumanoidRootPart.CFrame.LookVector -- shoot forward
	local Distance = 50

	local RaycastResult = workspace:Spherecast(OriginPosition, Radius, Direction * Distance)

    local Player = Players:GetPlayerFromCharacter(RaycastResult.Instance.Parent)

    local DetectedColor = Player and Color3.new(0, 0, 1) or Color3.new(1, 0, 0)
	self.Debug:DrawDebugSphere(OriginPosition + Direction * (Distance / 2), Radius, DetectedColor)

    if Player then
        return Player
    end

	
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
        AgentCanClimb = false,
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

    local function ValidateLoopContinuing()
        
        if not self.Patrolling then return false end
        return true
        
    end
    
    for i = 1, #Waypoints do
        if not ValidateLoopContinuing() then break end

        self.Debug:UpdatePathIndex(i) -- Place inside the loop before MoveTo


		local Waypoint = Waypoints[i]

        self.Humanoid:MoveTo(Waypoint.Position)
        self.Humanoid.MoveToFinished:Wait()
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

function Controller:MoveToPlayer(Player)
    if not Player or not Player.Character or not (Player.Character.Humanoid.Health > 0) then return end

    self.Debug:UpdateDebugUI("Chasing")


    local Path : Path = self:CalculatePath(Player.Character.PrimaryPart.Position)
    local Waypoints = Path:GetWaypoints()

    self.Debug:VisualizePath(Waypoints)
    self.Debug:UpdateTargetInfo(Player.Name) -- Place right after VisualizePath

    self.TargetingPlayer = Player

    

    local function ValidateLoopContinuing()
        if Player.Character and Player.Character.Humanoid.Health > 0 and self.TargetingPlayer and self:DetectSpecificPlayer(Player) then
            return true
        else

            return false
        end
    end

    -- Move to fourth waypoint, this will be a short distance from the AI
    while ValidateLoopContinuing() do
        self.Debug:UpdatePathIndex(4)

        local Waypoint = Waypoints[4] or Waypoints[1]

        self.Humanoid:MoveTo(Waypoint.Position)
        self.Humanoid.MoveToFinished:Wait()

        local Distance = (Player.Character.HumanoidRootPart.Position - self.HumanoidRootPart.Position).Magnitude

        if Distance <= 5 then
            self:KillPlayer(Player)
            break
        end
    end
    
end

function Controller:DetectionLoop()
    self.DetectionLoop = coroutine.create(function()
        while true do
            local Player = self:DetectPlayers()

            if Player then
                self.Patrolling = false
                self:MoveToPlayer(Player)
            else
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
        WaypointLibrary = WaypointLibrary:GetChildren(),
        Debug = Debug.new() 

    }, Controller)
    self.Debug:CreateDebugUI()

    self:DetectionLoop()

    return self
end

return Controller
