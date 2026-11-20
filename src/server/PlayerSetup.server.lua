local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.ItemsConfig)
local RemoteNames = require(ReplicatedStorage.RemoteNames)
local DataManager = require(ServerScriptService.DataManager)

-- RemoteEvent'ы создаём кодом из общего списка
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in RemoteNames do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local function setup(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	local rep = Instance.new("IntValue")
	rep.Name = "Reputation"
	rep.Parent = leaderstats

	for _, name in { "Parts", "Broken", "Repaired" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = player
	end

	-- уровни апгрейдов создаём сразу (значение 0), чтобы UI мог на них подписаться
	local upgrades = Instance.new("Folder")
	upgrades.Name = "Upgrades"
	for id in Config.Upgrades do
		local level = Instance.new("IntValue")
		level.Name = id
		level.Parent = upgrades
	end
	upgrades.Parent = player

	DataManager.Load(player)
end

Players.PlayerAdded:Connect(setup)
for _, player in Players:GetPlayers() do
	task.spawn(setup, player)
end
