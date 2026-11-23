local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- один префикс "/a": остальное разбирает сервер, он же проверяет права
local command = Instance.new("TextChatCommand")
command.Name = "AdminCommand"
command.PrimaryAlias = "/a"
command.Triggered:Connect(function(_, text: string)
	Remotes.AdminCommand:FireServer(text)
end)
command.Parent = TextChatService
