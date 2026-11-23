--!strict
-- Tiny boolean expression language used to wire puzzle parts together.
--
-- A Door's "Input" attribute can be a single signal name or a combination:
--   "ShutterPlate"                 open while the plate is pressed
--   "ShutterPlate | ShutterLever"  either one
--   "PlateA & PlateB"              both at once (co-op)
--   "!Alarm"                       while the alarm signal is off
--   "(PlateA & PlateB) | Override"
-- The words `and`, `or`, `not` and the operators `&&`, `||` also work.
-- Signal names may use letters, digits, `_` and `.`.

local Expression = {}

export type Lookup = (name: string) -> boolean

export type Compiled = {
	source: string,
	names: { string },
	evaluate: (lookup: Lookup) -> boolean,
}

type Token = { kind: string, value: string? }

type Node = {
	op: string,
	name: string?,
	a: Node?,
	b: Node?,
}

local function tokenize(source: string): { Token }
	local tokens: { Token } = {}
	local i = 1
	local length = #source
	while i <= length do
		local char = string.sub(source, i, i)
		if string.match(char, "%s") then
			i += 1
		elseif char == "(" or char == ")" then
			table.insert(tokens, { kind = char })
			i += 1
		elseif char == "&" then
			table.insert(tokens, { kind = "and" })
			i += if string.sub(source, i + 1, i + 1) == "&" then 2 else 1
		elseif char == "|" then
			table.insert(tokens, { kind = "or" })
			i += if string.sub(source, i + 1, i + 1) == "|" then 2 else 1
		elseif char == "!" then
			table.insert(tokens, { kind = "not" })
			i += 1
		else
			local word = string.match(source, "^[%w_%.]+", i)
			if not word then
				error(string.format("unexpected character %q at position %d", char, i), 0)
			end
			local lower = string.lower(word)
			if lower == "and" or lower == "or" or lower == "not" then
				table.insert(tokens, { kind = lower })
			elseif lower == "true" or lower == "false" then
				table.insert(tokens, { kind = "const", value = lower })
			else
				table.insert(tokens, { kind = "name", value = word })
			end
			i += #word
		end
	end
	return tokens
end

local function parse(tokens: { Token }): Node
	local position = 1

	local function peek(): string?
		local token = tokens[position]
		return if token then token.kind else nil
	end

	local parseOr: () -> Node

	local function parsePrimary(): Node
		local token = tokens[position]
		if not token then
			error("expression ended too early", 0)
		end
		position += 1
		if token.kind == "name" then
			return { op = "name", name = token.value }
		elseif token.kind == "const" then
			return { op = if token.value == "true" then "true" else "false" }
		elseif token.kind == "(" then
			local inner = parseOr()
			if peek() ~= ")" then
				error("missing ')'", 0)
			end
			position += 1
			return inner
		end
		error(string.format("unexpected '%s'", token.kind), 0)
	end

	local function parseUnary(): Node
		if peek() == "not" then
			position += 1
			return { op = "not", a = parseUnary() }
		end
		return parsePrimary()
	end

	local function parseAnd(): Node
		local left = parseUnary()
		while peek() == "and" do
			position += 1
			left = { op = "and", a = left, b = parseUnary() }
		end
		return left
	end

	parseOr = function(): Node
		local left = parseAnd()
		while peek() == "or" do
			position += 1
			left = { op = "or", a = left, b = parseAnd() }
		end
		return left
	end

	local root = parseOr()
	if position <= #tokens then
		error(string.format("unexpected '%s' after the end of the expression", tokens[position].kind), 0)
	end
	return root
end

local function evaluateNode(node: Node, lookup: Lookup): boolean
	local op = node.op
	if op == "name" then
		return lookup(node.name :: string)
	elseif op == "true" then
		return true
	elseif op == "false" then
		return false
	elseif op == "not" then
		return not evaluateNode(node.a :: Node, lookup)
	elseif op == "and" then
		return evaluateNode(node.a :: Node, lookup) and evaluateNode(node.b :: Node, lookup)
	else
		return evaluateNode(node.a :: Node, lookup) or evaluateNode(node.b :: Node, lookup)
	end
end

local function collectNames(node: Node, into: { string }, seen: { [string]: boolean })
	if node.op == "name" then
		local name = node.name :: string
		if not seen[name] then
			seen[name] = true
			table.insert(into, name)
		end
	end
	if node.a then
		collectNames(node.a, into, seen)
	end
	if node.b then
		collectNames(node.b, into, seen)
	end
end

-- Compiles an expression. Returns nil and an error message if it is not valid.
function Expression.compile(source: string): (Compiled?, string?)
	local ok, result = pcall(function()
		local tokens = tokenize(source)
		if #tokens == 0 then
			error("expression is empty", 0)
		end
		return parse(tokens)
	end)
	if not ok then
		return nil, tostring(result)
	end
	local root = result :: Node
	local names = {}
	collectNames(root, names, {})
	return {
		source = source,
		names = names,
		evaluate = function(lookup: Lookup): boolean
			return evaluateNode(root, lookup)
		end,
	},
		nil
end

return Expression
