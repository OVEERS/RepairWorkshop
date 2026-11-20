local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.ItemsConfig)
local Inventory = require(ServerScriptService.Inventory)
local OrderManager = require(ServerScriptService.OrderManager)
local RateLimit = require(ServerScriptService.RateLimit)
local Log = require(ServerScriptService.Log)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MIN_REPAIR_TIME = 1.5 -- быстрее мини-игру пройти нереально
local SESSION_TIMEOUT = 30 -- сколько живёт сессия ремонта без ответа клиента
local PERFECT_BONUS = 0.15 -- бонус монетами за 3/3

local repairing: { [Player]: { id: string, start: number } } = {}

-- ===== Хелперы =====
local function notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end

local function capacityOf(player: Player): number
	return Config.CapacityFor(Inventory.Get(player, "Upgrades", "Capacity"))
end

local function pickRandomItem(player: Player)
	local tier = Inventory.Get(player, "Upgrades", "Tier")
	local pool, totalWeight = {}, 0
	for id, item in Config.Items do
		if (item.tier or 0) <= tier then
			table.insert(pool, { id = id, item = item })
			totalWeight += item.weight
		end
	end

	local roll = math.random() * totalWeight
	for _, entry in pool do
		roll -= entry.item.weight
		if roll <= 0 then
			return entry.id, entry.item
		end
	end
	return pool[1].id, pool[1].item
end

local function pickBroken(player: Player): string?
	local selected = player:GetAttribute("Selected")
	if selected and Inventory.Get(player, "Broken", selected) > 0 then
		return selected
	end
	local broken = player:FindFirstChild("Broken")
	if not broken then
		return nil
	end
	for _, value in broken:GetChildren() do
		if value:IsA("IntValue") and value.Value > 0 then
			return value.Name
		end
	end
	return nil
end

local function formatParts(list: { [string]: number }): string
	local out = {}
	for partId, amount in list do
		local part = Config.Parts[partId]
		if part then
			table.insert(out, part.name .. " x" .. amount)
		end
	end
	return table.concat(out, ", ")
end

