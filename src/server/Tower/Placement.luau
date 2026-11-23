--!strict
-- Where every level and connector goes. Pure maths with no instances, so the tests can
-- check the whole tower without building it. See docs/TOWER.md for the picture.
--
-- Floors are FloorHeight apart. Each staircase is a column, ColumnPitch apart in x.
-- Odd floors face +z; even floors are turned 180 degrees, so each level's exit end sits
-- under the next floor's entrance end. Between them is a landing zone of three lanes:
--   lane 1 (next to the wall): a ladder shaft straight up to the same column's next level
--   lane 2: a corridor, a shaft, then a bridge to the column on the right (+x)
--   lane 3: the same, to the column on the left (-x)
-- Every connector ends at the target level's entrance pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TowerMap = require(ReplicatedStorage.Shared.TowerMap)

local tower = Config.Tower

local Placement = {}

export type Box = {
	name: string,
	min: Vector3,
	max: Vector3,
}

export type Exit = {
	target: string,
	-- -1: to the column on the left, 0: straight up, +1: to the column on the right.
	direction: number,
	-- x of the exit opening's centre in the level's own coordinates.
	localX: number,
}

export type Connector = {
	from: string,
	to: string,
	direction: number,
	lane: number,
	-- World z of the wall the connector starts from, and +1/-1 pointing away from the level.
	wallZ: number,
	outward: number,
	-- World x of the exit opening's centre, and of the target column.
	slotX: number,
	targetX: number,
	-- Floor tops: the exit opening's floor, and the entrance pad's floor.
	exitY: number,
	padY: number,
	corridor: Box?,
	shaft: Box,
	bridge: Box?,
}

-- What a room builder is told about the level it is building.
export type Context = {
	id: string,
	level: TowerMap.Level,
	-- "Level 2 · The Switchboard"
	label: string,
	-- Where the level's own coordinates sit in the world.
	frame: CFrame,
	-- The level's exits, left to right, with the local x of each opening.
	exits: { Exit },
}

-- Half the outside width of a tube: the opening plus a 1-stud wall each side.
local TUBE_HALF = tower.OpeningWidth / 2 + 1

local function levelOf(id: string): TowerMap.Level
	local level = TowerMap.levels[id]
	assert(level, "unknown level " .. id)
	return level
end

local function box(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number): Box
	return {
		name = name,
		min = Vector3.new(math.min(x0, x1), math.min(y0, y1), math.min(z0, z1)),
		max = Vector3.new(math.max(x0, x1), math.max(y0, y1), math.max(z0, z1)),
	}
end

function Placement.floorBase(floor: number): number
	return (floor - 1) * tower.FloorHeight
end

function Placement.columnX(column: number): number
	return column * tower.ColumnPitch
end

-- World z of the wall that a floor's exits go through, and the direction away from it.
function Placement.exitWall(floor: number): (number, number)
	if floor % 2 == 1 then
		return tower.EnvelopeMax.Z, 1
	end
	return tower.EnvelopeMin.Z, -1
end

-- Where a level's own coordinates sit in the world.
function Placement.levelFrame(id: string): CFrame
	local level = levelOf(id)
	local x = Placement.columnX(level.column)
	local y = Placement.floorBase(level.floor)
	if level.floor % 2 == 1 then
		return CFrame.new(x, y, 0)
	end
	-- Turned round about the middle of the footprint, which keeps the same world footprint.
	local middleZ = tower.EnvelopeMin.Z + tower.EnvelopeMax.Z
	return CFrame.new(x, y, middleZ) * CFrame.Angles(0, math.pi, 0)
end

-- The level's footprint in world space.
function Placement.envelope(id: string): Box
	local level = levelOf(id)
	local x = Placement.columnX(level.column)
	local y = Placement.floorBase(level.floor)
	local low, high = tower.EnvelopeMin, tower.EnvelopeMax
	-- The 180-degree turn mirrors x about the column and z about the footprint's middle,
	-- which maps the (x-symmetric, z-centred) envelope onto itself.
	return box("Level " .. id, x + low.X, x + high.X, y + low.Y, y + high.Y, low.Z, high.Z)
