--!strict

--[[
	First-session reward pacing. Pure rules.

	The first session rewards four steps, once each.
	  roll: Rare or better, matched to the class.
	  chest: a Rare weapon with one socket, plus a pet egg.
	  miniboss: an Uncommon armor piece.
	  forge: a free Uncommon ring.

	A returning player gets nothing. A step already granted, including
	by a skip, is not granted again. After the kit, nothing is rigged.
	A paid roll uses the same floor as a free roll. There is no paid skip.

	The caller passes what was rolled. This module says whether the
	guarantee still applies and whether that offer meets it. It does
	not roll, pick a template, or write the input. No clock. Nothing
	here costs Robux.

	It requires Rarities for the ladder and nothing else. Classes has
	no element field, so the class elements live in ELEMENTS. Nothing
	in src requires this module.
]]

local Rarities = require("./Rarities")

local FirstSession = {}

FirstSession.STEPS = table.freeze({ "roll", "chest", "miniboss", "forge" })

local ELEMENT_BY_CLASS: { [string]: string } = {
	warden = "Verdant",
	tidecaller = "Tide",
	forgeborn = "Fire",
	frostblade = "Frost",
	voidcaster = "Void",
}
FirstSession.ELEMENTS = table.freeze(ELEMENT_BY_CLASS)

FirstSession.CONFIG = table.freeze({
	rollFloor = "Rare",
	chestWeaponRarity = "Rare",
	chestSockets = 1,
	eggFloor = "Uncommon",
	armorRarity = "Uncommon",
	ringRarity = "Uncommon",
	ringCost = 0,
	shardKind = "shard",
	weaponKind = "Weapon",
	armorKind = "Armor",
	eggKind = "egg",
	ringKind = "Ring",
})

FirstSession.ERRORS = table.freeze({
	state = "That first-session record is unusable.",
	step = "That step is not in the first session.",
	offer = "That offer is unusable.",
	class = "That class is unusable.",
	rarity = "That rarity is not on the ladder.",
	picks = "Those element picks are unusable.",
	paid = "A paid skip is refused.",
	rules = "The first-session rules are unusable.",
})

export type Granted = {
	roll: boolean,
	chest: boolean,
	miniboss: boolean,
	forge: boolean,
}

export type State = {
	returning: boolean,
	granted: Granted,
}

export type Opened = {
	ok: boolean,
	state: State,
	error: string?,
}

export type Apply = {
	ok: boolean,
	state: State,
	step: string?,
	applies: boolean,
	rule: { [string]: any }?,
	error: string?,
}

export type Meet = {
	ok: boolean,
	step: string?,
	meets: boolean,
	rule: { [string]: any }?,
	error: string?,
}

export type Grant = {
	ok: boolean,
	state: State,
	step: string?,
	applies: boolean,
	meets: boolean,
	accepted: boolean,
	reward: { [string]: any }?,
	rule: { [string]: any }?,
	error: string?,
}

export type Skip = {
	ok: boolean,
	state: State,
	rewards: { { [string]: any } },
	error: string?,
}

export type Rigged = {
	ok: boolean,
	state: State,
	rigged: boolean,
	applies: Granted,
	error: string?,
}

type Judged = {
	meets: boolean,
	rule: { [string]: any },
	reward: { [string]: any }?,
}

local ERRORS = FirstSession.ERRORS
local CONFIG = FirstSession.CONFIG

