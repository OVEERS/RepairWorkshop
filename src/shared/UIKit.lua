local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UIKit = {}

UIKit.Theme = {
	Bg = Color3.fromRGB(30, 30, 36),
	Card = Color3.fromRGB(44, 44, 54),
	Button = Color3.fromRGB(70, 70, 80),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(150, 150, 160),
	Gold = Color3.fromRGB(255, 214, 90),
	Accent = Color3.fromRGB(150, 160, 255),
	Good = Color3.fromRGB(60, 160, 90),
	Bad = Color3.fromRGB(220, 80, 80),
}

function UIKit.new(class: string, props: { [string]: any }, parent: Instance?): any
	local inst: any = Instance.new(class)
	for key, value in props do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

function UIKit.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UIKit.round(parent: Instance, radius: number?): any
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

function UIKit.pad(parent: Instance, vertical: number, horizontal: number): any
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, vertical),
		PaddingBottom = UDim.new(0, vertical),
		PaddingLeft = UDim.new(0, horizontal),
		PaddingRight = UDim.new(0, horizontal),
	}, parent)
end

-- окно занимает 92% ширины экрана, но не шире maxWidth (чтобы влезало на телефон)
function UIKit.limitWidth(frame: GuiObject, maxWidth: number)
	frame.Size = UDim2.new(0.92, 0, frame.Size.Y.Scale, frame.Size.Y.Offset)
	local constraint = frame:FindFirstChildOfClass("UISizeConstraint")
	if not constraint then
		constraint = Instance.new("UISizeConstraint")
		constraint.Parent = frame
	end
	constraint.MaxSize = Vector2.new(maxWidth, math.huge)
end

-- Готовое модальное окно: рамка + шапка с крестиком.
-- Содержимое добавляй в w.frame с LayoutOrder >= 1.
function UIKit.window(name: string, title: string, maxWidth: number)
	local T = UIKit.Theme
	local player = Players.LocalPlayer
	local touch = UIKit.isTouch()

	local gui = UIKit.new(
		"ScreenGui",
		{ Name = name, ResetOnSpawn = false },
		player:WaitForChild("PlayerGui")
	)

	local frame = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.92, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	UIKit.round(frame, 12)
	UIKit.pad(frame, 12, 12)
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(maxWidth, math.huge) }, frame)
	UIKit.new(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) },
		frame
	)

	local buttonSize = touch and 44 or 28
	local header = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, buttonSize),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
	}, frame)
	UIKit.new("TextLabel", {
		Size = UDim2.new(1, -(buttonSize + 8), 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	}, header)
	local close = UIKit.new("TextButton", {
		Size = UDim2.fromOffset(buttonSize, buttonSize),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundColor3 = T.Button,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = T.Text,
		Text = "X",
	}, header)
	UIKit.round(close, 6)

	local window = { gui = gui, frame = frame }

	function window.show()
		frame.Visible = true
	end
	function window.hide()
		frame.Visible = false
	end
	close.Activated:Connect(window.hide)

	return window
end

return UIKit
