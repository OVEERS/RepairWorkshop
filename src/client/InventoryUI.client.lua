local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("ItemsConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local partsFolder = player:WaitForChild("Parts")
local brokenFolder = player:WaitForChild("Broken")
local repairedFolder = player:WaitForChild("Repaired")

-- ===== Каркас UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "InventoryUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(260, 0)
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.AnchorPoint = Vector2.new(0, 0.5)
frame.Position = UDim2.new(0, 16, 0.5, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = frame

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = frame

local function makeLabel(text: string, order: number, color: Color3, bold: boolean?)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextSize = 16
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.LayoutOrder = order
	label.Parent = frame
	return label
end

local function makeRow(order: number)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundTransparency = 1
	row.AutoButtonColor = false
	row.Font = Enum.Font.Gotham
	row.TextSize = 16
	row.TextColor3 = Color3.fromRGB(230, 230, 235)
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = ""
	row.LayoutOrder = order
	row.Parent = frame
	return row
end

makeLabel("Мастерская", 0, Color3.fromRGB(255, 255, 255), true)
local emptyLabel = makeLabel("Пусто", 1, Color3.fromRGB(140, 140, 150))
local totalLabel = makeLabel("", 999, Color3.fromRGB(255, 214, 90), true)

-- ===== Подсчёт =====
local function recalcTotal()
	local total, count = 0, 0

	for _, value in partsFolder:GetChildren() do
		local info = Config.Parts[value.Name]
		if info and value.Value > 0 then
			total += info.price * value.Value
			count += 1
		end
	end
	for _, value in repairedFolder:GetChildren() do
		local info = Config.Items[value.Name]
		if info and value.Value > 0 then
			total += info.sellPrice * value.Value
			count += 1
		end
	end
	for _, value in brokenFolder:GetChildren() do
		if value.Value > 0 then
			count += 1
		end
	end

	emptyLabel.Visible = count == 0
	totalLabel.Visible = total > 0
	totalLabel.Text = "Можно продать на: " .. total
end

-- ===== Секции =====
local sections = {
	{
		folder = brokenFolder,
		title = "Сломано (клик: выбрать)",
		source = Config.Items,
		clickable = true,
	},
	{ folder = partsFolder, title = "Детали", source = Config.Parts },
	{ folder = repairedFolder, title = "Починено", source = Config.Items },
}

for index, def in sections do
	local header = makeLabel(def.title, index * 100, Color3.fromRGB(150, 160, 255), true)
	header.Visible = false

	local rows: { [string]: TextButton } = {}
	local nextOrder = index * 100 + 1

	local function refreshHeader()
		header.Visible = false
		for _, row in rows do
			if row.Visible then
				header.Visible = true
				return
			end
		end
	end

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
				row.MouseButton1Click:Connect(function()
					Remotes.SelectItem:FireServer(id)
				end)
			end
		end

		local function update()
			row.Visible = value.Value > 0
			local selected = def.clickable and player:GetAttribute("Selected") == value.Name
			row.Text = (selected and "▶ " or "") .. displayName .. "  x" .. value.Value
			row.TextColor3 = selected and Color3.fromRGB(255, 214, 90)
				or Color3.fromRGB(230, 230, 235)
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

recalcTotal()
