--!strict
-- Tuning values shared by the server and the client. Masses are Roblox mass units;
-- signs in the world call them "KG" so players can do the sums.

local Config = {}

Config.Grab = {
	-- How far from the HumanoidRootPart a player can reach an object (to its nearest surface).
	Reach = 11,
	-- Extra distance the server accepts, to allow for network delay.
	ServerReachSlack = 6,
	-- If a held object ends up this far from the holder, it is dropped.
	BreakDistance = 22,
	-- Heaviest object a player can lift off the ground. Heavier objects can only be dragged.
	LiftCapacity = 45,
	-- Horizontal pull for dragging (as a multiple of LiftCapacity's weight).
	DragStrength = 1.4,
	-- Gap between the player's head and the near side of a held object.
	HoldGap = 1.5,
	-- Throw speed is ThrowImpulse / mass, capped at ThrowMaxSpeed (studs per second).
	ThrowImpulse = 900,
	ThrowMaxSpeed = 70,
	-- How quickly a held object follows the hold point.
	Responsiveness = 30,
	-- Maximum speed of a held object is SpeedBudget / mass, kept between these limits.
	SpeedBudget = 800,
	MinHoldSpeed = 14,
	MaxHoldSpeed = 50,
	-- Walk speed while carrying drops towards this fraction for the heaviest loads.
	MinWalkFactor = 0.45,
	-- Rotation step for the rotate action, in degrees.
	RotateStep = 90,
	-- After a release the thrower keeps physics ownership this long, then the server takes over.
	OwnershipHandBackDelay = 1.0,
}

Config.Weight = {
	-- Every player counts as this much on plates and lifts, plus whatever they are carrying.
	Player = 25,
	-- Objects moving faster than this are not "resting" and are not counted.
	RestingSpeed = 10,
	-- A character keeps counting this long after leaving the ground (stops jumps flickering lifts).
	GroundedGrace = 0.6,
	-- Default height of the column above a plate that is weighed.
	SensorHeight = 14,
}

Config.Lift = {
	Speed = 5,
	Deadband = 2,
	SensorHz = 10,
}

Config.Door = {
	OpenTime = 1.2,
}

Config.Reset = {
	Cooldown = 10,
	-- Objects that fall below this height are returned to their starting place.
	VoidHeight = -80,
	-- Objects carried this far from where they started (out of their level) go back too.
	MaxDistanceFromHome = 180,
}

-- Layout of the tower. See docs/TOWER.md.
Config.Tower = {
	FloorHeight = 64,
	ColumnPitch = 64,
	-- Every level fits in this box, in its own coordinates. Its entrance is in the wall at
	-- z = EnvelopeMin.Z (floor level), its exits in the wall at z = EnvelopeMax.Z.
	EnvelopeMin = Vector3.new(-26, -16, -42),
	EnvelopeMax = Vector3.new(26, 44, 100),
	-- Exit openings: floor height, side-slot offset, and size.
	ExitHeight = 16,
	ExitSlotOffset = 16,
	OpeningWidth = 6,
	OpeningHeight = 8,
	-- Landing zone beyond each level's end: three lanes of this depth.
	LaneDepth = 8,
	-- Half the width of an entrance pad, and its inside height.
	PadHalfWidth = 10,
	TubeHeight = 10,
}

Config.Colors = {
	Off = Color3.fromRGB(150, 40, 35),
	On = Color3.fromRGB(70, 200, 90),
	Neutral = Color3.fromRGB(90, 90, 95),
	Highlight = Color3.fromRGB(255, 210, 90),
	TooHeavy = Color3.fromRGB(255, 120, 60),
}

return Config
