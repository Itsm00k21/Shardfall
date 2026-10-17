--!strict

--[[
	Peak live locals per function.

	Roblox refuses to compile a function with 200 locals in scope at once
	("Out of local registers"). Lune does not enforce that cap, so this
	scanner counts the same stack the Luau compiler keeps: parameters and
	`self`, each `local`, and `for` names, pushed at the declaration and
	popped when the block ends. Nested functions have their own stack.
	Varargs do not take a local slot. Register reuse and inlining are
	ignored, which is the conservative count (optimization level 0).
]]

local LocalLimit = {}

LocalLimit.LIMIT = 180

export type Report = {
	name: string,
	line: number,
	locals: number,
}

type Tok = {
	kind: string,
	text: string,
	line: number,
	nl: boolean,
}

local KEYWORDS: { [string]: boolean } = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}

local function lex(src: string): { Tok }
	local toks: { Tok } = {}
	local n = #src
	local i = 1
	local line = 1
	local pendingNl = false

	local function bump(k: number?)
		local count = k or 1
		for _ = 1, count do
			if i <= n and string.sub(src, i, i) == "\n" then
				line += 1
				pendingNl = true
			end
			i += 1
		end
	end

	local function emit(kind: string, text: string, startLine: number)
		table.insert(toks, {
			kind = kind,
			text = text,
			line = startLine,
			nl = pendingNl,
		})
		pendingNl = false
	end

	while i <= n do
		local c = string.sub(src, i, i)
		if c == " " or c == "\t" or c == "\r" or c == "\n" then
			bump()
		elseif c == "-" and string.sub(src, i + 1, i + 1) == "-" then
			bump(2)
			if string.sub(src, i, i + 1) == "[[" then
				bump(2)
				while i + 1 <= n and string.sub(src, i, i + 1) ~= "]]" do
					bump()
				end
				if i + 1 <= n then
					bump(2)
				end
			else
				while i <= n and string.sub(src, i, i) ~= "\n" do
					bump()
				end
			end
		elseif c == "[" and string.sub(src, i + 1, i + 1) == "[" then
			local startLine = line
			bump(2)
			while i + 1 <= n and string.sub(src, i, i + 1) ~= "]]" do
				bump()
			end
			if i + 1 <= n then
				bump(2)
			end
			emit("str", "", startLine)
		elseif c == '"' or c == "'" then
			local q = c
			local startLine = line
			bump()
			while i <= n and string.sub(src, i, i) ~= q do
				if string.sub(src, i, i) == "\\" then
					bump()
					if i <= n then
						bump()
					end
				elseif string.sub(src, i, i) == "\n" then
					break
				else
					bump()
				end
			end
			if i <= n and string.sub(src, i, i) == q then
				bump()
			end
			emit("str", "", startLine)
		elseif string.match(c, "%d") or (c == "." and string.match(string.sub(src, i + 1, i + 1), "%d")) then
			local startLine = line
			if c == "." then
				bump()
			end
			while i <= n do
				local ch = string.sub(src, i, i)
				local two = string.sub(src, i, i + 1)
				if (ch == "e" or ch == "E") and (string.sub(two, 2, 2) == "+" or string.sub(two, 2, 2) == "-") then
					bump(2)
				elseif string.match(ch, "[%w_%.]") then
					bump()
				else
					break
				end
			end
			emit("num", "", startLine)
		elseif string.match(c, "[%a_]") then
			local start = i
			local startLine = line
			bump()
			while i <= n and string.match(string.sub(src, i, i), "[%w_]") do
				bump()
			end
			local word = string.sub(src, start, i - 1)
			local kind = if KEYWORDS[word] then "kw" else "name"
			emit(kind, word, startLine)
		else
			local startLine = line
			local three = string.sub(src, i, i + 2)
			local two = string.sub(src, i, i + 1)
			if three == "..." then
				bump(3)
				emit("sym", "...", startLine)
			elseif three == "..=" then
				bump(3)
				emit("sym", three, startLine)
			elseif
				two == "=="
				or two == "~="
				or two == "<="
				or two == ">="
				or two == "+="
				or two == "-="
				or two == "*="
				or two == "/="
				or two == "%="
				or two == "^="
				or two == ".."
				or two == "//"
				or two == "::"
				or two == "->"
			then
				bump(2)
				emit("sym", two, startLine)
			else
				bump()
				emit("sym", c, startLine)
			end
		end
	end
	emit("eof", "", line)
	return toks
