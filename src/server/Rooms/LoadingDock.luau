--!strict
-- Builds Room 1, "The Loading Dock", as a grey-box level. See LoadingDockLayout for the
-- positions and puzzle numbers, and docs/ROOM_1.md for the walkthrough.
--
-- The game builds this room when the server starts, unless Workspace.Rooms.LoadingDock
-- already exists. `lune run tools/bake.luau` also runs this builder to put the room into
-- the place file, so it can be edited directly in Studio. Because of that, this file only
-- creates instances and sets properties, attributes and tags (no services, no waiting).

local Layout = require(script.Parent.LoadingDockLayout)

local LoadingDock = {}
LoadingDock.InstanceName = "LoadingDock"

local palette = {
	floor = Color3.fromRGB(118, 118, 114),
	brick = Color3.fromRGB(150, 104, 84),
	wall = Color3.fromRGB(176, 172, 162),
	trailer = Color3.fromRGB(222, 224, 226),
	bayFloor = Color3.fromRGB(105, 88, 70),
	trim = Color3.fromRGB(232, 188, 36),
	dark = Color3.fromRGB(42, 42, 46),
	crate = Color3.fromRGB(166, 120, 72),
	steel = Color3.fromRGB(88, 96, 108),
	lift = Color3.fromRGB(214, 170, 38),
	shutter = Color3.fromRGB(132, 136, 146),
	sign = Color3.fromRGB(28, 30, 34),
	signText = Color3.fromRGB(245, 205, 60),
	reset = Color3.fromRGB(220, 110, 40),
}

type PartOptions = {
	name: string,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	castShadow: boolean?,
	class: string?,
	anchored: boolean?,
}

local function makePart(parent: Instance, options: PartOptions, cframe: CFrame, size: Vector3): BasePart
	local part = Instance.new((options.class or "Part") :: any) :: BasePart
	part.Name = options.name
	part.Anchored = if options.anchored == nil then true else options.anchored
	part.Size = size
	part.CFrame = cframe
	part.Color = options.color or palette.wall
	part.Material = options.material or Enum.Material.SmoothPlastic
	part.Transparency = options.transparency or 0
	part.CanCollide = if options.canCollide == nil then true else options.canCollide
	part.CastShadow = if options.castShadow == nil then true else options.castShadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A box between two opposite corners.
local function box(parent: Instance, options: PartOptions, from: Vector3, to: Vector3): BasePart
	local low = from:Min(to)
	local high = from:Max(to)
	return makePart(parent, options, CFrame.new((low + high) / 2), high - low)
end

local function folder(parent: Instance, name: string): Folder
	local newFolder = Instance.new("Folder")
	newFolder.Name = name
	newFolder.Parent = parent
	return newFolder
end

local function textOnFace(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	textColor: Color3,
	background: Color3?
)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.BackgroundTransparency = if background then 0 else 1
	label.BorderSizePixel = 0
	label.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
end

-- A wall sign. `facing` is the direction the text faces (towards the reader).
local function sign(
	parent: Instance,
	name: string,
	position: Vector3,
	facing: Vector3,
	size: Vector2,
	text: string
)
	local cframe = CFrame.lookAt(position, position + facing)
	local part = makePart(
		parent,
		{ name = name, color = palette.sign, castShadow = false },
		cframe,
		Vector3.new(size.X, size.Y, 0.2)
	)
	textOnFace(part, Enum.NormalId.Front, text, palette.signText)
	return part
end

local function tag(instance: Instance, tagName: string, attributes: { [string]: any }?)
	instance:AddTag(tagName)
	if attributes then
		for key, value in attributes do
			instance:SetAttribute(key, value)
		end
	end
end

