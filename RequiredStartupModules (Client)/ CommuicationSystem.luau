-- Handles both subtitles and communication interface

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlayVoiceline = RemoteEvents:WaitForChild("PlayVoiceline")
local PlayVoicelineCharacterNearby = RemoteEvents:WaitForChild("PlayVoicelineCharacterNearby")

local SoundModule = require(ReplicatedStorage.Modules.Shared.SoundModule)
local Voicelines = require(ReplicatedStorage.Modules.Shared.Voicelines)



local Player = Players.LocalPlayer
local PlayerGui =  Player.PlayerGui

local CommunicationSystem = {}

function CommunicationSystem.AddSubtitle(CharacterName, Subtitle, Duration)
	task.spawn(function()
		print(CharacterName, Subtitle, Duration)
		Duration = Duration or 7.5
		local Misc = ReplicatedStorage.Misc
		local SubtitleFrame = Misc.SubtitleFrame:Clone()
		local Subtitles = PlayerGui:WaitForChild("CommunicationsSystem"):WaitForChild("Subtitles")
		local SubtitleInfo = TweenInfo.new(.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)


		--SubtitleFrame.Visible = false


		local OldCharacterGlowTransparency = SubtitleFrame.Character.Glow.ImageTransparency
		local CharacterStrokeTransparency = SubtitleFrame.Character.UIStroke.Transparency
		local OriginalBarSize = UDim2.new(0.639, 0,-0.05, 0)
		print("Chilling")

		SubtitleFrame.BackgroundTransparency = 1
		for Index, Value in pairs(SubtitleFrame:GetDescendants()) do
			if Value.Name == "Bar" then
				Value.Size = UDim2.new(0, 0,-0.05, 0)
				Value.BackgroundTransparency = 1
			end
			if Value:IsA("TextLabel") then
				Value.TextTransparency = 1
			elseif Value:IsA("ImageLabel") then
				Value.ImageTransparency = 1
			elseif Value:IsA("UIStroke") then
				Value.Transparency = 1

			end
		end

		SubtitleFrame.Character.Text = CharacterName
		SubtitleFrame.Dialogue.Text = Subtitle

		print("change text")
		--SubtitleFrame.Visible = true

		local FrameTween = TweenService:Create(SubtitleFrame, SubtitleInfo, {BackgroundTransparency = 0}):Play()
		SubtitleFrame.Parent = Subtitles
		for Index, Value in pairs(SubtitleFrame:GetDescendants()) do
			if Value:IsA("TextLabel") then
				print("kabel")
				local Tween = TweenService:Create(Value, SubtitleInfo, {TextTransparency = 0}):Play()
			elseif Value:IsA("ImageLabel") then
				local Tween = TweenService:Create(Value, SubtitleInfo, {ImageTransparency = OldCharacterGlowTransparency}):Play()
				print("labelim")
			elseif Value:IsA("UIStroke") then
				local Tween = TweenService:Create(Value, SubtitleInfo, {Transparency = CharacterStrokeTransparency}):Play()
				print("stroke")
			elseif Value:IsA("Frame") and Value.Name == "Bar" then

				print("Bar")
				local Tween = TweenService:Create(Value, SubtitleInfo, {Size = OriginalBarSize, BackgroundTransparency = 0}):Play()
			end
		end
		task.wait(Duration)
		local FrameTween = TweenService:Create(SubtitleFrame, SubtitleInfo, {BackgroundTransparency = 1}):Play()
		for Index, Value in pairs(SubtitleFrame:GetDescendants()) do
			if Value.Name == "Bar" then
				local Tween = TweenService:Create(Value, SubtitleInfo, {Size = UDim2.new(0, 0,-0.05, 0), BackgroundTransparency = 1}):Play()
			end
			if Value:IsA("TextLabel") then
				local Tween = TweenService:Create(Value, SubtitleInfo, {TextTransparency = 1}):Play()
			elseif Value:IsA("ImageLabel") then
				local Tween = TweenService:Create(Value, SubtitleInfo, {ImageTransparency = 1}):Play()
			elseif Value:IsA("UIStroke") then
				local Tween = TweenService:Create(Value, SubtitleInfo, {Transparency = 1}):Play()

			end
		end
	end)

end

