local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.ItemsConfig)
local DataManager = require(ServerScriptService.DataManager)
local Inventory = require(ServerScriptService.Inventory)
local Net = require(ServerScriptService.Net)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- дополнительные админы: [UserId] = true
local EXTRA_ADMINS: { [number]: boolean } = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() or EXTRA_ADMINS[player.UserId] then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function amountArg(text: string?, default: number): number?
	if text == nil then
		return default
	end
	local n = tonumber(text)
	if not n or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.floor(n)
end

local function giver(folderName: string, source: { [string]: any })
	return function(player: Player, args: { string }): string
		local id = args[2]
		local n = amountArg(args[3], 1)
		if not id or not source[id] then
			return "Неизвестный id. Смотри ItemsConfig"
		end
		if not n or n <= 0 then
			return "Количество должно быть больше 0"
		end
		Inventory.Add(player, folderName, id, n)
		return ("+%d %s"):format(n, id)
	end
end

local commands: { [string]: (Player, { string }) -> string } = {
	help = function()
		return "coins N | rep N | part ID [N] | broken ID [N] | repaired ID [N] | upgrade ID LVL | reset confirm"
	end,
	coins = function(player, args)
		local n = amountArg(args[2], 0)
		if not n or n <= 0 then
			return "Использование: /a coins 500"
		end
		Inventory.AddCoins(player, n)
		return "+" .. n .. " монет"
	end,
	rep = function(player, args)
		local n = amountArg(args[2], 0)
		if not n or n <= 0 then
			return "Использование: /a rep 10"
		end
		Inventory.AddReputation(player, n)
		return "+" .. n .. " репутации"
	end,
	part = giver("Parts", Config.Parts),
	broken = giver("Broken", Config.Items),
	repaired = giver("Repaired", Config.Items),
	upgrade = function(player, args)
		local id, level = args[2], amountArg(args[3], -1)
		local def = id and Config.Upgrades[id]
		if not def or not level or level < 0 or level > def.maxLevel then
			return "Использование: /a upgrade Capacity 3"
		end
		local current = Inventory.Get(player, "Upgrades", id)
		if level > current then
			Inventory.Add(player, "Upgrades", id, level - current)
		elseif level < current then
			Inventory.Remove(player, "Upgrades", id, current - level)
		end
		return ("%s: уровень %d"):format(id, level)
	end,
	reset = function(player, args)
		if args[2] ~= "confirm" then
			return "Это удалит весь прогресс. Напиши: /a reset confirm"
		end
		return DataManager.Reset(player) and "Данные сброшены"
			or "Не удалось сбросить"
	end,
}

Net.on("AdminCommand", 0.3, function(player, text)
	if typeof(text) ~= "string" or #text > 100 or not isAdmin(player) then
		return
	end

	local args = {}
	for word in text:gmatch("%S+") do
		table.insert(args, word)
	end
	table.remove(args, 1) -- сам "/a"

	local handler = args[1] and commands[args[1]]
	local reply = if handler
		then handler(player, args)
		else "Неизвестная команда. /a help"
	print(("[Admin] %s: %s -> %s"):format(player.Name, text, reply))
	Remotes.Notify:FireClient(player, reply)
end)
