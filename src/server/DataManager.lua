local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local OrderManager = require(ServerScriptService.OrderManager)
local PlayerData = require(ServerScriptService.PlayerData)

local DataManager = {}

-- вызывается из PlayerSetup после создания папок игрока
function DataManager.Load(player: Player)
	if not PlayerData.Start(player) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	-- OrderManager чистит список заказов; тот же самый список лежит в профиле,
	-- поэтому ProfileStore сохраняет его сам
	OrderManager.Init(player, data.Orders)
	data.Orders = OrderManager.Get(player)

	if data.TutorialDone then
		player:SetAttribute("TutorialDone", true)
	end
	player:SetAttribute("DataLoaded", true)
end

function DataManager.Reset(player: Player): boolean
	if not PlayerData.Reset(player) then
		return false
	end
	local data = PlayerData.Get(player)
	if data then
		OrderManager.Init(player, nil)
		data.Orders = OrderManager.Get(player)
	end
	player:SetAttribute("Selected", nil)
	player:SetAttribute("TutorialDone", nil)
	return true
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Release(player) -- сохранение делает ProfileStore
	OrderManager.Cleanup(player)
end)

return DataManager
