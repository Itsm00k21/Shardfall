--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local GuiFake = require("./GuiFake")

local VIEWS = {
	{ 390, 844 },
	{ 844, 390 },
}

local function profile()
	local settings = Settings.default()
	return {
		level = 8,
		xp = 10,
		classId = "warden",
		shardTokens = 10,
		gold = 40,
		inventory = {},
		pets = {},
		equipped = {},
		uiSettings = settings,
	}
end

local function boot(width: number, height: number)
	local world = GuiFake.world()
	local MenuHub = world.load("MenuHub")
	local hub = MenuHub.start(world.playerGui, {
		invoke = function()
			return { ok = true }
		end,
		onBag = function() end,
		onMarket = function() end,
		onDim = function() end,
	})
	local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
	screen.AbsoluteSize = { X = width, Y = height }
	hub.setProfile(profile())
	return world, hub, screen
end

local function shownText(root: any, text: string): boolean
	for _, child in ipairs(root:GetDescendants()) do
		if not (child:IsA("TextLabel") or child:IsA("TextButton")) then
			continue
		end
		if child.Text ~= text and string.find(tostring(child.Text), text, 1, true) == nil then
			continue
		end
		local node = child
		local visible = true
		while node ~= nil do
			if node.Visible == false or node.Enabled == false then
				visible = false
				break
			end
			node = node.Parent
		end
		if visible then
			return true
		end
	end
	return false
end

describe("MenuClear", function()
	it("keeps hero meter text off the fill on both phone sizes", function()
		for _, view in ipairs(VIEWS) do
			local _, hub, screen = boot(view[1], view[2])
			hub.open("hero")
			local sheet = GuiFake.findNamed(screen, "Stats")
			for _, id in ipairs({ "damage", "health", "defense" }) do
				local host = sheet:FindFirstChild(id)
				expect(host ~= nil).toBeTrue()
				local caption = host:FindFirstChild("Caption")
				local track = host:FindFirstChild("Track")
				local fill = track:FindFirstChild("Fill")
				expect(caption ~= nil and track ~= nil and fill ~= nil).toBeTrue()
				expect(fill.Parent == track).toBeTrue()
				expect(caption.Parent == host).toBeTrue()
				local captionBottom = caption.Position.Y.Offset + caption.Size.Y.Offset
				expect(track.Position.Y.Offset >= captionBottom).toBeTrue()
			end
			expect(shownText(screen, "Gold shop. Gold only.")).toBeFalse()
		end
	end)

	it("gives pets one crack action and does not list the roster", function()
		local _, hub, screen = boot(390, 844)
		hub.open("pets")
		expect(shownText(screen, "Crack a Pet Shard")).toBeTrue()
		expect(shownText(screen, "CRACK PET SHARD")).toBeFalse()
		expect(shownText(screen, "Open pets")).toBeFalse()
		expect(shownText(screen, "Shardjaw")).toBeFalse()
		expect(shownText(screen, "Thorn Lantern")).toBeFalse()
		expect(shownText(screen, "Glass Kestrel")).toBeFalse()
		local cracks = 0
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and string.find(tostring(child.Text), "Crack a Pet Shard", 1, true) ~= nil then
				cracks += 1
			end
		end
		expect(cracks).toEqual(1)
	end)

	it("drops the repeated shop title and the roll gold counter", function()
		local _, hub, screen = boot(844, 390)
		hub.open("shop")
		expect(shownText(screen, "Gold shop. Gold only.")).toBeFalse()
		expect(shownText(screen, "Gold  40")).toBeTrue()
		expect(shownText(screen, "  Healing Tonic  40 Gold")).toBeTrue()
		hub.open("roll")
		local gold = GuiFake.findNamed(screen, "Gold")
		expect(gold.Visible).toEqual(false)
		expect(GuiFake.findNamed(screen, "ShardCount").Visible).toEqual(true)
		expect(shownText(screen, "Gold  40")).toBeFalse()
	end)
end)
