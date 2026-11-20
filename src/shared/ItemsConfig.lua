local Config = {}

Config.Parts = {
	Wire = { name = "Провод", price = 3 },
	Circuit = { name = "Плата", price = 12 },
	Case = { name = "Корпус", price = 5 },
	Motor = { name = "Моторчик", price = 10 },
	Gear = { name = "Шестерёнка", price = 4 },
	Spring = { name = "Пружина", price = 6 },
	Battery = { name = "Батарейка", price = 9 },
	Lens = { name = "Линза", price = 14 },
}

-- tier: уровень апгрейда "Новые заказы", с которого предмет начинает попадаться
Config.Items = {
	OldRadio = {
		name = "Старое радио",
		tier = 0,
		weight = 5,
		sellPrice = 60,
		parts = { Wire = 2, Circuit = 1, Case = 1 },
		repairCost = { Circuit = 1 },
	},
	BrokenToyCar = {
		name = "Сломанная машинка",
		tier = 0,
		weight = 4,
		sellPrice = 55,
		parts = { Motor = 1, Gear = 2, Case = 1 },
		repairCost = { Motor = 1, Gear = 1 },
	},
	OldRobot = {
		name = "Старый робот",
		tier = 0,
		weight = 1,
		sellPrice = 140,
		parts = { Motor = 2, Circuit = 1, Gear = 3, Wire = 2 },
		repairCost = { Motor = 1, Circuit = 1, Wire = 1 },
	},
	OldTV = {
		name = "Старый телевизор",
		tier = 1,
		weight = 4,
		sellPrice = 130,
		parts = { Circuit = 2, Wire = 3, Case = 1, Lens = 1 },
		repairCost = { Circuit = 1, Wire = 2 },
	},
	ToyDrone = {
		name = "Игрушечный дрон",
		tier = 1,
		weight = 3,
		sellPrice = 120,
		parts = { Motor = 2, Battery = 1, Circuit = 1, Case = 1 },
		repairCost = { Motor = 1, Battery = 1 },
	},
	Gramophone = {
		name = "Граммофон",
		tier = 2,
		weight = 3,
		sellPrice = 220,
		parts = { Spring = 3, Gear = 3, Case = 2, Wire = 1 },
		repairCost = { Spring = 1, Gear = 2 },
	},
	OldCamera = {
		name = "Старая камера",
		tier = 2,
		weight = 2,
		sellPrice = 260,
		parts = { Lens = 2, Circuit = 1, Gear = 2, Case = 1, Battery = 1 },
		repairCost = { Lens = 1, Gear = 1, Battery = 1 },
	},
}

-- costs[i] = цена перехода с уровня i-1 на уровень i
Config.UpgradeOrder = { "Capacity", "Speed", "Tier" }
Config.Upgrades = {
	Capacity = {
		name = "Склад",
		desc = "+5 мест для сломанных предметов",
		maxLevel = 5,
		costs = { 80, 160, 320, 640, 1280 },
	},
	Speed = {
		name = "Скорость работы",
		desc = "Станции быстрее, зона в ремонте шире",
		maxLevel = 5,
		costs = { 100, 200, 400, 800, 1600 },
	},
	Tier = {
		name = "Новые заказы",
		desc = "Открывает более редкие и дорогие предметы",
		maxLevel = 2,
		costs = { 500, 2500 },
	},
}

Config.BaseCapacity = 10
Config.CapacityPerLevel = 5
Config.SpeedPerLevel = 0.1 -- -10% к времени удержания за уровень

function Config.CapacityFor(capacityLevel: number): number
	return Config.BaseCapacity + capacityLevel * Config.CapacityPerLevel
end

return Config
