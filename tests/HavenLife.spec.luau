--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Haven = require("../src/ReplicatedStorage/Shared/Haven")
local HavenLife = require("../src/ReplicatedStorage/Shared/HavenLife")

local function flat(piece: HavenLife.Piece): boolean
	if piece.transparency >= 1 or piece.shape == "Ball" then
		return false
	end
	return math.abs(piece.rx) < 8 and math.abs(piece.rz) < 8
end

local function topY(piece: HavenLife.Piece): number
	return piece.y + piece.size[2] / 2
end

local function overlaps(a: HavenLife.Piece, b: HavenLife.Piece): boolean
	local function span(piece: HavenLife.Piece): (number, number, number, number)
		local yaw = math.rad(piece.ry)
		local c = math.abs(math.cos(yaw))
		local s = math.abs(math.sin(yaw))
		local halfX = (piece.size[1] * c + piece.size[3] * s) / 2
		local halfZ = (piece.size[1] * s + piece.size[3] * c) / 2
		return piece.x - halfX, piece.x + halfX, piece.z - halfZ, piece.z + halfZ
	end
	local a0, a1, a2, a3 = span(a)
	local b0, b1, b2, b3 = span(b)
	return a0 < b1 and a1 > b0 and a2 < b3 and a3 > b2
end

describe("HavenLife", function()
	it("stays inside the dressing budget and keeps decoration off the walk", function()
		local count = HavenLife.partCount()
		print(string.format("Haven alive dressing parts: %d (budget %d)", count, HavenLife.BUDGET))
		expect(count > 40).toBeTrue()
		expect(count <= HavenLife.BUDGET).toBeTrue()
		local orbitNamed = 0
		for _, piece in ipairs(HavenLife.pieces()) do
			expect(piece.collide).toBeFalse()
			if piece.name == "OrbitShard" then
				orbitNamed += 1
			end
			if piece.name == "SkyShard" then
				expect((piece.drift or 0) >= 70).toBeTrue()
			end
			if piece.name == "Waterfall" then
				-- Local Z is the long axis. A steep pitch hangs that axis
				-- down, so the sheet is a curtain and not a flat deck.
				expect(piece.size[3] > piece.size[1] and piece.size[3] > piece.size[2]).toBeTrue()
				expect(piece.material).toEqual("Glass")
				expect(piece.transparency < 0.5).toBeTrue()
				local tilt = math.rad(piece.rx)
				expect(math.abs(math.sin(tilt)) >= 0.9).toBeTrue()
				local top = piece.y + math.abs(math.sin(tilt)) * (piece.size[3] / 2)
				expect(top >= 8).toBeTrue()
				local islands = {
					{ x = 0, z = 0, radius = Haven.PLAZA_RADIUS },
				}
				for _, district in ipairs(Haven.DISTRICTS) do
					table.insert(islands, {
						x = district.x,
						z = district.z,
						radius = district.radius or 30,
					})
				end
				local nearest = islands[1]
				local nearestReach = math.huge
				for _, island in ipairs(islands) do
					local reach = math.sqrt((piece.x - island.x) ^ 2 + (piece.z - island.z) ^ 2)
					if reach < nearestReach then
						nearest = island
						nearestReach = reach
					end
				end
				expect(nearestReach > nearest.radius + 8).toBeTrue()
				local hang = math.abs(math.cos(tilt)) * (piece.size[3] / 2) + piece.size[2] / 2
				expect(nearestReach - hang > nearest.radius + 8).toBeTrue()
			end
		end
		expect(orbitNamed).toEqual(0)
		for key, soundId in pairs(HavenLife.AUDIO) do
			expect(soundId == "" or HavenLife.audioReady(soundId)).toBeTrue()
			expect(key ~= "").toBeTrue()
		end
		expect(HavenLife.audioReady("rbxassetid://123")).toBeTrue()
		expect(HavenLife.audioReady("rbxasset://sounds/oops")).toBeFalse()
		expect(HavenLife.audioReady("")).toBeFalse()
	end)

	it("turns lanterns on at night and keeps daytime at the start clock", function()
		expect(HavenLife.lanternsOn(HavenLife.START_CLOCK)).toBeFalse()
		expect(HavenLife.lanternsOn(HavenLife.clock(0))).toBeFalse()
		expect(HavenLife.lanternsOn(20)).toBeTrue()
		expect(HavenLife.lanternsOn(3)).toBeTrue()
		expect(HavenLife.lanternsOn(12)).toBeFalse()
		local night = HavenLife.mood(21)
		local day = HavenLife.mood(15.4)
		expect(night.brightness < day.brightness).toBeTrue()
		local later = HavenLife.clock(HavenLife.DAY_SECONDS)
		expect(math.abs(later - HavenLife.START_CLOCK) < 0.001).toBeTrue()
	end)

	it("keeps townsfolk on the plaza and flat tops apart", function()
		local heights = {}
		for _, rig in ipairs(HavenLife.rigs()) do
			if rig.kind == "folk" then
				expect(rig.name).toEqual("Townsfolk")
				expect(rig.points ~= nil).toBeTrue()
				for _, point in ipairs(rig.points :: { { number } }) do
					local reach = math.sqrt(point[1] * point[1] + point[2] * point[2])
					expect(reach < Haven.PLAZA_RADIUS - 6).toBeTrue()
					expect(reach > 13).toBeTrue()
					local clearOfSpawn = math.abs(point[1] - Haven.SPAWN.x) > 6
						or math.abs(point[2] - Haven.SPAWN.z) > 6
					expect(clearOfSpawn).toBeTrue()
				end
				for _, piece in ipairs(rig.parts) do
					if piece.name == "Body" then
						table.insert(heights, piece.size[2])
					end
				end
			end
		end
		expect(#heights).toEqual(3)
		expect(heights[1] ~= heights[2] and heights[2] ~= heights[3]).toBeTrue()

		local flats = {}
		for _, piece in ipairs(HavenLife.pieces()) do
			if flat(piece) then
				table.insert(flats, piece)
			end
		end
		for i = 1, #flats do
			for j = i + 1, #flats do
				local left = flats[i]
				local right = flats[j]
				if overlaps(left, right) and math.abs(topY(left) - topY(right)) < 0.01 then
					error(string.format("%s and %s share a dressing top", left.name, right.name), 2)
				end
			end
		end
	end)

	it("clamps sunset bloom and sun rays below the midday values", function()
		local day = HavenLife.exposure(12)
		local sunset = HavenLife.exposure(18.2)
		expect(day.bloomIntensity).toEqual(0.12)
		expect(day.bloomSize).toEqual(10)
		expect(sunset.bloomIntensity < day.bloomIntensity).toBeTrue()
		expect(sunset.bloomIntensity <= 0.12).toBeTrue()
		expect(sunset.bloomSize <= 12).toBeTrue()
		expect(sunset.sunIntensity < day.sunIntensity).toBeTrue()
		expect(sunset.sunIntensity <= 0.05).toBeTrue()
		expect(sunset.sunSpread < day.sunSpread).toBeTrue()
		expect(sunset.brightness < day.brightness).toBeTrue()
	end)
end)