local function weld(part0: BasePart, part1: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part1
end

local function attachmentAt(part: BasePart, worldPosition: Vector3, name: string): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = CFrame.new(part.CFrame:PointToObjectSpace(worldPosition))
	attachment.Parent = part
	return attachment
end

local function rope(parent: Instance, a: Attachment, b: Attachment)
	local beam = Instance.new("Beam")
	beam.Name = "Rope"
	beam.Attachment0 = a
	beam.Attachment1 = b
	beam.Width0 = 0.25
	beam.Width1 = 0.25
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(60, 56, 50))
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 1
	beam.Parent = parent
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

	-- Exit corridor behind the door.
	box(shell, floor, Vector3.new(-6, mezzanine - 2, 82), Vector3.new(6, mezzanine, 98))
	box(shell, concrete, Vector3.new(-8, mezzanine - 2, 82), Vector3.new(-6, top, 100))
	box(shell, concrete, Vector3.new(6, mezzanine - 2, 82), Vector3.new(8, top, 100))
	box(shell, concrete, Vector3.new(-6, mezzanine - 2, 98), Vector3.new(6, top, 100))

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
		local heavy = spec.mass > 45
		local part = makePart(crates, {
			name = spec.name,
			color = if heavy then palette.steel else palette.crate,
			material = if heavy then Enum.Material.DiamondPlate else Enum.Material.WoodPlanks,
			anchored = false,
		}, CFrame.new(spec.position) * CFrame.Angles(0, math.rad(spec.yaw), 0), spec.size)
		tag(part, "Grabbable", {
			Mass = spec.mass,
			DisplayName = if heavy then "Steel crate" else "Crate",
		})
		local text = string.format("%d KG", spec.mass)
		for _, face in
			{
				Enum.NormalId.Front,
				Enum.NormalId.Back,
				Enum.NormalId.Left,
				Enum.NormalId.Right,
				Enum.NormalId.Top,
			}
		do
			textOnFace(part, face, if heavy then text .. "\nHEAVY" else text, Color3.fromRGB(30, 24, 18))
		end
	end
end

local function buildLever(
	parent: Instance,
	name: string,
	position: Vector3,
	attributes: { [string]: any }
): Model
	local lever = Instance.new("Model")
	lever.Name = name
	makePart(
		lever,
		{ name = "Base", color = palette.steel, material = Enum.Material.Metal },
		CFrame.new(position + Vector3.new(0, 1.25, 0)),
		Vector3.new(1.2, 2.5, 1.2)
	)
	makePart(
		lever,
		{ name = "Handle", color = palette.dark, material = Enum.Material.Metal },
		CFrame.new(position + Vector3.new(0, 3.5, 0)),
		Vector3.new(0.35, 2, 0.35)
	)
	makePart(
		lever,
		{ name = "Lamp", color = Color3.fromRGB(150, 40, 35), material = Enum.Material.Neon },
		CFrame.new(position + Vector3.new(0, 2.1, -0.65)),
		Vector3.new(0.5, 0.5, 0.1)
	)
	tag(lever, "Lever", attributes)
	lever.Parent = parent
	return lever
end

local function buildResetConsole(parent: Instance, name: string, position: Vector3, facing: Vector3)
	local cframe =
		CFrame.lookAt(position + Vector3.new(0, 1.5, 0), position + Vector3.new(0, 1.5, 0) + facing)
	local console = makePart(
		parent,
		{ name = name, color = palette.reset, material = Enum.Material.Metal },
		cframe,
		Vector3.new(2, 3, 1.2)
	)
	textOnFace(console, Enum.NormalId.Front, "RESET\nROOM", Color3.new(1, 1, 1))
	tag(console, "RoomReset")
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
	tag(spawn, "Checkpoint", { Order = 1 })

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

	buildResetConsole(dock, "ResetDock", Vector3.new(-21, 0, -9), Vector3.new(1, 0, 0))
end

