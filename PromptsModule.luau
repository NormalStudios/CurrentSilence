local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")


local SoundModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("SoundModule"))

local EndPromptSize = UDim2.new(.5,0,.5,0)
local EndPromptPosition = UDim2.new(.25,0,.25,0)

local PromptInfo = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

local PromptsModule = {}



function PromptsModule.SetupPrompt(Prompt : ProximityPrompt)
	local PromptGUI = Prompt.Parent:FindFirstChild("PromptGUI")
	local Main = PromptGUI:WaitForChild("Background")


	local KeyCodeLabel = Main:WaitForChild("KeyCode")
	local MobileTouch = Main:WaitForChild("MobileTouch")
	local XboxButton = Main:WaitForChild("XboxButton")
	local Desc = Main:WaitForChild("Desc")
	local Misc = ReplicatedStorage:WaitForChild("Misc")
	local Buttons = Misc:WaitForChild("Buttons")
	local XboxButtons = Buttons:WaitForChild("XboxButtons")
	local Bar = Main:WaitForChild("Bar")
	local InsideBar = Bar:WaitForChild("InsideBar")
	local Hold = Main:WaitForChild("Hold")

	local GamepadCode = tostring(Prompt.GamepadKeyCode)
	local KeyCodeCode = tostring(Prompt.KeyboardKeyCode)

	Desc.Text = Prompt.ObjectText
	KeyCodeLabel.Text = string.gsub(KeyCodeCode, "Enum.KeyCode.", "")

	XboxButton.Image = XboxButtons:FindFirstChild(string.gsub(GamepadCode, "Enum.KeyCode.", "")).Image

	
	local Highlight = Prompt.Parent.Parent.Parent:FindFirstChildOfClass("Highlight") or Prompt.Parent.Parent:FindFirstChildOfClass("Highlight")
	if Highlight == nil then
		Highlight = Instance.new("Highlight")
		Highlight.Name = "Highlight"
		Highlight.FillTransparency = 1
		Highlight.OutlineTransparency = 1
		Highlight.Parent = Prompt:FindFirstChild("HighlightParent") and Prompt:FindFirstChild("HighlightParent").Value or Prompt.Parent.Parent.Parent
	else
		--print("highlight already exists")
	end
	 
	Prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		Desc.Text = Prompt.ObjectText
	end)
	

	if Prompt.HoldDuration > 0 then
		Hold.Visible = true
		Bar.Visible = true
	else
		Hold.Visible = false
		Bar.Visible = false
	end

	PromptsModule.HidePrompt(Prompt)
end

function PromptsModule.AddPrompt(Part, Preset)
	local PromptAttachment = Part.Parent:FindFirstChild("PromptAttachment", true)
	if PromptAttachment == nil then
		PromptAttachment = Instance.new("Attachment")
		PromptAttachment.Parent = Part
		PromptAttachment.Name = "PromptAttachment"
	end
	 
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Parent = PromptAttachment
	for Key, Value in pairs(Preset) do
		print(Key, Value, "Changed Property")
		Prompt[Key] = Value
	end
	local PromptGUI = ReplicatedStorage:WaitForChild("Misc"):WaitForChild("PromptGUI"):Clone()
	PromptGUI.Parent = PromptAttachment
	PromptsModule.SetupPrompt(Prompt)
	return Prompt
end

function PromptsModule.EnablePrompt(Prompt)
	Prompt.Enabled = true
end

function PromptsModule.DisablePrompt(Prompt)
	Prompt.Enabled = false
	PromptsModule.HidePrompt(Prompt)
end

function PromptsModule.PromptShown(Prompt)
	SoundModule.PlaySound(ReplicatedStorage.Sounds.InterfaceSounds:WaitForChild("PromptHover"), nil)
	if Prompt.Parent.Name == "PromptAttachment" and Prompt.Style == Enum.ProximityPromptStyle.Custom then
		local PromptInterface = Prompt.Parent:FindFirstChild("PromptGUI")
		local Highlight = Prompt.Parent.Parent.Parent:FindFirstChild("Highlight", true)

		if PromptInterface then
			local Background = PromptInterface:FindFirstChild("Background")

			local PromptInterfaceTween = TweenService:Create(Background, PromptInfo, {Size = EndPromptSize, Position = EndPromptPosition})
			--			local OutsideStrokeTween = TweenService:Create(Background:FindFirstChildOfClass("UIStroke"), PromptInfo, {Transparency = .9})
			local HighlightTween = TweenService:Create(Highlight, PromptInfo, {OutlineTransparency = .25, FillTransparency = 0.98})

			HighlightTween:Play()
			--OutsideStrokeTween:Play()
			PromptInterfaceTween:Play()
		end
	end
end

function PromptsModule.ShowPromptBasic(Prompt)
	SoundModule.PlaySound(ReplicatedStorage.Sounds.InterfaceSounds:WaitForChild("PromptHover"), nil)

	local PromptInterface = Prompt.Parent:FindFirstChild("PromptGUI")


	if PromptInterface then
		local Background = PromptInterface:FindFirstChild("Background")
		
		Background.Size = UDim2.new(.35,0,.35,0)
		Background.Position = UDim2.new(.35,0,.35,0)
		PromptInterface.Enabled = true

		local Highlight = Prompt.Parent.Parent.Parent:FindFirstChild("Highlight", true)
		local HighlightTween = TweenService:Create(Highlight, PromptInfo, {OutlineTransparency = .25, FillTransparency = 0.98})
		HighlightTween:Play()

	end
