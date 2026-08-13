local mod = get_mod("scores")

local Archetypes = mod:original_require("scripts/settings/archetype/archetypes")
local MasterItems = mod:original_require("scripts/backend/master_items")

local VERSION = 1
local MAX_DEPTH = 8
local MAX_NODES = 4096
local MAX_STRING_BYTES = 131072
local MAX_OVERRIDE_DEPTH = 6
local MAX_OVERRIDE_NODES = 512
local MAX_LOADOUT_SLOTS = 24
local MAX_ENCODED_BYTES = 700000
local MAX_DECODED_BYTES = 525000
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function encode_atom(tag, payload)
	return tag..#payload..":"..payload
end

local function serialize_value(value, depth, seen, budget)
	budget.nodes = budget.nodes + 1
	if budget.nodes > MAX_NODES then
		error("profile snapshot node limit exceeded")
	end

	local value_type = type(value)
	if value_type == "nil" then
		return encode_atom("n", "")
	elseif value_type == "boolean" then
		return encode_atom("b", value and "1" or "0")
	elseif value_type == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			error("profile snapshot contains a non-finite number")
		end
		return encode_atom("d", string.format("%.17g", value))
	elseif value_type == "string" then
		if #value > MAX_STRING_BYTES then
			error("profile snapshot string limit exceeded")
		end
		return encode_atom("s", value)
	elseif value_type ~= "table" then
		error("profile snapshot contains unsupported data")
	end

	if depth >= MAX_DEPTH then
		error("profile snapshot depth limit exceeded")
	end
	if seen[value] then
		error("profile snapshot contains a cycle")
	end

	seen[value] = true
	local keys = {}
	for key in pairs(value) do
		local key_type = type(key)
		if key_type == "string" or key_type == "number" then
			keys[#keys+1] = key
		end
	end
	table.sort(keys, function(a, b)
		return type(a) == type(b) and tostring(a) < tostring(b) or type(a) < type(b)
	end)

	local parts = {}
	for i = 1, #keys do
		local key = keys[i]
		local key_atom = type(key) == "string"
			and encode_atom("s", key)
			or encode_atom("d", string.format("%.17g", key))
		parts[#parts+1] = key_atom..serialize_value(value[key], depth + 1, seen, budget)
	end
	seen[value] = nil
	return encode_atom("t", table.concat(parts))
end

local function base64_encode(data)
	local result = {}
	for i = 1, #data, 3 do
		local b1 = string.byte(data, i) or 0
		local b2 = string.byte(data, i + 1)
		local b3 = string.byte(data, i + 2)
		local value = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
		result[#result+1] = string.sub(B64_CHARS, math.floor(value / 262144) % 64 + 1, math.floor(value / 262144) % 64 + 1)
		result[#result+1] = string.sub(B64_CHARS, math.floor(value / 4096) % 64 + 1, math.floor(value / 4096) % 64 + 1)
		result[#result+1] = b2 and string.sub(B64_CHARS, math.floor(value / 64) % 64 + 1, math.floor(value / 64) % 64 + 1) or "="
		result[#result+1] = b3 and string.sub(B64_CHARS, value % 64 + 1, value % 64 + 1) or "="
	end
	return table.concat(result)
end

local function base64_decode(data)
	if type(data) ~= "string" or #data == 0 or #data > MAX_ENCODED_BYTES or #data % 4 ~= 0 then
		return nil
	end

	local lookup = {}
	for i = 1, #B64_CHARS do
		lookup[string.sub(B64_CHARS, i, i)] = i - 1
	end

	local result = {}
	for i = 1, #data, 4 do
		local s1, s2 = string.sub(data, i, i), string.sub(data, i + 1, i + 1)
		local s3, s4 = string.sub(data, i + 2, i + 2), string.sub(data, i + 3, i + 3)
		local c1, c2, c3, c4 = lookup[s1], lookup[s2], lookup[s3], lookup[s4]
		if c1 == nil or c2 == nil or (s3 ~= "=" and c3 == nil) or (s4 ~= "=" and c4 == nil) then
			return nil
		end
		if (s3 == "=" and s4 ~= "=") or (i + 3 < #data and (s3 == "=" or s4 == "=")) then
			return nil
		end
		local value = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
		result[#result+1] = string.char(math.floor(value / 65536) % 256)
		if s3 ~= "=" then result[#result+1] = string.char(math.floor(value / 256) % 256) end
		if s4 ~= "=" then result[#result+1] = string.char(value % 256) end
	end
	local decoded = table.concat(result)
	return #decoded <= MAX_DECODED_BYTES and decoded or nil
end

local function parse_atom(source, position, depth, budget)
	budget.nodes = budget.nodes + 1
	if budget.nodes > MAX_NODES or depth > MAX_DEPTH or position > #source then
		error("invalid profile snapshot")
	end

	local tag = string.sub(source, position, position)
	local colon = string.find(source, ":", position + 1, true)
	if not colon then error("invalid profile snapshot atom") end
	local length_text = string.sub(source, position + 1, colon - 1)
	if not string.match(length_text, "^%d+$") then error("invalid profile snapshot length") end
	local length = tonumber(length_text)
	if not length or length > MAX_DECODED_BYTES then error("profile snapshot atom too large") end
	local payload_start = colon + 1
	local payload_end = payload_start + length - 1
	if payload_end > #source then error("truncated profile snapshot") end
	local next_position = payload_end + 1
	local payload = string.sub(source, payload_start, payload_end)

	if tag == "n" then
		if length ~= 0 then error("invalid nil atom") end
		return nil, next_position
	elseif tag == "b" then
		if payload ~= "0" and payload ~= "1" then error("invalid boolean atom") end
		return payload == "1", next_position
	elseif tag == "d" then
		local number = tonumber(payload)
		if not number then error("invalid number atom") end
		return number, next_position
	elseif tag == "s" then
		if length > MAX_STRING_BYTES then error("profile snapshot string too large") end
		return payload, next_position
	elseif tag ~= "t" then
		error("unknown profile snapshot atom")
	end

	local result = {}
	local inner_position = 1
	while inner_position <= #payload do
		local key, after_key = parse_atom(payload, inner_position, depth + 1, budget)
		local value, after_value = parse_atom(payload, after_key, depth + 1, budget)
		if type(key) ~= "string" and type(key) ~= "number" then error("invalid profile snapshot key") end
		result[key] = value
		inner_position = after_value
	end
	return result, next_position
end

local function primitive_value(value)
	local value_type = type(value)
	if value_type == "string" then
		return #value <= MAX_STRING_BYTES and value or nil
	elseif value_type == "number" then
		return value == value and value ~= math.huge and value ~= -math.huge and value or nil
	elseif value_type == "boolean" then
		return value
	end
	return nil
end

local function sanitized_table(value, depth, seen, budget)
	if type(value) ~= "table" or depth > MAX_OVERRIDE_DEPTH or seen[value] then
		return nil
	end

	seen[value] = true
	local result = {}
	local count = 0
	for key, child in pairs(value) do
		budget.nodes = budget.nodes + 1
		if budget.nodes > MAX_OVERRIDE_NODES then
			break
		end

		local safe_key = primitive_value(key)
		if safe_key ~= nil and (type(safe_key) == "string" or type(safe_key) == "number") then
			local safe_value = primitive_value(child)
			if safe_value == nil and type(child) == "table" then
				safe_value = sanitized_table(child, depth + 1, seen, budget)
			end
			if safe_value ~= nil then
				result[safe_key] = safe_value
				count = count + 1
			end
		end
	end
	seen[value] = nil

	return count > 0 and result or nil
end

local function sanitized_overrides(overrides)
	return sanitized_table(overrides, 1, {}, {nodes = 0})
end

local function is_inspection_loadout_slot(slot_name)
	if slot_name == "slot_primary" or slot_name == "slot_secondary" then
		return true
	end
	if type(slot_name) ~= "string" then
		return false
	end
	return string.sub(slot_name, 1, 15) == "slot_attachment"
		or string.sub(slot_name, 1, 10) == "slot_body_"
		or string.sub(slot_name, 1, 10) == "slot_gear_"
end

local function loadout_item_snapshot(item_data, gear_id)
	if type(item_data) ~= "table" then
		return nil, nil
	end

	local item_id = type(item_data.id) == "string" and item_data.id or nil
	if not item_id then
		local master_data = type(item_data.masterDataInstance) == "table" and item_data.masterDataInstance or nil
		item_id = master_data and type(master_data.id) == "string" and master_data.id or nil
		item_data = master_data or item_data
	end
	if not item_id then return nil, nil end

	local safe_gear_id = primitive_value(gear_id or item_data.gear_id or item_data.id)
	local overrides = sanitized_overrides(item_data.overrides)
	return {
		id = item_id,
		overrides = overrides,
	}, safe_gear_id or item_id
end

local function snapshot_profile(profile)
	local archetype = profile.archetype
	local snapshot = {
		version = VERSION,
		name = primitive_value(profile.name),
		character_id = primitive_value(profile.character_id),
		current_level = primitive_value(profile.current_level),
		archetype_name = type(archetype) == "table" and primitive_value(archetype.name) or nil,
		gender = primitive_value(profile.gender),
		height = primitive_value(profile.height),
		selected_voice = primitive_value(profile.selected_voice),
		selected_personality = primitive_value(profile.selected_personality),
		selected_nodes = sanitized_table(profile.selected_nodes, 1, {}, {nodes = 0}),
		talents = sanitized_table(profile.talents, 1, {}, {nodes = 0}),
		talent_points = primitive_value(profile.talent_points),
		expertise_points = primitive_value(profile.expertise_points),
		loadout_item_ids = {},
		loadout_item_data = {},
	}

	local ids = {}
	local data = {}
	for slot_name, gear_id in pairs(type(profile.loadout_item_ids) == "table" and profile.loadout_item_ids or {}) do
		if is_inspection_loadout_slot(slot_name) then
			local safe_gear_id = primitive_value(gear_id)
			if safe_gear_id ~= nil then
				ids[slot_name] = safe_gear_id
			end
		end
	end
	for slot_name, item_data in pairs(type(profile.loadout_item_data) == "table" and profile.loadout_item_data or {}) do
		if is_inspection_loadout_slot(slot_name) then
			local item_snapshot, gear_id = loadout_item_snapshot(item_data, ids[slot_name])
			if item_snapshot then
				data[slot_name] = item_snapshot
				ids[slot_name] = ids[slot_name] or gear_id
			end
		end
	end
	for slot_name, item in pairs(type(profile.loadout) == "table" and profile.loadout or {}) do
		if is_inspection_loadout_slot(slot_name) then
			local master_data = type(item) == "table" and item.masterDataInstance
			local item_snapshot, gear_id = loadout_item_snapshot(master_data, item.gear_id or item.id)
			if item_snapshot then
				ids[slot_name] = ids[slot_name] or gear_id
				data[slot_name] = data[slot_name] or item_snapshot
			end
		end
	end

	local slot_names = {}
	for slot_name in pairs(data) do
		slot_names[#slot_names+1] = slot_name
	end
	table.sort(slot_names)

	for i = 1, math.min(#slot_names, MAX_LOADOUT_SLOTS) do
		local slot_name = slot_names[i]
		snapshot.loadout_item_ids[slot_name] = ids[slot_name] or data[slot_name].id
		snapshot.loadout_item_data[slot_name] = data[slot_name]
	end
	return snapshot
end

local function reconstruct_loadout(profile)
	local ids = profile.loadout_item_ids
	local data = profile.loadout_item_data
	if type(ids) ~= "table" or type(data) ~= "table" then return nil end

	local loadout = {}
	for slot_name, gear_id in pairs(ids) do
		local item_data = data[slot_name]
		if type(slot_name) == "string" and type(item_data) == "table" and type(item_data.id) == "string" then
			local gear = {
				masterDataInstance = {id = item_data.id, overrides = item_data.overrides},
				slots = {slot_name},
			}
			local ok, item = false, nil
			if MasterItems.get_item_instance then
				ok, item = pcall(MasterItems.get_item_instance, gear, gear_id)
			end
			if (not ok or not item) and MasterItems.item_plus_overrides then
				ok, item = pcall(MasterItems.item_plus_overrides, gear, gear_id)
			end
			if ok and item then loadout[slot_name] = item end
		end
	end
	return next(loadout) and loadout or nil
end

local Snapshot = {}

Snapshot.encode = function(profile)
	if type(profile) ~= "table" then return nil end
	local snapshot_ok, snapshot = pcall(snapshot_profile, profile)
	if not snapshot_ok then return nil end
	local ok, serialized = pcall(serialize_value, snapshot, 0, {}, {nodes = 0})
	if not ok then return nil end
	local encoded = base64_encode(serialized)
	return #encoded <= MAX_ENCODED_BYTES and encoded or nil
end

Snapshot.decode = function(encoded)
	local decoded = base64_decode(encoded)
	if not decoded then return nil end
	local ok, profile, next_position = pcall(parse_atom, decoded, 1, 0, {nodes = 0})
	if not ok or type(profile) ~= "table" or next_position ~= #decoded + 1 or profile.version ~= VERSION then
		return nil
	end
	profile.version = nil
	-- Inventory builder views read these profile fields directly. Early v1
	-- snapshots did not persist all of them, so retain v1 compatibility with
	-- read-only-safe defaults.
	profile.current_level = tonumber(profile.current_level) or 30
	profile.talent_points = tonumber(profile.talent_points) or 0
	profile.expertise_points = tonumber(profile.expertise_points) or 0
	profile.character_id = profile.character_id or "scoreboard_history"
	profile.selected_nodes = type(profile.selected_nodes) == "table" and profile.selected_nodes or {}
	profile.lore = type(profile.lore) == "table" and profile.lore or {backstory = {}}
	profile.lore.backstory = type(profile.lore.backstory) == "table" and profile.lore.backstory or {}
	profile.archetype = profile.archetype_name and Archetypes[profile.archetype_name] or nil
	profile.archetype_name = nil
	profile.loadout = reconstruct_loadout(profile)
	return profile
end

Snapshot.version = VERSION
Snapshot.max_encoded_bytes = MAX_ENCODED_BYTES

return Snapshot
