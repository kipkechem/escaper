--!strict
-- Builds Level 1, "The Loading Dock", as a grey-box level. See LoadingDockLayout for the
-- positions and puzzle numbers, and docs/ROOM_1.md for the walkthrough.
--
-- Built in the level's own coordinates (see Tower/Placement). Level 1 sits at the tower's
-- origin; its one exit is the opening at the end of the exit corridor.
-- Like every builder, this only creates instances (see Rooms/Build).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerMap = require(ReplicatedStorage.Shared.TowerMap)
local Placement = require(script.Parent.Parent.Tower.Placement)
local Layout = require(script.Parent.LoadingDockLayout)

local LoadingDock = {}

local Build = require(script.Parent.Build)

local palette = Build.palette
local folder, tag = Build.folder, Build.tag

-- Everything is placed through the level's frame (set at the start of `build`).
local builder = Build.new()

local function makePart(parent: Instance, options: Build.PartOptions, cframe: CFrame, size: Vector3): BasePart
	return builder:part(parent, options, cframe, size)
end

local function box(parent: Instance, options: Build.PartOptions, from: Vector3, to: Vector3): BasePart
	return builder:box(parent, options, from, to)
end

local function sign(
	parent: Instance,
	name: string,
	position: Vector3,
	facing: Vector3,
	size: Vector2,
	text: string
)
	return builder:sign(parent, name, position, facing, size, text)
end

