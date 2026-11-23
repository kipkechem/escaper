--!strict
-- Tag: CounterweightLift (a model containing two parts, "PlatformA" and "PlatformB")
--
-- Two platforms hang from one rope over a pulley: when A goes down, B goes up by the
-- same amount. Whichever side carries more weight sinks. Build the model with A at its
-- TOP position and B at its BOTTOM position; the lift starts there.
--
-- Attributes on the model:
--   Travel (number)     how far each platform moves (default 16)
--   Speed (number)      base speed in studs per second (default Config.Lift.Speed)
--   TareA, TareB        the platforms' own weight in KG (default 0 and 10). Give B the larger
--                       tare so an empty lift rests with B at the bottom.
--   Deadband (number)   difference in weight that is treated as balanced (default 2)
--   SensorHeight        how tall a column above each platform is weighed (default 12)
--   Output (string)     signal that is on while B is at the top
--   LabelA, LabelB      gauge titles (default "CARGO" and "RIDER")
--   ShowGauge (bool)    floating weight displays (default true)
--
-- Railings and decorations that should move with a platform go inside the model, welded
-- to that platform, with Massless on. The platforms are unanchored at runtime and driven
-- by servo PrismaticConstraints owned by the server. A platform will not move down onto a
-- player or object underneath it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local LiftMath = require(ReplicatedStorage.Shared.LiftMath)
local Gauge = require(script.Parent.Parent.Services.Gauge)
local MassSensor = require(script.Parent.Parent.Services.MassSensor)
local Signals = require(script.Parent.Parent.Services.Signals)

local CounterweightLift = {}
CounterweightLift.__index = CounterweightLift

type Side = {
	platform: BasePart,
	prismatic: PrismaticConstraint,
	-- +1 if this platform rises as `s` grows, -1 if it sinks.
	sign: number,
	tare: number,
	load: number,
	gauge: Gauge.Gauge?,
}

export type CounterweightLift = typeof(setmetatable(
	{} :: {
		instance: Model,
		scope: Instance,
		a: Side,
		b: Side,
		travel: number,
		speed: number,
		deadband: number,
		sensorHeight: number,
		output: string,
		s: number,
		direction: number,
		currentSpeed: number,
		atTop: boolean,
		connection: RBXScriptConnection?,
		created: { Instance },
	},
	CounterweightLift
))