local function whole(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < 0 or value ~= math.floor(value) then
		return nil
	end
	return value
end

local function isStep(value: any): boolean
	return value == "roll" or value == "chest" or value == "miniboss" or value == "forge"
end

local function blankGranted(): Granted
	return {
		roll = false,
		chest = false,
		miniboss = false,
		forge = false,
	}
end

local function blankState(): State
	return {
		returning = false,
		granted = blankGranted(),
	}
end

local function copyGranted(granted: Granted): Granted
	return {
		roll = granted.roll,
		chest = granted.chest,
		miniboss = granted.miniboss,
		forge = granted.forge,
	}
end

local function copyState(state: State): State
	return {
		returning = state.returning,
		granted = copyGranted(state.granted),
	}
end

local function rulesOk(): string?
	local floors = {
		CONFIG.rollFloor,
		CONFIG.chestWeaponRarity,
		CONFIG.eggFloor,
		CONFIG.armorRarity,
		CONFIG.ringRarity,
	}
	for _, floor in ipairs(floors) do
		if type(floor) ~= "string" or type(Rarities.INDEX[floor]) ~= "number" then
			return ERRORS.rules
		end
	end
	if CONFIG.chestSockets ~= 1 or CONFIG.ringCost ~= 0 then
		return ERRORS.rules
	end
	local kinds = {
		CONFIG.shardKind,
		CONFIG.weaponKind,
		CONFIG.armorKind,
		CONFIG.eggKind,
		CONFIG.ringKind,
	}
	for _, kind in ipairs(kinds) do
		if type(kind) ~= "string" or kind == "" then
			return ERRORS.rules
		end
	end
	local seen: { [string]: boolean } = {}
	local classes = 0
	for classId, element in pairs(ELEMENT_BY_CLASS) do
		if type(classId) ~= "string" or classId == "" then
			return ERRORS.rules
		end
		if type(element) ~= "string" or element == "" or seen[element] == true then
			return ERRORS.rules
		end
		seen[element] = true
		classes += 1
	end
	if classes ~= 5 then
		return ERRORS.rules
	end
	return nil
end

local function readGranted(value: any): (Granted?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	if type(value.roll) ~= "boolean" or type(value.chest) ~= "boolean" then
		return nil, ERRORS.state
	end
	if type(value.miniboss) ~= "boolean" or type(value.forge) ~= "boolean" then
		return nil, ERRORS.state
	end
	local seen = 0
	for key in pairs(value) do
		if key ~= "roll" and key ~= "chest" and key ~= "miniboss" and key ~= "forge" then
			return nil, ERRORS.state
		end
		seen += 1
	end
	if seen ~= 4 then
		return nil, ERRORS.state
	end
	return {
		roll = value.roll,
		chest = value.chest,
		miniboss = value.miniboss,
		forge = value.forge,
	},
		nil
end

local function readState(value: any): (State?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	if type(value.returning) ~= "boolean" then
		return nil, ERRORS.state
	end
	local seen = 0
	for key in pairs(value) do
		if key ~= "returning" and key ~= "granted" then
			return nil, ERRORS.state
		end
		seen += 1
	end
	if seen ~= 2 then
		return nil, ERRORS.state
	end
	local granted, grantedErr = readGranted(value.granted)
	if granted == nil then
		return nil, grantedErr or ERRORS.state
	end
	return {
		returning = value.returning,
		granted = granted,
	}, nil
end

local function stepOpen(state: State, step: string): boolean
	if state.returning then
		return false
	end
	if step == "roll" then
		return state.granted.roll == false
	elseif step == "chest" then
		return state.granted.chest == false
	elseif step == "miniboss" then
		return state.granted.miniboss == false
	elseif step == "forge" then
		return state.granted.forge == false
	end
	return false
end

local function withStep(state: State, step: string): State
	local granted = copyGranted(state.granted)
	if step == "roll" then
		granted.roll = true
	elseif step == "chest" then
		granted.chest = true
	elseif step == "miniboss" then
		granted.miniboss = true
	elseif step == "forge" then
		granted.forge = true
	end
	return {
		returning = state.returning,
		granted = granted,
	}
end

local function readClass(value: any): (string?, string?)
	if type(value) ~= "string" then
		return nil, ERRORS.class
	end
	local element = ELEMENT_BY_CLASS[value]
	if type(element) ~= "string" then
		return nil, ERRORS.class
	end
	return value, nil
end

local function paidShape(value: any): string?
	if value == nil or type(value) == "boolean" then
		return nil
	end
	return ERRORS.offer
end

local function arraySize(value: any): number?
	if type(value) ~= "table" then
		return nil
	end
	local count = #value
	local seen = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key > count or key ~= math.floor(key) then
			return nil
		end
		seen += 1
	end
	if seen ~= count then
		return nil
	end
	return count
end

local function knownElement(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	for _, element in pairs(ELEMENT_BY_CLASS) do
		if element == value then
			return true
		end
	end
	return false
end

local function readPicks(value: any, classElement: string): ({ string }?, string?)
	if value == nil then
		return nil, nil
	end
	local size = arraySize(value)
	if size ~= 2 then
		return nil, ERRORS.picks
	end
	local first = value[1]
	local second = value[2]
	if not knownElement(first) or not knownElement(second) or first == second then
		return nil, ERRORS.picks
	end
	if first ~= classElement and second ~= classElement then
		return nil, ERRORS.picks
	end
	return { first, second }, nil
end

local function compare(rarity: any, floor: string, exact: boolean): (boolean?, string?)
	if type(rarity) ~= "string" then
		return nil, ERRORS.rarity
	end
	local rank = Rarities.INDEX[rarity]
	local floorRank = Rarities.INDEX[floor]
	if type(rank) ~= "number" or type(floorRank) ~= "number" then
		return nil, ERRORS.rarity
	end
	if exact then
		return rarity == floor, nil
	end
	return rank >= floorRank, nil
end

local function readCost(value: any): (number?, string?)
	if value == nil then
		return 0, nil
	end
	local cost = whole(value)
	if cost == nil then
		return nil, ERRORS.offer
	end
	return cost, nil
end

local function rollRule(classId: string?, picks: { string }?): { [string]: any }
	local rule: { [string]: any } = {
		step = "roll",
		kind = CONFIG.shardKind,
		floor = CONFIG.rollFloor,
		orBetter = true,
		match = "class",
	}
	if classId ~= nil then
		rule.classId = classId
		rule.element = ELEMENT_BY_CLASS[classId]
	end
	if picks ~= nil then
		rule.picks = { picks[1], picks[2] }
	end
	return rule
end

local function chestRule(classId: string?): { [string]: any }
	local weapon: { [string]: any } = {
		kind = CONFIG.weaponKind,
		floor = CONFIG.chestWeaponRarity,
		exact = true,
		sockets = CONFIG.chestSockets,
		match = "class",
	}
	if classId ~= nil then
		weapon.classId = classId
	end
	return {
		step = "chest",
		weapon = weapon,
		egg = {
			kind = CONFIG.eggKind,
			floor = CONFIG.eggFloor,
			orBetter = true,
		},
	}
end

local function armorRule(): { [string]: any }
	return {
		step = "miniboss",
		kind = CONFIG.armorKind,
		floor = CONFIG.armorRarity,
		exact = true,
	}
end

local function ringRule(): { [string]: any }
	return {
		step = "forge",
		kind = CONFIG.ringKind,
		floor = CONFIG.ringRarity,
		exact = true,
		cost = CONFIG.ringCost,
	}
end

local function ruleFor(step: string, classId: string?): { [string]: any }
	if step == "roll" then
		return rollRule(classId, nil)
	elseif step == "chest" then
		return chestRule(classId)
	elseif step == "miniboss" then
		return armorRule()
	end
	return ringRule()
end

local function judgeRoll(offer: { [string]: any }): (Judged?, string?)
	local shapeErr = paidShape(offer.paid)
	if shapeErr ~= nil then
		return nil, shapeErr
	end
	local classId, classErr = readClass(offer.classId)
	if classId == nil then
		return nil, classErr or ERRORS.class
	end
	local classElement = ELEMENT_BY_CLASS[classId]
	local picks, picksErr = readPicks(offer.picks, classElement)
	if picksErr ~= nil then
		return nil, picksErr
	end
	if type(offer.element) ~= "string" or offer.element == "" then
		return nil, ERRORS.offer
	end
	local highEnough, rarityErr = compare(offer.rarity, CONFIG.rollFloor, false)
	if highEnough == nil then
		return nil, rarityErr or ERRORS.rarity
	end
	local elementMatches = false
	if picks == nil then
		elementMatches = offer.element == classElement
	else
		elementMatches = offer.element == picks[1] or offer.element == picks[2]
	end
	local meets = highEnough == true and elementMatches
	local reward = nil
	if meets then
		reward = {
			step = "roll",
			kind = CONFIG.shardKind,
			rarity = offer.rarity,
			floor = CONFIG.rollFloor,
			orBetter = true,
			match = "class",
			classId = classId,
			element = offer.element,
		}
		if picks ~= nil then
			reward.picks = { picks[1], picks[2] }
		end
	end
	return {
		meets = meets,
		rule = rollRule(classId, picks),
		reward = reward,
	}, nil
end

local function judgeChest(offer: { [string]: any }): (Judged?, string?)
	local shapeErr = paidShape(offer.paid)
	if shapeErr ~= nil then
		return nil, shapeErr
	end
	local weapon = offer.weapon
	local egg = offer.egg
	if type(weapon) ~= "table" or type(egg) ~= "table" then
		return nil, ERRORS.offer
	end
	if type(weapon.kind) ~= "string" or type(egg.kind) ~= "string" then
		return nil, ERRORS.offer
	end
	local classId, classErr = readClass(weapon.classId)
	if classId == nil then
		return nil, classErr or ERRORS.class
	end
	local sameClass = true
	if offer.classId ~= nil then
		local offerClass, offerErr = readClass(offer.classId)
		if offerClass == nil then
			return nil, offerErr or ERRORS.class
		end
		sameClass = offerClass == classId
	end
	local sockets = whole(weapon.sockets)
	if sockets == nil then
		return nil, ERRORS.offer
	end
	local weaponExact, weaponErr = compare(weapon.rarity, CONFIG.chestWeaponRarity, true)
	if weaponExact == nil then
		return nil, weaponErr or ERRORS.rarity
	end
	local eggHigh, eggErr = compare(egg.rarity, CONFIG.eggFloor, false)
	if eggHigh == nil then
		return nil, eggErr or ERRORS.rarity
	end
	local meets = weapon.kind == CONFIG.weaponKind
		and egg.kind == CONFIG.eggKind
		and sameClass
		and weaponExact == true
		and sockets == CONFIG.chestSockets
		and eggHigh == true
	local reward = nil
	if meets then
		reward = {
			step = "chest",
			weapon = {
				kind = CONFIG.weaponKind,
				rarity = weapon.rarity,
				sockets = sockets,
				classId = classId,
			},
			egg = {
				kind = CONFIG.eggKind,
				rarity = egg.rarity,
				floor = CONFIG.eggFloor,
				orBetter = true,
			},
		}
	end
	return {
		meets = meets,
		rule = chestRule(classId),
		reward = reward,
	}, nil
end

local function judgeArmor(offer: { [string]: any }): (Judged?, string?)
	local shapeErr = paidShape(offer.paid)
	if shapeErr ~= nil then
		return nil, shapeErr
	end
	if offer.classId ~= nil then
		local _, classErr = readClass(offer.classId)
		if classErr ~= nil then
			return nil, classErr
		end
	end
	if type(offer.kind) ~= "string" then
		return nil, ERRORS.offer
	end
	local exact, rarityErr = compare(offer.rarity, CONFIG.armorRarity, true)
	if exact == nil then
		return nil, rarityErr or ERRORS.rarity
	end
	local meets = offer.kind == CONFIG.armorKind and exact == true
	local reward = nil
	if meets then
		reward = {
			step = "miniboss",
			kind = CONFIG.armorKind,
			rarity = offer.rarity,
			floor = CONFIG.armorRarity,
			exact = true,
		}
	end
	return {
		meets = meets,
		rule = armorRule(),
		reward = reward,
	}, nil
end

local function judgeRing(offer: { [string]: any }): (Judged?, string?)
	local shapeErr = paidShape(offer.paid)
	if shapeErr ~= nil then
		return nil, shapeErr
	end
	if offer.classId ~= nil then
		local _, classErr = readClass(offer.classId)
		if classErr ~= nil then
			return nil, classErr
		end
	end
	if type(offer.kind) ~= "string" then
		return nil, ERRORS.offer
	end
	local exact, rarityErr = compare(offer.rarity, CONFIG.ringRarity, true)
	if exact == nil then
		return nil, rarityErr or ERRORS.rarity
	end
	local cost, costErr = readCost(offer.cost)
	if cost == nil then
		return nil, costErr or ERRORS.offer
	end
	local robux, robuxErr = readCost(offer.robux)
	if robux == nil then
		return nil, robuxErr or ERRORS.offer
	end
	local free = cost == 0 and robux == 0 and offer.productId == nil
	local meets = offer.kind == CONFIG.ringKind and exact == true and free
	local reward = nil
	if meets then
		reward = {
			step = "forge",
			kind = CONFIG.ringKind,
			rarity = offer.rarity,
			floor = CONFIG.ringRarity,
			exact = true,
			cost = 0,
		}
	end
	return {
		meets = meets,
		rule = ringRule(),
		reward = reward,
	}, nil
end

local function judge(step: string, offer: any): (Judged?, string?)
	if type(offer) ~= "table" then
		return nil, ERRORS.offer
	end
	if step == "roll" then
		return judgeRoll(offer)
	elseif step == "chest" then
		return judgeChest(offer)
	elseif step == "miniboss" then
		return judgeArmor(offer)
	end
	return judgeRing(offer)
end

local function failApply(state: State, err: string): Apply
	return {
		ok = false,
		state = state,
		applies = false,
		error = err,
	}
end

local function failMeet(err: string, step: string?): Meet
	return {
		ok = false,
		step = step,
		meets = false,
		error = err,
	}
end

local function failGrant(state: State, err: string, step: string?): Grant
	return {
		ok = false,
		state = state,
		step = step,
		applies = false,
		meets = false,
		accepted = false,
		error = err,
	}
end

local function failSkip(state: State, err: string): Skip
	return {
		ok = false,
		state = state,
		rewards = {},
		error = err,
	}
end

local function failRigged(state: State, err: string): Rigged
	return {
		ok = false,
		state = state,
		rigged = false,
		applies = blankGranted(),
		error = err,
	}
end

function FirstSession.fresh(options: any): Opened
	local broken = rulesOk()
	if broken ~= nil then
		return {
			ok = false,
			state = blankState(),
			error = broken,
		}
	end
	if options == nil then
		return {
			ok = true,
			state = blankState(),
		}
	end
	if type(options) ~= "table" then
		return {
			ok = false,
			state = blankState(),
			error = ERRORS.state,
		}
	end
	for key in pairs(options) do
		if key ~= "returning" then
			return {
				ok = false,
				state = blankState(),
				error = ERRORS.state,
			}
		end
	end
	if options.returning ~= nil and type(options.returning) ~= "boolean" then
		return {
			ok = false,
			state = blankState(),
			error = ERRORS.state,
		}
	end
	return {
		ok = true,
		state = {
			returning = options.returning == true,
			granted = blankGranted(),
		},
	}
end

function FirstSession.applies(state: any, step: any, classId: any): Apply
	local broken = rulesOk()
	if broken ~= nil then
		return failApply(blankState(), broken)
	end
	local current, stateErr = readState(state)
	if current == nil then
		return failApply(blankState(), stateErr or ERRORS.state)
	end
	if not isStep(step) then
		return failApply(copyState(current), ERRORS.step)
	end
	if classId ~= nil then
		local _, classErr = readClass(classId)
		if classErr ~= nil then
			return failApply(copyState(current), classErr)
		end
	end
	local live = stepOpen(current, step)
	local knownClass = if type(classId) == "string" then classId else nil
	return {
		ok = true,
		state = copyState(current),
		step = step,
		applies = live,
		rule = if live then ruleFor(step, knownClass) else nil,
	}
end

function FirstSession.meets(step: any, offer: any): Meet
	local broken = rulesOk()
	if broken ~= nil then
		return failMeet(broken, nil)
	end
	if not isStep(step) then
		return failMeet(ERRORS.step, nil)
	end
	local judged, judgeErr = judge(step, offer)
	if judged == nil then
		return failMeet(judgeErr or ERRORS.offer, step)
	end
	return {
		ok = true,
		step = step,
		meets = judged.meets,
		rule = judged.rule,
	}
end

function FirstSession.grant(state: any, step: any, offer: any): Grant
	local broken = rulesOk()
	if broken ~= nil then
		return failGrant(blankState(), broken, nil)
	end
	local current, stateErr = readState(state)
	if current == nil then
		return failGrant(blankState(), stateErr or ERRORS.state, nil)
	end
	if not isStep(step) then
		return failGrant(copyState(current), ERRORS.step, nil)
	end
	local judged, judgeErr = judge(step, offer)
	if judged == nil then
		return failGrant(copyState(current), judgeErr or ERRORS.offer, step)
	end
	local live = stepOpen(current, step)
	if live and judged.meets then
		return {
			ok = true,
			state = withStep(current, step),
			step = step,
			applies = true,
			meets = true,
			accepted = true,
			reward = judged.reward,
			rule = judged.rule,
		}
	end
	return {
		ok = true,
		state = copyState(current),
		step = step,
		applies = live,
		meets = judged.meets,
		accepted = false,
		rule = if live then judged.rule else nil,
	}
end

local function skipPaid(request: any): (boolean?, string?)
	if type(request) ~= "table" then
		return nil, ERRORS.offer
	end
	if request.paid ~= nil and type(request.paid) ~= "boolean" then
		return nil, ERRORS.offer
	end
	if request.paid == true or request.productId ~= nil then
		return true, nil
	end
	local cost, costErr = readCost(request.cost)
	if cost == nil then
		return nil, costErr or ERRORS.offer
	end
	local robux, robuxErr = readCost(request.robux)
	if robux == nil then
		return nil, robuxErr or ERRORS.offer
	end
	if cost ~= 0 or robux ~= 0 then
		return true, nil
	end
	return false, nil
end

function FirstSession.skip(state: any, request: any): Skip
	local broken = rulesOk()
	if broken ~= nil then
		return failSkip(blankState(), broken)
	end
	local current, stateErr = readState(state)
	if current == nil then
		return failSkip(blankState(), stateErr or ERRORS.state)
	end
	local paid, paidErr = skipPaid(request)
	if paid == nil then
		return failSkip(copyState(current), paidErr or ERRORS.offer)
	end
	if paid then
		return failSkip(copyState(current), ERRORS.paid)
	end
	if current.returning then
		return {
			ok = true,
			state = copyState(current),
			rewards = {},
		}
	end
	local needsClass = stepOpen(current, "roll") or stepOpen(current, "chest")
	local classId = nil
	if needsClass or request.classId ~= nil then
		local read, classErr = readClass(request.classId)
		if read == nil then
			return failSkip(copyState(current), classErr or ERRORS.class)
		end
		classId = read
	end
	local rewards = {}
	local nextState = copyState(current)
	if stepOpen(current, "roll") then
		table.insert(rewards, rollRule(classId, nil))
		nextState = withStep(nextState, "roll")
	end
	if stepOpen(current, "chest") then
		table.insert(rewards, chestRule(classId))
		nextState = withStep(nextState, "chest")
	end
	if stepOpen(current, "miniboss") then
		table.insert(rewards, armorRule())
		nextState = withStep(nextState, "miniboss")
	end
	if stepOpen(current, "forge") then
		table.insert(rewards, ringRule())
		nextState = withStep(nextState, "forge")
	end
	return {
		ok = true,
		state = nextState,
		rewards = rewards,
	}
end

function FirstSession.rigged(state: any): Rigged
	local broken = rulesOk()
	if broken ~= nil then
		return failRigged(blankState(), broken)
	end
	local current, stateErr = readState(state)
	if current == nil then
		return failRigged(blankState(), stateErr or ERRORS.state)
	end
	local flags = {
		roll = stepOpen(current, "roll"),
		chest = stepOpen(current, "chest"),
		miniboss = stepOpen(current, "miniboss"),
		forge = stepOpen(current, "forge"),
	}
	return {
		ok = true,
		state = copyState(current),
		rigged = flags.roll or flags.chest or flags.miniboss or flags.forge,
		applies = flags,
	}
end

return FirstSession
