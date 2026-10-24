--!strict

--[[
	G-101. Suggested world-boss rows from docs/content/bosses.md.

	Eight field bosses. Each row has a name, a zone, three phases,
	a signature, a loot theme, and a visual. Phase bands, the 90
	stud nearby range, the 2 second roar, and the 5 minute leash
	are suggested. They are not live numbers. No chest. No Robux.
	No stat on the first-kill cosmetic.

	mireoak is already the Waves mini-boss id in Dungeons.luau.
	That row stays. The other seven ids are not live enemy ids.
	This file does not change Dungeons.luau or Raids.luau.
]]

return {
	{
		id = "mireoak",
		name = "Mireoak",
		zone = "Far Glade",
		arena = "Mireoak's Bowl",
		signature = "The amber knot takes the last hits, and the yellow circle shares them.",
		lootTheme = "Suggested. First kill that day: Heartwood. Repeat that day: Verdant Bark. No chest. No Robux.",
		visual = "Wide walking oak, mud-brown bark, short root legs, one amber knot, calm amber eye-lights, soft amber glow.",
		cosmetic = "Mire Lamp",
		cosmeticVisual = "A small amber knot in an iron cage. Soft amber glow. No stats.",
		note = "Live Waves mini-boss id in Dungeons. The field spawn, Heartwood drop, and Mire Lamp are not wired. Do not replace the waves row.",
		phases = {
			{
				name = "Mud Ring",
				suggestedBand = "100-70%",
				action = "Step out of the rings.",
				telegraph = "Purple rings under players.",
			},
			{
				name = "Root Charge",
				suggestedBand = "70-35%",
				action = "Dodge to the side.",
				telegraph = "Red line, then a straight rush.",
			},
			{
				name = "Amber Knot",
				suggestedBand = "35-0%",
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
		lootTheme = "Suggested. First kill that day: Black Pearl. Repeat that day: Coral Shard. No chest. No Robux.",
		visual = "Giant low tortoise, white salt crust, one clear horn, teal rim, steady rim glow.",
		cosmetic = "Glasshorn Crest",
		cosmeticVisual = "A small clear horn on a salt-white plate. Steady pale glow. No stats.",
		phases = {
			{
				name = "Salt Cone",
				suggestedBand = "100-70%",
				action = "Dodge sideways.",
				telegraph = "Red cone of salt spray.",
			},
			{
				name = "Horn Bell",
				suggestedBand = "70-35%",
				action = "Hit the glowing horn.",
				telegraph = "Blue charge on the horn, then a wide pulse.",
			},
			{
				name = "Glass Plates",
				suggestedBand = "35-0%",
				action = "Stand on a plate. The plates are huge. No jump.",
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
		lootTheme = "Suggested. First kill that day: Leviathan Crown-Scale. Repeat that day: Coral Shard. No chest. No Robux.",
		visual = "Long whale-eel, deep blue, one gold-blue brow scale, soft lamp spots down the side. No blood.",
		cosmetic = "Brine Clasp",
		cosmeticVisual = "A gold-blue scale on a teal pin. Steady scale glow. No stats.",
		phases = {
			{
				name = "Tail Sweep",
				suggestedBand = "100-70%",
				action = "Dodge the slow arc.",
				telegraph = "Wide red arc.",
			},
			{
				name = "Scale Flash",
				suggestedBand = "70-35%",
				action = "Step off the rings around the brow scale.",
				telegraph = "Purple rings at the gold-blue scale.",
			},
			{
				name = "Jaw Breach",
				suggestedBand = "35-0%",
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
		lootTheme = "Suggested. First kill that day: Molten Core. Repeat that day: Cinder Ore. No chest. No Robux.",
		visual = "Bulky walking heap, charcoal rock, orange cracks, bright crack glow, no face.",
		cosmetic = "Slag Cloak",
		cosmeticVisual = "A short charcoal cloak with one orange seam. Steady seam glow. No stats.",
		phases = {
			{
				name = "Slow Slam",
				suggestedBand = "100-70%",
				action = "Step out of the circle.",
				telegraph = "Red circle, slow.",
			},
			{
				name = "Slag Path",
				suggestedBand = "70-35%",
				action = "Do not stand in the path it walks.",
				telegraph = "Purple pools behind it.",
			},
			{
				name = "Cool Vent",
				suggestedBand = "35-0%",
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
		lootTheme = "Suggested. First kill that day: Tyrant's Ember Heart. Repeat that day: Cinder Ore. No chest. No Robux.",
		visual = "Huge seated slag figure, dark iron, a cinder crown, one orange crystal in the chest, bright crystal glow.",
		cosmetic = "Cinderseat Charm",
		cosmeticVisual = "A tiny orange crystal in a dark iron cage. Bright crystal glow. No stats.",
		phases = {
			{
				name = "Mace Arc",
				suggestedBand = "100-70%",
				action = "Dodge back.",
				telegraph = "Wide red arc from the seated swing.",
			},
			{
				name = "Blue Vents",
				suggestedBand = "70-35%",
				action = "Stand in a floor vent while the crystal holds.",
				telegraph = "Three blue floor vents, large.",
			},
			{
				name = "Open Crystal",
				suggestedBand = "35-0%",
				action = "Stand at the chair's foot. Hits on the crystal count for everyone in the circle.",
				telegraph = "Yellow circle. The orange crystal opens. It is a crystal, not a wound.",
			},
		},
	},
	{
		id = "pane_strider",
		name = "Pane Strider",
		zone = "Hoarfrost Expanse",
		arena = "Pane Strider's Run",
		signature = "You track its blue glow when the field goes white.",
		lootTheme = "Suggested. First kill that day: Everfrost Gem. Repeat that day: Frost Pelt. No chest. No Robux.",
		visual = "Tall ice strider, clear pane antlers, blue-white body, strong blue eye glow, short frost trail.",
		cosmetic = "Pane Halo",
		cosmeticVisual = "A thin clear ring that sits over the shoulders. Soft blue edge glow. No stats.",
		phases = {
			{
				name = "Antler Sweep",
				suggestedBand = "100-70%",
				action = "Dodge the slow arc.",
				telegraph = "Red arc from the pane antlers.",
			},
			{
				name = "White Gust",
				suggestedBand = "70-35%",
				action = "Step out of the circles. Follow the blue eye glow. The body stays visible.",
				telegraph = "The field whitens. Purple circles mark the gusts.",
			},
			{
				name = "Warm Breath",
				suggestedBand = "35-0%",
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
		lootTheme = "Suggested. First kill that day: Matriarch's Frozen Fang. Repeat that day: Frost Pelt. No chest. No Robux.",
		visual = "Long low ice serpent, blue-white plates, one oversized pale crystal fang, strong cold glow.",
		cosmetic = "Stillfang Pin",
		cosmeticVisual = "A tiny pale crystal fang on a white pin. Strong cold glow. No stats.",
		phases = {
			{
				name = "Low Bite",
				suggestedBand = "100-70%",
				action = "Dodge the wide slow bite.",
				telegraph = "Very wide red line.",
			},
			{
				name = "Coil Rings",
				suggestedBand = "70-35%",
				action = "Step out of the rings along the body.",
				telegraph = "Four large purple rings.",
			},
			{
				name = "Planted Fang",
				suggestedBand = "35-0%",
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
		lootTheme = "Suggested. First kill that day: Sovereign's Hollow Core. Repeat that day: Void Dust. No chest. No Robux.",
		visual = "Tall mirrorless gray figure, no face, violet rim, a bright hole of light in the chest, rim glow across the field.",
		cosmetic = "Regent Circlet",
		cosmeticVisual = "A thin gray ring with one violet gap. Soft violet glow. No stats.",
		phases = {
			{
				name = "Dust Bolts",
				suggestedBand = "100-70%",
				action = "Step out of the landing circles.",
				telegraph = "Purple circles.",
			},
			{
				name = "Lit Rings",
				suggestedBand = "70-35%",
				action = "Stand in a lit ring when the field dims. The rings are huge.",
				telegraph = "Three violet glass rings stay bright.",
			},
			{
				name = "Open Core",
				suggestedBand = "35-0%",
				action = "Stand in the circle. Hits on the light count for everyone in it.",
				telegraph = "Yellow circle. A hole of light opens in the chest.",
			},
		},
	},
}
