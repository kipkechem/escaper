--!strict
-- Builds Level 2, "The Switchboard": the tower's first fork. Three exits, each opened by a
-- harder use of the same parts (fuses, sockets, weight):
--   to 3M (medium):    a fuse in socket M. Fuse 1 is in a glass cage that opens while its
--                      plate holds 40 KG.
--   to 3H (hard):      a fuse in socket H and 60 KG on plate H. Fuse 2 is on a high shelf
--                      over plate H: stack crates on the plate, climb, and socket the fuse
--                      while still standing on the stack (two 20s + you = 65).
--   to 3 (very hard):  all three fuses in the main sockets and 120 KG on the main plate.
--                      Fuse 3 is at the bottom of the lift pit. 120 KG is out of reach with
--                      crates alone; the steel crate has to ride the lift up.
-- See SwitchboardLayout for the numbers and docs/LEVEL_2.md for the walkthrough.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerMap = require(ReplicatedStorage.Shared.TowerMap)
local Placement = require(script.Parent.Parent.Tower.Placement)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.SwitchboardLayout)

local Switchboard = {}

local palette = Build.palette
local tag = Build.tag

local MEZZANINE = Layout.MezzanineHeight
local TOP = Layout.WallTop

local concrete = { name = "Wall", color = palette.wall, material = Enum.Material.Concrete }
local floorStyle = { name = "Floor", color = palette.floor, material = Enum.Material.Concrete }
local trim = { name = "Trim", color = palette.trim, material = Enum.Material.SmoothPlastic }

