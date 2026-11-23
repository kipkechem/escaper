--!strict
-- Builds the connectors between levels and the entrance pads in front of them, from the
-- boxes in Placement. Each connector is an enclosed tube, so players cannot hop from one
-- route to another:
--   straight up: a ladder shaft from the exit opening into the next level's pad
--   sideways:    a short corridor, a ladder shaft, then a bridge into the neighbour's pad
-- A pad in front of a level that is not built yet is closed off with a sign.
--
-- Like the room builders, this only creates instances, so tools/bake.luau can run it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TowerMap = require(ReplicatedStorage.Shared.TowerMap)
local Build = require(script.Parent.Parent.Rooms.Build)
local Placement = require(script.Parent.Placement)

local tower = Config.Tower
local palette = Build.palette

local Connectors = {}

local world = Build.new()

local wallStyle = { name = "Wall", color = palette.tube, material = Enum.Material.Concrete }
local floorStyle = { name = "Floor", color = palette.floor, material = Enum.Material.DiamondPlate }
local ladderStyle =
	{ name = "Ladder", class = "TrussPart", color = palette.trim, material = Enum.Material.Metal }

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function trigger(parent: Instance, name: string, low: Vector3, high: Vector3): BasePart
	return world:box(
		parent,
		{ name = name, transparency = 1, canCollide = false, castShadow = false },
		low,
		high
	)
end

local function lamp(parent: Instance, position: Vector3)
	local part = world:part(parent, {
		name = "Lamp",
		color = Color3.fromRGB(255, 244, 214),
		material = Enum.Material.Neon,
		canCollide = false,
	}, CFrame.new(position), v(2, 0.2, 2))
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.5
	light.Parent = part
end

-- A ladder from `bottom` (its foot) up to `topY`, as a 2x2 truss.
local function ladder(parent: Instance, x: number, z: number, bottom: number, topY: number)
	-- Truss lengths must be whole multiples of 2 studs.
	local length = 2 * math.ceil((topY - bottom) / 2)
	world:part(parent, ladderStyle, CFrame.new(x, bottom + length / 2, z), v(2, length, 2))
end

