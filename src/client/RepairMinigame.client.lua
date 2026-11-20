local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage:WaitForChild("ItemsConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local upgrades = player:WaitForChild("Upgrades")

local WHITE = Color3.fromRGB(255, 255, 255)
local GREEN = Color3.fromRGB(80, 200, 120)
local RED = Color3.fromRGB(220, 80, 80)
local ROUNDS = 3

local function new(class: string, props: { [string]: any }, parent: Instance?)
	local inst: any = Instance.new(class)
	for key, value in props do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

-- ===== UI =====
local gui = new(
	"ScreenGui",
	{ Name = "RepairMinigame", ResetOnSpawn = false },
	player:WaitForChild("PlayerGui")
)

local frame = new("Frame", {
	Size = UDim2.fromOffset(440, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -40),
	BackgroundColor3 = Color3.fromRGB(30, 30, 36),
	BorderSizePixel = 0,
	Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
new("UIPadding", {
	PaddingTop = UDim.new(0, 12),
	PaddingBottom = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 14),
	PaddingRight = UDim.new(0, 14),
}, frame)
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 10),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, frame)

local title = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	LayoutOrder = 0,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = WHITE,
}, frame)
local info = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	LayoutOrder = 1,
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(150, 150, 160),
}, frame)

local bar = new("Frame", {
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundColor3 = Color3.fromRGB(55, 55, 66),
	BorderSizePixel = 0,
	LayoutOrder = 2,
}, frame)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, bar)

local zone = new("Frame", { BackgroundColor3 = GREEN, BorderSizePixel = 0 }, bar)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, zone)
local marker = new("Frame", {
	Size = UDim2.new(0, 6, 1.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 2,
}, bar)

local action = new("TextButton", {
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundColor3 = Color3.fromRGB(60, 120, 200),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = WHITE,
	Text = "Жми!  (Пробел)",
	LayoutOrder = 3,
}, frame)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, action)

local cancel = new("TextButton", {
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	LayoutOrder = 4,
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(150, 150, 160),
	Text = "Отмена",
}, frame)

-- ===== Логика =====
local pressed = Instance.new("BindableEvent")
local active, cancelled = false, false

action.Activated:Connect(function()
	if active then
		pressed:Fire()
	end
end)
cancel.Activated:Connect(function()
	if active then
		cancelled = true
		pressed:Fire()
	end
end)

local function onSpace(_, state)
	if state == Enum.UserInputState.Begin and active then
		pressed:Fire()
	end
	return Enum.ContextActionResult.Sink -- чтобы пробел не прыгал персонажем
end

local function play(itemId: string)
	if active then
		return
	end
	active, cancelled = true, false

	local item = Config.Items[itemId]
	title.Text = "Ремонт: " .. (item and item.name or itemId)
	frame.Visible = true
	ContextActionService:BindActionAtPriority(
		"RepairPress",
		onSpace,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space
	)

	local zoneWidth = math.min(0.18 + 0.02 * upgrades.Speed.Value, 0.3)
	local hits = 0

	for round = 1, ROUNDS do
		local zoneStart = 0.05 + math.random() * (0.9 - zoneWidth)
		zone.Position = UDim2.fromScale(zoneStart, 0)
		zone.Size = UDim2.fromScale(zoneWidth, 1)
		zone.BackgroundColor3 = GREEN
		info.Text = ("Раунд %d/%d  ·  попаданий: %d"):format(round, ROUNDS, hits)

		local speed = 0.8 + 0.3 * round -- проходов по шкале в секунду
		local t0 = os.clock()
		local pos = 0
		local conn = RunService.RenderStepped:Connect(function()
			local phase = ((os.clock() - t0) * speed) % 2
			pos = if phase < 1 then phase else 2 - phase
			marker.Position = UDim2.fromScale(pos, 0.5)
		end)

		pressed.Event:Wait()
		conn:Disconnect()
		if cancelled then
			break
		end

		if pos >= zoneStart and pos <= zoneStart + zoneWidth then
			hits += 1
			zone.BackgroundColor3 = WHITE
		else
			zone.BackgroundColor3 = RED
		end
		task.wait(0.4)
		if cancelled then
			break
		end
	end

	ContextActionService:UnbindAction("RepairPress")
	frame.Visible = false
	active = false
	Remotes.RepairResult:FireServer(cancelled and -1 or hits)
end

Remotes.StartRepair.OnClientEvent:Connect(play)

UIKit.limitWidth(frame, 440)
