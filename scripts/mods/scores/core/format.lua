local mod = get_mod("scores")

local UIFonts = mod:original_require("scripts/managers/ui/ui_fonts")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")

local string_format = string.format
local tonumber = tonumber

mod.shorten_value = function(self, value, decimals)
	value = tonumber(value) or 0
	if value >= 1000 then return string_format("%.1fK", value / 1000) end
	return string_format("%."..(decimals or 0).."f", value)
end

mod.shorten_time = function(self, time, decimals)
	time = tonumber(time) or 0
	if time >= 60 then return string_format("%.1f", time / 60).."m" end
	return string_format("%."..(decimals or 0).."f", time).."s"
end

mod.shrink_text = function(self, text, style, max_width, ui_renderer)
	if ui_renderer then
		local width = max_width + 10
		local fsize = (style.font_size or 20) + 1
		while width > max_width - 20 and fsize > 8 do
			fsize = fsize - 1
			style.font_size = fsize
			local font_type = style.font_type
			local scale = ui_renderer.scale or 1
			local scaled_font_size = UIFonts.scaled_size(fsize, scale)
			width = UIRenderer.text_size(ui_renderer, text, font_type, scaled_font_size)
		end
	end
end

return mod

