local mod = get_mod("scores")

-- Havoc missions carry a set of modifiers ("Elite HP increased by 25%") on top of
-- the rank. The rank alone was already captured; this turns the rest of the parsed
-- havoc payload into something storable and readable.
--
-- Everything here is defensive. The havoc payload is a packed string the game
-- parses positionally, and the settings tables these labels come from are engine
-- data that a patch can reshape without warning -- so every lookup degrades to a
-- readable fallback instead of erroring inside a view's draw path.

local HavocModifiers = {}

local function havoc_settings()
	local ok, settings = pcall(mod.original_require, mod, "scripts/settings/havoc_settings")
	return ok and settings or nil
end

local function template_list(settings, name)
	local templates = settings and settings.modifier_templates
	local positive = settings and settings.positive_modifier_templates
	return (templates and templates[name]) or (positive and positive[name]) or nil
end

local function ui_entry(settings, name)
	local ui = settings and settings.ui_settings and settings.ui_settings.modifiers
	return ui and ui[name] or nil
end

-- The per-level entry is a table of effect values keyed by effect name. Sorted so
-- a multi-value template ("%d Monstrosities ... HP increased by %d%%") fills its
-- placeholders in a stable order rather than whatever pairs() happens to give.
local function level_values(settings, name, level)
	local list = template_list(settings, name)
	local entry = type(list) == "table" and list[level] or nil
	if type(entry) ~= "table" then
		return nil
	end

	local keys = {}
	for key in pairs(entry) do
		keys[#keys + 1] = key
	end
	table.sort(keys)

	local values = {}
	for i = 1, #keys do
		local value = entry[keys[i]]
		if type(value) == "number" then
			-- Ratios are stored as fractions (0.25) and read as percentages; counts
			-- are already whole. Scaling only the fractions gets both right in the
			-- templates that mix them.
			values[i] = value < 1 and math.floor(value * 100 + 0.5) or value
		else
			values[i] = value
		end
	end

	return values
end

local function humanised(name, level)
	local words = string.gsub(tostring(name), "_", " ")
	words = string.gsub(words, "^%l", string.upper)
	if level and level > 1 then
		return words.." "..level
	end
	return words
end

-- A displayable line for one {name, level} modifier.
HavocModifiers.label = function(modifier)
	local name = type(modifier) == "table" and modifier.name
	if type(name) ~= "string" or name == "" then
		return nil
	end

	local level = tonumber(modifier.level) or 1
	local settings = havoc_settings()
	local ui = ui_entry(settings, name)
	local text = ui and ui.text
	local values = level_values(settings, name, level)

	if type(text) == "string" and values and #values > 0 then
		local ok, formatted = pcall(string.format, text, unpack(values))
		if ok and type(formatted) == "string" and formatted ~= "" then
			return formatted
		end
	end

	return humanised(name, level)
end

HavocModifiers.labels = function(modifiers)
	local labels = {}
	for i = 1, #(modifiers or {}) do
		local label = HavocModifiers.label(modifiers[i])
		if label then
			labels[#labels + 1] = label
		end
	end
	return labels
end

-- Serialised as `name.level`, joined with ":" -- the same shape the game's own
-- havoc payload uses, so it stays readable in a saved file.
HavocModifiers.encode = function(modifiers)
	local parts = {}
	for i = 1, #(modifiers or {}) do
		local modifier = modifiers[i]
		local name = type(modifier) == "table" and modifier.name
		if type(name) == "string" and name ~= "" and not string.find(name, "[:.;]") then
			parts[#parts + 1] = name.."."..tostring(tonumber(modifier.level) or 1)
		end
	end

	return #parts > 0 and table.concat(parts, ":") or nil
end

HavocModifiers.decode = function(encoded)
	if type(encoded) ~= "string" or encoded == "" or encoded == "nil" then
		return nil
	end

	local modifiers = {}
	for _, part in ipairs(string.split(encoded, ":")) do
		local split = string.split(part, ".")
		local name = split[1]
		if type(name) == "string" and name ~= "" then
			modifiers[#modifiers + 1] = {name = name, level = tonumber(split[2]) or 1}
		end
	end

	return #modifiers > 0 and modifiers or nil
end

return HavocModifiers