function CommunicationSystem.Init()	
	PlayVoicelineCharacterNearby.OnClientEvent:Connect(function(CharacterModel, CharacterName, Category, Line)
		local data = Voicelines[CharacterName][Category][Line]
		if not data then return end

		local sound = SoundModule.PlaySoundFromID(data.ID, CharacterModel.PrimaryPart or CharacterModel:FindFirstChild("HumanoidRootPart") or CharacterModel, 1)
		if data.Subtitle then
			print("Subtitle:", data.Subtitle) -- Replace with GUI logic

			CommunicationSystem.AddSubtitle(CharacterName, data.Subtitle, sound.TimeLength + 0.5)
		end

	end)
	

	PlayVoiceline.OnClientEvent:Connect(function(CharacterName, Category, Line)
		local data = Voicelines[CharacterName][Category][Line]
		if not data then return end

		local sound = SoundModule.PlaySoundFromID(data.ID, nil, 1)
		
		if data.Subtitle then
			
			CommunicationSystem.AddSubtitle(CharacterName, data.Subtitle, sound.TimeLength + 0.5)
		end
		
		local Info = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
		
		local CharacterHUD = PlayerGui:WaitForChild("CommunicationsSystem"):WaitForChild("Character")
		local Audio = PlayerGui:WaitForChild("CommunicationsSystem"):WaitForChild("Audio")
		local guiVisualizer = PlayerGui:WaitForChild("CommunicationsSystem"):WaitForChild("Audio"):WaitForChild("AudioContainer")
		local FinalSize = UDim2.new(0.093, 0,0.082, 0)
		Audio.Size = UDim2.new(0, 0, FinalSize.Y.Scale, 0)
		
		Audio.Visible = true
		CharacterHUD.Visible = true
		-- PLAY SOUND EFFECT TO INDICATE THAT THE MIC IS ON 
		
		TweenService:Create(CharacterHUD, Info, {BackgroundTransparency = 0.5}):Play()
		TweenService:Create(CharacterHUD:WaitForChild("UIStroke"), Info, {Transparency = 0.5}):Play()
		TweenService:Create(Audio, Info, {Size = FinalSize}):Play()
		TweenService:Create(CharacterHUD:WaitForChild("ImageLabel"), Info, {ImageTransparency = 0.93}):Play()
		TweenService:Create(CharacterHUD:WaitForChild("Glow"), Info, {ImageTransparency = 0.77}):Play()
		TweenService:Create(CharacterHUD:WaitForChild("CharacterRender"), Info, {ImageTransparency = 0}):Play()
		TweenService:Create(CharacterHUD:WaitForChild("CharacterName"), Info, {TextTransparency = 0}):Play()


	
		-- add electronicy sound + static
		-- Hook into the visualizer system if available
	
	
		warn("spawning loop")		
		
		task.spawn(function()
			warn(sound.TimeLength)
			
			local Count = 0
			while Count<= (sound.TimeLength + 0.5) do
				Count += .01
				warn("Starting loop")
				for _, g in pairs(guiVisualizer:GetChildren()) do
					if g:IsA("Frame") then
						local loudnessScale = math.clamp(sound.PlaybackLoudness / 300, 0.01, 1)
						g.Size = UDim2.new(0.1, 0, loudnessScale, 0)
						TweenService:Create(g, TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
							Size = UDim2.new(0.1, 0, 0.01, 0)
						}):Play()
					end
				end
				task.wait(.01)
			end
		end)
		
		task.spawn(function()
			local TemporaryConnection
			local Count = 0
			local CanTweenBackToInvisible = true
			
			TemporaryConnection = PlayVoiceline.OnClientEvent:Once(function()
				TemporaryConnection:Disconnect()
				CanTweenBackToInvisible = false
			end)
							
			while Count <= (sound.TimeLength + 0.5) do
				Count += 0.1
				task.wait(0.1)
			end
			
			if CanTweenBackToInvisible then
				TemporaryConnection:Disconnect()
				
				TweenService:Create(CharacterHUD, Info, {BackgroundTransparency = 1}):Play()
				TweenService:Create(CharacterHUD:WaitForChild("ImageLabel"), Info, {ImageTransparency = 1}):Play()

				TweenService:Create(CharacterHUD:WaitForChild("UIStroke"), Info, {Transparency = 1}):Play()
				TweenService:Create(Audio, Info, {Size = UDim2.new(0, 0, FinalSize.Y.Scale, 0)}):Play()
				TweenService:Create(CharacterHUD:WaitForChild("Glow"), Info, {ImageTransparency = 1}):Play()
				TweenService:Create(CharacterHUD:WaitForChild("CharacterRender"), Info, {ImageTransparency = 1}):Play()
				TweenService:Create(CharacterHUD:WaitForChild("CharacterName"), Info, {TextTransparency = 1}):Play()

				task.wait(0.75)
				
				Audio.Visible = false
				CharacterHUD.Visible = false
			end
			
		end)


		
	end)

end

return CommunicationSystem
