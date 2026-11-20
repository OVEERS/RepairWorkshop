local Log = {}

-- выполняет fn, и если она упала, пишет ошибку со стеком и контекстом
function Log.run(context: string, fn: (...any) -> ...any, ...: any): boolean
	local ok, err = xpcall(fn, function(e)
		return debug.traceback(tostring(e), 2)
	end, ...)
	if not ok then
		warn(("[%s] %s"):format(context, tostring(err)))
	end
	return ok
end

return Log
