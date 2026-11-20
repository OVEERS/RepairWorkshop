local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("ItemsConfig"))
local PlotUtil = require(ReplicatedStorage:WaitForChild("PlotUtil"))

local player = Players.LocalPlayer
local speed = player:WaitForChild("Upgrades"):WaitForChild("Speed")

-- HoldDuration меняется только у этого клиента: у каждого игрока своя скорость
ProximityPromptService.PromptShown:Connect(function(prompt)
	local owner = PlotUtil.ownerOf(prompt)
	if owner and owner ~= player.UserId then
		prompt.Enabled = false -- чужая мастерская
		return
	end

	local base = prompt:GetAttribute("BaseHold")
	if base then
		local mult = math.max(0.4, 1 - speed.Value * Config.SpeedPerLevel)
		prompt.HoldDuration = base * mult
	end
end)
