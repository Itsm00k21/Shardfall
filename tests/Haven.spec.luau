--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local Haven = require("../src/ReplicatedStorage/Shared/Haven")

describe("Haven", function()
	it("lays the districts and six gates on the crescent", function()
		expect(Haven.district("forge") ~= nil).toBeTrue()
		expect(Haven.district("market") ~= nil).toBeTrue()
		expect(Haven.district("guild") ~= nil).toBeTrue()
		expect(Haven.district("garden") ~= nil).toBeTrue()
		expect(Haven.district("observatory") ~= nil).toBeTrue()
		expect(Haven.ARMORY.station).toEqual("armory")
		expect(Haven.district("forge").station).toEqual("craft")
		expect(Haven.district("garden").station).toEqual("pets")
		expect(#Haven.PORTALS).toEqual(6)
		expect(Haven.SPAWN.x).toEqual(0)
		expect(Haven.SPAWN.z).toEqual(30)
		expect(Haven.SPAWN.lookX).toEqual(0)
		expect(Haven.SPAWN.lookZ).toEqual(108)
		expect(Haven.ARMORY.x).toEqual(-38)
		expect(Haven.ARMORY.z).toEqual(-35.8)
		expect(Haven.SHOP.x).toEqual(-70.5)
		expect(Haven.SHOP.z).toEqual(1.5)
		expect(Haven.SHRINE.x).toEqual(28.5)
		expect(Haven.SHRINE.z).toEqual(-40.5)
		expect(Haven.SHRINE.message).toEqual("The shrine wakes inside a run.")
		expect(#Haven.NOVICE.z).toEqual(5)
		expect(Haven.NOVICE.x).toEqual(-40)
		expect(Haven.NOVICE.z[1]).toEqual(18)
		expect(Haven.NOVICE.z[5]).toEqual(-14)
	end)

	it("leaves Rootvault and Heartwood live and seals the rest", function()
		local openIds = {}
		for index, portal in ipairs(Haven.PORTALS) do
			expect(portal.bearing).toEqual((index - 1) * Haven.GATE_STEP)
			local dx = portal.x - Haven.SPAWN.x
			local dz = portal.z - Haven.SPAWN.z
			local radius = math.sqrt(dx * dx + dz * dz)
			expect(math.abs(radius - Haven.GATE_RADIUS) < 0.1).toBeTrue()
			if index > 1 then
				local previous = Haven.PORTALS[index - 1]
				local chord = math.sqrt(
					(portal.x - previous.x) * (portal.x - previous.x)
						+ (portal.z - previous.z) * (portal.z - previous.z)
				)
				expect(math.abs(chord - 16.3) < 0.15).toBeTrue()
			end
			if portal.open == true then
				table.insert(openIds, portal.id)
			else
				expect(type(portal.message) == "string").toBeTrue()
			end
		end
		expect(openIds).toEqual({ "rootvault", "heartwood" })
		expect(Haven.portal("rootvault").dungeonId).toEqual(Dungeons.ROOTVAULT_ID)
		expect(Haven.portal("heartwood").dungeonId).toEqual(Dungeons.HEARTWOOD_ID)
		expect(Haven.portal("tidecrypt").open).toEqual(false)
		expect(Haven.portal("tidecrypt").message).toEqual("Sunken Reach is sealed.")
		expect(Haven.portal("ember").message).toEqual("Emberforge is sealed.")
		expect(Haven.portal("frost").message).toEqual("Frostveil is sealed.")
		expect(Haven.portal("void").message).toEqual("Void Rift is sealed.")
	end)

	it("gives every live dungeon exactly one arch", function()
		local counts: { [string]: number } = {}
		for _, portal in ipairs(Haven.PORTALS) do
			if type(portal.dungeonId) == "string" then
				local id = portal.dungeonId :: string
				counts[id] = (counts[id] or 0) + 1
			end
		end
		local live = 0
		for _, dungeon in ipairs(Dungeons.all()) do
			if dungeon.implemented == true and dungeon.endless ~= true then
				live += 1
				expect(counts[dungeon.id]).toEqual(1)
			elseif dungeon.endless == true then
				expect(counts[dungeon.id] or 0).toEqual(0)
			end
		end
		expect(live).toEqual(2)
	end)

	it("treats a fall below the sky island as leaving the hub", function()
		expect(Haven.fellOffHub(59)).toBeTrue()
		expect(Haven.fellOffHub(Haven.FLOOR_Y)).toBeFalse()
		expect(Haven.fellOffHub(4)).toBeTrue()
	end)

	it("puts the spawn on the plaza and a 20 to 30 second walk across the hub", function()
		expect(Haven.spawnOnPlaza()).toBeTrue()
		local seconds = Haven.crossingSeconds(Haven.WALK_SPEED)
		expect(seconds >= 20).toBeTrue()
		expect(seconds <= 30).toBeTrue()
	end)

	it("keeps overlapping walk tops apart by the layer offset", function()
		expect(Haven.LAYER >= 0.04 and Haven.LAYER <= 0.08).toBeTrue()
		local function box(x: number, z: number, half: number): Haven.Footprint
			return {
				x = x,
				z = z,
				rightX = 1,
				rightZ = 0,
				forwardX = 0,
				forwardZ = 1,
				halfX = half,
				halfZ = half,
			}
		end
		local plaza = box(0, 0, 52)
		local deck = box(52, 0, 7)
		expect(Haven.footprintsOverlap(plaza, deck)).toBeTrue()
		expect(Haven.sameTop(Haven.FLOOR_Y, Haven.FLOOR_Y)).toBeTrue()
		expect(Haven.sameTop(Haven.FLOOR_Y, Haven.FLOOR_Y + Haven.LAYER)).toBeFalse()
		expect(Haven.coplanarTops(plaza, Haven.FLOOR_Y, deck, Haven.FLOOR_Y)).toBeTrue()
		expect(Haven.coplanarTops(plaza, Haven.FLOOR_Y, deck, Haven.FLOOR_Y + Haven.LAYER)).toBeFalse()
		local neighbor = box(104, 0, 52)
		expect(Haven.footprintsOverlap(plaza, neighbor)).toBeFalse()
	end)

	it("keeps the dungeon rooms beyond the islands", function()
		local _, _, waveZ = Dungeons.roomOrigin(Dungeons.WAVES_ROOM_INDEX)
		local _, _, roomZ = Dungeons.roomOrigin(1)
		local reach = Haven.reach()
		expect(math.abs(waveZ) > reach + 80).toBeTrue()
		expect(math.abs(roomZ) > reach + 80).toBeTrue()
	end)
end)
