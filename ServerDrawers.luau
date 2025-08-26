local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = ReplicatedStorage.RemoteEvents
local DrawerEvent = RemoteEvents.DrawerEvent

local ItemStats = {
	{ Name = "Flashlight", Weight = 5, Description = "Basic light source. Limited durability." },
	{ Name = "ScrapsToy", Weight = 4, Description = "Distraction tool. Sings and attracts enemies. One-time use." },
	{ Name = "Lantern", Weight = 6, Description = "Powerful light source. Limited durability." },
	{ Name = "Stim", Weight = 2, Description = "Temporarily boosts movement speed. One-time use." },
	{ Name = "Pills", Weight = 3, Description = "Restores 30 health. One-time use." },
	{ Name = "ThreatSensor", Weight = 2, Description = "Detects enemy presence. Limited durability." }
}

local BigDrawers = {}
BigDrawers.__index = BigDrawers

function BigDrawers:CalculateLootingForDrawer()
	local Chance = math.random(1, 100)
	if Chance <= 10 then
		local Item = ItemStats[math.random(1, #ItemStats)]
		print("Item Found: " .. Item.Name)
		return Item
	elseif Chance <= 85 then
		print("Drawer Contains Junk.")
		return { Name = "Junk", Description = "Useless debris. Nothing of value." }
	else
		print("Drawer Is Empty.")
		return nil
	end
end

function BigDrawers.new(BigDrawer)
	local Self = setmetatable({ BigDrawer = BigDrawer }, BigDrawers)

	for _, DrawerModel in pairs(BigDrawer:GetChildren()) do
		if DrawerModel:IsA("Model") then
			local ProximityPrompt = DrawerModel:FindFirstChild("ProximityPrompt", true)
			local ClosedCFrame = DrawerModel.PrimaryPart.CFrame

			ProximityPrompt.Triggered:Connect(function(Player)
				local State = DrawerModel:GetAttribute("State")
				if State == "Closed" then
					State = "Opened"
					DrawerModel:SetAttribute("State", State)
					ProximityPrompt.ObjectText = "Close"
					local Loot = Self:CalculateLootingForDrawer()
				else
					State = "Closed"
					DrawerModel:SetAttribute("State", State)
					ProximityPrompt.ObjectText = "Open"
				end

				DrawerEvent:FireAllClients(DrawerModel, State, ClosedCFrame)
			end)
		end
	end

	return Self
end

function BigDrawers.Init()
	for _, BigDrawer in pairs(CollectionService:GetTagged("BigDrawers")) do
		BigDrawers.new(BigDrawer)
	end
end

return BigDrawers