local function numberAttribute(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else default
end

local function stringAttribute(instance: Instance, name: string, default: string): string
	local value = instance:GetAttribute(name)
	return if type(value) == "string" then value else default
end

-- A vertical slider for `platform`, anchored to the Terrain at the platform's start.
local function makeSlider(
	platform: BasePart,
	lower: number,
	upper: number,
	created: { Instance }
): PrismaticConstraint
	-- The prismatic slides along its attachments' X axis, so point X straight up.
	local axis = CFrame.fromMatrix(platform.Position, Vector3.yAxis, -Vector3.xAxis)

	local anchor = Instance.new("Attachment")
	anchor.Name = "LiftAnchor_" .. platform.Name
	anchor.Parent = workspace.Terrain
	anchor.WorldCFrame = axis
	table.insert(created, anchor)

	local moving = Instance.new("Attachment")
	moving.Name = "LiftSlider"
	moving.Parent = platform
	moving.WorldCFrame = axis
	table.insert(created, moving)

	local prismatic = Instance.new("PrismaticConstraint")
	prismatic.Name = "LiftSlider"
	prismatic.Attachment0 = anchor
	prismatic.Attachment1 = moving
	prismatic.ActuatorType = Enum.ActuatorType.Servo
	prismatic.ServoMaxForce = 5e6
	prismatic.LimitsEnabled = true
	prismatic.LowerLimit = lower
	prismatic.UpperLimit = upper
	prismatic.TargetPosition = 0
	prismatic.Parent = platform
	table.insert(created, prismatic)
	return prismatic
end

function CounterweightLift.new(instance: Instance): CounterweightLift?
	if not instance:IsA("Model") then
		warn("[Escaper] CounterweightLift must be a model: " .. instance:GetFullName())
		return nil
	end
	local platformA = instance:FindFirstChild("PlatformA")
	local platformB = instance:FindFirstChild("PlatformB")
	if not (platformA and platformA:IsA("BasePart") and platformB and platformB:IsA("BasePart")) then
		warn(
			"[Escaper] CounterweightLift needs parts named PlatformA and PlatformB: "
				.. instance:GetFullName()
		)
		return nil
	end

	local travel = numberAttribute(instance, "Travel", 16)
	local speed = numberAttribute(instance, "Speed", Config.Lift.Speed)
	local created: { Instance } = {}
	local prismaticA = makeSlider(platformA, -travel, 0, created)
	local prismaticB = makeSlider(platformB, 0, travel, created)
	for _, prismatic in { prismaticA, prismaticB } do
		-- Faster than the fastest the lift is driven, so the servo keeps up with its target.
		prismatic.Speed = speed * 1.5 * 1.3
	end

	local showGauge = instance:GetAttribute("ShowGauge") ~= false
	local function side(
		platform: BasePart,
		prismatic: PrismaticConstraint,
		sign: number,
		tare: number,
		label: string
	): Side
		return {
			platform = platform,
			prismatic = prismatic,
			sign = sign,
			tare = tare,
			load = 0,
			gauge = if showGauge then Gauge.new(platform, label, Vector3.new(0, 7, 0)) else nil,
		}
	end

	local self = setmetatable({
		instance = instance,
		scope = Signals.scopeFor(instance),
		a = side(
			platformA,
			prismaticA,
			-1,
			numberAttribute(instance, "TareA", 0),
			stringAttribute(instance, "LabelA", "CARGO")
		),
		b = side(
			platformB,
			prismaticB,
			1,
			numberAttribute(instance, "TareB", 10),
			stringAttribute(instance, "LabelB", "RIDER")
		),
		travel = travel,
		speed = speed,
		deadband = numberAttribute(instance, "Deadband", Config.Lift.Deadband),
		sensorHeight = numberAttribute(instance, "SensorHeight", 12),
		output = stringAttribute(instance, "Output", ""),
		s = 0,
		direction = 0,
		currentSpeed = 0,
		atTop = false,
		connection = nil,
		created = created,
	}, CounterweightLift)

	for _, platform in { platformA, platformB } do
		for _, part in platform:GetConnectedParts(true) do
			if part ~= platform then
				part.Anchored = false
				part.Massless = true
			end
		end
		platform.Anchored = false
	end
	for _, platform in { platformA, platformB } do
		if platform:CanSetNetworkOwnership() then
			platform:SetNetworkOwner(nil)
		end
	end

	local sinceSense = math.huge
	self.connection = RunService.Heartbeat:Connect(function(dt)
		sinceSense += dt
		if sinceSense >= 1 / Config.Lift.SensorHz then
			sinceSense = 0
			self:sense()
		end
		self:move(dt)
	end)
	return self
end

function CounterweightLift.weigh(self: CounterweightLift, side: Side): number
	local cframe, size = MassSensor.columnAbove(side.platform, self.sensorHeight)
	return MassSensor.measure(cframe, size, { self.instance }).total + side.tare
end

-- Is something under this platform that it would land on?
function CounterweightLift.blockedBelow(self: CounterweightLift, side: Side): boolean
	local platform = side.platform
	local height = 1.5
	local size =
		Vector3.new(math.max(platform.Size.X - 0.4, 0.2), height, math.max(platform.Size.Z - 0.4, 0.2))
	local cframe = platform.CFrame * CFrame.new(0, -platform.Size.Y / 2 - height / 2 - 0.05, 0)
	return MassSensor.anythingIn(cframe, size, { self.instance })
end

function CounterweightLift.sense(self: CounterweightLift)
	local a, b = self.a, self.b
	a.load = self:weigh(a)
	b.load = self:weigh(b)

	local direction = LiftMath.direction(a.load, b.load, self.deadband)
	-- +1 lowers A, -1 lowers B. Stop at the ends, and rather than land on someone.
	local atEnd = (direction == 1 and self.s >= self.travel) or (direction == -1 and self.s <= 0)
	local sinking = if direction == 1 then a elseif direction == -1 then b else nil
	if atEnd or (sinking and self:blockedBelow(sinking)) then
		direction = 0
	end
	self.direction = direction
	self.currentSpeed = LiftMath.speed(a.load, b.load, self.speed)

	local heavier = if a.load > b.load + self.deadband
		then a
		elseif b.load > a.load + self.deadband then b
		else nil
	for _, side in { a, b } do
		if side.gauge then
			side.gauge:show(string.format("%d KG", side.load), 1, side == heavier)
		end
	end
	self.instance:SetAttribute("LoadA", a.load)
	self.instance:SetAttribute("LoadB", b.load)
end

function CounterweightLift.move(self: CounterweightLift, dt: number)
	if self.direction ~= 0 then
		self.s = LiftMath.step(self.s, self.direction, self.currentSpeed, dt, self.travel)
		self.a.prismatic.TargetPosition = self.a.sign * self.s
		self.b.prismatic.TargetPosition = self.b.sign * self.s
	end
	local atTop = self.s >= self.travel - 0.3
	if atTop ~= self.atTop then
		self.atTop = atTop
		Signals.set(self.scope, self.output, self, atTop)
	end
end

function CounterweightLift.destroy(self: CounterweightLift)
	if self.connection then
		self.connection:Disconnect()
	end
	Signals.set(self.scope, self.output, self, false)
	for _, side in { self.a, self.b } do
		if side.gauge then
			side.gauge:destroy()
		end
	end
	for _, instance in self.created do
		instance:Destroy()
	end
end

return CounterweightLift
