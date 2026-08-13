local rows = {}

local function add(name, text, options)
	options = options or {}
	rows[#rows + 1] = {
		name = name,
		text = text or name,
		validation = options.validation or "ASC",
		iteration = options.iteration or "ADD",
		summary = options.summary,
		setting = options.setting,
		visible = options.visible,
		group = options.group,
		update = options.update,
		normalize = options.normalize,
		is_time = options.is_time,
		is_text = options.is_text,
		parent = options.parent,
		big = options.big,
		icon = options.icon,
		icon_package = options.icon_package,
		icon_width = options.icon_width,
		decimals = options.decimals,
		suffix = options.suffix,
	}
end

local function hidden(name, text, setting, group)
	add(name, text or name, {
		setting = setting,
		group = group,
		visible = false,
	})
end

local function add_hidden_rows(names, setting, group, labels)
	for i = 1, #names do
		hidden(names[i], labels and labels[names[i]] or names[i], setting, group)
	end
end

local plasteel = {"small_plasteel", "large_plasteel"}
local diamantine = {"small_diamantine", "large_diamantine"}
add("resources_collected", "row_resources_collected", {
	summary = {"small_plasteel", "large_plasteel", "small_diamantine", "large_diamantine"},
	setting = "show_resources_collected",
})
add_hidden_rows(plasteel, "plugin_resources")
add("plasteel", "row_plasteel", {summary = plasteel, setting = "show_resources_collected"})
add_hidden_rows(diamantine, "plugin_resources")
add("diamantine", "row_diamantine", {summary = diamantine, setting = "show_resources_collected"})

add("operated", "row_operated", {
	summary = {"machinery_operated", "gadget_operated"},
})
hidden("machinery_operated", "row_machinery_operated", "plugin_machinery_gadget_operated")
hidden("gadget_operated", "row_gadget_operated", "plugin_machinery_gadget_operated")

add("revived_rescued", "row_rescues", {
	summary = {"revived_operative", "rescued_operative"},
	setting = "show_revived_rescued",
})
hidden("revived_operative", "row_revived_operative", "plugin_revived_rescued")
hidden("rescued_operative", "row_rescued_operative", "plugin_revived_rescued")
add("team_saves", "row_team_saves", {
	setting = "show_team_saves",
})

add("ammo_collected", "row_ammo_collected", {
	validation = "ASC",
	setting = "show_ammo_collected",
})
hidden("ammo_score_actual", "row_ammo_picked_up")
hidden("ammo_score_nominal", "row_ammo_picked_up")
hidden("ammo_small_picked_up", "row_ammo_small_picked_up")
hidden("ammo_large_picked_up", "row_ammo_large_picked_up")
hidden("ammo_crate_picked_up", "row_ammo_crate_picked_up")

add("damage_taken", "row_damage_taken", {
	validation = "LOWEST",
	iteration = "DIFF",
})
add("times_downed", "row_times_downed", {
	validation = "LOWEST",
	setting = "show_times_downed",
})
add("deaths", "row_deaths", {
	validation = "LOWEST",
	setting = "show_deaths",
})
add("times_disabled", "row_times_disabled", {
	validation = "LOWEST",
	setting = "show_times_disabled",
})
add("attacks_blocked", "row_attacks_blocked", {setting = "show_attacks_blocked"})
add("heal_station_used", "row_heal_station_used", {
	validation = "DESC",
	setting = "show_heal_station_used",
})
add("coherency_efficiency", "row_coherency_efficiency", {
	setting = "show_coherency_efficiency",
	update = "update_coherency",
	normalize = true,
})

add("damage_dealt", "row_damage_dealt", {
	summary = {"actual_damage_dealt"},
})
add("actual_damage_dealt", "row_actual_damage_dealt", {visible = false})
hidden("overkill_damage_dealt", "row_overkill_damage_dealt")
add("boss_damage_dealt", "row_boss_damage_dealt", {setting = "show_boss_damage_dealt"})
add("weakspot_hits", "row_weakspot_hits", {setting = "show_weakspot_hits"})
add("weakspot_hit_percent", "row_weakspot_hit_percent", {
	setting = "show_weakspot_hit_percent",
	decimals = 1,
	suffix = "%",
})
hidden("damaging_hits", "row_damaging_hits")
hidden("weakspot_damaging_hits", "row_weakspot_damaging_hits")
add("accuracy", "row_accuracy", {
	setting = "show_accuracy",
	decimals = 1,
	suffix = "%",
})
hidden("ranged_shots_fired", "row_ranged_shots_fired")
hidden("ranged_shots_hit", "row_ranged_shots_hit")
add("critical_hits", "row_critical_hits", {
	setting = "show_critical_hits",
	decimals = 1,
	suffix = "%",
})
hidden("critical_damaging_hits", "row_critical_damaging_hits")
add("ranged_kills", "row_ranged_kills", {setting = "show_melee_ranged_kills"})
add("melee_kills", "row_melee_kills", {setting = "show_melee_ranged_kills"})