end

-- A level's exits, left to right, with the local x of each opening.
function Placement.exits(id: string): { Exit }
	local level = levelOf(id)
	local exits: { Exit } = {}
	for _, targetId in level.exits do
		local direction = levelOf(targetId).column - level.column
		local worldOffset = direction * tower.ExitSlotOffset
		table.insert(exits, {
			target = targetId,
			direction = direction,
			-- Even floors are turned round, so world-right is local-left.
			localX = if level.floor % 2 == 1 then worldOffset else -worldOffset,
		})
	end
	return exits
end

function Placement.connector(fromId: string, toId: string): Connector
	local from, to = levelOf(fromId), levelOf(toId)
	local direction = to.column - from.column
	local lane = if direction == 0 then 1 elseif direction > 0 then 2 else 3
	local wallZ, outward = Placement.exitWall(from.floor)
	local base = Placement.floorBase(from.floor)
	local exitY = base + tower.ExitHeight
	local padY = base + tower.FloorHeight
	local slotX = Placement.columnX(from.column) + direction * tower.ExitSlotOffset
	local targetX = Placement.columnX(to.column)
	local depth = tower.LaneDepth
	local laneNear = wallZ + outward * (lane - 1) * depth
	local laneFar = wallZ + outward * lane * depth

	local corridor: Box? = nil
	local bridge: Box? = nil
	if direction ~= 0 then
		corridor = box(
			"Corridor",
			slotX - TUBE_HALF,
			slotX + TUBE_HALF,
			exitY - 1,
			exitY + tower.OpeningHeight + 1,
			wallZ,
			laneNear
		)
		local padEdge = targetX - direction * tower.PadHalfWidth
		bridge = box(
			"Bridge",
			slotX - direction * TUBE_HALF,
			padEdge,
			padY - 1,
			padY + tower.TubeHeight,
			laneNear,
			laneFar
		)
	end
	local shaft = box("Shaft", slotX - TUBE_HALF, slotX + TUBE_HALF, exitY - 1, padY - 1, laneNear, laneFar)

	return {
		from = fromId,
		to = toId,
		direction = direction,
		lane = lane,
		wallZ = wallZ,
		outward = outward,
		slotX = slotX,
		targetX = targetX,
		exitY = exitY,
		padY = padY,
		corridor = corridor,
		shaft = shaft,
		bridge = bridge,
	}
end

-- The entrance pad in front of a level (not Level 1, which has no way in).
function Placement.pad(id: string): Box
	local level = levelOf(id)
	local wallZ, outward = Placement.exitWall(level.floor - 1)
	local x = Placement.columnX(level.column)
	local y = Placement.floorBase(level.floor)
	return box(
		"Pad " .. id,
		x - tower.PadHalfWidth,
		x + tower.PadHalfWidth,
		y - 1,
		y + tower.TubeHeight,
		wallZ,
		wallZ + outward * 3 * tower.LaneDepth
	)
end

-- The opening a connector leaves through, in the level's own coordinates.
function Placement.exitOpening(exit: Exit): Box
	local half = tower.OpeningWidth / 2
	local wall = tower.EnvelopeMax.Z
	return box(
		"Exit opening",
		exit.localX - half,
		exit.localX + half,
		tower.ExitHeight,
		tower.ExitHeight + tower.OpeningHeight,
		wall - 1,
		wall
	)
end

-- The entrance opening, in the level's own coordinates.
function Placement.entranceOpening(): Box
	local half = tower.OpeningWidth / 2
	local wall = tower.EnvelopeMin.Z
	return box("Entrance opening", -half, half, 0, tower.OpeningHeight, wall, wall + 1)
end

return Placement