end

local Parser = {}
Parser.__index = Parser

function Parser.new(toks: { Tok })
	return setmetatable({
		toks = toks,
		i = 1,
		frames = {} :: { { name: string, line: number, live: number, peak: number } },
		reports = {} :: { Report },
	}, Parser)
end

function Parser:cur(): Tok
	return self.toks[self.i]
end

function Parser:bump(): Tok
	local tok = self:cur()
	self.i += 1
	return tok
end

function Parser:accept(kind: string, text: string?): boolean
	local tok = self:cur()
	if tok.kind == kind and (text == nil or tok.text == text) then
		self:bump()
		return true
	end
	return false
end

function Parser:expect(kind: string, text: string?)
	if not self:accept(kind, text) then
		local tok = self:cur()
		error(
			string.format(
				"expected %s %s, got %s %q at line %d",
				kind,
				text or "",
				tok.kind,
				tok.text,
				tok.line
			),
			0
		)
	end
end

function Parser:pushFrame(name: string, line: number, base: number)
	table.insert(self.frames, { name = name, line = line, live = base, peak = base })
end

function Parser:popFrame()
	local frame = table.remove(self.frames)
	table.insert(self.reports, {
		name = frame.name,
		line = frame.line,
		locals = frame.peak,
	})
end

function Parser:addLocals(count: number)
	if count <= 0 then
		return
	end
	local frame = self.frames[#self.frames]
	frame.live += count
	if frame.live > frame.peak then
		frame.peak = frame.live
	end
end

function Parser:mark(): number
	return self.frames[#self.frames].live
end

function Parser:restore(mark: number)
	self.frames[#self.frames].live = mark
end

function Parser:blockFollow(): boolean
	local tok = self:cur()
	if tok.kind == "eof" then
		return true
	end
	return tok.kind == "kw"
		and (tok.text == "end" or tok.text == "else" or tok.text == "elseif" or tok.text == "until")
end

function Parser:parseBlock()
	local mark = self:mark()
	while not self:blockFollow() do
		self:parseStat()
		self:accept("sym", ";")
	end
	self:restore(mark)
end

function Parser:parseBlockKeep()
	while not self:blockFollow() do
		self:parseStat()
		self:accept("sym", ";")
	end
end

function Parser:expectName(): string
	local tok = self:cur()
	if tok.kind ~= "name" then
		error(string.format("expected name, got %s %q at line %d", tok.kind, tok.text, tok.line), 0)
	end
	self:bump()
	return tok.text
end

function Parser:parseStat()
	local tok = self:cur()
	if tok.kind == "kw" and tok.text == "if" then
		self:parseIf()
	elseif tok.kind == "kw" and tok.text == "while" then
		self:parseWhile()
	elseif tok.kind == "kw" and tok.text == "do" then
		self:bump()
		self:parseBlock()
		self:expect("kw", "end")
	elseif tok.kind == "kw" and tok.text == "for" then
		self:parseFor()
	elseif tok.kind == "kw" and tok.text == "repeat" then
		self:bump()
		self:parseBlock()
		self:expect("kw", "until")
		self:parseExpr()
	elseif tok.kind == "kw" and tok.text == "function" then
		self:parseFunctionStat()
	elseif tok.kind == "kw" and tok.text == "local" then
		self:parseLocal()
	elseif tok.kind == "kw" and tok.text == "return" then
		self:bump()
		if not self:blockFollow() and not (self:cur().kind == "sym" and self:cur().text == ";") then
			self:parseExprList()
		end
	elseif tok.kind == "kw" and tok.text == "break" then
		self:bump()
	elseif tok.kind == "name" and tok.text == "continue" then
		self:bump()
	elseif tok.kind == "sym" and tok.text == "::" then
		self:bump()
		self:expect("name")
		self:expect("sym", "::")
	elseif tok.kind == "name" and tok.text == "type" then
		self:bump()
		self:parseTypeAliasRest()
	elseif tok.kind == "name" and tok.text == "export" then
		self:bump()
		if self:cur().kind == "name" and self:cur().text == "type" then
			self:bump()
			self:parseTypeAliasRest()
		else
			error(string.format("unexpected export at line %d", self:cur().line), 0)
		end
	else
		self:parsePrefix()
		local nxt = self:cur()
		if nxt.kind == "sym" and (nxt.text == "," or nxt.text == "=") then
			while self:accept("sym", ",") do
				self:parsePrefix()
			end
			self:expect("sym", "=")
			self:parseExprList()
		elseif
			nxt.kind == "sym"
			and (
				nxt.text == "+="
				or nxt.text == "-="
				or nxt.text == "*="
				or nxt.text == "/="
				or nxt.text == "%="
				or nxt.text == "^="
				or nxt.text == "..="
			)
		then
			self:bump()
			self:parseExpr()
		end
	end
end

function Parser:parseIf()
	self:expect("kw", "if")
	self:parseExpr()
	self:expect("kw", "then")
	self:parseBlock()
	while self:accept("kw", "elseif") do
		self:parseExpr()
		self:expect("kw", "then")
		self:parseBlock()
	end
	if self:accept("kw", "else") then
		self:parseBlock()
	end
	self:expect("kw", "end")
end

function Parser:parseWhile()
	self:expect("kw", "while")
	self:parseExpr()
	self:expect("kw", "do")
	self:parseBlock()
	self:expect("kw", "end")
end

function Parser:parseFor()
	self:expect("kw", "for")
	self:expectName()
	if self:accept("sym", "=") then
		self:parseExpr()
		self:expect("sym", ",")
		self:parseExpr()
		if self:accept("sym", ",") then
			self:parseExpr()
		end
		self:expect("kw", "do")
		self:addLocals(1)
		local marked = self:mark()
		self:parseBlockKeep()
		self:restore(marked - 1)
		self:expect("kw", "end")
	else
		local names = 1
		while self:accept("sym", ",") do
			self:expectName()
			names += 1
		end
		self:expect("kw", "in")
		self:parseExprList()
		self:expect("kw", "do")
		self:addLocals(names)
		local marked = self:mark()
		self:parseBlockKeep()
		self:restore(marked - names)
		self:expect("kw", "end")
	end
end

function Parser:parseLocal()
	self:expect("kw", "local")
	if self:accept("kw", "function") then
		local name = self:expectName()
		local line = self.toks[self.i - 1].line
		self:addLocals(1)
		self:parseFuncBody(name, line, false)
		return
	end
	local count = 0
	while true do
		self:expectName()
		count += 1
		if self:accept("sym", ":") then
			self:parseType()
		end
		if not self:accept("sym", ",") then
			break
		end
	end
	self:addLocals(count)
	if self:accept("sym", "=") then
		self:parseExprList()
	end
end

function Parser:parseFunctionStat()
	self:expect("kw", "function")
	local name = self:expectName()
	local hasSelf = false
	while self:accept("sym", ".") do
		name = self:expectName()
	end
	if self:accept("sym", ":") then
		name = self:expectName()
		hasSelf = true
	end
	local line = self.toks[self.i - 1].line
	self:parseFuncBody(name, line, hasSelf)
end

function Parser:parseFuncBody(name: string, line: number, hasSelf: boolean)
	if self:accept("sym", "<") then
		local depth = 1
		while depth > 0 do
			local tok = self:bump()
			if tok.text == "<" then
				depth += 1
			elseif tok.text == ">" then
				depth -= 1
			elseif tok.kind == "eof" then
				break
			end
		end
	end
	self:expect("sym", "(")
	local args = if hasSelf then 1 else 0
	if not self:accept("sym", ")") then
		while true do
			if self:accept("sym", "...") then
				if self:accept("sym", ":") then
					self:parseType()
				end
				break
			end
			self:expectName()
			args += 1
			if self:accept("sym", ":") then
				self:parseType()
			end
			if not self:accept("sym", ",") then
				break
			end
		end
		self:expect("sym", ")")
	end
	if self:accept("sym", ":") then
		self:parseType()
	end
	self:pushFrame(name, line, args)
	self:parseBlock()
	self:expect("kw", "end")
	self:popFrame()
end

function Parser:parseTypeAliasRest()
	self:expectName()
	if self:accept("sym", "<") then
		local depth = 1
		while depth > 0 do
			local tok = self:bump()
			if tok.text == "<" then
				depth += 1
			elseif tok.text == ">" then
				depth -= 1
			elseif tok.kind == "eof" then
				break
			end
		end
	end
	if self:accept("sym", "=") then
		self:parseType()
	end
end

function Parser:parseType()
	local depth = 0
	local consumed = false
	while true do
		local tok = self:cur()
		if tok.kind == "eof" then
			break
		end
		if depth == 0 and consumed then
			if tok.nl and tok.text ~= "|" and tok.text ~= "&" and tok.text ~= "?" and tok.text ~= "->" and tok.text ~= "." then
				break
			end
			if
				tok.kind == "kw"
				and (
					tok.text == "local"
					or tok.text == "function"
					or tok.text == "if"
					or tok.text == "for"
					or tok.text == "while"
					or tok.text == "repeat"
					or tok.text == "do"
					or tok.text == "return"
					or tok.text == "break"
					or tok.text == "end"
					or tok.text == "else"
					or tok.text == "elseif"
					or tok.text == "until"
					or tok.text == "then"
					or tok.text == "in"
				)
			then
				break
			end
			if tok.kind == "name" and (tok.text == "type" or tok.text == "export" or tok.text == "continue") then
				break
			end
			if tok.kind == "sym" and (tok.text == "=" or tok.text == "," or tok.text == ")" or tok.text == "]" or tok.text == "}") then
				break
			end
		end
		if tok.kind == "sym" and (tok.text == "(" or tok.text == "{" or tok.text == "[" or tok.text == "<") then
			depth += 1
			self:bump()
			consumed = true
		elseif tok.kind == "sym" and (tok.text == ")" or tok.text == "}" or tok.text == "]" or tok.text == ">") then
			if depth == 0 then
				break
			end
			depth -= 1
			self:bump()
			consumed = true
		else
			self:bump()
			consumed = true
		end
	end
end

function Parser:parseExprList()
	self:parseExpr()
	while self:accept("sym", ",") do
		self:parseExpr()
	end
end

function Parser:parseExpr()
	self:parseOr()
end

function Parser:parseOr()
	self:parseAnd()
	while self:accept("kw", "or") do
		self:parseAnd()
	end
end

function Parser:parseAnd()
	self:parseRel()
	while self:accept("kw", "and") do
		self:parseRel()
	end
end

function Parser:parseRel()
	self:parseConcat()
	while self:cur().kind == "sym" and (
		self:cur().text == "<"
		or self:cur().text == ">"
		or self:cur().text == "<="
		or self:cur().text == ">="
		or self:cur().text == "=="
		or self:cur().text == "~="
	) do
		self:bump()
		self:parseConcat()
	end
end

function Parser:parseConcat()
	self:parseAdd()
	if self:accept("sym", "..") then
		self:parseConcat()
	end
end

function Parser:parseAdd()
	self:parseMul()
	while self:cur().kind == "sym" and (self:cur().text == "+" or self:cur().text == "-") do
		self:bump()
		self:parseMul()
	end
end

function Parser:parseMul()
	self:parseUnary()
	while
		self:cur().kind == "sym"
		and (self:cur().text == "*" or self:cur().text == "/" or self:cur().text == "//" or self:cur().text == "%")
	do
		self:bump()
		self:parseUnary()
	end
end

function Parser:parseUnary()
	local tok = self:cur()
	if (tok.kind == "kw" and tok.text == "not") or (tok.kind == "sym" and (tok.text == "-" or tok.text == "#")) then
		self:bump()
		self:parseUnary()
		return
	end
	self:parsePow()
end

function Parser:parsePow()
	self:parseSimple()
	if self:accept("sym", "^") then
		self:parseUnary()
	end
end

function Parser:parseSimple()
	self:parsePrefix()
	if self:accept("sym", "::") then
		self:parseType()
	end
end

function Parser:parsePrefix()
	self:parseAtom()
	while true do
		if self:accept("sym", ".") then
			self:expectName()
		elseif self:accept("sym", "[") then
			self:parseExpr()
			self:expect("sym", "]")
		elseif self:cur().kind == "sym" and self:cur().text == ":" then
			self:bump()
			self:expectName()
			self:parseArgs()
		elseif self:cur().kind == "sym" and self:cur().text == "(" then
			self:parseArgs()
		elseif self:cur().kind == "sym" and self:cur().text == "{" then
			self:parseTable()
		elseif self:cur().kind == "str" then
			self:bump()
		else
			break
		end
	end
end

function Parser:parseArgs()
	self:expect("sym", "(")
	if not self:accept("sym", ")") then
		self:parseExprList()
		self:expect("sym", ")")
	end
end

function Parser:parseAtom()
	local tok = self:cur()
	if tok.kind == "kw" and tok.text == "function" then
		self:bump()
		self:parseFuncBody("<anon>", tok.line, false)
	elseif tok.kind == "kw" and tok.text == "if" then
		self:parseIfExpr()
	elseif tok.kind == "sym" and tok.text == "(" then
		self:bump()
		self:parseExpr()
		self:expect("sym", ")")
	elseif tok.kind == "sym" and tok.text == "{" then
		self:parseTable()
	elseif tok.kind == "sym" and tok.text == "..." then
		self:bump()
	elseif tok.kind == "num" or tok.kind == "str" then
		self:bump()
	elseif tok.kind == "kw" and (tok.text == "nil" or tok.text == "true" or tok.text == "false") then
		self:bump()
	elseif tok.kind == "name" or (tok.kind == "kw" and (tok.text == "type" or tok.text == "export")) then
		self:bump()
	else
		error(string.format("bad expression atom %s %q at line %d", tok.kind, tok.text, tok.line), 0)
	end
end

function Parser:parseIfExpr()
	self:expect("kw", "if")
	self:parseExpr()
	self:expect("kw", "then")
	self:parseExpr()
	while self:accept("kw", "elseif") do
		self:parseExpr()
		self:expect("kw", "then")
		self:parseExpr()
	end
	self:expect("kw", "else")
	self:parseExpr()
end

function Parser:lookEq(): boolean
	local nxt = self.toks[self.i + 1]
	return nxt ~= nil and nxt.text == "="
end

function Parser:parseTable()
	self:expect("sym", "{")
	while not (self:cur().kind == "sym" and self:cur().text == "}") do
		if self:cur().kind == "eof" then
			break
		end
		if self:accept("sym", "[") then
			self:parseExpr()
			self:expect("sym", "]")
			self:expect("sym", "=")
			self:parseExpr()
		elseif self:cur().kind == "name" and self:lookEq() then
			self:bump()
			self:expect("sym", "=")
			self:parseExpr()
		else
			self:parseExpr()
		end
		if not self:accept("sym", ",") and not self:accept("sym", ";") then
			break
		end
	end
	self:expect("sym", "}")
end

function Parser:parseChunk(): { Report }
	self:pushFrame("<chunk>", 1, 0)
	self:parseBlock()
	self:popFrame()
	return self.reports
end

function LocalLimit.scan(source: string): { Report }
	local parser = Parser.new(lex(source))
	return parser:parseChunk()
end

function LocalLimit.over(source: string, limit: number?): Report?
	local cap = limit or LocalLimit.LIMIT
	local worst: Report? = nil
	for _, report in LocalLimit.scan(source) do
		if report.locals > cap and (worst == nil or report.locals > worst.locals) then
			worst = report
		end
	end
	return worst
end

return LocalLimit
