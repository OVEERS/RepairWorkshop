local PlotUtil = {}

-- UserId владельца плота, внутри которого лежит объект (nil: объект общий)
function PlotUtil.ownerOf(inst: Instance): number?
	local node: Instance? = inst
	while node and node ~= workspace do
		local id = node:GetAttribute("OwnerUserId")
		if type(id) == "number" then
			return id
		end
		node = node.Parent
	end
	return nil
end

return PlotUtil
