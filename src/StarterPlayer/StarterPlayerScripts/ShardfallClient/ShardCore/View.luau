--!strict

--[[
	Plain labels for the Shard Core panel. No instances.

	Mount builds the gui from View.lines(state). state is the table
	ShardCore.preview returns (and the server sends on GetShardCore
	and FeedShardCore). help is the once-per-session line when the
	server included it. An empty help means it was already shown.
]]

local View = {}

export type WeaponLine = {
	uid: string,
	label: string,
	selected: boolean,
}

export type PerkLine = {
	text: string,
	unlocked: boolean,
}

export type Lines = {
	title: string,
	essenceText: string,
	status: string,
	feedText: string,
	canFeed: boolean,
	selected: string,
	help: string,
	weapons: { WeaponLine },
	perks: { PerkLine },
}

function View.lines(state: any): Lines
	local weapons: { WeaponLine } = {}
	local perks: { PerkLine } = {}
	local selected = ""
	local status = "No weapon to feed."
	local canFeed = false
	local essence = 0
	local help = ""
	if type(state) == "table" then
		if
			type(state.essence) == "number"
			and state.essence == state.essence
			and state.essence >= 0
		then
			essence = math.floor(state.essence)
		end
		if type(state.selected) == "string" then
			selected = state.selected
		end
		if type(state.status) == "string" and state.status ~= "" then
			status = state.status
		end
		canFeed = state.canFeed == true
		if type(state.help) == "string" then
			help = state.help
		end
		if type(state.weapons) == "table" then
			for _, row in ipairs(state.weapons) do
				if type(row) == "table" and type(row.uid) == "string" then
					local name = if type(row.name) == "string" and row.name ~= ""
						then row.name
						else "Weapon"
					local level = 0
					if type(row.level) == "number" and row.level >= 0 then
						level = math.floor(row.level)
					end
					table.insert(weapons, {
						uid = row.uid,
						label = string.format("%s  Lv %d", name, level),
						selected = row.uid == selected,
					})
					if row.uid == selected and type(row.perks) == "table" then
						for _, perk in ipairs(row.perks) do
							if type(perk) == "table" and type(perk.text) == "string" then
								local shown = perk.text
								if perk.unlocked ~= true and type(perk.level) == "number" then
									shown = string.format("Lv %d  %s", perk.level, perk.text)
								end
								table.insert(perks, {
									text = shown,
									unlocked = perk.unlocked == true,
								})
							end
						end
					end
				end
			end
		end
	end
	return {
		title = "Shard Core",
		essenceText = string.format("Essence: %d", essence),
		status = status,
		feedText = status,
		canFeed = canFeed,
		selected = selected,
		help = help,
		weapons = weapons,
		perks = perks,
	}
end

return View