end

function PromptsModule.HidePromptBasic(Prompt)
	SoundModule.PlaySound(ReplicatedStorage.Sounds.InterfaceSounds:WaitForChild("PromptHover"), nil)
	if Prompt == nil or Prompt.Parent == nil then return warn("Prompt doesn't have a parent") end
	local PromptInterface = Prompt.Parent:FindFirstChild("PromptGUI")


	if PromptInterface then
		local Background = PromptInterface:FindFirstChild("Background")

		Background.Size = UDim2.new(0,0,0,0)
		Background.Position = UDim2.new(0.5,0,0.5,0)
		
		PromptInterface.Enabled = false
		local Highlight = Prompt.Parent.Parent.Parent:FindFirstChild("Highlight", true)
		local HighlightTween = TweenService:Create(Highlight, PromptInfo, {OutlineTransparency = 1, FillTransparency = 1})
		HighlightTween:Play()

	end
end

function PromptsModule.HidePrompt(Prompt)
	if Prompt.Parent == nil or Prompt == nil then return warn("Prompt no longer exists!") end
	local PromptInterface = Prompt.Parent:FindFirstChild("PromptGUI")
	local Highlight = Prompt.Parent.Parent.Parent:FindFirstChild("Highlight", true)



	if PromptInterface then
		local Background = PromptInterface:FindFirstChild("Background")
		local PromptInterfaceTween = TweenService:Create(Background, PromptInfo, {Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0)})
		--	local OutsideStrokeTween = TweenService:Create(Background:FindFirstChildOfClass("UIStroke"), PromptInfo, {Transparency = 1})
		local HighlightTween = TweenService:Create(Highlight, PromptInfo, {OutlineTransparency = 1, FillTransparency = 1})
		HighlightTween:Play()
		--	OutsideStrokeTween:Play()
		PromptInterfaceTween:Play()


	end
end

function PromptsModule.TriggerPrompt(Prompt)
	local PromptInterface = Prompt.Parent:FindFirstChild("PromptGUI")
	if PromptInterface then
		local Background = PromptInterface:FindFirstChild("Background")
		local PromptInterfaceTween = TweenService:Create(Background, PromptInfo, {Size = UDim2.new(0.35, 0,0.35, 0), Position = UDim2.new(0.325,0,0.325,0)})
		PromptInterfaceTween:Play()
	end
end

function PromptsModule.TriggerEndedPrompt(Prompt)
	local PromptInterface = Prompt.Parent:FindFirstChild("PromptGUI")
	if PromptInterface then
		local Background = PromptInterface:FindFirstChild("Background")
		local PromptInterfaceTween = TweenService:Create(Background, PromptInfo, {Size = EndPromptSize, Position = EndPromptPosition})
		PromptInterfaceTween:Play()

	end
end


function PromptsModule.PromptHoldBegin(Prompt, Mobile)
	local PromptInterface = Prompt.Parent:FindFirstChild("PromptGUI")
	if PromptInterface then
		local Background = PromptInterface:FindFirstChild("Background")
		local Bar : Frame = Background:FindFirstChild("Bar")

		local HoldInfo = TweenInfo.new(Prompt.HoldDuration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 0)
		--local PromptInterfaceTween = TweenService:Create(Bar.InsideBar, HoldInfo, {Size = UDim2.new(Bar.Size.X, 0, 1, 0)})
		local HoldEndConnection
	--	PromptInterfaceTween:Play()
		task.spawn(function()
			local Holding = true
			local Start = tick()
			local Current 
			
			HoldEndConnection = Prompt.PromptButtonHoldEnded:Connect(function()
			--[[local Current = tick()
			local TimeElapsed = (Current - Start)
			if TimeElapsed >= Prompt.HoldDuration then
				
			end--]]
				Holding = false
				Bar.InsideBar.Size = UDim2.new(0, 0, 1, 0)
				HoldEndConnection:Disconnect()
			end)
			
			
			while Holding == true do
				task.wait()
				Current = tick()
				local Calc = Current - Start
				--print(Calc, Calc / Prompt.HoldDuration)
				Bar.InsideBar.Size = UDim2.new(Calc / Prompt.HoldDuration, 0, 1, 0)
				
			end
			Bar.InsideBar.Size = UDim2.new(0, 0, 1, 0)
			
		end)

	end
end

function PromptsModule.Init()
	
	for Index, Value in pairs(workspace:GetDescendants()) do
		if Value:IsA("ProximityPrompt") and Value.Parent:FindFirstChild("PromptGUI") and Value.Style == Enum.ProximityPromptStyle.Custom then
			PromptsModule.SetupPrompt(Value)
		end
	end
	
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(Prompt)

		PromptsModule.PromptHoldBegin(Prompt)
	end)
	ProximityPromptService.PromptShown:Connect(function(Prompt)

	
		PromptsModule.ShowPromptBasic(Prompt)
	end)


	ProximityPromptService.PromptHidden:Connect(function(Prompt)
	
		PromptsModule.HidePromptBasic(Prompt)

	end)
end

return PromptsModule
