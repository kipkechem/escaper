--!strict
-- The tower: 100 floors of levels on overlapping staircases.
--
-- A level's number is its floor. Levels on the same floor share the number and add their
-- staircase's letter: "12" is on the main stair, "12E", "12M" and "12H" on the easy, medium
-- and hard staircases. Each staircase is a column of rooms, left to right: E, M, main, H.
--
-- Exits always go up one floor, to the same column or a neighbouring one. So a level has at
-- most three ways out (left, straight, right) and at most three ways in. A level with several
-- exits has several solutions, each leading onto a different staircase.
--
-- How to read the data below:
--   * The main stair runs from floor 1 to 100, each level leading to the next.
--   * Runs: { staircase, first floor, last floor } is a stretch of a side staircase where
--     each level leads to the one above it.
--   * Links: { from, to } are the extra exits: forks off a staircase, merges into another.
-- tests/run.luau checks the rules; `lune run tools/tower_map.luau` writes docs/TOWER_MAP.md.

local TowerMap = {}

export type Staircase = {
	id: string,
	suffix: string,
	column: number,
	difficulty: string,
	name: string,
}

export type Level = {
	id: string,
	floor: number,
	staircase: string,
	column: number,
	difficulty: string,
	name: string?,
	exits: { string },
	incoming: { string },
}

TowerMap.TopFloor = 100

TowerMap.Staircases = {
	E = { id = "E", suffix = "E", column = -2, difficulty = "Easy", name = "Easy staircase" },
	M = { id = "M", suffix = "M", column = -1, difficulty = "Medium", name = "Medium staircase" },
	Main = { id = "Main", suffix = "", column = 0, difficulty = "Very hard", name = "Main stair" },
	H = { id = "H", suffix = "H", column = 1, difficulty = "Hard", name = "Hard staircase" },
} :: { [string]: Staircase }

-- Names of levels that have been designed.
TowerMap.Names = {
	["1"] = "The Loading Dock",
	["2"] = "The Switchboard",
} :: { [string]: string }

-- Level 1 is the tutorial; the main stair is very hard from Level 2 on.
TowerMap.DifficultyOverrides = {
	["1"] = "Tutorial",
} :: { [string]: string }

TowerMap.Runs = {
	-- Floors 1-10: the first fork is Level 2.
	{ "M", 3, 9 },
	{ "H", 3, 9 },
	{ "E", 5, 8 },
	-- 11-20: hard rejoins early, then a short second hard stretch.
	{ "M", 13, 19 },
	{ "H", 13, 16 },
	{ "H", 19, 19 },
	{ "E", 15, 18 },
	-- 21-30
	{ "M", 23, 29 },
	{ "H", 23, 29 },
	{ "E", 25, 28 },
	-- 31-40
	{ "M", 33, 39 },
	{ "H", 33, 37 },
	{ "H", 39, 39 },
	{ "E", 34, 38 },
	-- 41-50
	{ "M", 43, 49 },
	{ "H", 43, 49 },
	{ "E", 44, 48 },
	-- 51-60
	{ "M", 53, 59 },
	{ "H", 53, 58 },
	{ "E", 55, 58 },
	-- 61-70
	{ "M", 63, 69 },
	{ "H", 63, 69 },
	{ "E", 64, 68 },
	-- 71-80
	{ "M", 73, 79 },
	{ "H", 73, 76 },
	{ "H", 78, 79 },
	{ "E", 75, 78 },
	-- 81-90
	{ "M", 83, 89 },
	{ "H", 83, 89 },
	{ "E", 84, 88 },
	-- 91-100: everything is back on the main stair by floor 99.
	{ "M", 93, 98 },
	{ "H", 93, 98 },
	{ "E", 94, 97 },
} :: { { any } }

