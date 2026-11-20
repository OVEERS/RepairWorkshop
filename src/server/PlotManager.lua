local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local SLOT_COUNT = 12
local RADIUS = 110 -- от центра площади до центра плота

local template = ServerStorage:FindFirstChild("WorkshopTemplate")
assert(
	template and template:IsA("Model"),
	"PlotManager: ServerStorage.WorkshopTemplate должна быть Model (создай шаблон через Command Bar)"
)

local originPart = workspace:FindFirstChild("PlotsOrigin")
local center = if originPart and originPart:IsA("BasePart")
	then originPart.Position
	else Vector3.zero

type Plot = { slot: number, cframe: CFrame, owner: Player?, model: Model? }

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

-- слоты по кругу, лицом (-Z) к центру площади
for i = 1, SLOT_COUNT do
	local angle = (i - 1) / SLOT_COUNT * math.pi * 2
	local pos = center + Vector3.new(math.cos(angle) * RADIUS, 0, math.sin(angle) * RADIUS)
	plots[i] = { slot = i, cframe = CFrame.lookAt(pos, center), owner = nil, model = nil }
end

local PlotManager = {}

local function teleport(player: Player, plot: Plot)
	local character = player.Character
	local model = plot.model
	if not character or not model then
		return
	end
	local spawnPart = model:FindFirstChild("Spawn")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return
	end
	if character:WaitForChild("HumanoidRootPart", 5) then
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
	end
end

-- выдаёт игроку свободный плот; false, если свободных нет
function PlotManager.Claim(player: Player): boolean
	if byPlayer[player] then
		return true
	end
	for _, plot in plots do
		if plot.owner == nil then
			local model = template:Clone()
			model.Name = "Plot_" .. plot.slot
			-- атрибуты ставим ДО Parent: к моменту появления станций владелец уже известен
			model:SetAttribute("OwnerUserId", player.UserId)
			model:SetAttribute("Slot", plot.slot)
			model:PivotTo(plot.cframe)
			model.Parent = workspace

			plot.owner, plot.model = player, model
			byPlayer[player] = plot
			player:SetAttribute("PlotSlot", plot.slot)

			player.CharacterAdded:Connect(function()
				teleport(player, plot)
			end)
			task.spawn(teleport, player, plot)
			return true
		end
	end
	return false
end

function PlotManager.Release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.owner = nil
	if plot.model then
		plot.model:Destroy()
		plot.model = nil
	end
end

function PlotManager.Get(player: Player): Plot?
	return byPlayer[player]
end

Players.PlayerRemoving:Connect(PlotManager.Release)

return PlotManager