local function buildShell(room: Model)
	local shell = folder(room, "Shell")
	local top = Layout.WallTop
	local brick = { name = "Wall", color = palette.brick, material = Enum.Material.Brick }
	local concrete = { name = "Wall", color = palette.wall, material = Enum.Material.Concrete }
	local floor = { name = "Floor", color = palette.floor, material = Enum.Material.Concrete }

	-- Outer walls along both sides of the dock and hall.
	box(shell, brick, Vector3.new(-26, -10, -14), Vector3.new(-24, top, 82))
	box(shell, brick, Vector3.new(24, -10, -14), Vector3.new(26, top, 82))

	-- Truck bay: a trailer backed up to the dock, its floor 9 studs below the dock.
	local bayFloor = -Layout.BayDepth
	box(
		shell,
		{ name = "BayFloor", color = palette.bayFloor, material = Enum.Material.WoodPlanks },
		Vector3.new(-8, bayFloor - 2, -40),
		Vector3.new(8, bayFloor, -12)
	)
	local trailer = { name = "TrailerWall", color = palette.trailer, material = Enum.Material.Metal }
	box(shell, trailer, Vector3.new(-10, bayFloor - 2, -42), Vector3.new(-8, top, -12))
	box(shell, trailer, Vector3.new(8, bayFloor - 2, -42), Vector3.new(10, top, -12))
	box(shell, trailer, Vector3.new(-8, bayFloor - 2, -42), Vector3.new(8, top, -40))
	-- Dock front wall either side of the bay.
	box(shell, brick, Vector3.new(-24, -10, -14), Vector3.new(-10, top, -12))
	box(shell, brick, Vector3.new(10, -10, -14), Vector3.new(24, top, -12))

	-- Dock floor: one solid block, so its face is the ledge you climb from the truck.
	box(shell, floor, Vector3.new(-24, -10, -12), Vector3.new(24, 0, 28))
	box(
		shell,
		{ name = "DockEdge", color = palette.trim, material = Enum.Material.SmoothPlastic },
		Vector3.new(-8, -0.6, -12.2),
		Vector3.new(8, 0.05, -11.6)
	)

	-- Wall between the dock and the lift hall, with the shutter opening (x -5..5, 10 high).
	box(shell, concrete, Vector3.new(-24, 0, 28), Vector3.new(-5, top, 30))
	box(shell, concrete, Vector3.new(5, 0, 28), Vector3.new(24, top, 30))
	box(shell, concrete, Vector3.new(-5, 10, 28), Vector3.new(5, top, 30))

	-- Lift hall floor, leaving holes for the rider platform's recess and the cargo pit.
	box(shell, floor, Vector3.new(-24, -2, 30), Vector3.new(24, 0, 55))
	box(shell, floor, Vector3.new(-24, -2, 55), Vector3.new(-5.5, 0, 64))
	box(shell, floor, Vector3.new(15.5, -2, 55), Vector3.new(24, 0, 64))
	box(shell, floor, Vector3.new(-24, -2, 64), Vector3.new(24, 0, 80))
	-- Rider platform recess, 1 stud deep.
	box(
		shell,
		{ name = "LiftRecess", color = palette.dark, material = Enum.Material.Metal },
		Vector3.new(-5.5, -2.2, 55),
		Vector3.new(3.25, -1.2, 64)
	)
	-- Cargo pit (x 3.5..15.5): the cargo platform drops into it; the east end is a ladder well.
	-- Only a thin wall separates it from the rider recess, so the platforms are 1 stud apart.
	local pit = { name = "PitWall", color = palette.wall, material = Enum.Material.Concrete }
	box(shell, pit, Vector3.new(3.25, -15, 55), Vector3.new(3.5, 0, 64))
	box(shell, pit, Vector3.new(15.5, -15, 54), Vector3.new(16.5, 1.5, 64))
	box(shell, pit, Vector3.new(3.5, -15, 54), Vector3.new(15.5, 1.5, 55))
	box(shell, pit, Vector3.new(3.25, -15, 64), Vector3.new(16.5, 0, 65))
	box(
		shell,
		{ name = "PitFloor", color = palette.dark, material = Enum.Material.Concrete },
		Vector3.new(3.5, -16, 55),
		Vector3.new(15.5, -14, 64)
	)
	box(
		shell,
		{ name = "PitCurb", color = palette.trim, material = Enum.Material.SmoothPlastic },
		Vector3.new(3.5, 1.5, 54),
		Vector3.new(16.5, 1.7, 55)
	)
	makePart(
		shell,
		{ name = "PitLadder", class = "TrussPart", color = palette.steel, material = Enum.Material.Metal },
		CFrame.new(14.5, -6, 63),
		Vector3.new(2, 16, 2)
	)

	-- Mezzanine: a solid block 16 studs high along the back of the hall.
	local mezzanine = Layout.MezzanineHeight
	box(
		shell,
		{ name = "Mezzanine", color = palette.wall, material = Enum.Material.Concrete },
		Vector3.new(-24, 0, 64),
		Vector3.new(24, mezzanine, 80)
	)
	box(
		shell,
		{ name = "MezzanineEdge", color = palette.trim, material = Enum.Material.SmoothPlastic },
		Vector3.new(-24, mezzanine - 0.6, 63.7),
		Vector3.new(24, mezzanine + 0.05, 64.2)
	)

	-- Back wall with the exit opening (x -3..3, from the mezzanine up 8 studs).
	box(shell, concrete, Vector3.new(-24, 0, 80), Vector3.new(-3, top, 82))
	box(shell, concrete, Vector3.new(3, 0, 80), Vector3.new(24, top, 82))
	box(shell, concrete, Vector3.new(-3, 0, 80), Vector3.new(3, mezzanine, 82))
	box(shell, concrete, Vector3.new(-3, mezzanine + 8, 80), Vector3.new(3, top, 82))

	-- Exit corridor behind the door. Its end wall has the opening (x -3..3, 8 high) where the
	-- ladder up to Level 2 starts.
	box(shell, floor, Vector3.new(-6, mezzanine - 2, 82), Vector3.new(6, mezzanine, 100))
	box(shell, concrete, Vector3.new(-8, mezzanine - 2, 82), Vector3.new(-6, top, 100))
	box(shell, concrete, Vector3.new(6, mezzanine - 2, 82), Vector3.new(8, top, 100))
	box(shell, concrete, Vector3.new(-6, mezzanine, 99), Vector3.new(-3, top, 100))
	box(shell, concrete, Vector3.new(3, mezzanine, 99), Vector3.new(6, top, 100))
	box(shell, concrete, Vector3.new(-3, mezzanine + 8, 99), Vector3.new(3, top, 100))

	-- Lamps: the level above shades this one from the sun.
	for _, position in
		{
			Vector3.new(0, top - 1.5, -26),
			Vector3.new(-12, top - 1.5, 0),
			Vector3.new(12, top - 1.5, 0),
			Vector3.new(-12, top - 1.5, 45),
			Vector3.new(12, top - 1.5, 45),
			Vector3.new(0, top - 1.5, 72),
			Vector3.new(0, top - 1.5, 91),
		}
	do
		builder:lamp(shell, position)
	end

	-- An invisible lid so stacked crates never let anyone climb out over the walls.
	box(
		shell,
		{ name = "InvisibleCeiling", transparency = 1, castShadow = false },
		Vector3.new(-26, top, -42),
		Vector3.new(26, top + 1, 100)
	)