TowerMap.Links = {
	-- 1-10
	{ "2", "3M" },
	{ "2", "3H" },
	{ "4M", "5E" },
	{ "8E", "9M" },
	{ "9M", "10" },
	{ "9H", "10" },
	-- 11-20
	{ "12", "13M" },
	{ "12", "13H" },
	{ "14M", "15E" },
	{ "15", "16H" },
	{ "16H", "17" },
	{ "18E", "19M" },
	{ "18", "19H" },
	{ "19M", "20" },
	{ "19H", "20" },
	-- 21-30
	{ "22", "23M" },
	{ "22", "23H" },
	{ "24M", "25E" },
	{ "25H", "26" },
	{ "26M", "27" },
	{ "26E", "27M" },
	{ "28E", "29M" },
	{ "29M", "30" },
	{ "29H", "30" },
	-- 31-40
	{ "32", "33M" },
	{ "32", "33H" },
	{ "33M", "34E" },
	{ "36", "37M" },
	{ "37H", "38" },
	{ "38E", "39M" },
	{ "38", "39H" },
	{ "39M", "40" },
	{ "39H", "40" },
	-- 41-50
	{ "42", "43M" },
	{ "42", "43H" },
	{ "43M", "44E" },
	{ "44H", "45" },
	{ "45E", "46M" },
	{ "46M", "47" },
	{ "48E", "49M" },
	{ "49M", "50" },
	{ "49H", "50" },
	-- 51-60
	{ "52", "53M" },
	{ "52", "53H" },
	{ "54M", "55E" },
	{ "56", "57H" },
	{ "58E", "59M" },
	{ "58H", "59" },
	{ "59M", "60" },
	-- 61-70
	{ "62", "63M" },
	{ "62", "63H" },
	{ "63M", "64E" },
	{ "65H", "66" },
	{ "66E", "67M" },
	{ "67M", "68" },
	{ "68E", "69M" },
	{ "69M", "70" },
	{ "69H", "70" },
	-- 71-80
	{ "72", "73M" },
	{ "72", "73H" },
	{ "74M", "75E" },
	{ "76H", "77" },
	{ "77", "78H" },
	{ "78E", "79M" },
	{ "79M", "80" },
	{ "79H", "80" },
	-- 81-90
	{ "82", "83M" },
	{ "82", "83H" },
	{ "83M", "84E" },
	{ "85", "86H" },
	{ "86M", "87" },
	{ "88E", "89M" },
	{ "89M", "90" },
	{ "89H", "90" },
	-- 91-100
	{ "92", "93M" },
	{ "92", "93H" },
	{ "93M", "94E" },
	{ "97E", "98M" },
	{ "98M", "99" },
	{ "98H", "99" },
} :: { { string } }

local levels: { [string]: Level } = {}
local ordered: { Level } = {}
local problems: { string } = {}

function TowerMap.levelId(floor: number, staircase: string): string
	return tostring(floor) .. TowerMap.Staircases[staircase].suffix
end

local function addLevel(floor: number, staircaseId: string)
	local staircase = TowerMap.Staircases[staircaseId]
	if not staircase then
		table.insert(problems, "unknown staircase " .. tostring(staircaseId))
		return
	end
	local id = TowerMap.levelId(floor, staircaseId)
	if levels[id] then
		table.insert(problems, "level " .. id .. " is defined twice")
		return
	end
	local level: Level = {
		id = id,
		floor = floor,
		staircase = staircaseId,
		column = staircase.column,
		difficulty = TowerMap.DifficultyOverrides[id] or staircase.difficulty,
		name = TowerMap.Names[id],
		exits = {},
		incoming = {},
	}
	levels[id] = level
	table.insert(ordered, level)
end

local function addLink(fromId: string, toId: string)
	local from, to = levels[fromId], levels[toId]
	if not from or not to then
		table.insert(problems, string.format("link %s -> %s names a level that does not exist", fromId, toId))
		return
	end
	if table.find(from.exits, toId) then
		table.insert(problems, string.format("link %s -> %s is listed twice", fromId, toId))
		return
	end
	table.insert(from.exits, toId)
	table.insert(to.incoming, fromId)
end

for floor = 1, TowerMap.TopFloor do
	addLevel(floor, "Main")
