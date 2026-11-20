local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("ItemsConfig"))
local speed = Players.LocalPlayer:WaitForChild("Upgrades"):WaitForChild("Speed")

-- HoldDuration меняется только у этого клиента: у каждого игрока своя скорость
ProximityPromptService.PromptShown:Connect(function(prompt)
	local base = prompt:GetAttribute("BaseHold")
	if base then
		local mult = math.max(0.4, 1 - speed.Value * Config.SpeedPerLevel)
		prompt.HoldDuration = base * mult
	end
end)
