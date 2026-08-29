local mod = get_mod("scores")

-- The modifiers players actually talk about -- Blight Spreads, Rotten Armour,
-- Ventilation Purge -- are the mission's *circumstances*, not the havoc rank
-- scaling modifiers. A mission carries at most a handful, so they fit on the
-- history entry line rather than needing a board section.
--
-- Two sources feed the same list. A normal mission has a single
-- `mechanism_data.circumstance_name`; a havoc mission stacks several, packed into
-- field 5 of its havoc payload, which `Havoc.parse_data` already splits out as
-- `circumstances`.
--
-- Every lookup degrades to a readable fallback: these templates are engine data a
-- patch can reshape, and this resolves inside a view's draw path.

local Circumstances = {}

-- Present on every havoc mission and not a modifier anyone means -- it is the
-- "this is the hardest difficulty" marker the mission board uses.
local ignored = {
	-- "The Emperor's Fading light (I)" and "(II)". Every havoc mission carries one
	-- of the two and which one follows from the rank, so listing them says nothing
	-- a reader cannot already see next to it.
	mutator_increased_difficulty = true,
	mutator_highest_difficulty = true,
	default = true,
	nil_ = true,
}

local function templates()
	local ok, loaded = pcall(mod.original_require, mod, "scripts/settings/circumstance/circumstance_templates")
	return ok and loaded or nil
end

local function is_usable(name)
	return type(name) == "string"
		and name ~= ""
		and name ~= "nil"
		and not ignored[name]
		-- Circumstance names are plain identifiers -- circ_exp_rotten_armor,
		-- darkness_01. A dot means this is a havoc scaling modifier from the
		-- `name.level` payload that briefly occupied the same field, so it is not
		-- ours to display. Rejecting it here keeps those older entries from
		-- rendering "Reduce toughness.4" as if it were a circumstance.
		and not string.find(name, ".", 1, true)
end

local function humanised(name)
	local words = string.gsub(tostring(name), "_", " ")
	return (string.gsub(words, "^%l", string.upper))
end

-- Display name for one circumstance, localized. Falls back to the raw name so an
-- unknown circumstance still reads as something rather than vanishing.
Circumstances.label = function(name)
	if not is_usable(name) then
		return nil
	end

	local template = templates()
	template = type(template) == "table" and template[name] or nil
	local key = template and template.ui and template.ui.display_name

	if type(key) == "string" and rawget(_G, "Localize") then
		local ok, localized = pcall(Localize, key)
		if ok and type(localized) == "string" and localized ~= "" and localized ~= key then
			return localized
		end
	end

	return humanised(name)
end

Circumstances.labels = function(names)
	local labels = {}
	for i = 1, #(names or {}) do
		local label = Circumstances.label(names[i])
		if label then
			labels[#labels + 1] = label
		end
	end
	return labels
end

-- Merge the single-circumstance field and the havoc list into one deduped set,
-- keeping declaration order so the same mission always reads the same way.
Circumstances.merge = function(...)
	local seen = {}
	local names = {}

	for i = 1, select("#", ...) do
		local source = select(i, ...)
		if type(source) == "string" then
			source = {source}
		end
		for j = 1, #(type(source) == "table" and source or {}) do
			local name = source[j]
			if is_usable(name) and not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
	end

	return #names > 0 and names or nil
end

-- Stored as the bare names joined with ":", matching the shape the game's own
-- havoc payload uses, so a saved file stays readable.
Circumstances.encode = function(names)
	local parts = {}
	for i = 1, #(names or {}) do
		local name = names[i]
		if is_usable(name) and not string.find(name, "[:;]") then
			parts[#parts + 1] = name
		end
	end

	return #parts > 0 and table.concat(parts, ":") or nil
end

Circumstances.decode = function(encoded)
	if type(encoded) ~= "string" or encoded == "" or encoded == "nil" then
		return nil
	end

	local names = {}
	for _, name in ipairs(string.split(encoded, ":")) do
		if is_usable(name) then
			names[#names + 1] = name
		end
	end

	return #names > 0 and names or nil
end

return Circumstances
