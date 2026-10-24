--!strict

--[[
	Strategy Board markers.

	The raid lead places markers on one shared top-down board. The whole
	party reads that board. Assistants and every other role cannot place,
	move, or remove. Kinds are stack, soak1, and soak2. A marker is
	{ id, kind, x, y } with x and y in 0..1 inclusive.

	Presets are named and keyed by a caller-supplied guild id. save copies
	the current markers. load returns a new board and does not write the
	preset. The board is not per player and it is not loot.

	Practice, difficulty, and the Tuesday week do not change these rules.
	Each call returns a new table and does not write its input. Tunables
	live in CONFIG. Nothing here costs Robux. There is no paid marker,
	preset, or skip.
]]

local RaidStrategy = {}

local MAX_SAFE = 9007199254740991

local KINDS = table.freeze({
	stack = true,
	soak1 = true,
	soak2 = true,
})

RaidStrategy.CONFIG = table.freeze({
	-- Placeholder. A full board refuses a new marker instead of dropping one.
	maxMarkers = 16,
	-- Placeholder. Saved presets per guild, not a global cap.
	maxPresets = 8,
	-- Placeholder cap for a marker id, a preset name, and a guild id.
	maxIdLength = 64,
	-- Only this role may place, move, or remove. Compared after trim and lower.
	leadRole = "lead",
	kinds = KINDS,
})

RaidStrategy.ERRORS = table.freeze({
	rules = "The strategy board rules are unusable.",
	state = "That strategy board is unusable.",
	presets = "Those guild presets are unusable.",
	request = "That marker request is unusable.",
	role = "Only the raid lead can change the board.",
	id = "That marker id is unusable.",
	kind = "That marker kind is unusable.",
	coord = "That marker coordinate is unusable.",
	missing = "That marker is not on the board.",
	full = "That board is full.",
	guild = "That guild id is unusable.",
	name = "That preset name is unusable.",
	preset = "That preset is not saved.",
	presetsFull = "That guild's preset list is full.",
	skip = "The strategy board has no paid marker, preset, or skip.",
})

-- A present field is refused even when the value is false.
local SKIP = table.freeze({
	skip = true,
	waive = true,
	waiveLock = true,
	waiveLockout = true,
	bypass = true,
	bypassLock = true,
	paid = true,
	robux = true,
	premium = true,
	price = true,
	productId = true,
	gamePass = true,
	force = true,
	unlock = true,
	skipLock = true,
	skipLockout = true,
	paidMarker = true,
	paidPreset = true,
	skipCap = true,
	buyMarker = true,
	buyPreset = true,
})

export type Marker = {
	id: string,
	kind: string,
	x: number,
	y: number,
}

export type Board = {
	markers: { Marker },
}

export type Preset = {
	name: string,
	markers: { Marker },
}

export type GuildPresets = {
	guildId: string,
	presets: { Preset },
}

export type Store = {
	guilds: { GuildPresets },
}

export type BoardResult = {
	ok: boolean,
	persist: boolean,
	state: Board,
	error: string?,
}

export type PresetResult = {
	ok: boolean,
	persist: boolean,
	state: Store,
	board: Board,
	error: string?,
}

type Limits = {
	maxMarkers: number,
	maxPresets: number,
	idCap: number,
}

local ERRORS = RaidStrategy.ERRORS

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function wholeBetween(value: any, minimum: number, maximum: number): number?
	local number = finite(value)
	if number == nil or number < minimum or number > maximum or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function positive(value: any): number?
	return wholeBetween(value, 1, MAX_SAFE)
end

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
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

local function stringKeyed(value: { [any]: any }): boolean
	for key in pairs(value) do
		if type(key) ~= "string" then
			return false
		end
	end
	return true
end

local function skipField(value: { [any]: any }): boolean
	for key in pairs(SKIP) do
		if value[key] ~= nil then
			return true
		end
	end
	return false
end

local function blankBoard(): Board
	return {
		markers = {},
	}
