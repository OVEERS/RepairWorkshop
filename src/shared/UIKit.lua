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

return UIKit
