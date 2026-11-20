local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("ItemsConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local new, T = UIKit.new, UIKit.Theme

local player = Players.LocalPlayer
local partsFolder = player:WaitForChild("Parts")
local brokenFolder = player:WaitForChild("Broken")
local repairedFolder = player:WaitForChild("Repaired")
local capacityLevel = player:WaitForChild("Upgrades"):WaitForChild("Capacity")

local ROW_HEIGHT = UIKit.isTouch() and 32 or 22

-- ===== Каркас =====
local gui = new(
	"ScreenGui",
	{ Name = "InventoryUI", ResetOnSpawn = false },
	player:WaitForChild("PlayerGui")
)

local frame = new("Frame", {
	Size = UDim2.fromScale(0.5, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	BackgroundColor3 = T.Bg,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
}, gui)
UIKit.round(frame, 10)
UIKit.pad(frame, 8, 12)
new("UISizeConstraint", { MaxSize = Vector2.new(300, math.huge) }, frame)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, frame)

local toggle = new("TextButton", {
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = T.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 0,
}, frame)

local body = new("Frame", {
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 1,
}, frame)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, body)

local function setOpen(open: boolean)
	body.Visible = open
	toggle.Text = (open and "- " or "+ ") .. "Мастерская"
end
toggle.Activated:Connect(function()
	setOpen(not body.Visible)
end)
setOpen(not UIKit.isTouch()) -- на телефоне по умолчанию свёрнуто

local function makeLabel(text: string, order: number, color: Color3, bold: boolean?)
	return new("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = color,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		LayoutOrder = order,
	}, body)
end

local function makeRow(order: number)
	return new("TextButton", {
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		LayoutOrder = order,
	}, body)
end

local emptyLabel =
	makeLabel("Пусто. Начни со станции приёма", 1, T.TextDim)
local totalLabel = makeLabel("", 999, T.Gold, true)

-- ===== Подсчёты =====
local function sumFolder(folder: Folder): number
	local n = 0
	for _, value in folder:GetChildren() do
		if value:IsA("IntValue") then
			n += value.Value
		end
	end
	return n
end

local function capacity(): number
	return Config.CapacityFor(capacityLevel.Value)
end

local function recalcTotal()
	local total, count = 0, 0

	for _, value in partsFolder:GetChildren() do
		local info = Config.Parts[value.Name]
		if info and value:IsA("IntValue") and value.Value > 0 then
			total += info.price * value.Value
			count += 1
		end
	end
	for _, value in repairedFolder:GetChildren() do
		local info = Config.Items[value.Name]
		if info and value:IsA("IntValue") and value.Value > 0 then
			total += info.sellPrice * value.Value
			count += 1
		end
	end
	count += sumFolder(brokenFolder) > 0 and 1 or 0

	emptyLabel.Visible = count == 0
	totalLabel.Visible = total > 0
	totalLabel.Text = "Можно продать на: " .. total
end

-- ===== Секции =====
type Section = {
	folder: Folder,
	source: any,
	clickable: boolean?,
	alwaysShow: boolean?,
	title: () -> string,
	isFull: (() -> boolean)?,
	refresh: (() -> ())?,
}

local sections: { Section } = {
	{
		folder = brokenFolder,
		source = Config.Items,
		clickable = true,
		alwaysShow = true,
		title = function()
			return ("Сломано %d/%d  (клик: выбрать)"):format(
				sumFolder(brokenFolder),
				capacity()
			)
		end,
		isFull = function()
			return sumFolder(brokenFolder) >= capacity()
		end,
	},
	{
		folder = partsFolder,
		source = Config.Parts,
		title = function()
			return "Детали"
		end,
	},
	{
		folder = repairedFolder,
		source = Config.Items,
		title = function()
			return "Починено"
		end,
	},
}

for index, def in sections do
	local header = makeLabel("", index * 100, T.Accent, true)
	local rows: { [string]: TextButton } = {}
	local nextOrder = index * 100 + 1

	local function refreshHeader()
		local any = false
		for _, row in rows do
			if row.Visible then
				any = true
				break
			end
		end
		header.Visible = any or def.alwaysShow == true
		header.Text = def.title()
		header.TextColor3 = if def.isFull and def.isFull() then T.Bad else T.Accent
	end
	def.refresh = refreshHeader

	local function track(value: IntValue)
		local info = def.source[value.Name]
		local displayName = info and info.name or value.Name

		local row = rows[value.Name]
		if not row then
			row = makeRow(nextOrder)
			nextOrder += 1
			rows[value.Name] = row

			if def.clickable then
				local id = value.Name
				row.Activated:Connect(function()
					Remotes.SelectItem:FireServer(id)
				end)
			end
		end

		local function update()
			row.Visible = value.Value > 0
			local selected = def.clickable and player:GetAttribute("Selected") == value.Name
			row.Text = (selected and "> " or "") .. displayName .. "  x" .. value.Value
			row.TextColor3 = selected and T.Gold or T.Text
			refreshHeader()
			recalcTotal()
		end

		value.Changed:Connect(update)
		if def.clickable then
			player:GetAttributeChangedSignal("Selected"):Connect(update)
		end
		update()
	end

	def.folder.ChildAdded:Connect(function(child)
		if child:IsA("IntValue") then
			track(child)
		end
	end)
	for _, child in def.folder:GetChildren() do
		if child:IsA("IntValue") then
			track(child)
		end
	end
end

local function refreshAll()
	for _, def in sections do
		if def.refresh then
			def.refresh()
		end
	end
	recalcTotal()
end

capacityLevel.Changed:Connect(refreshAll)
refreshAll()