end

local function blankStore(): Store
	return {
		guilds = {},
	}
end

local function copyMarker(marker: Marker): Marker
	return {
		id = marker.id,
		kind = marker.kind,
		x = marker.x,
		y = marker.y,
	}
end

local function copyMarkers(markers: { Marker }): { Marker }
	local copy = {}
	for _, marker in ipairs(markers) do
		table.insert(copy, copyMarker(marker))
	end
	return copy
end

local function boardFrom(markers: { Marker }): Board
	return {
		markers = copyMarkers(markers),
	}
end

local function sameMarker(left: Marker, right: Marker): boolean
	return left.id == right.id
		and left.kind == right.kind
		and left.x == right.x
		and left.y == right.y
end

local function sameList(left: { Marker }, right: { Marker }): boolean
	if #left ~= #right then
		return false
	end
	for index, marker in ipairs(left) do
		if not sameMarker(marker, right[index]) then
			return false
		end
	end
	return true
end

local function kindsOk(): boolean
	local kinds = RaidStrategy.CONFIG.kinds
	if type(kinds) ~= "table" then
		return false
	end
	local count = 0
	for key, value in pairs(kinds) do
		if type(key) ~= "string" or value ~= true then
			return false
		end
		if key ~= "stack" and key ~= "soak1" and key ~= "soak2" then
			return false
		end
		count += 1
	end
	return count == 3
end

local function rules(): (Limits?, string?)
	local maxMarkers = positive(RaidStrategy.CONFIG.maxMarkers)
	local maxPresets = positive(RaidStrategy.CONFIG.maxPresets)
	local idCap = positive(RaidStrategy.CONFIG.maxIdLength)
	if maxMarkers == nil or maxPresets == nil or idCap == nil then
		return nil, ERRORS.rules
	end
	if RaidStrategy.CONFIG.leadRole ~= "lead" or not kindsOk() then
		return nil, ERRORS.rules
	end
	return {
		maxMarkers = maxMarkers,
		maxPresets = maxPresets,
		idCap = idCap,
	}, nil
end

local function unit(value: any): number?
	local number = finite(value)
	if number == nil or number < 0 or number > 1 then
		return nil
	end
	if number == 0 then
		return 0
	end
	return number
end

local function storedLabel(value: any, cap: number): string?
	if type(value) ~= "string" then
		return nil
	end
	if value == "" or value ~= trim(value) or #value > cap then
		return nil
	end
	return value
end