local function buildConnector(parent: Instance, connector: Placement.Connector)
	local folder = Instance.new("Model")
	folder.Name = string.format("%s to %s", connector.from, connector.to)
	local shaft = connector.shaft
	local x0, x1 = shaft.min.X, shaft.max.X
	local z0, z1 = shaft.min.Z, shaft.max.Z
	local y0 = shaft.min.Y
	local top = shaft.max.Y -- = pad floor bottom
	local exitY = connector.exitY
	local slotX = connector.slotX
	local outward = connector.outward
	local open = tower.OpeningWidth / 2
	local openingTop = exitY + tower.OpeningHeight
	-- The shaft wall nearest the level (the corridor or the exit opening comes in there).
	local nearZ = if outward > 0 then z0 else z1
	local farZ = if outward > 0 then z1 else z0

	-- Corridor from the exit opening out to the shaft.
	local corridor = connector.corridor
	if corridor then
		local c0, c1 = corridor.min, corridor.max
		world:box(folder, floorStyle, v(c0.X, c0.Y, c0.Z), v(c1.X, c0.Y + 1, c1.Z))
		world:box(folder, wallStyle, v(c0.X, c1.Y - 1, c0.Z), v(c1.X, c1.Y, c1.Z))
		world:box(folder, wallStyle, v(c0.X, c0.Y + 1, c0.Z), v(c0.X + 1, c1.Y - 1, c1.Z))
		world:box(folder, wallStyle, v(c1.X - 1, c0.Y + 1, c0.Z), v(c1.X, c1.Y - 1, c1.Z))
		trigger(folder, "LevelExit", v(slotX - open, exitY, c0.Z + 1), v(slotX + open, exitY + 6, c1.Z - 1))
	end

	-- Shaft: floor, four walls, an opening at the bottom on the level side.
	world:box(folder, floorStyle, v(x0, y0, z0), v(x1, y0 + 1, z1))
	world:box(folder, wallStyle, v(x0, y0 + 1, z0), v(x0 + 1, top, z1))
	world:box(folder, wallStyle, v(x1 - 1, y0 + 1, z0), v(x1, top, z1))
	world:box(folder, wallStyle, v(x0 + 1, y0 + 1, farZ - outward), v(x1 - 1, top, farZ))
	world:box(folder, wallStyle, v(x0 + 1, openingTop, nearZ), v(x1 - 1, top, nearZ + outward))
	if not corridor then
		trigger(
			folder,
			"LevelExit",
			v(slotX - open, exitY, nearZ + outward),
			v(slotX + open, exitY + 6, farZ - 3 * outward)
		)
	end

	local bridge = connector.bridge
	if bridge then
		-- Ladder against the wall on the side the bridge goes; climb over its top onto the deck.
		local direction = connector.direction
		local ladderX = slotX + direction * 2
		ladder(folder, ladderX, (z0 + z1) / 2, exitY, connector.padY + 2)
		local b0, b1 = bridge.min, bridge.max
		local deckFrom = slotX + direction * open
		local padEdge = connector.targetX - direction * tower.PadHalfWidth
		world:box(folder, floorStyle, v(deckFrom, b0.Y, b0.Z), v(padEdge, b0.Y + 1, b1.Z))
		world:box(folder, wallStyle, v(b0.X, b1.Y - 1, b0.Z), v(b1.X, b1.Y, b1.Z))
		world:box(folder, wallStyle, v(b0.X, b0.Y + 1, b0.Z), v(b1.X, b1.Y - 1, b0.Z + 1))
		world:box(folder, wallStyle, v(b0.X, b0.Y + 1, b1.Z - 1), v(b1.X, b1.Y - 1, b1.Z))
		-- Close the end of the bridge behind the shaft.
		local backX = slotX - direction * (open + 1)
		world:box(folder, wallStyle, v(backX, b0.Y, b0.Z + 1), v(backX + direction, b1.Y - 1, b1.Z - 1))
		lamp(folder, v((deckFrom + padEdge) / 2, b1.Y - 1.1, (b0.Z + b1.Z) / 2))
	else
		-- Straight up: ladder against the far wall; climb over its top onto the pad.
		ladder(folder, slotX, farZ - outward * 2, exitY, connector.padY + 2)
	end
	lamp(folder, v(slotX, exitY + tower.OpeningHeight - 0.5, (nearZ + farZ) / 2 - outward * 2))

	local message = string.format(
		"Level %s complete! On to %s (%s)",
		connector.from,
		TowerMap.label(connector.to),
		TowerMap.levels[connector.to].difficulty
	)
	local exitTrigger = folder:FindFirstChild("LevelExit") :: BasePart
	Build.tag(exitTrigger, "RoomGoal", { Message = message, Id = connector.from .. "_" .. connector.to })

	folder.Parent = parent
end

type Arrivals = { straight: Placement.Connector?, fromLeft: boolean, fromRight: boolean }