end
for _, run in TowerMap.Runs do
	for floor = run[2], run[3] do
		addLevel(floor, run[1])
	end
end
table.sort(ordered, function(a, b)
	if a.floor ~= b.floor then
		return a.floor < b.floor
	end
	return a.column < b.column
end)
for floor = 1, TowerMap.TopFloor - 1 do
	addLink(tostring(floor), tostring(floor + 1))
end
for _, run in TowerMap.Runs do
	for floor = run[2], run[3] - 1 do
		addLink(TowerMap.levelId(floor, run[1]), TowerMap.levelId(floor + 1, run[1]))
	end
end
for _, link in TowerMap.Links do
	addLink(link[1], link[2])
end
-- Exits in a fixed order: left to right.
for _, level in ordered do
	table.sort(level.exits, function(a, b)
		return levels[a].column < levels[b].column
	end)
	table.sort(level.incoming, function(a, b)
		return levels[a].column < levels[b].column
	end)
end

TowerMap.levels = levels
-- All levels, bottom floor first, left to right within a floor.
TowerMap.ordered = ordered

function TowerMap.get(id: string): Level?
	return levels[id]
end

-- "Level 3M · Medium staircase" style label.
function TowerMap.label(id: string): string
	local level = levels[id]
	if not level then
		return "Level " .. id
	end
	if level.name then
		return string.format("Level %s · %s", id, level.name)
	end
	return string.format("Level %s · %s", id, TowerMap.Staircases[level.staircase].name)
end

local function reach(start: string, step: (Level) -> { string }): { [string]: boolean }
	local seen = { [start] = true }
	local queue = { start }
	while #queue > 0 do
		local id = table.remove(queue) :: string
		for _, nextId in step(levels[id]) do
			if not seen[nextId] then
				seen[nextId] = true
				table.insert(queue, nextId)
			end
		end
	end
	return seen
end

-- Every way the map breaks the tower's rules. An empty list means the map is valid.
function TowerMap.validate(): { string }
	local found = table.clone(problems)
	local function problem(message: string, ...: any)
		table.insert(found, string.format(message, ...))
	end

	for floor = 1, TowerMap.TopFloor do
		if not levels[tostring(floor)] then
			problem("floor %d has no main-stair level", floor)
		end
	end

	for _, level in ordered do
		if level.floor >= TowerMap.TopFloor - 1 and level.staircase ~= "Main" then
			problem(
				"%s: floors %d and %d must be main stair only",
				level.id,
				TowerMap.TopFloor - 1,
				TowerMap.TopFloor
			)
		end
		if #level.exits > 3 then
			problem("%s has %d exits (at most 3)", level.id, #level.exits)
		end
		if #level.incoming > 3 then
			problem("%s has %d ways in (at most 3)", level.id, #level.incoming)
		end
		if level.floor == TowerMap.TopFloor then
			if #level.exits > 0 then
				problem("%s is the final level and must have no exits", level.id)
			end
		elseif #level.exits == 0 then
			problem("%s has no exit", level.id)
		end
		if level.id ~= "1" and #level.incoming == 0 then
			problem("%s has no way in", level.id)
		end
		for _, exitId in level.exits do
			local target = levels[exitId]
			if target.floor ~= level.floor + 1 then
				problem("%s -> %s does not go up exactly one floor", level.id, exitId)
			end
			if math.abs(target.column - level.column) > 1 then
				problem("%s -> %s skips a staircase (only neighbouring columns connect)", level.id, exitId)
			end
		end
	end

	local fromStart = reach("1", function(level)
		return level.exits
	end)
	local top = tostring(TowerMap.TopFloor)
	local toTop = reach(top, function(level)
		return level.incoming
	end)
	for _, level in ordered do
		if not fromStart[level.id] then
			problem("%s cannot be reached from Level 1", level.id)
		end
		if not toTop[level.id] then
			problem("%s cannot reach Level %s", level.id, top)
		end
	end
	return found
end

return TowerMap