function Switchboard.build(parent: Instance, context: Placement.Context): Model
	local builder = Build.new(context.frame)
	local exitsByTarget: { [string]: Placement.Exit } = {}
	for _, exit in context.exits do
		exitsByTarget[exit.target] = exit
	end
	local medium = exitsByTarget["3M"]
	assert(medium and exitsByTarget["3H"] and exitsByTarget["3"], "Level 2 needs exits to 3M, 3 and 3H")
	-- u points towards the medium exit's side, whichever way the level is turned.
	local side = if medium.localX > 0 then 1 else -1

	local function U(u: number, y: number, z: number): Vector3
		return Vector3.new(u * side, y, z)
	end
	local function box(where: Instance, options: Build.PartOptions, from: Vector3, to: Vector3): BasePart
		return builder:box(where, options, from, to)
	end
	local function part(
		where: Instance,
		options: Build.PartOptions,
		position: Vector3,
		size: Vector3
	): BasePart
		return builder:part(where, options, CFrame.new(position), size)
	end
	local function sign(
		where: Instance,
		name: string,
		position: Vector3,
		facing: Vector3,
		size: Vector2,
		text: string
	)
		return builder:sign(where, name, position, facing, size, text)
	end
	-- A socket on a post: a tray with lips, and the tagged volume above it.
	local function socket(where: Instance, name: string, output: string, base: Vector3)
		local post = Instance.new("Model")
		post.Name = name
		local trayTop = base.Y + 0.3
		box(
			post,
			{ name = "Tray", color = palette.dark, material = Enum.Material.Metal },
			base + Vector3.new(-1.3, 0, -1.3),
			base + Vector3.new(1.3, 0.3, 1.3)
		)
		for _, lip in
			{
				{ Vector3.new(-1.3, 0, -1.3), Vector3.new(1.3, 0.7, -1.1) },
				{ Vector3.new(-1.3, 0, 1.1), Vector3.new(1.3, 0.7, 1.3) },
				{ Vector3.new(-1.3, 0, -1.1), Vector3.new(-1.1, 0.7, 1.1) },
				{ Vector3.new(1.1, 0, -1.1), Vector3.new(1.3, 0.7, 1.1) },
			}
		do
			box(
				post,
				{ name = "Lip", color = palette.dark, material = Enum.Material.Metal },
				base + lip[1],
				base + lip[2]
			)
		end
		local volume = builder:part(post, {
			name = "Socket",
			color = palette.fuse,
			material = Enum.Material.ForceField,
			transparency = 0.5,
			canCollide = false,
			canQuery = false,
			castShadow = false,
		}, CFrame.new(Vector3.new(base.X, trayTop + 1, base.Z)), Vector3.new(2.2, 2, 2.2))
		tag(volume, "Socket", { Key = "Fuse", Output = output })
		post.Parent = where
		return post
	end

	local room = Instance.new("Model")
	room.Name = "Level" .. context.id
	tag(room, "Room", { RoomName = context.label })

	-- Shell ---------------------------------------------------------------------------
	local shell = Build.folder(room, "Shell")
	-- Side walls and floor.
	box(shell, concrete, U(-26, -2, -42), U(-24, TOP, 100))
	box(shell, concrete, U(24, -2, -42), U(26, TOP, 100))
	-- Front wall with the entrance opening (x -3..3, 8 high).
	box(shell, concrete, U(-24, -2, -42), U(-3, TOP, -41))
	box(shell, concrete, U(3, -2, -42), U(24, TOP, -41))
	box(shell, concrete, U(-3, 8, -42), U(3, TOP, -41))
	box(shell, concrete, U(-3, -2, -42), U(3, 0, -41))
	-- Main floor, leaving the rider recess (u -4.5..4.25) and the pit (u 4.5..19.5).
	box(shell, floorStyle, U(-24, -2, -41), U(24, 0, 55))
	box(shell, floorStyle, U(-24, -2, 55), U(-4.5, 0, 64))
	box(shell, floorStyle, U(20.5, -2, 55), U(24, 0, 64))
	box(
		shell,
		{ name = "LiftRecess", color = palette.dark, material = Enum.Material.Metal },
		U(-4.5, -2.2, 55),
		U(4.25, -1.2, 64)
	)
	local pit = { name = "PitWall", color = palette.wall, material = Enum.Material.Concrete }
	box(shell, pit, U(4.25, -15, 55), U(4.5, 0, 64))
	box(shell, pit, U(19.5, -15, 55), U(20.5, 0, 64))
	box(shell, pit, U(4.25, -15, 54), U(20.5, 1.5, 55))
	box(shell, pit, U(4.25, -15, 64), U(20.5, 0, 65))
	box(
		shell,
		{ name = "PitFloor", color = palette.dark, material = Enum.Material.Concrete },
		U(4.5, -16, 55),
		U(19.5, -14, 64)
	)
	box(shell, trim, U(4.25, 1.5, 54), U(20.5, 1.7, 55))
	-- Mezzanine block and its edge.
	box(
		shell,
		{ name = "Mezzanine", color = palette.wall, material = Enum.Material.Concrete },
		U(-24, 0, 64),
		U(24, MEZZANINE, 99)
	)
	box(shell, trim, U(-24, MEZZANINE - 0.6, 63.7), U(24, MEZZANINE + 0.05, 64.2))
	-- Back wall with an opening for each exit.
	local openingHalf = 3
	local slots = {}
	for _, exit in context.exits do
		table.insert(slots, exit.localX * side)
	end
	table.sort(slots)
	box(shell, concrete, U(-24, -2, 99), U(24, MEZZANINE, 100))
	box(shell, concrete, U(-24, MEZZANINE + 8, 99), U(24, TOP, 100))
	local previous = -24
	for _, u in slots do
		box(shell, concrete, U(previous, MEZZANINE, 99), U(u - openingHalf, MEZZANINE + 8, 100))
		previous = u + openingHalf
	end
	box(shell, concrete, U(previous, MEZZANINE, 99), U(24, MEZZANINE + 8, 100))
	box(
		shell,
		{ name = "InvisibleCeiling", transparency = 1, castShadow = false },
		U(-26, TOP - 1, -42),
		U(26, TOP, 100)
	)
	for _, position in
		{
			U(-12, TOP - 1.5, -20),
			U(12, TOP - 1.5, -20),
			U(-12, TOP - 1.5, 30),
			U(12, TOP - 1.5, 30),
			U(0, TOP - 1.5, 80),
		}
	do
		builder:lamp(shell, position)
	end

	-- Ramp to the mezzanine: 4.6 wide between the wall and a divider. Crates fit up it; the
	-- 5-wide steel crate does not.
	local rampInner = -24 + Layout.RampWidth
	builder:part(
		shell,
		{ name = "Ramp", class = "WedgePart", color = palette.floor, material = Enum.Material.DiamondPlate },
		CFrame.new(U((-24 + rampInner) / 2, MEZZANINE / 2, 46)),
		Vector3.new(Layout.RampWidth, MEZZANINE, 32)
	)
	box(
		shell,
		{ name = "RampLanding", color = palette.floor, material = Enum.Material.DiamondPlate },
		U(-24, MEZZANINE - 2, 62),
		U(rampInner, MEZZANINE, 64)
	)
	box(shell, concrete, U(rampInner, 0, 30), U(rampInner + 0.5, MEZZANINE + 4, 64))

	-- Main floor ------------------------------------------------------------------------
	local floorFolder = Build.folder(room, "Floor")
	-- The glass fuse cage (fuse 1) and its plate.
	local glass =
		{ name = "Glass", color = palette.glass, material = Enum.Material.Glass, transparency = 0.55 }
	box(floorFolder, glass, U(13, 0, 9), U(19, 7, 9.3))
	box(floorFolder, glass, U(13, 0, 14.7), U(19, 7, 15))
	box(floorFolder, glass, U(18.7, 0, 9.3), U(19, 7, 14.7))
	box(floorFolder, glass, U(13, 7, 9), U(19, 7.3, 15))
	box(
		floorFolder,
		{ name = "Pedestal", color = palette.steel, material = Enum.Material.Metal },
		U(15, 0, 11),
		U(17, 2, 13)
	)
	local cageDoor = box(
		floorFolder,
		{ name = "CageDoor", color = palette.glass, material = Enum.Material.Glass, transparency = 0.4 },
		U(13, 0, 9.3),
		U(13.3, 7, 14.7)
	)
	tag(cageDoor, "Door", { Input = "CagePlate", OpenOffset = Vector3.new(0, 6.8, 0), OpenTime = 1 })
	local cagePlate = part(
		floorFolder,
		{ name = "CagePlate", material = Enum.Material.DiamondPlate },
		U(Layout.CagePlate.X, 0, Layout.CagePlate.Z),
		Vector3.new(8, 1, 8)
	)
	tag(
		cagePlate,
		"PressurePlate",
		{ Output = "CagePlate", RequiredMass = Layout.CagePlateMass, Label = "CAGE" }
	)
	sign(
		floorFolder,
		"CageSign",
		U(16, 9.5, 8.85),
		Vector3.new(0, 0, -1),
		Vector2.new(8, 2.5),
		"FUSE CAGE\nOPENS WITH 40 KG ON THE PLATE"
	)

	-- The counterweight lift, and the pit below its cargo platform.
	local lift = Layout.Lift
	local function liftCenter(center: Vector3): Vector3
		return U(center.X, center.Y, center.Z)
	end
	builder:counterweightLift(floorFolder, {
		travel = lift.Travel,
		speed = lift.Speed,
		tareA = lift.TareA,
		tareB = lift.TareB,
		output = "LiftUp",
		a = { center = liftCenter(lift.PlatformA.center), size = lift.PlatformA.size },
		b = { center = liftCenter(lift.PlatformB.center), size = lift.PlatformB.size },
		railsA = { { name = "RailAlcove", offset = U(3.8, 1.25, 0), size = Vector3.new(0.4, 1.5, 8) } },
		railsB = { { name = "RailOuter", offset = U(-3.8, 1.25, 0), size = Vector3.new(0.4, 1.5, 8) } },
		girderHeight = 32,
	})
	sign(
		floorFolder,
		"LiftSign",
		U(-12, 9, 63.85),
		Vector3.new(0, 0, -1),
		Vector2.new(11, 4),
		"FREIGHT LIFT\nTHE HEAVIER SIDE GOES DOWN\nTHE RIDER CAGE WEIGHS 10 KG"
	)
	-- The pit alcove: a grate hatch that only opens from below, a ladder, and the lever.
	local hatch = box(floorFolder, {
		name = "PitHatch",
		color = palette.dark,
		material = Enum.Material.DiamondPlate,
		transparency = 0.35,
	}, U(13.5, -0.5, 55), U(19.5, 0, 64))
	tag(hatch, "Door", { Input = "PitLever", OpenOffset = builder:vector(U(6.5, 0, 0)), OpenTime = 0.8 })
	builder:part(
		floorFolder,
		{ name = "PitLadder", class = "TrussPart", color = palette.steel, material = Enum.Material.Metal },
		CFrame.new(U(18.5, -7.5, 63)),
		Vector3.new(2, 14, 2)
	)
	builder:lever(floorFolder, "PitLever", U(15, -14, 62.5), {
		Output = "PitLever",
		Mode = "Timed",
		Duration = Layout.PitLeverSeconds,
		Label = "Hatch release",
	})
	sign(
		floorFolder,
		"HatchSign",
		U(16.5, 4, 63.85),
		Vector3.new(0, 0, -1),
		Vector2.new(6, 2.5),
		"MAINTENANCE PIT\nHATCH OPENS FROM BELOW"
	)
	sign(
		floorFolder,
		"RampSign",
		U(-21.7, 9, 29.85),
		Vector3.new(0, 0, -1),
		Vector2.new(4.2, 2),
		"STAIRS\nNO HEAVY LOADS"
	)
	builder:resetConsole(floorFolder, "ResetFloor", U(-21, 0, -36), U(1, 0, 0))

	-- Mezzanine: the switchboard ------------------------------------------------------
	local mezzanine = Build.folder(room, "Mezzanine")
	local checkpoint = part(
		mezzanine,
		{ name = "MezzanineCheckpoint", transparency = 1, canCollide = false, castShadow = false },
		U(0, MEZZANINE + 3, 66),
		Vector3.new(10, 6, 3)
	)
	tag(checkpoint, "Checkpoint", { Order = context.level.floor * 10 + 2 })

	-- Hard: plate H, the rack beside it, and the shelf over it holding fuse 2.
	local plateH = part(
		mezzanine,
		{ name = "PlateH", material = Enum.Material.DiamondPlate },
		U(Layout.PlateH.X, MEZZANINE, Layout.PlateH.Z),
		Vector3.new(8, 1, 8)
	)
	tag(plateH, "PressurePlate", { Output = "PlateH", RequiredMass = Layout.PlateHMass, Label = "HARD EXIT" })
	box(
		mezzanine,
		{ name = "Rack", color = palette.steel, material = Enum.Material.Metal },
		U(-24, MEZZANINE, 82),
		U(-19, Layout.ShelfHeight, 90)
	)
	box(
		mezzanine,
		{ name = "Shelf", color = palette.steel, material = Enum.Material.Metal },
		U(-19, Layout.ShelfHeight - 0.4, 84),
		U(-13, Layout.ShelfHeight, 88)
	)
	socket(mezzanine, "SocketH", "SocketH", U(-21.5, MEZZANINE + 8, 91.3))
	box(
		mezzanine,
		{ name = "SocketHBracket", color = palette.steel, material = Enum.Material.Metal },
		U(-22.8, MEZZANINE, 90),
		U(-20.2, MEZZANINE + 8, 92.6)
	)

	-- Main: the plate at the lift landing and three sockets.
	local plateMain = part(
		mezzanine,
		{ name = "PlateMain", material = Enum.Material.DiamondPlate },
		U(Layout.PlateMain.X, MEZZANINE, Layout.PlateMain.Z),
		Vector3.new(8, 1, 8)
	)
	tag(
		plateMain,
		"PressurePlate",
		{ Output = "PlateMain", RequiredMass = Layout.PlateMainMass, Label = "MAIN EXIT" }
	)
	for _, spec in Layout.Sockets do
		local post = U(spec.u, MEZZANINE, spec.z)
		box(
			mezzanine,
			{ name = spec.name .. "Post", color = palette.steel, material = Enum.Material.Metal },
			post + Vector3.new(-0.5, 0, -0.5),
			post + Vector3.new(0.5, 3.5, 0.5)
		)
		socket(mezzanine, spec.name, spec.output, post + Vector3.new(0, 3.5, 0))
	end

	-- The three exits: a door, a light and a sign each.
	for _, exit in context.exits do
		local rule = Layout.ExitRules[exit.target]
		local target = TowerMap.levels[exit.target]
		local x = exit.localX
		local door = builder:part(mezzanine, {
			name = "Exit" .. exit.target,
			color = Build.difficultyColor(target.difficulty),
			material = Enum.Material.CorrodedMetal,
		}, CFrame.new(x, MEZZANINE + 4, 99.5), Vector3.new(6, 8, 1))
		tag(door, "Door", { Input = rule.input, Latch = true, OpenOffset = Vector3.new(0, 7.6, 0) })
		local light = builder:part(
			mezzanine,
			{ name = "ExitLight" .. exit.target, castShadow = false },
			CFrame.new(x, MEZZANINE + 9, 98.85),
			Vector3.new(3, 0.8, 0.3)
		)
		tag(light, "Indicator", { Input = rule.input })
		sign(
			mezzanine,
			"ExitSign" .. exit.target,
			Vector3.new(x, MEZZANINE + 12.5, 98.85),
			Vector3.new(0, 0, -1),
			Vector2.new(11, 5),
			string.format(
				"%s\n%s\nNEEDS %s",
				string.upper(TowerMap.label(exit.target)),
				string.upper(target.difficulty),
				rule.needs
			)
		)
	end
	builder:resetConsole(mezzanine, "ResetMezzanine", U(21, MEZZANINE, 68), U(-1, 0, 0))

	-- Loose objects ------------------------------------------------------------------
	local loose = Build.folder(room, "Loose")
	for _, spec in Layout.Objects do
		builder:loose(loose, {
			name = spec.name,
			kind = spec.kind,
			mass = spec.mass,
			position = U(spec.position.X, spec.position.Y, spec.position.Z),
			size = spec.size,
			yaw = spec.yaw,
		})
	end

	room.Parent = parent
	return room
end

return Switchboard
