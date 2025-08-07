local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Clocks = {}
Clocks.__index = Clocks

function Clocks:GetFormattedTime()
	local LocalTime = os.date("*t")
	local Hour = LocalTime.hour
	local Minute = LocalTime.min

	local Period = Hour >= 12 and "PM" or "AM"
	local DisplayHour = Hour % 12
	DisplayHour = DisplayHour == 0 and 12 or DisplayHour

	local FormattedMinute = Minute < 10 and "0" .. Minute or tostring(Minute)

	return DisplayHour .. ":" .. FormattedMinute .. " " .. Period
end

function Clocks:Update()
	while self.Instance and self.TextLabel and self.Running do
		self.TextLabel.Text = self:GetFormattedTime()
		task.wait(1)
	end
end

function Clocks.new(ClockModel)
	local self = setmetatable({
		Instance = ClockModel,
		Screen = ClockModel:FindFirstChild("Screen"),
		TextLabel = nil,
		Running = true
	}, Clocks)

	if self.Screen then
		local SurfaceGui = self.Screen:FindFirstChildOfClass("SurfaceGui")
		if SurfaceGui then
			self.TextLabel = SurfaceGui:FindFirstChildOfClass("TextLabel")
		end
	end

	if self.TextLabel then
		task.spawn(function()
			self:Update()
		end)
	end

	return self
end

function Clocks.Init()
	for _, ClockModel in ipairs(CollectionService:GetTagged("Clock")) do
		Clocks.new(ClockModel)
	end
end

return Clocks
