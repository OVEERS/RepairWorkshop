local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RateLimit = require(ServerScriptService.RateLimit)
local Log = require(ServerScriptService.Log)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Net = {}

-- Подписка на клиентский ремоут с общими проверками:
--   лимит частоты, загруженные данные, перехват ошибок.
-- needsData = false отключает проверку DataLoaded (почти всегда не нужно).
function Net.on(
	name: string,
	interval: number,
	handler: (player: Player, ...any) -> (),
	needsData: boolean?
)
	local remote = Remotes:WaitForChild(name) :: RemoteEvent

	remote.OnServerEvent:Connect(function(player: Player, ...)
		if not RateLimit.allow(player, name, interval) then
			return
		end
		if needsData ~= false and not player:GetAttribute("DataLoaded") then
			return
		end
		Log.run("Remote " .. name, handler, player, ...)
	end)
end

return Net
