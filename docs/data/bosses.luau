--!strict

--[[
	G-101. Suggested world-boss rows from docs/content/bosses.md.

	Eight field bosses. Three phases each. Name, zone, signature,
	loot theme, and visual note. Arena is the landmark from the
	source. Phase cuts at 70% and 35%, a 2 second roar, a 5 minute
	leash, and a 90 stud nearby range are suggested. They are not
	live numbers.

	These are not Heartwood wings and not Rootvault rooms. The
	cosmetic in lootTheme has no stats. No chest. No drop odds.
	This file does not change Raids.luau or Dungeons.luau.
]]

return {
	{
		id = "mireoak",
		name = "Mireoak",
		zone = "Far Glade",
		arena = "Mireoak's Bowl",
		signature = "The amber knot takes the last hits, and the yellow circle shares them.",
		lootTheme = "First kill that day: Heartwood. Later that day: Verdant Bark. First kill ever: Mire Lamp, a small amber knot in an iron cage, soft amber glow, no stats.",
		visual = "Wide walking oak, mud-brown bark, short root legs, one amber knot, calm amber eye-lights, soft amber glow.",
		phases = {
			{
				name = "Mud Ring",
				suggestedHp = "100-70%",
				action = "Step out of the rings.",
				telegraph = "Purple rings under players.",
			},
			{
				name = "Root Charge",
				suggestedHp = "70-35%",
				action = "Dodge to the side.",
				telegraph = "Red line, then a straight rush.",
			},
			{
				name = "Amber Knot",
				suggestedHp = "35-0%",
				action = "Stand in the circle. Hits on the knot count for everyone in it.",
				telegraph = "Yellow circle in front of the trunk.",
			},
		},
	},
	{
		id = "glasshorn",
		name = "Glasshorn",
		zone = "Saltglass Strand",
		arena = "The Saltglass Arch",
		signature = "The glass horn is a big blue interrupt. Three huge plates are the safe floor.",
		lootTheme = "First kill that day: Black Pearl. Later that day: Coral Shard. First kill ever: Glasshorn Crest, a small clear horn on a salt-white plate, steady pale glow, no stats.",
		visual = "Giant low tortoise, white salt crust, one clear horn, teal rim, steady rim glow.",
		phases = {
			{
				name = "Salt Cone",
				suggestedHp = "100-70%",
				action = "Dodge sideways.",
				telegraph = "Red cone of salt spray.",
			},
			{
				name = "Horn Bell",
				suggestedHp = "70-35%",
				action = "Hit the glowing horn.",
				telegraph = "Blue charge on the horn, then a wide pulse.",
			},
			{
				name = "Glass Plates",
				suggestedHp = "35-0%",
				action = "Stand on a plate. The plates are huge.",
				telegraph = "Three pale plates. The shelf outside them dims.",
			},
		},
	},
	{
		id = "brinecrown",
		name = "Brinecrown",
		zone = "Pearl Trench",
		arena = "Brinecrown Trench",
		signature = "The gold-blue brow scale is the only bright target.",
		lootTheme = "First kill that day: Leviathan Crown-Scale. Later that day: Coral Shard. First kill ever: Brine Clasp, a gold-blue scale on a teal pin, steady scale glow, no stats.",
		visual = "Long whale-eel, deep blue, one gold-blue brow scale, soft lamp spots down the side.",
		phases = {
			{
				name = "Tail Sweep",
				suggestedHp = "100-70%",
				action = "Dodge the slow arc.",
				telegraph = "Wide red arc.",
			},
			{
				name = "Scale Flash",
				suggestedHp = "70-35%",
				action = "Step off the rings around the brow scale.",
				telegraph = "Purple rings at the gold-blue scale.",
			},
			{
				name = "Jaw Breach",
				suggestedHp = "35-0%",
				action = "Stand under the jaw. Hits on the scale count for everyone in the circle.",
				telegraph = "Yellow circle under the jaw.",
			},
		},
	},
	{
		id = "slagwalker",
		name = "Slagwalker",
		zone = "Slag Marches",
		arena = "The Cool Vent",
		signature = "It walks a purple slag path. Blue vents on its back stop the heat wave.",
		lootTheme = "First kill that day: Molten Core. Later that day: Cinder Ore. First kill ever: Slag Cloak, a short charcoal cloak with one orange seam, steady seam glow, no stats.",
		visual = "Bulky walking heap, charcoal rock, orange cracks, bright crack glow, no face.",
		phases = {
			{
				name = "Slow Slam",
				suggestedHp = "100-70%",
				action = "Step out of the circle.",
				telegraph = "Red circle, slow.",
			},
			{
				name = "Slag Path",
				suggestedHp = "70-35%",
				action = "Do not stand in the path it walks.",
				telegraph = "Purple pools behind it.",
			},
			{
				name = "Cool Vent",
				suggestedHp = "35-0%",
				action = "Hit a glowing vent on its back.",
				telegraph = "Blue vents, large, then a heat wave.",
			},
		},
	},
	{
		id = "cinderseat",
		name = "Cinderseat",
		zone = "Slag Marches",
		arena = "The Cinder Chair",
		signature = "It stays seated. The chest crystal opens. The yellow circle at the chair shares the last hits.",
		lootTheme = "First kill that day: Tyrant's Ember Heart. Later that day: Cinder Ore. First kill ever: Cinderseat Charm, a tiny orange crystal in a dark iron cage, bright crystal glow, no stats.",
		visual = "Huge seated slag figure, dark iron, a cinder crown, one orange crystal in the chest, bright crystal glow.",
		phases = {
			{
				name = "Mace Arc",
				suggestedHp = "100-70%",
				action = "Dodge back.",
				telegraph = "Wide red arc from the seated swing.",
			},
			{
				name = "Blue Vents",
				suggestedHp = "70-35%",
				action = "Stand in a floor vent while the crystal holds.",
				telegraph = "Three blue floor vents, large.",
			},
			{
				name = "Open Crystal",
				suggestedHp = "35-0%",
				action = "Stand at the chair's foot. Hits on the crystal count for everyone in the circle.",
				telegraph = "Yellow circle. The orange crystal opens.",
			},
		},
	},
	{
		id = "pane_strider",
		name = "Pane Strider",
		zone = "Hoarfrost Expanse",
		arena = "Pane Strider's Run",
		signature = "You track its blue glow when the field goes white.",
		lootTheme = "First kill that day: Everfrost Gem. Later that day: Frost Pelt. First kill ever: Pane Halo, a thin clear ring that sits over the shoulders, soft blue edge glow, no stats.",
		visual = "Tall ice strider, clear pane antlers, blue-white body, strong blue eye glow, short frost trail.",
		phases = {
			{
				name = "Antler Sweep",
				suggestedHp = "100-70%",
				action = "Dodge the slow arc.",
				telegraph = "Red arc from the pane antlers.",
			},
			{
				name = "White Gust",
				suggestedHp = "70-35%",
				action = "Step out of the circles. Follow the blue eye glow. The body stays visible.",
				telegraph = "The field whitens. Purple circles mark the gusts.",
			},
			{
				name = "Warm Breath",
				suggestedHp = "35-0%",
				action = "Stand at the muzzle. The circle shares the last hits and clears the slow.",
				telegraph = "Yellow circle at the muzzle.",
			},
		},
	},
	{
		id = "stillfang",
		name = "Stillfang",
		zone = "Hoarfrost Expanse",
		arena = "The Still Fang",
		signature = "One crystal fang plants in the ice and is the blue interrupt.",
		lootTheme = "First kill that day: Matriarch's Frozen Fang. Later that day: Frost Pelt. First kill ever: Stillfang Pin, a tiny pale crystal fang on a white pin, strong cold glow, no stats.",
		visual = "Long low ice serpent, blue-white plates, one oversized pale crystal fang, strong cold glow.",
		phases = {
			{
				name = "Low Bite",
				suggestedHp = "100-70%",
				action = "Dodge the wide slow bite.",
				telegraph = "Very wide red line.",
			},
			{
				name = "Coil Rings",
				suggestedHp = "70-35%",
				action = "Step out of the rings along the body.",
				telegraph = "Four large purple rings.",
			},
			{
				name = "Planted Fang",
				suggestedHp = "35-0%",
				action = "Hit the planted fang.",
				telegraph = "The crystal fang glows blue, then a freeze pulse.",
			},
		},
	},
	{
		id = "hollow_regent",
		name = "Hollow Regent",
		zone = "Rift Margin",
		arena = "Regent's Step",
		signature = "A hole of light opens in the chest. The yellow circle shares the last hits.",
		lootTheme = "First kill that day: Sovereign's Hollow Core. Later that day: Void Dust. First kill ever: Regent Circlet, a thin gray ring with one violet gap, soft violet glow, no stats.",
		visual = "Tall mirrorless gray figure, no face, violet rim, a bright hole of light in the chest, rim glow across the field.",
		phases = {
			{
				name = "Dust Bolts",
				suggestedHp = "100-70%",
				action = "Step out of the landing circles.",
				telegraph = "Purple circles.",
			},
			{
				name = "Lit Rings",
				suggestedHp = "70-35%",
				action = "Stand in a lit ring when the field dims. The rings are huge.",
				telegraph = "Three violet glass rings stay bright.",
			},
			{
				name = "Open Core",
				suggestedHp = "35-0%",
				action = "Stand in the circle. Hits on the light count for everyone in it.",
				telegraph = "Yellow circle. A hole of light opens in the chest.",
			},
		},
	},
}
