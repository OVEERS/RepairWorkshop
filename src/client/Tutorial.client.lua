local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local PlotUtil = require(ReplicatedStorage:WaitForChild("PlotUtil"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local new, T = UIKit.new, UIKit.Theme

local player = Players.LocalPlayer
local partsFolder = player:WaitForChild("Parts")
local brokenFolder = player:WaitForChild("Broken")
local repairedFolder = player:WaitForChild("Repaired")
local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")

-- ждём, пока сервер загрузит данные (там же приходит флаг TutorialDone)
if not player:GetAttribute("DataLoaded") then
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
if player:GetAttribute("TutorialDone") then
	return
end

local function sumFolder(folder: Folder): number
	local n = 0
	for _, value in folder:GetChildren() do
		if value:IsA("IntValue") then
			n += value.Value
		end
	end
	return n
end

-- ===== Шаги =====
-- done: проверка по состоянию инвентаря; event: шаг закрывается событием
type Step = { tag: string, text: string, done: (() -> boolean)?, event: string? }

local steps: { Step } = {
	{
		tag = "Station_Intake",
		text = "Подойди к станции приёма и возьми два сломанных предмета (удерживай E)",
		done = function()
			return sumFolder(brokenFolder) >= 2
				or sumFolder(partsFolder) > 0
				or sumFolder(repairedFolder) > 0
		end,
	},
	{
		tag = "Station_Disassemble",
		text = "Кликни предмет в списке «Сломано» и разбери его на станции разборки: получишь детали",
		done = function()
			return sumFolder(partsFolder) > 0 or sumFolder(repairedFolder) > 0
		end,
	},
	{
		tag = "Station_Repair",
		text = "Почини предмет на станции ремонта: жми Пробел, когда маркер в зелёной зоне. Не хватает деталей? Разбери ещё что-нибудь",
		done = function()
			return sumFolder(repairedFolder) > 0
		end,
	},
	{
		tag = "Station_Orders",
		text = "Загляни на доску заказов: клиенты платят больше рыночной цены",
		event = "orders",
	},
	{
		tag = "Station_Sell",
		text = "Продай лишнее на станции продажи",
		event = "earned",
	},
	{
		tag = "Station_Upgrade",
		text = "Потрать монеты на улучшения: больше места, быстрее работа, новые заказы",
		event = "shop",
	},
}

local current = 1
local finished = false

-- ===== UI =====
local gui =
	new("ScreenGui", { Name = "Tutorial", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

local frame = new("Frame", {
	Size = UDim2.fromScale(0.92, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 84),
	BackgroundColor3 = T.Bg,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
}, gui)
UIKit.round(frame, 10)
UIKit.pad(frame, 10, 14)
UIKit.limitWidth(frame, 420)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, frame)

local title = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextColor3 = T.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 0,
}, frame)

local bodyText = new("TextLabel", {
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 16,
	TextColor3 = T.Text,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
}, frame)

local skip = new("TextButton", {
	Size = UDim2.new(1, 0, 0, UIKit.isTouch() and 32 or 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = T.TextDim,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Пропустить обучение",
	LayoutOrder = 2,
}, frame)

-- ===== Подсветка станции =====
local markers: { Instance } = {}

local function clearMarkers()
	for _, marker in markers do
		marker:Destroy()
	end
	table.clear(markers)
end

local function nearestTagged(tag: string): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local best: BasePart? = nil
	local bestDist = math.huge
	for _, part in CollectionService:GetTagged(tag) do
		local owner = PlotUtil.ownerOf(part)
		if part:IsA("BasePart") and (owner == nil or owner == player.UserId) then
			local dist = root and (part.Position - (root :: BasePart).Position).Magnitude or 0
			if dist < bestDist then
				best, bestDist = part, dist
			end
		end
	end
	return best
end

local function mark(part: BasePart)
	local highlight = new("Highlight", {
		Adornee = part,
		FillColor = T.Gold,
		FillTransparency = 0.7,
		OutlineColor = T.Gold,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, part)

	local billboard = new("BillboardGui", {
		Adornee = part,
		Size = UDim2.fromOffset(50, 50),
		StudsOffset = Vector3.new(0, part.Size.Y / 2 + 3, 0),
		AlwaysOnTop = true,
	}, part)
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		Rotation = 45,
		BackgroundColor3 = T.Gold,
		BorderSizePixel = 0,
	}, billboard)

	TweenService:Create(
		billboard,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffset = billboard.StudsOffset + Vector3.new(0, 1.5, 0) }
	):Play()

	table.insert(markers, highlight)
	table.insert(markers, billboard)
end

-- ===== Логика =====
local function finish()
	if finished then
		return
	end
	finished = true
	clearMarkers()
	Remotes.TutorialDone:FireServer()
	gui:Destroy()
end

local function render()
	clearMarkers()
	local step = steps[current]
	if not step then
		return
	end
	title.Text = ("Обучение  %d/%d"):format(current, #steps)
	bodyText.Text = step.text
	local target = nearestTagged(step.tag)
	if target then
		mark(target)
	end
end

local function advance()
	if finished then
		return
	end
	while steps[current] and steps[current].done and (steps[current].done :: () -> boolean)() do
		current += 1
	end
	if not steps[current] then
		finish()
	else
		render()
	end
end

local function fire(eventName: string)
	local step = steps[current]
	if not finished and step and step.event == eventName then
		current += 1
		advance()
	end
end

skip.Activated:Connect(finish)

-- следим за инвентарём
local function watch(folder: Folder)
	folder.ChildAdded:Connect(function(child)
		child.Changed:Connect(advance)
		advance()
	end)
	for _, child in folder:GetChildren() do
		child.Changed:Connect(advance)
	end
end
watch(partsFolder)
watch(brokenFolder)
watch(repairedFolder)

-- и за событиями
Remotes.OpenOrders.OnClientEvent:Connect(function()
	fire("orders")
end)
Remotes.OpenShop.OnClientEvent:Connect(function()
	fire("shop")
end)

local lastCoins = coins.Value
coins.Changed:Connect(function(value)
	if value > lastCoins then
		fire("earned")
	end
	lastCoins = value
end)

-- станция могла появиться после старта шага: перерисуем подсветку
for _, step in steps do
	local tag = step.tag
	CollectionService:GetInstanceAddedSignal(tag):Connect(function()
		task.defer(function()
			local cur = steps[current]
			if not finished and cur and cur.tag == tag then
				render()
			end
		end)
	end)
end

advance()
