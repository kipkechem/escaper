--!strict
-- Helpers shared by the room and tower builders. A builder works in its level's own
-- coordinates; `Build.new(frame)` places everything through that frame.
--
-- Builders only create instances and set properties, attributes and tags (no services, no
-- waiting), so they also run under Lune for tools/bake.luau and the tests.

local Build = {}

Build.palette = {
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
	glass = Color3.fromRGB(170, 210, 230),
	fuse = Color3.fromRGB(255, 196, 40),
	tube = Color3.fromRGB(96, 100, 108),
	easy = Color3.fromRGB(80, 170, 90),
	medium = Color3.fromRGB(70, 140, 210),
	hard = Color3.fromRGB(230, 140, 40),
	veryHard = Color3.fromRGB(200, 50, 50),
}

export type PartOptions = {
	name: string,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	canQuery: boolean?,
	castShadow: boolean?,
	class: string?,
	anchored: boolean?,
}

local Builder = {}
Builder.__index = Builder

export type Builder = typeof(setmetatable({} :: { frame: CFrame }, Builder))

function Build.new(frame: CFrame?): Builder
	return setmetatable({ frame = frame or CFrame.identity }, Builder)
end

-- A part at `cframe` (in the builder's coordinates).
function Builder.part(
	self: Builder,
	parent: Instance,
	options: PartOptions,
	cframe: CFrame,
	size: Vector3
): BasePart
	local part = Instance.new((options.class or "Part") :: any) :: BasePart
	part.Name = options.name
	part.Anchored = if options.anchored == nil then true else options.anchored
	part.Size = size
	part.CFrame = self.frame * cframe
	part.Color = options.color or Build.palette.wall
	part.Material = options.material or Enum.Material.SmoothPlastic
	part.Transparency = options.transparency or 0
	part.CanCollide = if options.canCollide == nil then true else options.canCollide
	if options.canQuery == false then
		part.CanQuery = false
	end
	part.CastShadow = if options.castShadow == nil then true else options.castShadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A box between two opposite corners.
function Builder.box(
	self: Builder,
	parent: Instance,
	options: PartOptions,
	from: Vector3,
	to: Vector3
): BasePart
	local low = from:Min(to)
	local high = from:Max(to)
	return self:part(parent, options, CFrame.new((low + high) / 2), high - low)
end

-- A wall sign. `facing` is the direction the text faces (towards the reader).
function Builder.sign(
	self: Builder,
	parent: Instance,
	name: string,
	position: Vector3,
	facing: Vector3,
	size: Vector2,
	text: string,
	background: Color3?
): BasePart
	local cframe = CFrame.lookAt(position, position + facing)
	local part = self:part(
		parent,
		{ name = name, color = background or Build.palette.sign, castShadow = false },
		cframe,
		Vector3.new(size.X, size.Y, 0.2)
	)
	Build.textOnFace(
		part,
		Enum.NormalId.Front,
		text,
		if background then Color3.new(1, 1, 1) else Build.palette.signText
	)
	return part
end

-- A point or direction in the builder's coordinates, in world space.
function Builder.point(self: Builder, position: Vector3): Vector3
	return self.frame * position
end

function Builder.vector(self: Builder, direction: Vector3): Vector3
	return self.frame:VectorToWorldSpace(direction)
end

function Build.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Build.textOnFace(
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

function Build.tag(instance: Instance, tagName: string, attributes: { [string]: any }?)
	instance:AddTag(tagName)
	if attributes then
		for key, value in attributes do
			instance:SetAttribute(key, value)
		end
	end
end

function Build.weld(part0: BasePart, part1: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part1
end

-- An attachment at a world position.
function Build.attachmentAt(part: BasePart, worldPosition: Vector3, name: string): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = CFrame.new(part.CFrame:PointToObjectSpace(worldPosition))
	attachment.Parent = part
	return attachment
end

function Build.rope(parent: Instance, a: Attachment, b: Attachment)
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

-- A ceiling light.
function Builder.lamp(self: Builder, parent: Instance, position: Vector3, range: number?)
	local part = self:part(parent, {
		name = "Lamp",
		color = Color3.fromRGB(255, 244, 214),
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
	}, CFrame.new(position), Vector3.new(4, 0.3, 4))
	local light = Instance.new("PointLight")
	light.Range = range or 40
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = part
end

-- A pull lever: a model with Base, Handle and Lamp, tagged Lever. `position` is its foot.
function Builder.lever(
	self: Builder,
	parent: Instance,
	name: string,
	position: Vector3,
	attributes: { [string]: any }
): Model
	local lever = Instance.new("Model")
	lever.Name = name
	local metal = Enum.Material.Metal
	local palette = Build.palette
	self:part(
		lever,
		{ name = "Base", color = palette.steel, material = metal },
		CFrame.new(position + Vector3.new(0, 1.25, 0)),
		Vector3.new(1.2, 2.5, 1.2)
	)
	self:part(
		lever,
		{ name = "Handle", color = palette.dark, material = metal },
		CFrame.new(position + Vector3.new(0, 3.5, 0)),
		Vector3.new(0.35, 2, 0.35)
	)
	self:part(
		lever,
		{ name = "Lamp", color = Color3.fromRGB(150, 40, 35), material = Enum.Material.Neon },
		CFrame.new(position + Vector3.new(0, 2.1, -0.65)),
		Vector3.new(0.5, 0.5, 0.1)
	)
	Build.tag(lever, "Lever", attributes)
	lever.Parent = parent
	return lever
end

-- A RESET ROOM console standing on `position`, its front facing `facing`.
function Builder.resetConsole(
	self: Builder,
	parent: Instance,
	name: string,
	position: Vector3,
	facing: Vector3
)
	local centre = position + Vector3.new(0, 1.5, 0)
	local console = self:part(
		parent,
		{ name = name, color = Build.palette.reset, material = Enum.Material.Metal },
		CFrame.lookAt(centre, centre + facing),
		Vector3.new(2, 3, 1.2)
	)
	Build.textOnFace(console, Enum.NormalId.Front, "RESET\nROOM", Color3.new(1, 1, 1))
	Build.tag(console, "RoomReset")
end

export type LooseSpec = {
	name: string,
	kind: string, -- "crate", "steel" or "fuse"
	mass: number,
	position: Vector3,
	size: Vector3,
	yaw: number,
}

-- A grabbable crate, steel crate or fuse with its weight stencilled on.
function Builder.loose(self: Builder, parent: Instance, spec: LooseSpec): BasePart
	local palette = Build.palette
	local styles = {
		crate = { color = palette.crate, material = Enum.Material.WoodPlanks, name = "Crate" },
		steel = { color = palette.steel, material = Enum.Material.DiamondPlate, name = "Steel crate" },
		fuse = { color = palette.fuse, material = Enum.Material.Neon, name = "Fuse" },
	}
	local style = styles[spec.kind] or styles.crate
	local part = self:part(parent, {
		name = spec.name,
		color = style.color,
		material = style.material,
		anchored = false,
	}, CFrame.new(spec.position) * CFrame.Angles(0, math.rad(spec.yaw), 0), spec.size)
	local attributes: { [string]: any } = { Mass = spec.mass, DisplayName = style.name }
	if spec.kind == "fuse" then
		attributes.Key = "Fuse"
	end
	Build.tag(part, "Grabbable", attributes)
	if spec.kind ~= "fuse" then
		local text = string.format("%d KG", spec.mass)
		if spec.kind == "steel" then
			text ..= "\nHEAVY"
		end
		for _, face in
			{
				Enum.NormalId.Front,
				Enum.NormalId.Back,
				Enum.NormalId.Left,
				Enum.NormalId.Right,
				Enum.NormalId.Top,
			}
		do
			Build.textOnFace(part, face, text, Color3.fromRGB(30, 24, 18))
		end
	end
	return part
end

export type LiftSpec = {
	travel: number,
	speed: number,
	tareA: number,
	tareB: number,
	output: string,
	-- Platform centres in the builder's coordinates: A at its top, B at its bottom.
	a: { center: Vector3, size: Vector3 },
	b: { center: Vector3, size: Vector3 },
	-- Railings, as offsets from their platform's centre.
	railsA: { { name: string, offset: Vector3, size: Vector3 } },
	railsB: { { name: string, offset: Vector3, size: Vector3 } },
	girderHeight: number,
}

-- A counterweight lift model (see Components/CounterweightLift), with a decorative pulley.
function Builder.counterweightLift(self: Builder, parent: Instance, spec: LiftSpec): Model
	local palette = Build.palette
	local lift = Instance.new("Model")
	lift.Name = "FreightLift"
	local metal = Enum.Material.Metal
	local platformA = self:part(
		lift,
		{ name = "PlatformA", color = palette.lift, material = Enum.Material.DiamondPlate },
		CFrame.new(spec.a.center),
		spec.a.size
	)
	local platformB = self:part(
		lift,
		{ name = "PlatformB", color = palette.lift, material = Enum.Material.DiamondPlate },
		CFrame.new(spec.b.center),
		spec.b.size
	)
	for _, side in { { platformA, spec.a, spec.railsA }, { platformB, spec.b, spec.railsB } } do
		local platform, platformSpec, rails = side[1] :: BasePart, side[2] :: any, side[3] :: any
		for _, rail in rails do
			local part = self:part(
				lift,
				{ name = rail.name, color = palette.dark, material = metal, anchored = false },
				CFrame.new(platformSpec.center + rail.offset),
				rail.size
			)
			part.Massless = true
			Build.weld(platform, part)
		end
	end

	-- Pulley girder, wheels and ropes (decoration only).
	local z = spec.a.center.Z
	local ax, bx = spec.a.center.X, spec.b.center.X
	local girder = self:part(
		lift,
		{ name = "Girder", color = palette.steel, material = metal },
		CFrame.new((ax + bx) / 2, spec.girderHeight + 2.5, z),
		Vector3.new(math.abs(ax - bx) + 11, 1, 1)
	)
	for index, x in { bx, ax } do
		-- Cylinders run along their X axis; turn it to face along Z like a pulley wheel.
		local wheel = self:part(
			lift,
			{ name = "Wheel" .. index, color = palette.dark, material = metal },
			CFrame.new(x, spec.girderHeight, z) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(0.8, 3, 3)
		) :: Part
		wheel.Shape = Enum.PartType.Cylinder
	end
	local function at(x: number, y: number): Vector3
		return self:point(Vector3.new(x, y, z))
	end
	local underB = Build.attachmentAt(girder, at(bx, spec.girderHeight - 1.5), "RopeB")
	local underA = Build.attachmentAt(girder, at(ax, spec.girderHeight - 1.5), "RopeA")
	local overB = Build.attachmentAt(girder, at(bx, spec.girderHeight + 1.5), "OverB")
	local overA = Build.attachmentAt(girder, at(ax, spec.girderHeight + 1.5), "OverA")
	local topB = self:point(spec.b.center + Vector3.new(0, spec.b.size.Y / 2, 0))
	local topA = self:point(spec.a.center + Vector3.new(0, spec.a.size.Y / 2, 0))
	Build.rope(lift, Build.attachmentAt(platformB, topB, "Rope"), underB)
	Build.rope(lift, Build.attachmentAt(platformA, topA, "Rope"), underA)
	Build.rope(lift, overB, overA)

	Build.tag(lift, "CounterweightLift", {
		Travel = spec.travel,
		Speed = spec.speed,
		TareA = spec.tareA,
		TareB = spec.tareB,
		Output = spec.output,
		LabelA = "CARGO",
		LabelB = "RIDER + CAGE",
	})
	lift.Parent = parent
	return lift
end

function Build.difficultyColor(difficulty: string): Color3
	local palette = Build.palette
	if difficulty == "Easy" then
		return palette.easy
	elseif difficulty == "Medium" then
		return palette.medium
	elseif difficulty == "Hard" then
		return palette.hard
	elseif difficulty == "Very hard" then
		return palette.veryHard
	end
	return palette.sign
end

return Build
