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
}

Config.Colors = {
	Off = Color3.fromRGB(150, 40, 35),
	On = Color3.fromRGB(70, 200, 90),
	Neutral = Color3.fromRGB(90, 90, 95),
	Highlight = Color3.fromRGB(255, 210, 90),
	TooHeavy = Color3.fromRGB(255, 120, 60),
}

return Config
