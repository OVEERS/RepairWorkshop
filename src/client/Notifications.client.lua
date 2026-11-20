local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local T = UIKit.Theme

local gui = UIKit.new(
	"ScreenGui",
	{ Name = "Notifications", ResetOnSpawn = false },
	player:WaitForChild("PlayerGui")
)

local label = UIKit.new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 24),
	Size = UDim2.fromScale(0.9, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = T.Card,
	BorderSizePixel = 0,
	Font = Enum.Font.Gotham,
	TextSize = 16,
	TextColor3 = T.Text,
	TextWrapped = true,
	Visible = false,
}, gui)
UIKit.round(label, 8)
UIKit.pad(label, 10, 14)
UIKit.limitWidth(label, 480)

local notificationId = 0

Remotes.Notify.OnClientEvent:Connect(function(message)
	if typeof(message) ~= "string" then
		return
	end

	notificationId += 1
	local currentId = notificationId
	label.Text = message
	label.Visible = true

	task.delay(4, function()
		if notificationId == currentId then
			label.Visible = false
		end
	end)
end)