local function buildPad(parent: Instance, id: string, arrivals: Arrivals, levelBuilt: boolean)
	local level = TowerMap.levels[id]
	local pad = Placement.pad(id)
	local model = Instance.new("Model")
	model.Name = "Pad " .. id
	local p0, p1 = pad.min, pad.max
	local padY = p0.Y + 1
	local wallZ, outward = Placement.exitWall(level.floor - 1)
	local depth = tower.LaneDepth
	local function laneSpan(lane: number): (number, number)
		local a = wallZ + outward * (lane - 1) * depth
		local b = wallZ + outward * lane * depth
		return math.min(a, b), math.max(a, b)
	end

	-- Deck, with a hole over the straight-up shaft.
	local straight = arrivals.straight
	if straight then
		local s0, s1 = straight.shaft.min, straight.shaft.max
		local holeNear = straight.wallZ + outward
		local holeFar = straight.wallZ + outward * (depth - 1)
		local holeLow, holeHigh = math.min(holeNear, holeFar), math.max(holeNear, holeFar)
		-- Strips around the hole.
		world:box(model, floorStyle, v(p0.X, p0.Y, p0.Z), v(s0.X + 1, padY, p1.Z))
		world:box(model, floorStyle, v(s1.X - 1, p0.Y, p0.Z), v(p1.X, padY, p1.Z))
		world:box(model, floorStyle, v(s0.X + 1, p0.Y, p0.Z), v(s1.X - 1, padY, holeLow))
		world:box(model, floorStyle, v(s0.X + 1, p0.Y, holeHigh), v(s1.X - 1, padY, p1.Z))
	else
		world:box(model, floorStyle, v(p0.X, p0.Y, p0.Z), v(p1.X, padY, p1.Z))
	end
	world:box(model, wallStyle, v(p0.X, p1.Y - 1, p0.Z), v(p1.X, p1.Y, p1.Z))

	-- Far wall, and the label for the level you are about to enter.
	local farZ = wallZ + outward * 3 * depth
	world:box(model, wallStyle, v(p0.X, padY, farZ - outward), v(p1.X, p1.Y - 1, farZ))
	local label = string.format("%s\n%s", string.upper(TowerMap.label(id)), string.upper(level.difficulty))
	world:sign(
		model,
		"LevelSign",
		v(level.column * tower.ColumnPitch, padY + 5, farZ - outward * 1.15),
		v(0, 0, -outward),
		Vector2.new(14, 3.5),
		label,
		Build.difficultyColor(level.difficulty)
	)

	-- Side walls, with an opening where a bridge arrives (lane 2 from the left, lane 3 from
	-- the right).
	local function sideWall(x0: number, x1: number, openLane: number?)
		if not openLane then
			world:box(model, wallStyle, v(x0, padY, p0.Z), v(x1, p1.Y - 1, p1.Z))
			return
		end
		local laneLow, laneHigh = laneSpan(openLane)
		world:box(model, wallStyle, v(x0, padY, p0.Z), v(x1, p1.Y - 1, laneLow + 1))
		world:box(model, wallStyle, v(x0, padY, laneHigh - 1), v(x1, p1.Y - 1, p1.Z))
		world:box(model, wallStyle, v(x0, p1.Y - 2, laneLow + 1), v(x1, p1.Y - 1, laneHigh - 1))
	end
	sideWall(p0.X, p0.X + 1, if arrivals.fromLeft then 2 else nil)
	sideWall(p1.X - 1, p1.X, if arrivals.fromRight then 3 else nil)

	-- The level side: open into a built level, walled off with a sign otherwise.
	if not levelBuilt then
		world:box(model, wallStyle, v(p0.X + 1, padY, wallZ), v(p1.X - 1, p1.Y - 1, wallZ + outward))
		world:sign(
			model,
			"ConstructionSign",
			v(level.column * tower.ColumnPitch, padY + 4, wallZ + outward * 1.15),
			v(0, 0, outward),
			Vector2.new(12, 4),
			string.format("LEVEL %s\nUNDER CONSTRUCTION", id),
			palette.hard
		)
	end

	local checkpoint = trigger(
		model,
		"Checkpoint",
		v(p0.X + 2, padY, math.min(wallZ + outward * 2, farZ - outward * 2)),
		v(p1.X - 2, padY + 6, math.max(wallZ + outward * 2, farZ - outward * 2))
	)
	Build.tag(checkpoint, "Checkpoint", { Order = level.floor * 10 + 1, Announce = TowerMap.label(id) })
	lamp(model, v(level.column * tower.ColumnPitch, p1.Y - 1.1, (wallZ + farZ) / 2))

	model.Parent = parent
end

-- Builds every connector leaving a built level, and the pads they arrive at.
-- `isBuilt(id)` says whether a level has a room.
function Connectors.build(parent: Instance, isBuilt: (string) -> boolean): Folder
	local folder = Build.folder(parent, "Connectors")
	local arrivals: { [string]: Arrivals } = {}
	local padOrder: { string } = {}
	for _, level in TowerMap.ordered do
		if not isBuilt(level.id) then
			continue
		end
		for _, targetId in level.exits do
			local connector = Placement.connector(level.id, targetId)
			buildConnector(folder, connector)
			local entry = arrivals[targetId]
			if not entry then
				entry = { straight = nil, fromLeft = false, fromRight = false }
				arrivals[targetId] = entry
				table.insert(padOrder, targetId)
			end
			if connector.direction == 0 then
				entry.straight = connector
			elseif connector.direction > 0 then
				entry.fromLeft = true
			else
				entry.fromRight = true
			end
		end
	end
	for _, id in padOrder do
		buildPad(folder, id, arrivals[id], isBuilt(id))
	end
	return folder
end

return Connectors
