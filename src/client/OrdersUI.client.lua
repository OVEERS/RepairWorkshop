local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("ItemsConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local repaired = player:WaitForChild("Repaired")
local reputation = player:WaitForChild("leaderstats"):WaitForChild("Reputation")

local WHITE = Color3.fromRGB(255, 255, 255)
local GREY = Color3.fromRGB(150, 150, 160)
local GOLD = Color3.fromRGB(255, 214, 90)

local function new(class: string, props: { [string]: any }, parent: Instance?)
	local inst: any = Instance.new(class)
	for key, value in props do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

-- ===== Каркас =====
local gui =
	new("ScreenGui", { Name = "OrdersUI", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

local frame = new("Frame", {
	Size = UDim2.fromOffset(460, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(30, 30, 36),
	BorderSizePixel = 0,
	Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
new("UIPadding", {
	PaddingTop = UDim.new(0, 12),
	PaddingBottom = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
}, frame)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, frame)

local header = new(
	"Frame",
	{ Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 0 },
	frame
)
new("TextLabel", {
	Size = UDim2.new(1, -40, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Доска заказов",
}, header)
local close = new("TextButton", {
	Size = UDim2.fromOffset(28, 28),
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.fromRGB(70, 70, 80),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = WHITE,
	Text = "✕",
}, header)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, close)
close.Activated:Connect(function()
	frame.Visible = false
end)

local repLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	LayoutOrder = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
}, frame)

local emptyLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Font = Enum.Font.Gotham,
	TextSize = 15,
	TextColor3 = GREY,
	Text = "Новых заказов пока нет. Загляни позже.",
	Visible = false,
}, frame)

-- ===== Отрисовка =====
local timers: { { label: TextLabel, expires: number } } = {}

local function fmtTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function render()
	for _, child in frame:GetChildren() do
		if child.Name == "Card" then
			child:Destroy()
		end
	end
	table.clear(timers)

	local ok, list = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Orders") or "[]")
	end)
	if not ok then
		list = {}
	end

	repLabel.Text = "Репутация: " .. reputation.Value
	emptyLabel.Visible = #list == 0

	for index, o in list do
		local item = Config.Items[o.item]
		if not item then
			continue
		end

		local have = repaired:FindFirstChild(o.item)
		local canDeliver = have ~= nil and have.Value >= o.count

		local card = new("Frame", {
			Name = "Card",
			Size = UDim2.new(1, 0, 0, 84),
			BackgroundColor3 = o.rush and Color3.fromRGB(64, 42, 42) or Color3.fromRGB(44, 44, 54),
			BorderSizePixel = 0,
			LayoutOrder = 10 + index,
		}, frame)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, card)

		new("TextLabel", {
			Size = UDim2.new(1, -150, 0, 20),
			Position = UDim2.fromOffset(10, 6),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = o.rush and Color3.fromRGB(255, 150, 120) or GREY,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = (o.rush and "СРОЧНО · " or "") .. o.customer,
		}, card)
		new("TextLabel", {
			Size = UDim2.new(1, -150, 0, 22),
			Position = UDim2.fromOffset(10, 28),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ("%s  x%d"):format(item.name, o.count),
		}, card)
		new("TextLabel", {
			Size = UDim2.new(1, -150, 0, 18),
			Position = UDim2.fromOffset(10, 54),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ("Награда: %d   (на рынке: %d)"):format(
				o.reward,
				item.sellPrice * o.count
			),
		}, card)

		local timerLabel = new("TextLabel", {
			Size = UDim2.fromOffset(60, 18),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -40, 0, 8),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, card)
		table.insert(timers, { label = timerLabel, expires = o.expires })

		local decline = new("TextButton", {
			Size = UDim2.fromOffset(24, 24),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 6),
			BackgroundColor3 = Color3.fromRGB(70, 70, 80),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = WHITE,
			Text = "✕",
		}, card)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, decline)
		decline.Activated:Connect(function()
			Remotes.DeclineOrder:FireServer(o.id)
		end)

		local deliver = new("TextButton", {
			Size = UDim2.fromOffset(120, 32),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -8),
			BackgroundColor3 = canDeliver and Color3.fromRGB(60, 160, 90)
				or Color3.fromRGB(90, 90, 100),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = WHITE,
			Text = canDeliver and "Выдать"
				or ("Есть %d/%d"):format(have and have.Value or 0, o.count),
		}, card)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, deliver)
		deliver.Activated:Connect(function()
			Remotes.DeliverOrder:FireServer(o.id)
		end)
	end
end

-- таймеры обновляем раз в секунду, пока окно открыто
task.spawn(function()
	while true do
		task.wait(1)
		if frame.Visible then
			local t = workspace:GetServerTimeNow()
			for _, entry in timers do
				local left = entry.expires - t
				entry.label.Text = fmtTime(left)
				entry.label.TextColor3 = left < 60 and Color3.fromRGB(255, 120, 110) or WHITE
			end
		end
	end
end)

player:GetAttributeChangedSignal("Orders"):Connect(render)
reputation.Changed:Connect(render)
repaired.ChildAdded:Connect(function(child)
	render()
	child.Changed:Connect(render)
end)
for _, child in repaired:GetChildren() do
	child.Changed:Connect(render)
end

Remotes.OpenOrders.OnClientEvent:Connect(function()
	render()
	frame.Visible = true
end)

render()

UIKit.limitWidth(frame, 460)
