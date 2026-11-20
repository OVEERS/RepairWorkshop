local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.ItemsConfig)
local Inventory = require(ServerScriptService.Inventory)
local OrderManager = require(ServerScriptService.OrderManager)

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local DATA_VERSION = 1

local store = DataStoreService:GetDataStore(STORE_NAME)

-- папка игрока → таблица конфига, по которой проверяем id
local FOLDERS = {
	Parts = Config.Parts,
	Broken = Config.Items,
	Repaired = Config.Items,
	Upgrades = Config.Upgrades,
}

local loaded: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
local MAX_INT_VALUE = 2147483647

local DataManager = {}

-- ===== Утилиты =====
local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function finiteInteger(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.min(MAX_INT_VALUE, math.max(0, math.floor(value)))
end

-- повторяет fn до `tries` раз с растущей паузой
local function retry(fn: () -> any, tries: number)
	local lastErr
	for attempt = 1, tries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(
			("DataStore: попытка %d/%d не удалась: %s"):format(
				attempt,
				tries,
				tostring(result)
			)
		)
		if attempt < tries then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, lastErr
end

-- ===== Сериализация =====
local function serialize(player: Player)
	local data = {
		Version = DATA_VERSION,
		Coins = 0,
		Reputation = 0,
		Orders = OrderManager.Get(player),
		TutorialDone = player:GetAttribute("TutorialDone") == true,
	}
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins")
		local reputation = leaderstats:FindFirstChild("Reputation")
		if coins and coins:IsA("IntValue") then
			data.Coins = math.max(0, coins.Value)
		end
		if reputation and reputation:IsA("IntValue") then
			data.Reputation = math.max(0, reputation.Value)
		end
	end
	for folderName in FOLDERS do
		local t = {}
		local folder = player:FindFirstChild(folderName)
		if folder then
			for _, value in folder:GetChildren() do
				if not value:IsA("IntValue") or value.Value <= 0 then
					continue
				end
				t[value.Name] = value.Value
			end
		end
		data[folderName] = t
	end
	return data
end

local function apply(player: Player, data)
	if type(data) ~= "table" then
		return
	end
	if data.TutorialDone == true then
		player:SetAttribute("TutorialDone", true)
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = finiteInteger(data.Coins)
		local reputation = finiteInteger(data.Reputation)
		local coinsValue = coins and leaderstats:FindFirstChild("Coins")
		local reputationValue = reputation and leaderstats:FindFirstChild("Reputation")
		if coinsValue and coinsValue:IsA("IntValue") then
			coinsValue.Value = coins
		end
		if reputationValue and reputationValue:IsA("IntValue") then
			reputationValue.Value = reputation
		end
	end

	for folderName, source in FOLDERS do
		local saved = data[folderName]
		if type(saved) == "table" then
			for id, amount in saved do
				if source[id] and type(amount) == "number" and amount > 0 then
					local clean = math.floor(amount)
					if folderName == "Upgrades" then
						clean = math.min(clean, source[id].maxLevel)
					end
					clean = math.min(MAX_INT_VALUE, clean)
					Inventory.Add(player, folderName, id, clean)
				end
			end
		end
	end
end

-- ===== Загрузка / сохранение =====
function DataManager.Load(player: Player)
	local ok, data = retry(function()
		return store:GetAsync(keyFor(player))
	end, 3)

	if not player.Parent then
		return
	end -- успел выйти

	if not ok then
		-- не загрузили: сохранять НЕЛЬЗЯ, иначе затрём старый прогресс пустыми данными
		player:Kick(
			"Не удалось загрузить данные. Зайди ещё раз."
		)
		return
	end

	if data then
		apply(player, data)
	end

	OrderManager.Init(player, data and data.Orders)

	loaded[player] = true
	player:SetAttribute("DataLoaded", true)
end

function DataManager.Save(player: Player)
	if not loaded[player] then
		return
	end

	-- если уже идёт сохранение (автосейв), дождёмся, чтобы записать самое свежее
	while saving[player] do
		task.wait()
	end

	saving[player] = true
	local data = serialize(player)

	local ok = retry(function()
		store:UpdateAsync(keyFor(player), function()
			return data
		end)
	end, 3)
	saving[player] = nil

	if not ok then
		warn("Не удалось сохранить данные игрока " .. player.Name)
	end
end

-- ===== События =====
Players.PlayerRemoving:Connect(function(player)
	DataManager.Save(player)
	OrderManager.Cleanup(player)
	loaded[player] = nil
	saving[player] = nil
end)

-- автосохранение
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			task.spawn(DataManager.Save, player)
		end
	end
end)

-- закрытие сервера: ждём, пока все сохранятся
game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			DataManager.Save(player)
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
end)

return DataManager
