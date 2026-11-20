local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.ItemsConfig)
local Inventory = require(ServerScriptService.Inventory)

local CUSTOMERS = {
	"Дед Михалыч",
	"Тётя Люба",
	"Студент Паша",
	"Коллекционер Артур",
	"Соседка Нина",
	"Мальчик Тимур",
	"Профессор Гусев",
	"Бабушка Роза",
	"Курьер Макс",
	"Мастер Игнат",
}

local GEN_INTERVAL = 40 -- сек между появлением новых заказов
local TICK = 5 -- как часто проверяем таймеры
local BASE_SLOTS = 2
local MAX_SLOTS = 5
local REP_PER_SLOT = 25 -- каждые 25 репутации = +1 слот

local orders: { [Player]: { any } } = {}
local lastGen: { [Player]: number } = {}
local counter: { [Player]: number } = {}

local OrderManager = {}

-- ===== Утилиты =====
local function now(): number
	return workspace:GetServerTimeNow()
end

local function reputation(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Reputation")
	if not value or not value:IsA("IntValue") then
		return 0
	end
	return math.max(0, value.Value)
end

local function slotsFor(player: Player): number
	return math.min(MAX_SLOTS, BASE_SLOTS + math.floor(reputation(player) / REP_PER_SLOT))
end

local function publish(player: Player)
	player:SetAttribute("Orders", HttpService:JSONEncode(orders[player] or {}))
end

local function generate(player: Player)
	local tier = Inventory.Get(player, "Upgrades", "Tier")
	local rep = reputation(player)

	local pool, totalWeight = {}, 0
	for id, item in Config.Items do
		if (item.tier or 0) <= tier then
			table.insert(pool, { id = id, item = item })
			totalWeight += item.weight
		end
	end

	local roll = math.random() * totalWeight
	local chosen = pool[1]
	for _, entry in pool do
		roll -= entry.item.weight
		if roll <= 0 then
			chosen = entry
			break
		end
	end

	local maxCount = if rep >= 50 then 3 elseif rep >= 15 then 2 else 1
	local count = math.random(1, maxCount)
	local rush = math.random() < 0.2

	local mult = 1.3 + math.random() * 0.3
	if rush then
		mult += 0.5
	end
	local repBonus = 1 + math.min(rep, 100) * 0.004

	counter[player] = (counter[player] or 0) + 1
	local duration = if rush then math.random(150, 240) else math.random(420, 720)

	table.insert(orders[player], {
		id = counter[player],
		customer = CUSTOMERS[math.random(#CUSTOMERS)],
		item = chosen.id,
		count = count,
		reward = math.floor(chosen.item.sellPrice * count * mult * repBonus),
		rush = rush,
		expires = now() + duration,
	})
end

-- ===== API =====
function OrderManager.Get(player: Player)
	return orders[player] or {}
end

function OrderManager.Init(player: Player, saved: any)
	local list = {}
	local maxId = 0

	if type(saved) == "table" then
		for _, o in saved do
			if
				type(o) == "table"
				and type(o.id) == "number"
				and type(o.item) == "string"
				and Config.Items[o.item]
				and type(o.count) == "number"
				and o.count >= 1
				and o.count <= 5
				and type(o.reward) == "number"
				and o.reward > 0
				and type(o.expires) == "number"
				and type(o.customer) == "string"
			then
				table.insert(list, {
					id = o.id,
					customer = o.customer,
					item = o.item,
					count = math.floor(o.count),
					reward = math.floor(o.reward),
					rush = o.rush == true,
					expires = o.expires,
				})
				maxId = math.max(maxId, o.id)
			end
		end
	end

	orders[player] = list
	counter[player] = maxId
	lastGen[player] = os.clock()

	-- новичку сразу даём пару заказов
	if #list == 0 then
		generate(player)
		generate(player)
	end
	publish(player)
end

function OrderManager.Cleanup(player: Player)
	orders[player] = nil
	lastGen[player] = nil
	counter[player] = nil
end

local function find(player: Player, orderId: number): (number?, any?)
	local list = orders[player]
	if not list then
		return nil, nil
	end
	for index = 1, #list do
		local o = list[index]
		if o.id == orderId then
			return index, o
		end
	end
	return nil, nil
end

-- возвращает ok, сообщение
function OrderManager.Deliver(player: Player, orderId: number): (boolean, string)
	local index, o = find(player, orderId)
	if not o then
		return false, "Заказ уже недоступен"
	end
	if o.expires <= now() then
		table.remove(orders[player], index)
		publish(player)
		return false, "Клиент не дождался"
	end

	local item = Config.Items[o.item]
	if not Inventory.Remove(player, "Repaired", o.item, o.count) then
		return false, ("Нужно починенное: %s x%d"):format(item.name, o.count)
	end

	table.remove(orders[player], index)
	Inventory.AddCoins(player, o.reward)
	local leaderstats = player:FindFirstChild("leaderstats")
	local reputationValue = leaderstats and leaderstats:FindFirstChild("Reputation")
	if reputationValue and reputationValue:IsA("IntValue") then
		reputationValue.Value += if o.rush then 2 else 1
	end
	lastGen[player] = math.min(lastGen[player], os.clock() - GEN_INTERVAL + 10) -- новый заказ скоро
	publish(player)
	return true, ("%s доволен! +%d монет"):format(o.customer, o.reward)
end

function OrderManager.Decline(player: Player, orderId: number)
	local index = find(player, orderId)
	if index then
		table.remove(orders[player], index)
		lastGen[player] = os.clock() -- замена придёт не сразу
		publish(player)
	end
end

-- ===== Цикл: удаление просроченных и появление новых =====
task.spawn(function()
	while true do
		task.wait(TICK)
		for _, player in Players:GetPlayers() do
			local list = orders[player]
			if list and player:GetAttribute("DataLoaded") then
				local changed = false

				for i = #list, 1, -1 do
					if list[i].expires <= now() then
						table.remove(list, i)
						changed = true
					end
				end

				if #list < slotsFor(player) and os.clock() - lastGen[player] >= GEN_INTERVAL then
					generate(player)
					lastGen[player] = os.clock()
					changed = true
				end

				if changed then
					publish(player)
				end
			end
		end
	end
end)

return OrderManager
