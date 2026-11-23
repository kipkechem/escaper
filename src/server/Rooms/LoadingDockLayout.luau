--!strict
-- Numbers and positions for Room 1, "The Loading Dock". The builder reads this table,
-- and tests/run.luau checks the puzzle maths against it, so change values here.
--
-- Floor of the dock and lift hall is at y = 0. Players move towards +Z:
--   truck bay (z -40..-12, 9 studs below the dock)
--   dock floor (z -12..28) with the weighted shutter in the wall at z 28..30
--   lift hall (z 30..64) with the counterweight lift against the mezzanine
--   mezzanine (z 64..80, 16 studs up) with the exit door in the back wall
--   exit corridor (z 82..98)

local Layout = {}

Layout.RoomName = "The Loading Dock"
Layout.WallTop = 40
Layout.BayDepth = 9
Layout.CrateSize = 4
Layout.MezzanineHeight = 16
Layout.ShutterPlateMass = 40
Layout.ExitPlateMass = 30

Layout.Lift = {
	Travel = 16,
	Speed = 5,
	TareA = 0,
	-- The rider cage is heavier than the empty cargo platform, so an empty lift rests
	-- with the rider platform at the bottom and nothing ever gets stranded at the top.
	TareB = 10,
	-- Rider platform (B): top flush with the hall floor when down.
	PlatformB = { center = Vector3.new(-1, -0.5, 59.5), size = Vector3.new(8, 1, 8) },
	-- Cargo platform (A): top 4 studs above the floor when up, drops into a pit.
	PlatformA = { center = Vector3.new(8, 3.5, 59.5), size = Vector3.new(8, 1, 8) },
}

export type CrateSpec = {
	name: string,
	zone: string,
	mass: number,
	position: Vector3,
	size: Vector3,
	yaw: number,
}

-- zone: "bay" (truck), "dock" (before the shutter), "hall" (after the shutter).
Layout.Crates = {
	{
		name = "BayCrateA",
		zone = "bay",
		mass = 10,
		position = Vector3.new(-3.5, -7, -25),
		size = Vector3.one * 4,
		yaw = 12,
	},
	{
		name = "BayCrateB",
		zone = "bay",
		mass = 10,
		position = Vector3.new(3.5, -7, -21),
		size = Vector3.one * 4,
		yaw = -20,
	},
	{
		name = "DockCrateA",
		zone = "dock",
		mass = 20,
		position = Vector3.new(12, 2, 6),
		size = Vector3.one * 4,
		yaw = 8,
	},
	{
		name = "DockCrateB",
		zone = "dock",
		mass = 20,
		position = Vector3.new(-6, 2, 12),
		size = Vector3.one * 4,
		yaw = -15,
	},
	{
		name = "DockCrateC",
		zone = "dock",
		mass = 10,
		position = Vector3.new(16, 2, 18),
		size = Vector3.one * 4,
		yaw = 30,
	},
	{
		name = "SteelCrate",
		zone = "dock",
		mass = 60,
		position = Vector3.new(17, 2, -4),
		size = Vector3.new(5, 4, 5),
		yaw = 0,
	},
	{
		name = "HallCrateA",
		zone = "hall",
		mass = 20,
		position = Vector3.new(-14, 2, 44),
		size = Vector3.one * 4,
		yaw = 5,
	},
	{
		name = "HallCrateB",
		zone = "hall",
		mass = 10,
		position = Vector3.new(-8, 2, 50),
		size = Vector3.one * 4,
		yaw = -25,
	},
	{
		name = "HallCrateC",
		zone = "hall",
		mass = 10,
		position = Vector3.new(18, 2, 40),
		size = Vector3.one * 4,
		yaw = 18,
	},
} :: { CrateSpec }

return Layout
