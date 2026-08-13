local mod = get_mod("scores")

local CLASS = CLASS

local function install_history_chat_hook()
	local function has_method(class, method_name)
		return type(method_name) == "string" and type(class[method_name]) == "function"
	end

	local function hook_chat_class(chat_class, flag_name)
		if mod[flag_name] or not chat_class then
			return false
		end

		local hooked = false
		local function hook_chat_method(method_name)
			if not has_method(chat_class, method_name) then
				return
			end

			mod:hook(chat_class, method_name, function(func, self, ...)
				if mod:scoreboard_history_opened() then
					return
				end
				if func then
					return func(self, ...)
				end
			end)
			hooked = true
		end

		hook_chat_method("draw")
		hook_chat_method("_draw_widgets")
		hook_chat_method("_draw_elements")
		mod[flag_name] = hooked
		return hooked
	end

	local hooked = hook_chat_class(CLASS.ConstantElementChat, "_history_constant_chat_hooked")
	hooked = hook_chat_class(CLASS.HudElementChat, "_history_hud_chat_hooked") or hooked
	return hooked
end

local function install_history_chat_input_hook()
	if mod._history_chat_input_hooked or not CLASS.ConstantElementChat then
		return false
	end

	local chat_class = CLASS.ConstantElementChat
	local function hook_input_method(method_name)
		if type(method_name) ~= "string" or type(chat_class[method_name]) ~= "function" then
			return false
		end

		mod:hook(chat_class, method_name, function(func, self, ...)
			if mod:scoreboard_history_opened() then
				return
			end
			if func then
				return func(self, ...)
			end
		end)
		return true
	end

	mod._history_chat_input_hooked = hook_input_method("_handle_input")
		or hook_input_method("_handle_active_chat_input")
	return mod._history_chat_input_hooked
end

install_history_chat_hook()
install_history_chat_input_hook()

mod:hook_require("scripts/ui/constant_elements/elements/chat/constant_element_chat", function()
	install_history_chat_hook()
	install_history_chat_input_hook()
end)

mod:hook_require("scripts/ui/hud/elements/chat/hud_element_chat", function()
	install_history_chat_hook()
end)

return mod
