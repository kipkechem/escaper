--!strict
-- Tag: Door (an anchored part or model; also works for gates, bridges and ladders)
-- Attributes:
--   Input (string)          expression of signals, e.g. "ShutterPlate | ShutterLever"
--   OpenOffset (Vector3)    world-space move when open (default: up by its own height)
--   OpenTime (number)       seconds to open or close (default 1.2)
--   Latch (boolean)         once opened, stays open (use for progress doors)
-- A closing door stops rather than crush a player or object in its way, so a crate
-- can prop a door open.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MassSensor = require(script.Parent.Parent.Services.MassSensor)
local Signals = require(script.Parent.Parent.Services.Signals)
local Wiring = require(script.Parent.Parent.Services.Wiring)

local Door = {}
Door.__index = Door

export type Door = typeof(setmetatable(
	{} :: {
		instance: PVInstance,
		scope: Instance,
		closed: CFrame,
		open: CFrame,
		boxOffset: CFrame,
		boxSize: Vector3,
		openTime: number,
		latch: boolean,
		latched: boolean,
		alpha: number,
		target: number,
		watcher: Wiring.Watcher?,
		connection: RBXScriptConnection?,
	},
	Door
))

local function smoothstep(x: number): number
	return x * x * (3 - 2 * x)
end

function Door.new(instance: Instance): Door?
	if not instance:IsA("PVInstance") then
		warn("[Escaper] Door must be a part or model: " .. instance:GetFullName())
		return nil
	end
	local pv = instance :: PVInstance
	if pv:IsA("BasePart") then
		pv.Anchored = true
	end
	for _, descendant in pv:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	local closed = pv:GetPivot()
	local boxCFrame: CFrame, boxSize: Vector3
	if pv:IsA("BasePart") then
		boxCFrame, boxSize = pv.CFrame, pv.Size
	else
		boxCFrame, boxSize = (pv :: Model):GetBoundingBox()
	end
	local offset = pv:GetAttribute("OpenOffset")
	local openOffset = if typeof(offset) == "Vector3" then offset else Vector3.new(0, boxSize.Y - 0.5, 0)
	local openTime = pv:GetAttribute("OpenTime")
	local input = pv:GetAttribute("Input")

	local self = setmetatable({
		instance = pv,
		scope = Signals.scopeFor(pv),
		closed = closed,
		open = closed + openOffset,
		boxOffset = closed:Inverse() * boxCFrame,
		boxSize = boxSize - Vector3.new(0.2, 0.2, 0.2),
		openTime = if type(openTime) == "number" and openTime > 0 then openTime else Config.Door.OpenTime,
		latch = pv:GetAttribute("Latch") == true,
		latched = false,
		alpha = 0,
		target = 0,
		watcher = nil,
		connection = nil,
	}, Door)

	if type(input) == "string" then
		self.watcher = Wiring.watch(pv, input, function(value)
			self:setWanted(value)
		end)
		if self.watcher then
			self:setWanted(self.watcher.value)
		end
	else
		warn("[Escaper] Door has no Input attribute: " .. pv:GetFullName())
	end

	self.connection = RunService.Heartbeat:Connect(function(dt)
		self:step(dt)
	end)
	return self
end

function Door.setWanted(self: Door, wanted: boolean)
	if self.latch and wanted then
		self.latched = true
	end
	local open = wanted or self.latched
	self.target = if open then 1 else 0
	self.instance:SetAttribute("Open", open)
end

function Door.pose(self: Door, alpha: number): CFrame
	return self.closed:Lerp(self.open, smoothstep(alpha))
end

function Door.step(self: Door, dt: number)
	if self.alpha == self.target then
		return
	end
	local rate = dt / self.openTime
	local nextAlpha
	if self.target > self.alpha then
		nextAlpha = math.min(self.alpha + rate, self.target)
	else
		nextAlpha = math.max(self.alpha - rate, self.target)
		local box = self:pose(nextAlpha) * self.boxOffset
		if MassSensor.anythingIn(box, self.boxSize, { self.instance }) then
			return
		end
	end
	self.alpha = nextAlpha
	self.instance:PivotTo(self:pose(nextAlpha))
end

function Door.destroy(self: Door)
	if self.connection then
		self.connection:Disconnect()
	end
	if self.watcher then
		self.watcher.disconnect()
	end
end

return Door
