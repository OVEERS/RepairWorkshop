local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("ItemsConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local upgrades = player:WaitForChild("Upgrades")
local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")

local WHITE = Color3.fromRGB(255, 255, 255)
local GREY = Color3.fromRGB(150, 150, 160)

local new = UIKit.new

local gui =
	new("ScreenGui", { Name = "ShopUI", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

local frame = new("Frame", {
	Size = UDim2.fromOffset(420, 0),
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

-- шапка
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
	Text = "Улучшения",
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

local coinsLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	LayoutOrder = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(255, 214, 90),
	TextXAlignment = Enum.TextXAlignment.Left,
}, frame)
local function updateCoins()
	coinsLabel.Text = "Монеты: " .. coins.Value
end
coins.Changed:Connect(updateCoins)
updateCoins()

-- строки апгрейдов
for index, id in Config.UpgradeOrder do
	local def = Config.Upgrades[id]

	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = Color3.fromRGB(44, 44, 54),
		BorderSizePixel = 0,
		LayoutOrder = index + 1,
	}, frame)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, row)

	local title = new("TextLabel", {
		Size = UDim2.new(1, -130, 0, 24),
		Position = UDim2.fromOffset(10, 8),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	new("TextLabel", {
		Size = UDim2.new(1, -130, 0, 32),
		Position = UDim2.fromOffset(10, 32),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = GREY,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = def.desc,
	}, row)
	local buy = new("TextButton", {
		Size = UDim2.fromOffset(110, 36),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = WHITE,
	}, row)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, buy)

	local value = upgrades:WaitForChild(id)
	local function update()
		local level = value.Value
		title.Text = ("%s  (%d/%d)"):format(def.name, level, def.maxLevel)
		if level >= def.maxLevel then
			buy.Text = "Макс."
			buy.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		else
			local cost = def.costs[level + 1]
			buy.Text = "Купить: " .. cost
			buy.BackgroundColor3 = coins.Value >= cost and Color3.fromRGB(60, 160, 90)
				or Color3.fromRGB(110, 70, 70)
		end
	end
	value.Changed:Connect(update)
	coins.Changed:Connect(update)
	update()

	buy.Activated:Connect(function()
		Remotes.BuyUpgrade:FireServer(id)
	end)
end

Remotes.OpenShop.OnClientEvent:Connect(function()
	frame.Visible = true
end)

UIKit.limitWidth(frame, 420)
