local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.ItemsConfig)
local PlayerData = require(ServerScriptService.PlayerData)

local Inventory = {}
local MAX_INT_VALUE = 2147483647

local function positiveAmount(amount: any): number?
	if
		type(amount) ~= "number"
		or amount ~= amount
		or amount == math.huge
		or amount == -math.huge
	then
		return nil
	end
	local clean = math.floor(amount)
	if clean <= 0 then
		return nil
	end
	return clean
end

local function folderData(player: Player, folderName: string): { [string]: number }?
	local data = PlayerData.Get(player)
	local t = data and data[folderName]
	if type(t) ~= "table" then
		return nil
	end
	return t
end

-- folderName: "Parts" | "Broken" | "Repaired" | "Upgrades"
function Inventory.Get(player: Player, folderName: string, id: string): number
	local t = folderData(player, folderName)
	return t and t[id] or 0
end

function Inventory.Count(player: Player, folderName: string): number
	local t = folderData(player, folderName)
	local total = 0
	if t then
		for _, amount in t do
			total += amount
		end
	end
	return total
end

function Inventory.Add(player: Player, folderName: string, id: string, amount: number)
	if type(folderName) ~= "string" or type(id) ~= "string" then
		return
	end
	local clean = positiveAmount(amount)
	local t = folderData(player, folderName)
	if not clean or not t then
		return
	end
	local new = math.min(MAX_INT_VALUE, (t[id] or 0) + clean)
	t[id] = new
	PlayerData.SetMirror(player, folderName, id, new)
end

function Inventory.Remove(player: Player, folderName: string, id: string, amount: number): boolean
	local clean = positiveAmount(amount)
	local t = folderData(player, folderName)
	if not clean or not t then
		return false
	end
	local have = t[id] or 0
	if have < clean then
		return false
	end
	local left = have - clean
	t[id] = if left > 0 then left else nil
	PlayerData.SetMirror(player, folderName, id, left)
	return true
end

-- чего не хватает из costs: { [id] = сколько_не_хватает }
function Inventory.Missing(player: Player, folderName: string, costs: { [string]: number })
	local missing = {}
	if type(costs) ~= "table" then
		return missing
	end
	for id, amount in costs do
		local clean = positiveAmount(amount)
		if not clean then
			continue
		end
		local lack = clean - Inventory.Get(player, folderName, id)
		if lack > 0 then
			missing[id] = lack
		end
	end
	return missing
end

function Inventory.Spend(player: Player, folderName: string, costs: { [string]: number }): boolean
	if type(costs) ~= "table" or next(Inventory.Missing(player, folderName, costs)) ~= nil then
		return false
	end
	for id, amount in costs do
		if type(id) ~= "string" or not positiveAmount(amount) then
			return false
		end
	end
	for id, amount in costs do
		local clean = positiveAmount(amount)
		if clean and not Inventory.Remove(player, folderName, id, clean) then
			return false
		end
	end
	return true
end

-- ===== Монеты и репутация =====
function Inventory.GetCoins(player: Player): number
	local data = PlayerData.Get(player)
	return data and data.Coins or 0
end

function Inventory.AddCoins(player: Player, amount: number)
	local clean = positiveAmount(amount)
	local data = PlayerData.Get(player)
	if not clean or not data then
		return
	end
	data.Coins = math.min(MAX_INT_VALUE, data.Coins + clean)
	PlayerData.SetStat(player, "Coins", data.Coins)
end

function Inventory.SpendCoins(player: Player, amount: number): boolean
	local clean = positiveAmount(amount)
	local data = PlayerData.Get(player)
	if not clean or not data or data.Coins < clean then
		return false
	end
	data.Coins -= clean
	PlayerData.SetStat(player, "Coins", data.Coins)
	return true
end

function Inventory.GetReputation(player: Player): number
	local data = PlayerData.Get(player)
	return data and data.Reputation or 0
end

function Inventory.AddReputation(player: Player, amount: number)
	local clean = positiveAmount(amount)
	local data = PlayerData.Get(player)
	if not clean or not data then
		return
	end
	data.Reputation = math.min(MAX_INT_VALUE, data.Reputation + clean)
	PlayerData.SetStat(player, "Reputation", data.Reputation)
end

-- продаёт детали и починенные предметы
function Inventory.SellAll(player: Player): number
	local total = 0

	local parts = folderData(player, "Parts")
	if parts then
		for id, amount in parts do
			local info = Config.Parts[id]
			if info and Inventory.Remove(player, "Parts", id, amount) then
				total += info.price * amount
			end
		end
	end

	local repaired = folderData(player, "Repaired")
	if repaired then
		for id, amount in repaired do
			local info = Config.Items[id]
			if info and Inventory.Remove(player, "Repaired", id, amount) then
				total += info.sellPrice * amount
			end
		end
	end

	if total > 0 then
		Inventory.AddCoins(player, total)
	end
	return total
end

return Inventory