-- вешает ProximityPrompt на все Part с тегом (и на те, что появятся позже)
local function bindTag(tag: string, action: string, object: string, hold: number, callback)
	local function setup(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("StationPrompt") then
			return
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StationPrompt"
		prompt.ActionText = action
		prompt.ObjectText = object
		prompt.HoldDuration = hold
		prompt:SetAttribute("BaseHold", hold) -- клиент умножает на множитель скорости
		prompt.MaxActivationDistance = 8
		prompt.Parent = part

		prompt.Triggered:Connect(function(player)
			if not player:GetAttribute("DataLoaded") then
				notify(
					player,
					"Данные ещё загружаются. Попробуй через секунду."
				)
				return
			end
			Log.run("Station " .. tag, callback, player)
		end)
	end

	for _, part in CollectionService:GetTagged(tag) do
		task.spawn(setup, part)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(setup)
end

-- ===== Выбор предмета =====
Remotes.SelectItem.OnServerEvent:Connect(function(player, itemId)
	if not RateLimit.allow(player, "SelectItem", 0.1) then
		return
	end
	if typeof(itemId) ~= "string" or not Config.Items[itemId] then
		return
	end
	if Inventory.Get(player, "Broken", itemId) <= 0 then
		return
	end
	player:SetAttribute("Selected", itemId)
end)

-- ===== Приём =====
bindTag(
	"Station_Intake",
	"Взять заказ",
	"Станция приёма",
	0.5,
	function(player)
		local cap = capacityOf(player)
		if Inventory.Count(player, "Broken") >= cap then
			notify(
				player,
				("Склад полон (%d/%d). Разбери, почини или улучши склад"):format(
					cap,
					cap
				)
			)
			return
		end
		local id, item = pickRandomItem(player)
		Inventory.Add(player, "Broken", id, 1)
		notify(player, "Принято: " .. item.name)
	end
)

-- ===== Разборка =====
bindTag(
	"Station_Disassemble",
	"Разобрать",
	"Станция разборки",
	1,
	function(player)
		local id = pickBroken(player)
		if not id then
			notify(
				player,
				"Нет сломанных предметов. Загляни на станцию приёма"
			)
			return
		end

		local item = Config.Items[id]
		if not Inventory.Remove(player, "Broken", id, 1) then
			notify(player, "Предмет уже использован")
			return
		end
		for partId, amount in item.parts do
			Inventory.Add(player, "Parts", partId, amount)
		end
		notify(player, "Разобрано: " .. item.name .. " → " .. formatParts(item.parts))
	end
)

-- ===== Ремонт (старт мини-игры) =====
bindTag("Station_Repair", "Чинить", "Станция ремонта", 0.3, function(player)
	local old = repairing[player]
	if old and os.clock() - old.start < SESSION_TIMEOUT then
		return
	end

	local id = pickBroken(player)
	if not id then
		notify(
			player,
			"Нет сломанных предметов. Загляни на станцию приёма"
		)
		return
	end

	local missing = Inventory.Missing(player, "Parts", Config.Items[id].repairCost)
	if next(missing) ~= nil then
		notify(player, "Не хватает: " .. formatParts(missing))
		return
	end

	repairing[player] = { id = id, start = os.clock() }
	Remotes.StartRepair:FireClient(player, id)
end)

-- ===== Ремонт (результат мини-игры) =====
Remotes.RepairResult.OnServerEvent:Connect(function(player, hits)
	local session = repairing[player]
	repairing[player] = nil
	if not session then
		return
	end
	if typeof(hits) ~= "number" or hits ~= hits or hits == math.huge or hits == -math.huge then
		return
	end
	if hits < 0 then
		return
	end -- игрок отменил
	if os.clock() - session.start < MIN_REPAIR_TIME then
		return
	end
	hits = math.clamp(math.floor(hits), 0, 3)

	local id = session.id
	local item = Config.Items[id]

	-- пока шла мини-игра, инвентарь мог измениться: проверяем заново
	local stillOk = Inventory.Get(player, "Broken", id) > 0
		and next(Inventory.Missing(player, "Parts", item.repairCost)) == nil
	if not stillOk then
		notify(player, "Ремонт сорван: изменился инвентарь")
		return
	end

	if hits < 2 then
		notify(player, ("Не вышло (%d/3). Попробуй ещё раз"):format(hits))
		return
	end

	if not Inventory.Spend(player, "Parts", item.repairCost) then
		notify(player, "Ремонт сорван: недостаточно деталей")
		return
	end
	if not Inventory.Remove(player, "Broken", id, 1) then
		notify(player, "Ремонт сорван: предмет уже использован")
		return
	end
	Inventory.Add(player, "Repaired", id, 1)

	if hits == 3 then
		local bonus = math.floor(item.sellPrice * PERFECT_BONUS)
		Inventory.AddCoins(player, bonus)
		notify(
			player,
			("Идеально! %s починено, бонус +%d"):format(item.name, bonus)
		)
	else
		notify(player, "Починено: " .. item.name)
	end
end)

-- ===== Продажа =====
bindTag("Station_Sell", "Продать всё", "Приёмка", 1, function(player)
	local total = Inventory.SellAll(player)
	if total > 0 then
		notify(player, "Продано на " .. total .. " монет")
	else
		notify(player, "Продавать нечего")
	end
end)

-- ===== Магазин улучшений =====
bindTag("Station_Upgrade", "Открыть", "Улучшения", 0.3, function(player)
	Remotes.OpenShop:FireClient(player)
end)

Remotes.BuyUpgrade.OnServerEvent:Connect(function(player, id)
	if not RateLimit.allow(player, "BuyUpgrade", 0.3) then
		return
	end
	if not player:GetAttribute("DataLoaded") then
		return
	end
	if typeof(id) ~= "string" then
		return
	end
	local def = Config.Upgrades[id]
	if not def then
		return
	end

	local level = Inventory.Get(player, "Upgrades", id)
	if level >= def.maxLevel then
		notify(player, "Уже максимальный уровень")
		return
	end

	local cost = def.costs[level + 1]
	if type(cost) ~= "number" or cost ~= cost or cost == math.huge then
		notify(player, "Ошибка конфигурации улучшения")
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins or not coins:IsA("IntValue") then
		return
	end
	if coins.Value < cost then
		notify(player, "Не хватает монет: нужно " .. cost)
		return
	end

	coins.Value -= cost
	Inventory.Add(player, "Upgrades", id, 1)
	notify(player, ("Улучшено: %s → ур. %d"):format(def.name, level + 1))
end)

-- ===== Доска заказов =====
bindTag("Station_Orders", "Открыть", "Доска заказов", 0.3, function(player)
	Remotes.OpenOrders:FireClient(player)
end)

Remotes.DeliverOrder.OnServerEvent:Connect(function(player, orderId)
	if not RateLimit.allow(player, "DeliverOrder", 0.3) then
		return
	end
	if not player:GetAttribute("DataLoaded") then
		return
	end
	if typeof(orderId) ~= "number" then
		return
	end
	local _, message = OrderManager.Deliver(player, orderId)
	notify(player, message)
end)

Remotes.DeclineOrder.OnServerEvent:Connect(function(player, orderId)
	if not RateLimit.allow(player, "DeclineOrder", 0.3) then
		return
	end
	if not player:GetAttribute("DataLoaded") then
		return
	end
	if typeof(orderId) ~= "number" then
		return
	end
	OrderManager.Decline(player, orderId)
end)

-- ===== Туториал =====
Remotes.TutorialDone.OnServerEvent:Connect(function(player)
	if not player:GetAttribute("DataLoaded") then
		return
	end
	if player:GetAttribute("TutorialDone") then
		return
	end
	player:SetAttribute("TutorialDone", true)
	notify(player, "Обучение завершено. Удачи в мастерской!")
end)

Players.PlayerRemoving:Connect(function(player)
	repairing[player] = nil
end)