end

local function buildCrates(room: Model)
	local crates = folder(room, "Crates")
	for _, spec in Layout.Crates do
		builder:loose(crates, {
			name = spec.name,
			kind = if spec.mass > 45 then "steel" else "crate",
			mass = spec.mass,
			position = spec.position,
			size = spec.size,
			yaw = spec.yaw,
		})
	end
end

local function buildDock(room: Model)
	local dock = folder(room, "Dock")
	local bayFloor = -Layout.BayDepth

	local spawn = makePart(dock, {
		name = "Spawn",
		class = "SpawnLocation",
		color = palette.trim,
		material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, bayFloor + 0.5, -33), Vector3.new(6, 1, 6)) :: SpawnLocation
	spawn.Neutral = true
	spawn.Duration = 0
	tag(spawn, "Checkpoint", { Order = 11, Announce = TowerMap.label("1") })

	sign(
		dock,
		"DockSign",
		Vector3.new(0, bayFloor + 4.5, -12.15),
		Vector3.new(0, 0, -1),
		Vector2.new(10, 3),
		"LOADING DOCK 3\nSTAFF ONLY"
	)

	-- Puzzle 1: the shutter opens while its plate carries 40 KG, or while the override lever
	-- on the far side is on.
	local plate = makePart(
		dock,
		{ name = "ShutterPlate", material = Enum.Material.DiamondPlate },
		CFrame.new(-14, 0, 22),
		Vector3.new(8, 1, 8)
	)
	tag(
		plate,
		"PressurePlate",
		{ Output = "ShutterPlate", RequiredMass = Layout.ShutterPlateMass, Label = "SHUTTER" }
	)
	box(
		dock,
		{ name = "PlateFrame", color = palette.trim },
		Vector3.new(-18.4, -0.4, 17.6),
		Vector3.new(-9.6, 0.05, 26.4)
	)

	local shutter = makePart(
		dock,
		{ name = "Shutter", color = palette.shutter, material = Enum.Material.CorrodedMetal },
		CFrame.new(0, 5, 29),
		Vector3.new(10, 10, 2)
	)
	tag(
		shutter,
		"Door",
		{ Input = "ShutterPlate | ShutterLever", OpenOffset = Vector3.new(0, 9.6, 0), OpenTime = 1.4 }
	)
	for index, z in { 27.85, 30.15 } do
		local light = makePart(
			dock,
			{ name = "ShutterLight" .. index, castShadow = false },
			CFrame.new(0, 11.5, z),
			Vector3.new(3, 0.8, 0.3)
		)
		tag(light, "Indicator", { Input = "ShutterPlate | ShutterLever" })
	end

	sign(
		dock,
		"ShutterSign",
		Vector3.new(-14, 7, 27.85),
		Vector3.new(0, 0, -1),
		Vector2.new(9, 3),
		"SHUTTER RELEASE\nLOAD 40 KG ON THE PLATE"
	)
	sign(
		dock,
		"WeightSign",
		Vector3.new(-23.85, 6, 10),
		Vector3.new(1, 0, 0),
		Vector2.new(9, 3.5),
		"SAFETY NOTICE\nEACH WORKER COUNTS AS 25 KG\nCARRIED LOADS COUNT TOO"
	)

	builder:resetConsole(dock, "ResetDock", Vector3.new(-21, 0, -9), Vector3.new(1, 0, 0))
end

local function buildLift(parent: Instance): Model
	local lift = Layout.Lift
	return builder:counterweightLift(parent, {
		travel = lift.Travel,
		speed = lift.Speed,
		tareA = lift.TareA,
		tareB = lift.TareB,
		output = "LiftUp",
		a = lift.PlatformA,
		b = lift.PlatformB,
		-- Cargo side: a rail by the ladder well so crates do not slide off.
		railsA = {
			{ name = "RailEast", offset = Vector3.new(3.8, 1.25, 0), size = Vector3.new(0.4, 1.5, 8) },
		},
		-- Rider side: a rail on the open-air side only, so the cargo side is within easy reach.
		railsB = {
			{ name = "RailWest", offset = Vector3.new(-3.8, 1.25, 0), size = Vector3.new(0.4, 1.5, 8) },
		},
		girderHeight = 30,
	})
end

