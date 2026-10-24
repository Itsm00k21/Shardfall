--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local Haven = require("../src/ReplicatedStorage/Shared/Haven")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")

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
		expect(Haven.portal("tidecrypt").message).toEqual("Tidecrypt is sealed.")
		expect(Haven.portal("ember").message).toEqual("Emberforge is sealed.")
		expect(Haven.portal("frost").message).toEqual("Frostveil is sealed.")
		expect(Haven.portal("void").message).toEqual("Void Rift is sealed.")
	end)

	it("paints Rootvault and Heartwood open and seals the other gates with a level line", function()
		local lit = {}
		for _, portal in ipairs(Haven.PORTALS) do
			expect(type(portal.subline) == "string").toBeTrue()
			expect(type(portal.dress) == "string").toBeTrue()
			expect(type(portal.level) == "number").toBeTrue()
			expect(string.find(portal.subline :: string, tostring(portal.level), 1, true) ~= nil).toBeTrue()
			if Haven.gateLit(portal) then
				table.insert(lit, portal.id)
				expect(string.find(Haven.gatePlate(portal), "Sealed", 1, true)).toBeNil()
			else
				expect(type(portal.message) == "string").toBeTrue()
				expect(string.find(Haven.gatePlate(portal), "Sealed", 1, true) ~= nil).toBeTrue()
			end
		end
		expect(lit).toEqual({ "rootvault", "heartwood" })
		expect(Haven.NAMEPLATE_DISTANCE >= 90).toBeTrue()
		expect(Haven.PIER_REACH < Haven.GATE_REACH).toBeTrue()
		expect(Haven.portal("rootvault").dress).toEqual("roots")
		expect(Haven.portal("rootvault").subline).toEqual("Lv 1 · Solo")
		expect(Haven.gatePlate(Haven.portal("rootvault"))).toEqual("Lv 1 · Solo")
		expect(Haven.portal("heartwood").open).toEqual(true)
		expect(Haven.portal("heartwood").sealed).toEqual(false)
		expect(Haven.portal("heartwood").dress).toEqual("bark")
		expect(Haven.portal("heartwood").message).toEqual("Opens at level 15.")
		expect(Haven.portal("heartwood").subline).toEqual("Lv 15 · 4–8")
		expect(Haven.gatePlate(Haven.portal("heartwood"))).toEqual("Lv 15 · 4–8")
		expect(Haven.portal("heartwood").height).toEqual(22)
		expect(Haven.portal("tidecrypt").dress).toEqual("coral")
		expect(Haven.portal("ember").dress).toEqual("basalt")
		expect(Haven.portal("frost").dress).toEqual("ice")
		expect(Haven.portal("void").dress).toEqual("obsidian")
		expect(Haven.portal("void").glow).toEqual({ 18, 16, 24 })
	end)

	it("opens a gate from implemented dungeons and the Heartwood raid", function()
		local openIds = {}
		for _, portal in ipairs(Haven.PORTALS) do
			local open = Haven.gateOpen(portal)
			expect(Haven.gateLit(portal)).toEqual(open)
			if open then
				table.insert(openIds, portal.id)
			end
		end
		expect(openIds).toEqual({ "rootvault", "heartwood" })
		local painted = {
			id = "rootvault",
			name = "Rootvault",
			x = 0,
			z = 0,
			dungeonId = Dungeons.ROOTVAULT_ID,
			sealed = true,
		}
		expect(Haven.gateOpen(painted)).toEqual(true)
		expect(Haven.gateOpen({
			id = "heartwood",
			name = "Heartwood",
			x = 0,
			z = 0,
			dungeonId = "missing",
			sealed = true,
		})).toEqual(true)
		expect(Haven.gateOpen({
			id = "waves",
			name = "Waves",
			x = 0,
			z = 0,
			dungeonId = Dungeons.WAVES_ID,
			sealed = false,
		})).toEqual(false)
		expect(Haven.gateOpen({
			id = "tidecrypt",
			name = "Tidecrypt",
			x = 0,
			z = 0,
			dungeonId = "tidecrypt",
			sealed = false,
			open = true,
		})).toEqual(false)
		local shut = {
			id = "heartwood",
			name = "Heartwood",
			x = 0,
			z = 0,
			level = 15,
			subline = "Lv 15 · Sealed",
			sealed = true,
		}
		expect(Haven.gatePlate(shut)).toEqual("Lv 15")
	end)

	it("seals Heartwood with Opens later while raids are off", function()
		local heart = Haven.portal("heartwood")
		expect(LaunchGate.on("raids")).toEqual(false)
		expect(Haven.gateOpen(heart)).toEqual(true)
		expect(Haven.gateShownOpen(heart)).toEqual(false)
		expect(Haven.gateShownPlate(heart)).toEqual("Opens later")
		expect(Haven.gateShownOpen(Haven.portal("rootvault"))).toEqual(true)
		expect(Haven.gateShownPlate(Haven.portal("rootvault"))).toEqual("Lv 1 · Solo")
		expect(Haven.gateShownOpen(Haven.portal("tidecrypt"))).toEqual(false)
		expect(Haven.gateShownPlate(Haven.portal("tidecrypt"))).toEqual(Haven.gatePlate(Haven.portal("tidecrypt")))
		LaunchGate.SHOW.raids = true
		local shown = Haven.gateShownOpen(heart)
		local plate = Haven.gateShownPlate(heart)
		LaunchGate.SHOW.raids = false
		expect(shown).toEqual(true)
		expect(plate).toEqual("Lv 15 · 4–8")
		expect(LaunchGate.on("raids")).toEqual(false)
		expect(Haven.gateShownOpen(heart)).toEqual(false)
		expect(Haven.gateOpen(heart)).toEqual(true)
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

	it("keeps the training dummy on the south rim and out of the gate lanes", function()
		local grove = Haven.GROVE
		expect(grove.id).toEqual("grove")
		expect(grove.name).toEqual("Training Grove")
		expect(grove.x).toEqual(-16)
		expect(grove.z).toEqual(48.2)
		local radius = math.sqrt(grove.x * grove.x + grove.z * grove.z)
		expect(radius < Haven.PLAZA_RADIUS).toBeTrue()
		expect(radius > Haven.PLAZA_RADIUS - 4).toBeTrue()
		expect(grove.z > Haven.SPAWN.z).toBeTrue()
		expect(grove.x < -8).toBeTrue()
		for _, place in ipairs(Haven.places()) do
			expect(place.id == "grove").toBeFalse()
		end
		local function inLane(x: number, z: number, portal: any): boolean
			local bearing = math.rad(portal.bearing or 0)
			local dirX = math.sin(bearing)
			local dirZ = math.cos(bearing)
			local sideX = math.cos(bearing)
			local sideZ = -math.sin(bearing)
			local dx = x - Haven.SPAWN.x
			local dz = z - Haven.SPAWN.z
			local along = dx * dirX + dz * dirZ
			local side = math.abs(dx * sideX + dz * sideZ)
			if along < 8 or along > Haven.GATE_RADIUS then
				return false
			end
			return side <= 5
		end
		for _, portal in ipairs(Haven.PORTALS) do
			local mouth = math.sqrt((grove.x - portal.x) * (grove.x - portal.x) + (grove.z - portal.z) * (grove.z - portal.z))
			expect(mouth > 30).toBeTrue()
			for _, sx in ipairs({ -1, 0, 1 }) do
				for _, sz in ipairs({ -1, 0, 1 }) do
					local x = grove.x + sx * grove.halfX
					local z = grove.z + sz * grove.halfZ
					if inLane(x, z, portal) then
						error(portal.id .. " lane crosses the grove", 2)
					end
				end
			end
		end
	end)

	it("keeps the dungeon rooms beyond the islands", function()
		local _, _, waveZ = Dungeons.roomOrigin(Dungeons.WAVES_ROOM_INDEX)
		local _, _, roomZ = Dungeons.roomOrigin(1)
		local reach = Haven.reach()
		expect(math.abs(waveZ) > reach + 80).toBeTrue()
		expect(math.abs(roomZ) > reach + 80).toBeTrue()
	end)
end)
