local mod = get_mod("scores")

mod.tracking_hooks = mod.tracking_hooks or {}

local function report_error(hook, err)
	if mod.error then
		mod:error(string.format(
			"Tracking hook failed: %s.%s: %s",
			tostring(hook.name or hook.class),
			tostring(hook.method),
			tostring(err)
		))
	end
end

mod.register_tracking_hook = function(self, hook)
	if not hook or not hook.class or not hook.method or not hook.handler then
		error("tracking hook requires class, method, and handler")
	end

	self.tracking_hooks[#self.tracking_hooks + 1] = hook
	if hook.hot_path then
		-- High-frequency events such as attack results must not allocate return
		-- tables for every invocation. These handlers run before the original and
		-- the direct tail call preserves all original return values.
		self:hook(hook.class, hook.method, function(func, ...)
			local ok, err = pcall(hook.handler, ...)
			if not ok then
				report_error(hook, err)
			end
			if func then
				return func(...)
			end
		end)
		return
	end

	self:hook(hook.class, hook.method, function(func, ...)
		local result = {}

		if hook.call_order == "after" then
			if func then result = {func(...)} end
			local ok, err = pcall(hook.handler, ...)
			if not ok then
				report_error(hook, err)
			end
		else
			local ok, err = pcall(hook.handler, ...)
			if not ok then
				report_error(hook, err)
			end
			if func then result = {func(...)} end
		end

		return unpack(result)
	end)
end

return mod