local function buildHall(room: Model, context: Placement.Context)
	local hall = folder(room, "Hall")
	local mezzanine = Layout.MezzanineHeight

	local checkpoint = makePart(
		hall,
		{ name = "HallCheckpoint", transparency = 1, canCollide = false, castShadow = false },
		CFrame.new(0, 3, 33.5),
		Vector3.new(10, 6, 3)
	)
	tag(checkpoint, "Checkpoint", { Order = 12 })

	builder:lever(
		hall,
		"ShutterLever",
		Vector3.new(9, 0, 33),
		{ Output = "ShutterLever", Label = "Shutter override" }
	)
	sign(
		hall,
		"LeverSign",
		Vector3.new(9, 6, 30.15),
		Vector3.new(0, 0, 1),
		Vector2.new(6, 2),
		"SHUTTER OVERRIDE"
	)

	buildLift(hall)
	sign(
		hall,
		"LiftSign",
		Vector3.new(-14, 9, 63.85),
		Vector3.new(0, 0, -1),
		Vector2.new(11, 4),
		"FREIGHT LIFT\nTHE HEAVIER SIDE GOES DOWN\nTHE RIDER CAGE WEIGHS 10 KG"
	)

	local mezzanineCheckpoint = makePart(
		hall,
		{ name = "MezzanineCheckpoint", transparency = 1, canCollide = false, castShadow = false },
		CFrame.new(-1, mezzanine + 3, 67),
		Vector3.new(10, 6, 4)
	)
	tag(mezzanineCheckpoint, "Checkpoint", { Order = 13 })

	-- Puzzle 3: the exit opens (and stays open) once its plate carries 30 KG.
	local plate = makePart(
		hall,
		{ name = "ExitPlate", material = Enum.Material.DiamondPlate },
		CFrame.new(-12, mezzanine, 72),
		Vector3.new(6, 1, 6)
	)
	tag(plate, "PressurePlate", { Output = "ExitPlate", RequiredMass = Layout.ExitPlateMass, Label = "EXIT" })
	sign(
		hall,
		"ExitSign",
		Vector3.new(-12, mezzanine + 5.5, 79.85),
		Vector3.new(0, 0, -1),
		Vector2.new(7, 2.5),
		"EXIT RELEASE\nLOAD 30 KG"
	)

	local exitDoor = makePart(
		hall,
		{ name = "ExitDoor", color = palette.shutter, material = Enum.Material.CorrodedMetal },
		CFrame.new(0, mezzanine + 4, 81),
		Vector3.new(6, 8, 2)
	)
	tag(exitDoor, "Door", { Input = "ExitPlate", Latch = true, OpenOffset = Vector3.new(0, 7.6, 0) })
	local exitLight = makePart(
		hall,
		{ name = "ExitLight", castShadow = false },
		CFrame.new(0, mezzanine + 9.5, 79.85),
		Vector3.new(3, 0.8, 0.3)
	)
	tag(exitLight, "Indicator", { Input = "ExitPlate" })

	-- A fire-escape ladder that drops down once the exit is open, for anyone left below.
	local ladder = makePart(
		hall,
		{ name = "FireLadder", class = "TrussPart", color = palette.trim, material = Enum.Material.Metal },
		CFrame.new(-20, mezzanine + 8, 63),
		Vector3.new(2, 16, 2)
	)
	tag(
		ladder,
		"Door",
		{ Input = "ExitPlate", Latch = true, OpenOffset = Vector3.new(0, -mezzanine, 0), OpenTime = 2 }
	)

	builder:resetConsole(hall, "ResetHall", Vector3.new(-21, 0, 33), Vector3.new(1, 0, 0))

	-- Exit corridor: a sign over each exit opening (Level 1 has one).
	for _, exit in context.exits do
		sign(
			hall,
			"ExitSign" .. exit.target,
			Vector3.new(exit.localX, mezzanine + 10, 98.85),
			Vector3.new(0, 0, -1),
			Vector2.new(10, 3),
			string.upper("To " .. TowerMap.label(exit.target))
		)
	end
end

function LoadingDock.build(parent: Instance, context: Placement.Context): Model
	builder = Build.new(context.frame)
	local room = Instance.new("Model")
	room.Name = "Level" .. context.id
	tag(room, "Room", { RoomName = context.label })
	buildShell(room)
	buildDock(room)
	buildHall(room, context)
	buildCrates(room)
	room.Parent = parent
	return room
end

return LoadingDock