local function storedKind(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	if (RaidStrategy.CONFIG.kinds :: any)[value] ~= true then
		return nil
	end
	return value
end

local function readMarker(value: any, cap: number): Marker?
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil
	end
	local id = storedLabel(value.id, cap)
	local kind = storedKind(value.kind)
	local x = unit(value.x)
	local y = unit(value.y)
	if id == nil or kind == nil or x == nil or y == nil then
		return nil
	end
	return {
		id = id,
		kind = kind,
		x = x,
		y = y,
	}
end

local function readMarkers(value: any, limits: Limits, bad: string): ({ Marker }?, string?)
	if value == nil then
		return {}, nil
	end
	local count = arraySize(value)
	if count == nil or count > limits.maxMarkers then
		return nil, bad
	end
	local markers = {}
	local seen: { [string]: boolean } = {}
	for index = 1, count do
		local marker = readMarker(value[index], limits.idCap)
		if marker == nil then
			return nil, bad
		end
		if seen[marker.id] == true then
			return nil, bad
		end
		seen[marker.id] = true
		table.insert(markers, marker)
	end
	return markers, nil
end

local function readBoard(value: any, limits: Limits): (Board?, string?)
	if value == nil then
		return blankBoard(), nil
	end
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, ERRORS.state
	end
	local markers, markerError = readMarkers(value.markers, limits, ERRORS.state)
	if markers == nil then
		return nil, markerError or ERRORS.state
	end
	return {
		markers = markers,
	}, nil
end

local function readPreset(value: any, limits: Limits): (Preset?, string?)
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, ERRORS.presets
	end
	local name = storedLabel(value.name, limits.idCap)
	if name == nil then
		return nil, ERRORS.presets
	end
	local markers, markerError = readMarkers(value.markers, limits, ERRORS.presets)
	if markers == nil then
		return nil, markerError or ERRORS.presets
	end
	return {
		name = name,
		markers = markers,
	}, nil
end

local function readGuild(value: any, limits: Limits): (GuildPresets?, string?)
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, ERRORS.presets
	end
	local guildId = storedLabel(value.guildId, limits.idCap)
	if guildId == nil then
		return nil, ERRORS.presets
	end
	local listed = value.presets
	if listed == nil then
		listed = {}
	end
	local count = arraySize(listed)
	if count == nil or count > limits.maxPresets then
		return nil, ERRORS.presets
	end
	local presets = {}
	local seen: { [string]: boolean } = {}
	for index = 1, count do
		local preset, presetError = readPreset(listed[index], limits)
		if preset == nil then
			return nil, presetError or ERRORS.presets
		end
		if seen[preset.name] == true then
			return nil, ERRORS.presets
		end
		seen[preset.name] = true
		table.insert(presets, preset)
	end
	return {
		guildId = guildId,
		presets = presets,
	}, nil
end

local function readStore(value: any, limits: Limits): (Store?, string?)
	if value == nil then
		return blankStore(), nil
	end
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, ERRORS.presets
	end
	if value.guilds == nil then
		return blankStore(), nil
	end
	local count = arraySize(value.guilds)
	if count == nil then
		return nil, ERRORS.presets
	end
	local guilds = {}
	local seen: { [string]: boolean } = {}
	for index = 1, count do
		local guild, guildError = readGuild(value.guilds[index], limits)
		if guild == nil then
			return nil, guildError or ERRORS.presets
		end
		if seen[guild.guildId] == true then
			return nil, ERRORS.presets
		end
		seen[guild.guildId] = true
		table.insert(guilds, guild)
	end
	return {
		guilds = guilds,
	}, nil
end

local function parseLabel(value: any, cap: number, message: string): (string?, string?)
	if type(value) ~= "string" then
		return nil, message
	end
	local trimmed = trim(value)
	if trimmed == "" or #trimmed > cap then
		return nil, message
	end
	return trimmed, nil
end

local function parseRole(value: any): (string?, string?)
	if type(value) ~= "string" then
		return nil, ERRORS.role
	end
	local trimmed = string.lower(trim(value))
	if trimmed == "" or trimmed ~= RaidStrategy.CONFIG.leadRole then
		return nil, ERRORS.role
	end
	return trimmed, nil
end

local function parseKind(value: any): (string?, string?)
	if type(value) ~= "string" then
		return nil, ERRORS.kind
	end
	local trimmed = string.lower(trim(value))
	if (RaidStrategy.CONFIG.kinds :: any)[trimmed] ~= true then
		return nil, ERRORS.kind
	end
	return trimmed, nil
end

local function findId(markers: { Marker }, id: string): number?
	for index, marker in ipairs(markers) do
		if marker.id == id then
			return index
		end
	end
	return nil
end

local function findGuild(store: Store, guildId: string): GuildPresets?
	for _, guild in ipairs(store.guilds) do
		if guild.guildId == guildId then
			return guild
		end
	end
	return nil
end

local function findPreset(guild: GuildPresets, name: string): Preset?
	for _, preset in ipairs(guild.presets) do
		if preset.name == name then
			return preset
		end
	end
	return nil
end

local function okBoard(state: Board, persist: boolean): BoardResult
	return {
		ok = true,
		persist = persist,
		state = state,
		error = nil,
	}
end

local function deniedBoard(message: string, state: Board?): BoardResult
	local kept = state
	if kept == nil then
		kept = blankBoard()
	end
	return {
		ok = false,
		persist = false,
		state = kept,
		error = message,
	}
end

local function okPreset(state: Store, persist: boolean, markers: { Marker }): PresetResult
	return {
		ok = true,
		persist = persist,
		state = state,
		board = boardFrom(markers),
		error = nil,
	}
end

local function deniedPreset(message: string, state: Store?): PresetResult
	local kept = state
	if kept == nil then
		kept = blankStore()
	end
	return {
		ok = false,
		persist = false,
		state = kept,
		board = blankBoard(),
		error = message,
	}
end

local function prepareBoard(board: any, extra: any): (Limits?, Board?, BoardResult?)
	if extra ~= nil then
		return nil, nil, deniedBoard(ERRORS.skip, nil)
	end
	local limits, rulesError = rules()
	if limits == nil then
		return nil, nil, deniedBoard(rulesError or ERRORS.rules, nil)
	end
	local record, stateError = readBoard(board, limits)
	if record == nil then
		return nil, nil, deniedBoard(stateError or ERRORS.state, nil)
	end
	return limits, record, nil
end

local function prepareStore(store: any, extra: any): (Limits?, Store?, PresetResult?)
	if extra ~= nil then
		return nil, nil, deniedPreset(ERRORS.skip, nil)
	end
	local limits, rulesError = rules()
	if limits == nil then
		return nil, nil, deniedPreset(rulesError or ERRORS.rules, nil)
	end
	local record, storeError = readStore(store, limits)
	if record == nil then
		return nil, nil, deniedPreset(storeError or ERRORS.presets, nil)
	end
	return limits, record, nil
end

local function requestOf(
	value: any,
	record: Board?,
	message: string
): ({ [string]: any }?, BoardResult?)
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, deniedBoard(message, record)
	end
	if skipField(value) then
		return nil, deniedBoard(ERRORS.skip, record)
	end
	return value, nil
end

local function storeRequestOf(value: any, record: Store?): ({ [string]: any }?, PresetResult?)
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, deniedPreset(ERRORS.request, record)
	end
	if skipField(value) then
		return nil, deniedPreset(ERRORS.skip, record)
	end
	return value, nil
end

function RaidStrategy.fresh(): Board
	return blankBoard()
end

function RaidStrategy.freshPresets(): Store
	return blankStore()
end

function RaidStrategy.view(board: any, extra: any): BoardResult
	local _, record, failure = prepareBoard(board, extra)
	if failure ~= nil or record == nil then
		return failure or deniedBoard(ERRORS.state, nil)
	end
	return okBoard(record, false)
end

function RaidStrategy.place(board: any, request: any, extra: any): BoardResult
	local limits, record, failure = prepareBoard(board, extra)
	if failure ~= nil or limits == nil or record == nil then
		return failure or deniedBoard(ERRORS.state, nil)
	end
	local body, bad = requestOf(request, record, ERRORS.request)
	if body == nil or bad ~= nil then
		return bad or deniedBoard(ERRORS.request, record)
	end
	local _, roleError = parseRole(body.role)
	if roleError ~= nil then
		return deniedBoard(roleError, record)
	end
	local id, idError = parseLabel(body.id, limits.idCap, ERRORS.id)
	if id == nil then
		return deniedBoard(idError or ERRORS.id, record)
	end
	local kind, kindError = parseKind(body.kind)
	if kind == nil then
		return deniedBoard(kindError or ERRORS.kind, record)
	end
	local x = unit(body.x)
	local y = unit(body.y)
	if x == nil or y == nil then
		return deniedBoard(ERRORS.coord, record)
	end
	local index = findId(record.markers, id)
	if index == nil and #record.markers >= limits.maxMarkers then
		return deniedBoard(ERRORS.full, record)
	end
	local nextMarker: Marker = {
		id = id,
		kind = kind,
		x = x,
		y = y,
	}
	if index ~= nil then
		if sameMarker(record.markers[index], nextMarker) then
			return okBoard(record, false)
		end
		record.markers[index] = nextMarker
		return okBoard(record, true)
	end
	table.insert(record.markers, nextMarker)
	return okBoard(record, true)
end

function RaidStrategy.remove(board: any, request: any, extra: any): BoardResult
	local limits, record, failure = prepareBoard(board, extra)
	if failure ~= nil or limits == nil or record == nil then
		return failure or deniedBoard(ERRORS.state, nil)
	end
	local body, bad = requestOf(request, record, ERRORS.request)
	if body == nil or bad ~= nil then
		return bad or deniedBoard(ERRORS.request, record)
	end
	local _, roleError = parseRole(body.role)
	if roleError ~= nil then
		return deniedBoard(roleError, record)
	end
	local id, idError = parseLabel(body.id, limits.idCap, ERRORS.id)
	if id == nil then
		return deniedBoard(idError or ERRORS.id, record)
	end
	local index = findId(record.markers, id)
	if index == nil then
		return deniedBoard(ERRORS.missing, record)
	end
	table.remove(record.markers, index)
	return okBoard(record, true)
end

function RaidStrategy.save(store: any, request: any, extra: any): PresetResult
	local limits, record, failure = prepareStore(store, extra)
	if failure ~= nil or limits == nil or record == nil then
		return failure or deniedPreset(ERRORS.presets, nil)
	end
	local body, bad = storeRequestOf(request, record)
	if body == nil or bad ~= nil then
		return bad or deniedPreset(ERRORS.request, record)
	end
	local guildId, guildError = parseLabel(body.guildId, limits.idCap, ERRORS.guild)
	if guildId == nil then
		return deniedPreset(guildError or ERRORS.guild, record)
	end
	local name, nameError = parseLabel(body.name, limits.idCap, ERRORS.name)
	if name == nil then
		return deniedPreset(nameError or ERRORS.name, record)
	end
	local board, boardError = readBoard(body.board, limits)
	if board == nil then
		return deniedPreset(boardError or ERRORS.state, record)
	end
	local guild = findGuild(record, guildId)
	local preset: Preset? = nil
	if guild ~= nil then
		preset = findPreset(guild, name)
	end
	if preset ~= nil and sameList(preset.markers, board.markers) then
		return okPreset(record, false, board.markers)
	end
	if preset == nil then
		local count = 0
		if guild ~= nil then
			count = #guild.presets
		end
		if count >= limits.maxPresets then
			return deniedPreset(ERRORS.presetsFull, record)
		end
	end
	if guild == nil then
		local created: GuildPresets = {
			guildId = guildId,
			presets = {},
		}
		table.insert(record.guilds, created)
		guild = created
	end
	local copied = copyMarkers(board.markers)
	if preset == nil then
		table.insert(guild.presets, {
			name = name,
			markers = copied,
		})
	else
		preset.markers = copied
	end
	return okPreset(record, true, copied)
end

function RaidStrategy.load(store: any, request: any, extra: any): PresetResult
	local limits, record, failure = prepareStore(store, extra)
	if failure ~= nil or limits == nil or record == nil then
		return failure or deniedPreset(ERRORS.presets, nil)
	end
	local body, bad = storeRequestOf(request, record)
	if body == nil or bad ~= nil then
		return bad or deniedPreset(ERRORS.request, record)
	end
	local guildId, guildError = parseLabel(body.guildId, limits.idCap, ERRORS.guild)
	if guildId == nil then
		return deniedPreset(guildError or ERRORS.guild, record)
	end
	local name, nameError = parseLabel(body.name, limits.idCap, ERRORS.name)
	if name == nil then
		return deniedPreset(nameError or ERRORS.name, record)
	end
	local guild = findGuild(record, guildId)
	local preset: Preset? = nil
	if guild ~= nil then
		preset = findPreset(guild, name)
	end
	if preset == nil then
		return deniedPreset(ERRORS.preset, record)
	end
	return okPreset(record, false, preset.markers)
end

return RaidStrategy
