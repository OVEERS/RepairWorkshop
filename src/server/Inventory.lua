local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.ItemsConfig)

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

-- folderName: "Parts" | "Broken" | "Repaired"
function Inventory.Get(player: Player, folderName: string, id: string): number
	local folder = player:FindFirstChild(folderName)
	local value = folder and folder:FindFirstChild(id)
	if not value or not value:IsA("IntValue") then
		return 0
	end
	return math.max(0, positiveAmount(value.Value) or 0)
end

function Inventory.Count(player: Player, folderName: string): number
	local folder = player:FindFirstChild(folderName)
	local total = 0
	if folder then
		for _, value in folder:GetChildren() do
			if value:IsA("IntValue") then
				total += math.max(0, positiveAmount(value.Value) or 0)
			end
		end
	end
	return total
end

function Inventory.Add(player: Player, folderName: string, id: string, amount: number)
	if typeof(player) ~= "Instance" or type(folderName) ~= "string" or type(id) ~= "string" then
		return
	end
	local clean = positiveAmount(amount)
	if not clean then
		return
	end

	local folder = player:FindFirstChild(folderName)
	if not folder then
		return
	end

	local value = folder:FindFirstChild(id)
	if value then
		if value:IsA("IntValue") then
			value.Value = math.min(MAX_INT_VALUE, value.Value + clean)
		end
	else
		value = Instance.new("IntValue")
		value.Name = id
		value.Value = math.min(MAX_INT_VALUE, clean)
		value.Parent = folder
	end
end

function Inventory.Remove(player: Player, folderName: string, id: string, amount: number): boolean
	local clean = positiveAmount(amount)
	if not clean then
		return false
	end

	local folder = player:FindFirstChild(folderName)
	if not folder then
		return false
	end
	local value = folder:FindFirstChild(id)
	if not value or not value:IsA("IntValue") or value.Value < clean then
		return false
	end

	value.Value -= clean
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

function Inventory.AddCoins(player: Player, amount: number)
	local clean = positiveAmount(amount)
	if not clean then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value = math.min(MAX_INT_VALUE, coins.Value + clean)
	end
end

-- продаёт детали и починенные предметы
function Inventory.SellAll(player: Player): number
	local total = 0

	local parts = player:FindFirstChild("Parts")
	if parts then
		for _, value in parts:GetChildren() do
			if not value:IsA("IntValue") then
				continue
			end
			local info = Config.Parts[value.Name]
			if info and value.Value > 0 then
				total += info.price * value.Value
				value.Value = 0
			end
		end
	end

	local repaired = player:FindFirstChild("Repaired")
	if repaired then
		for _, value in repaired:GetChildren() do
			if not value:IsA("IntValue") then
				continue
			end
			local info = Config.Items[value.Name]
			if info and value.Value > 0 then
				total += info.sellPrice * value.Value
				value.Value = 0
			end
		end
	end

	if total > 0 then
		Inventory.AddCoins(player, total)
	end
	return total
end

return Inventory
