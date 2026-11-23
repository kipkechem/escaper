--!nonstrict
-- A tiny test harness: describe / it / expectations, and a summary at the end.

local Harness = {}

local passed = 0
local failed = 0
local currentSuite = ""

function Harness.describe(name: string, body: () -> ())
	currentSuite = name
	local ok, err = pcall(body)
	if not ok then
		failed += 1
		print(string.format("FAIL  %s (while setting up)\n      %s", name, tostring(err)))
	end
end

function Harness.it(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		print(string.format("FAIL  %s: %s\n      %s", currentSuite, name, tostring(err)))
	end
end

function Harness.expectEqual(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(
			string.format(
				"%sexpected %s, got %s",
				if label then label .. ": " else "",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end

function Harness.expectNear(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(
			string.format("%sexpected %.3f, got %.3f", if label then label .. ": " else "", expected, actual),
			2
		)
	end
end

-- Prints the totals and returns true if everything passed.
function Harness.summary(): boolean
	print(string.format("\n%d passed, %d failed", passed, failed))
	return failed == 0
end

return Harness