local lesser_enemies = {
	"chaos_newly_infected",
	"chaos_poxwalker",
	"chaos_mutated_poxwalker",
	"chaos_lesser_mutated_poxwalker",
	"chaos_armored_infected",
	"cultist_assault",
	"cultist_melee",
	"renegade_assault",
	"renegade_melee",
	"renegade_rifleman",
}
add("lesser_enemies", "row_lesser_enemies", {
	summary = lesser_enemies,
	setting = "detailed_kill_split",
})
add_hidden_rows(lesser_enemies, "plugin_lesser_enemies", "offense")

local melee_threats = {
	"cultist_berzerker",
	"renegade_berzerker",
	"renegade_executor",
	"chaos_ogryn_bulwark",
	"chaos_ogryn_executor",
}
local ranged_threats = {
	"cultist_gunner",
	"renegade_gunner",
	"cultist_shocktrooper",
	"renegade_shocktrooper",
	"chaos_ogryn_gunner",
	"renegade_radio_operator",
	"renegade_plasma_gunner",
}
local elite_labels = {
	cultist_berzerker = "Dreg Rager",
	renegade_berzerker = "Scab Rager",
	renegade_executor = "Scab Mauler",
	chaos_ogryn_bulwark = "Bulwark",
	chaos_ogryn_executor = "Crusher",
	cultist_gunner = "Dreg Gunner",
	renegade_gunner = "Scab Gunner",
	cultist_shocktrooper = "Dreg Shotgunner",
	renegade_shocktrooper = "Scab Shotgunner",
	chaos_ogryn_gunner = "Reaper",
	renegade_radio_operator = "Scab Radio Operator",
	renegade_plasma_gunner = "Scab Plasma Gunner",
}
local melee_ranged_threats = {}
for i = 1, #melee_threats do melee_ranged_threats[#melee_ranged_threats + 1] = melee_threats[i] end
for i = 1, #ranged_threats do melee_ranged_threats[#melee_ranged_threats + 1] = ranged_threats[i] end
add("melee_ranged_threats", "row_melee_ranged_threats", {
	summary = melee_ranged_threats,
	group = "offense",
	setting = "detailed_kill_split",
})
add("melee_threats", "row_melee_threats", {
	summary = melee_threats,
	visible = false,
	setting = "plugin_melee_ranged_threats",
})
add_hidden_rows(melee_threats, "plugin_melee_ranged_threats", "offense", elite_labels)
add("ranged_threats", "row_ranged_threats", {
	summary = ranged_threats,
	visible = false,
	setting = "plugin_melee_ranged_threats",
})
add_hidden_rows(ranged_threats, "plugin_melee_ranged_threats", "offense", elite_labels)

local disablers = {
	"chaos_hound",
	"chaos_hound_mutator",
	"cultist_mutant",
	"cultist_mutant_mutator",
	"renegade_netgunner",
	"chaos_armored_hound",
}
local disabler_labels = {
	chaos_hound = "Pox Hound",
	chaos_hound_mutator = "Pox Hound",
	cultist_mutant = "Mutant",
	cultist_mutant_mutator = "Mutant",
	renegade_netgunner = "Scab Trapper",
	chaos_armored_hound = "Armoured Pox Hound",
}

-- Specials list; include explicit special types plus disablers so they
-- are counted under the same "specials killed" summary when enabled.
local specials = {
	"chaos_poxwalker_bomber",
	"renegade_grenadier",
	"cultist_grenadier",
	"renegade_sniper",
	"renegade_flamer",
	"cultist_flamer",
}
local special_labels = {
	chaos_poxwalker_bomber = "Pox Burster",
	renegade_grenadier = "Scab Bomber",
	cultist_grenadier = "Dreg Bomber",
	renegade_sniper = "Scab Sniper",
	renegade_flamer = "Scab Flamer",
	cultist_flamer = "Dreg Tox Flamer",
}
-- Combine specials and disablers for the special summary and labels
local combined_specials = {}
for i = 1, #specials do combined_specials[#combined_specials+1] = specials[i] end
for i = 1, #disablers do combined_specials[#combined_specials+1] = disablers[i] end

local combined_labels = {}
for k, v in pairs(special_labels) do combined_labels[k] = v end
for k, v in pairs(disabler_labels) do combined_labels[k] = v end

add("special_threats", "row_special_threats", {
	summary = combined_specials,
	group = "offense",
	setting = "detailed_kill_split",
})
add_hidden_rows(combined_specials, "plugin_special_threats", "offense", combined_labels)

local kills = {}
for i = 1, #lesser_enemies do kills[#kills+1] = lesser_enemies[i] end
for i = 1, #melee_ranged_threats do kills[#kills+1] = melee_ranged_threats[i] end
for i = 1, #combined_specials do kills[#kills+1] = combined_specials[i] end
add("kills", "row_kills", {
	summary = kills,
	group = "offense",
	setting = "detailed_kill_split = false",
})

return rows