local function buildLift(parent: Instance): Model
	local lift = Instance.new("Model")
	lift.Name = "FreightLift"
	local specA = Layout.Lift.PlatformA
	local specB = Layout.Lift.PlatformB
	local liftStyle = { name = "", color = palette.lift, material = Enum.Material.DiamondPlate }

	liftStyle.name = "PlatformA"
	local platformA = makePart(lift, liftStyle, CFrame.new(specA.center), specA.size)
	liftStyle.name = "PlatformB"
	local platformB = makePart(lift, liftStyle, CFrame.new(specB.center), specB.size)

	local function railing(platform: BasePart, name: string, localCenter: Vector3, size: Vector3)
		local rail = makePart(
			lift,
			{ name = name, color = palette.dark, material = Enum.Material.Metal, anchored = false },
			platform.CFrame * CFrame.new(localCenter),
			size
		)
		rail.Massless = true
		weld(platform, rail)
	end
	-- Rider side: a rail on the open-air side only, so the cargo side is within easy reach.
	railing(platformB, "RailWest", Vector3.new(-3.8, 1.25, 0), Vector3.new(0.4, 1.5, 8))
	-- Cargo side: a rail by the ladder well so crates do not slide off.
	railing(platformA, "RailEast", Vector3.new(3.8, 1.25, 0), Vector3.new(0.4, 1.5, 8))

	-- Pulley girder, wheels and ropes (decoration only).
	local girder = makePart(
		lift,
		{ name = "Girder", color = palette.steel, material = Enum.Material.Metal },
		CFrame.new(3.5, 32.5, 59.5),
		Vector3.new(20, 1, 1)
	)
	for index, x in { specB.center.X, specA.center.X } do
		-- Cylinders run along their X axis; turn it to face along Z like a pulley wheel.
		local wheelCFrame = CFrame.new(x, 30, 59.5) * CFrame.Angles(0, math.rad(90), 0)
		local wheel = makePart(
			lift,
			{ name = "Wheel" .. index, color = palette.dark, material = Enum.Material.Metal },
			wheelCFrame,
			Vector3.new(0.8, 3, 3)
		) :: Part
		wheel.Shape = Enum.PartType.Cylinder
	end
	local ropeTopB = attachmentAt(girder, Vector3.new(specB.center.X, 28.5, 59.5), "RopeB")
	local ropeTopA = attachmentAt(girder, Vector3.new(specA.center.X, 28.5, 59.5), "RopeA")
	local wheelTopB = attachmentAt(girder, Vector3.new(specB.center.X, 31.5, 59.5), "OverB")
	local wheelTopA = attachmentAt(girder, Vector3.new(specA.center.X, 31.5, 59.5), "OverA")
	rope(lift, attachmentAt(platformB, specB.center + Vector3.new(0, specB.size.Y / 2, 0), "Rope"), ropeTopB)
	rope(lift, attachmentAt(platformA, specA.center + Vector3.new(0, specA.size.Y / 2, 0), "Rope"), ropeTopA)
	rope(lift, wheelTopB, wheelTopA)

	tag(lift, "CounterweightLift", {
		Travel = Layout.Lift.Travel,
		Speed = Layout.Lift.Speed,
		TareA = Layout.Lift.TareA,
		TareB = Layout.Lift.TareB,
		Output = "LiftUp",
		LabelA = "CARGO",
		LabelB = "RIDER + CAGE",
	})
	lift.Parent = parent
	return lift
end

local function buildHall(room: Model)
	local hall = folder(room, "Hall")
	local mezzanine = Layout.MezzanineHeight

	local checkpoint = makePart(
		hall,
		{ name = "HallCheckpoint", transparency = 1, canCollide = false, castShadow = false },
		CFrame.new(0, 3, 33.5),
		Vector3.new(10, 6, 3)
	)
	tag(checkpoint, "Checkpoint", { Order = 2 })

	buildLever(
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
	tag(mezzanineCheckpoint, "Checkpoint", { Order = 3 })

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

	buildResetConsole(hall, "ResetHall", Vector3.new(-21, 0, 33), Vector3.new(1, 0, 0))

	-- Exit corridor.
	local goal = makePart(
		hall,
		{ name = "Goal", transparency = 1, canCollide = false, castShadow = false },
		CFrame.new(0, mezzanine + 3, 94),
		Vector3.new(12, 6, 4)
	)
	tag(goal, "RoomGoal")
	sign(
		hall,
		"EndSign",
		Vector3.new(0, mezzanine + 5, 97.85),
		Vector3.new(0, 0, -1),
		Vector2.new(10, 4),
		"YOU ESCAPED THE LOADING DOCK\nROOM 2: COMING SOON"
	)
end

function LoadingDock.build(parent: Instance): Model
	local room = Instance.new("Model")
	room.Name = LoadingDock.InstanceName
	tag(room, "Room", { RoomName = Layout.RoomName })
	buildShell(room)
	buildDock(room)
	buildHall(room)
	buildCrates(room)
	room.Parent = parent
	return room
end

return LoadingDock
