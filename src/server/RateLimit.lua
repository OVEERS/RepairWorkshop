local RateLimit = {}

local last: { [Player]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

-- true, если действие разрешено; false, если игрок шлёт запросы слишком часто
function RateLimit.allow(player: Player, key: string, interval: number): boolean
	local t = os.clock()
	local bucket = last[player]
	if not bucket then
		bucket = {}
		last[player] = bucket
	end

	local prev = bucket[key]
	if prev and t - prev < interval then
		return false
	end
	bucket[key] = t
	return true
end

return RateLimit
