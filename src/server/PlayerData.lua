local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.ItemsConfig)
local ProfileStore = require(ServerScriptService.ProfileStore)

local PROFILE_STORE_NAME = "PlayerProfiles"
local LEGACY_STORE_NAME = "PlayerData_v1" -- старое хранилище: только читаем, не пишем
local CURRENT_VERSION = 2
local MAX_INT_VALUE = 2147483647

-- true: в Studio данные не сохраняются между запусками (чистый лист для тестов)
local USE_MOCK_IN_STUDIO = false

-- Шаблон нового профиля. Reconcile() доливает в старые профили новые поля отсюда.
local TEMPLATE = {
	Version = CURRENT_VERSION,
	LegacyChecked = false,
	Coins = 0,
	Reputation = 0,
	TutorialDone = false,
	Orders = {},
	Parts = {},
	Broken = {},
	Repaired = {},
	Upgrades = {},
}

-- поле профиля → таблица конфига, по которой проверяем id
local FOLDERS = {
	Parts = Config.Parts,
	Broken = Config.Items,
	Repaired = Config.Items,
	Upgrades = Config.Upgrades,
}

-- Миграции: [N] приводит данные с версии N-1 к версии N.
-- Пример на будущее (когда поднимешь CURRENT_VERSION до 3):
-- [3] = function(data)
--     data.Tools = data.Tools or {}
-- end,
local MIGRATIONS: { [number]: (any) -> () } = {}

local store = ProfileStore.New(PROFILE_STORE_NAME, TEMPLATE)
if USE_MOCK_IN_STUDIO and RunService:IsStudio() then
	store = store.Mock
end
local legacyStore = DataStoreService:GetDataStore(LEGACY_STORE_NAME)

local profiles: { [Player]: any } = {}

local PlayerData = {}

-- ===== Утилиты =====
local function finiteInteger(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.min(MAX_INT_VALUE, math.max(0, math.floor(value)))
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- ===== Санитайзинг: данные из хранилища не должны ломать игру =====
local function sanitize(data: any)
	data.Coins = finiteInteger(data.Coins) or 0
	data.Reputation = finiteInteger(data.Reputation) or 0
	data.TutorialDone = data.TutorialDone == true
	data.LegacyChecked = data.LegacyChecked == true
	if type(data.Orders) ~= "table" then
		data.Orders = {}
	end

	for folderName, source in FOLDERS do
		local clean = {}
		local saved = data[folderName]
		if type(saved) == "table" then
			for id, amount in saved do
				local n = finiteInteger(amount)
				if type(id) == "string" and source[id] and n and n > 0 then
					if folderName == "Upgrades" then
						n = math.min(n, source[id].maxLevel)
					end
					clean[id] = n
				else
					warn(
						("PlayerData: отброшена запись %s.%s"):format(
							folderName,
							tostring(id)
						)
					)
				end
			end
		end
		data[folderName] = clean
	end
end

local function migrate(data: any)
	local version = if type(data.Version) == "number" then data.Version else 1
	if version > CURRENT_VERSION then
		warn(
			"PlayerData: профиль новее кода (версия "
				.. version
				.. "), не трогаем Version"
		)
		return
	end
	for v = version + 1, CURRENT_VERSION do
		local step = MIGRATIONS[v]
		if step then
			step(data)
		end
	end
	data.Version = CURRENT_VERSION
end

-- ===== Импорт старых данных (один раз на профиль) =====
-- true: можно продолжать (импорт выполнен или не нужен)
local function importLegacy(player: Player, data: any): boolean
	local ok, legacy = false, nil
	for attempt = 1, 3 do
		ok, legacy = pcall(function()
			return legacyStore:GetAsync("Player_" .. player.UserId)
		end)
		if ok then
			break
		end
		warn(
			("PlayerData: чтение старых данных, попытка %d/3: %s"):format(
				attempt,
				tostring(legacy)
			)
		)
		task.wait(2 ^ (attempt - 1))
	end

	if not ok then
		if RunService:IsStudio() then
			warn(
				"PlayerData: старое хранилище недоступно в Studio, импорт пропущен"
			)
			return true -- LegacyChecked не ставим: попробуем в следующий раз
		end
		return false
	end

	if type(legacy) == "table" then
		for _, key in
			{
				"Coins",
				"Reputation",
				"TutorialDone",
				"Orders",
				"Parts",
				"Broken",
				"Repaired",
				"Upgrades",
			}
		do
			if legacy[key] ~= nil then
				data[key] = legacy[key]
			end
		end
		data.Version = type(legacy.Version) == "number" and legacy.Version or 1
		print(
			"PlayerData: импортированы старые данные игрока "
				.. player.Name
		)
	end
	data.LegacyChecked = true
	return true
end

-- ===== Зеркало для интерфейса (IntValue в папках игрока) =====
function PlayerData.SetStat(player: Player, name: string, amount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		value.Value = amount
	end
end

function PlayerData.SetMirror(player: Player, folderName: string, id: string, amount: number)
	local folder = player:FindFirstChild(folderName)
	if not folder then
		return
	end
	local value = folder:FindFirstChild(id)
	if value then
		if value:IsA("IntValue") then
			value.Value = amount
		end
	elseif amount > 0 then
		local created = Instance.new("IntValue")
		created.Name = id
		created.Value = amount
		created.Parent = folder
	end
end

-- полностью пересобирает зеркало из профиля
function PlayerData.SyncAll(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	PlayerData.SetStat(player, "Coins", data.Coins)
	PlayerData.SetStat(player, "Reputation", data.Reputation)

	for folderName in FOLDERS do
		local saved = data[folderName]
		local folder = player:FindFirstChild(folderName)
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("IntValue") and not saved[child.Name] then
					child.Value = 0
				end
			end
		end
		for id, amount in saved do
			PlayerData.SetMirror(player, folderName, id, amount)
		end
	end
end

-- ===== Доступ к данным =====
-- таблица данных игрока или nil (сессия не начата или уже закончилась)
function PlayerData.Get(player: Player): any
	local profile = profiles[player]
	if profile and profile:IsActive() then
		return profile.Data
	end
	return nil
end

function PlayerData.Start(player: Player): boolean
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		-- nil: игрок вышел, пока ждали, либо другой сервер не отпустил сессию
		if player.Parent == Players then
			player:Kick(
				"Не удалось загрузить данные. Зайди ещё раз."
			)
		end
		return false
	end

	profile:AddUserId(player.UserId) -- соответствие GDPR
	profile:Reconcile() -- долить новые поля из шаблона

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Сессия данных завершена. Зайди ещё раз.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return false
	end

	local data = profile.Data
	if not data.LegacyChecked and not importLegacy(player, data) then
		profile:EndSession() -- ничего не записываем: старый прогресс не затрём
		player:Kick(
			"Не удалось загрузить данные. Зайди ещё раз."
		)
		return false
	end
	migrate(data)
	sanitize(data)

	profiles[player] = profile
	PlayerData.SyncAll(player)
	return true
end

-- сброс до шаблона (админ-команда /a reset confirm)
function PlayerData.Reset(player: Player): boolean
	local data = PlayerData.Get(player)
	if not data then
		return false
	end
	for key in data do
		data[key] = nil
	end
	for key, value in TEMPLATE do
		data[key] = deepCopy(value)
	end
	data.LegacyChecked = true -- не импортировать старые данные заново
	PlayerData.SyncAll(player)
	return true
end

function PlayerData.Release(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile then
		profile:EndSession() -- финальное сохранение и снятие блокировки
	end
end

return PlayerData
