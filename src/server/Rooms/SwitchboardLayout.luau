--!strict
-- Numbers and positions for Level 2, "The Switchboard" (the first fork). The builder reads
-- this table, and tests/suites/level2.luau checks the puzzle maths against it.
--
-- Positions use u instead of x: u points towards the medium-staircase side of the room,
-- whichever way the level is turned in the tower. The builder converts u to x.
--   main floor  y 0, z -41..64     the fuse cage, its plate, crates, the steel crate
--   ramp        u -24..-19.4       narrow: crates fit, the steel crate does not
--   lift        u -4..13, z 55..64 rider platform B (u 0) and cargo platform A (u 9)
--   pit         under A, with a ladder alcove (u 13.5..19.5) closed by a hatch
--   mezzanine   y 16, z 64..99     the three exits, their sockets and plates

local Layout = {}

Layout.MezzanineHeight = 16
Layout.WallTop = 44
Layout.FuseMass = 5
Layout.CagePlateMass = 40
Layout.PlateHMass = 60
Layout.PlateMainMass = 120
Layout.RampWidth = 4.6
-- Fuse 2 rests on a shelf this high (its bottom), above plate H.
Layout.ShelfHeight = 38
Layout.PitLeverSeconds = 8
Layout.CrateSize = 4

Layout.Lift = {
	Travel = 16,
	Speed = 5,
	TareA = 0,
	TareB = 10,
	PlatformB = { center = Vector3.new(0, -0.5, 59.5), size = Vector3.new(8, 1, 8) },
	PlatformA = { center = Vector3.new(9, 3.5, 59.5), size = Vector3.new(8, 1, 8) },
}

export type ObjectSpec = {
	name: string,
	kind: string, -- "crate", "steel" or "fuse"
	mass: number,
	position: Vector3, -- (u, y, z)
	size: Vector3,
	yaw: number,
}

Layout.Objects = {
	{
		name = "CrateA",
		kind = "crate",
		mass = 20,
		position = Vector3.new(-10, 2, -20),
		size = Vector3.one * 4,
		yaw = 10,
	},
	{
		name = "CrateB",
		kind = "crate",
		mass = 20,
		position = Vector3.new(-14, 2, 2),
		size = Vector3.one * 4,
		yaw = -12,
	},
	{
		name = "CrateC",
		kind = "crate",
		mass = 20,
		position = Vector3.new(4, 2, 22),
		size = Vector3.one * 4,
		yaw = 25,
	},
	{
		name = "CrateD",
		kind = "crate",
		mass = 10,
		position = Vector3.new(-4, 2, -30),
		size = Vector3.one * 4,
		yaw = -30,
	},
	{
		name = "CrateE",
		kind = "crate",
		mass = 10,
		position = Vector3.new(8, 2, 38),
		size = Vector3.one * 4,
		yaw = 15,
	},
	{
		name = "SteelCrate",
		kind = "steel",
		mass = 60,
		position = Vector3.new(-6, 2, 36),
		size = Vector3.new(5, 4, 5),
		yaw = 0,
	},
	-- Fuse 1 sits on a pedestal in the glass cage.
	{
		name = "Fuse1",
		kind = "fuse",
		mass = 5,
		position = Vector3.new(16, 3, 12),
		size = Vector3.new(1, 2, 1),
		yaw = 0,
	},
	-- Fuse 2 is on the shelf above plate H.
	{
		name = "Fuse2",
		kind = "fuse",
		mass = 5,
		position = Vector3.new(-15.5, 39, 86),
		size = Vector3.new(1, 2, 1),
		yaw = 0,
	},
	-- Fuse 3 lies at the bottom of the lift pit, in the ladder alcove.
	{
		name = "Fuse3",
		kind = "fuse",
		mass = 5,
		position = Vector3.new(16.5, -13, 58),
		size = Vector3.new(1, 2, 1),
		yaw = 0,
	},
} :: { ObjectSpec }

-- Pressure plates (u, z on the floor they sit on) and sockets (u, z on the mezzanine).
Layout.CagePlate = Vector3.new(16, 0, -4)
Layout.PlateH = Vector3.new(-13, 16, 86)
Layout.PlateMain = Vector3.new(0, 16, 72)
Layout.Sockets = {
	{ name = "SocketM", output = "SocketM", u = 11, z = 94 },
	{ name = "SocketMainA", output = "MainA", u = -6, z = 94 },
	{ name = "SocketMainB", output = "MainB", u = 6, z = 94 },
	{ name = "SocketMainC", output = "MainC", u = -8, z = 72 },
}

-- What opens each exit, by target level. The signs say the same in words.
Layout.ExitRules = {
	["3M"] = { input = "SocketM", needs = "A FUSE IN ITS SOCKET" },
	["3H"] = { input = "SocketH & PlateH", needs = "A FUSE IN ITS SOCKET\n+ 60 KG ON THE PLATE" },
	["3"] = { input = "MainA & MainB & MainC & PlateMain", needs = "3 FUSES\n+ 120 KG ON THE PLATE" },
} :: { [string]: { input: string, needs: string } }

return Layout
