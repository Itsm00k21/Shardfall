--!strict

--[[
	Rootvault beta run rules.

	Two doors after a cleared room, five enemy roles, Grandmother Gnarl's
	three phases, and Normal / Hard / Nightmare. The server rolls the doors
	and applies the numbers. Layout shuffling stays post-beta.
]]

local Rootvault = {}

Rootvault.DIFFICULTIES = {
	normal = { id = "normal", hp = 1, damage = 1, level = 1, chest = "Common" },
	hard = { id = "hard", hp = 1.5, damage = 1.5, level = 10, chest = "Uncommon" },
	nightmare = { id = "nightmare", hp = 2, damage = 2, level = 15, chest = "Rare" },
}

Rootvault.ROLES = {
	grunt = { kind = "vine_crawler", note = "Basic. Swing through them." },
	charger = { kind = "thorn_sprite", note = "Dashes. Dodge the red line." },
	caster = { kind = "spore_bat", note = "Ranged. Close in." },
	shielder = { kind = "root_brute", note = "Blocks the front. Flank it." },
	mender = { kind = "moss_crawler", note = "Heals allies. Focus it." },
}

Rootvault.DOORS = {
	treasure = { id = "treasure", name = "Treasure", note = "A chest for clearing the room." },
	elite = { id = "elite", name = "Elite Fight", note = "One tougher foe with an affix." },
	spring = { id = "spring", name = "Healing Spring", note = "Restore 30% of max HP." },
	shrine = { id = "shrine", name = "Shrine", note = "A random boon for the rest of the run." },
	shop = { id = "shop", name = "Shop", note = "Spend 40 Shard Keys on an Uncommon chest." },
	boss = { id = "boss", name = "Grandmother Gnarl", note = "The last door." },
}

Rootvault.SHRINES = { "might", "ward", "haste" }
Rootvault.ELITE_HP = 1.6
Rootvault.ELITE_DAMAGE = 1.35
Rootvault.PHASE2 = 0.6
Rootvault.PHASE3 = 0.25

function Rootvault.difficulty(id: any)
	if type(id) == "string" and Rootvault.DIFFICULTIES[id] ~= nil then
		return Rootvault.DIFFICULTIES[id]
	end
	return Rootvault.DIFFICULTIES.normal
end

function Rootvault.scale(id: any, health: number, damage: number): (number, number)
	local row = Rootvault.difficulty(id)
	return math.floor(health * row.hp + 0.5), math.floor(damage * row.damage + 0.5)
end

function Rootvault.gnarlPhase(health: number, maxHealth: number): number
	if maxHealth <= 0 then
		return 1
	end
	local ratio = health / maxHealth
	if ratio <= Rootvault.PHASE3 then
		return 3
	end
	if ratio <= Rootvault.PHASE2 then
		return 2
	end
	return 1
end

function Rootvault.phaseNote(phase: number): string
	if phase == 3 then
		return "Thorn wall. Interrupt the roar."
	end
	if phase == 2 then
		return "Saplings. Cut them down before the vines sweep."
	end
	return "Root slams. Dodge the red circles."
end

-- Two choices, or the boss door when the next room is the last.
function Rootvault.offer(roomIndex: number, roomCount: number, roll: number)
	if roomIndex >= roomCount - 1 then
		return { Rootvault.DOORS.boss }
	end
	local pool = { "treasure", "elite", "spring", "shrine", "shop" }
	local first = pool[((roll - 1) % #pool) + 1]
	local second = pool[(roll % #pool) + 1]
	if second == first then
		second = pool[((roll + 1) % #pool) + 1]
	end
	return { Rootvault.DOORS[first], Rootvault.DOORS[second] }
end

function Rootvault.shrine(roll: number): string
	local index = ((roll - 1) % #Rootvault.SHRINES) + 1
	return Rootvault.SHRINES[index]
end

return Rootvault
