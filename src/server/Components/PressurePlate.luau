--!strict
-- Tag: PressurePlate (an anchored part; its top face is the plate)
-- Attributes:
--   Output (string)          signal that is on while the plate is loaded enough
--   RequiredMass (number)    weight needed, in the same units as Grabbable.Mass
--   SensorHeight (number)    how tall a column above the plate is weighed (default 14),
--                            so stacked crates and players standing on crates count
--   Label (string)           shown on the gauge, e.g. "SHUTTER"
--   ShowGauge (boolean)      floating "23 / 40 KG" display (default true)
-- Sets the attribute CurrentMass while running.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Gauge = require(script.Parent.Parent.Services.Gauge)
local MassSensor = require(script.Parent.Parent.Services.MassSensor)
local Signals = require(script.Parent.Parent.Services.Signals)

local SENSOR_INTERVAL = 0.1

local PressurePlate = {}
PressurePlate.__index = PressurePlate

export type PressurePlate = typeof(setmetatable(
	{} :: {
		instance: BasePart,
		scope: Instance,
		output: string,
		required: number,
		height: number,
		active: boolean,
		mass: number,
		gauge: Gauge.Gauge?,
		connection: RBXScriptConnection?,
	},
	PressurePlate
))

local function attribute<T>(instance: Instance, name: string, default: T): T
	local value = instance:GetAttribute(name)
	if value == nil then
		return default
	end
	return value :: any
end

function PressurePlate.new(instance: Instance): PressurePlate?
	if not instance:IsA("BasePart") then
		warn("[Escaper] PressurePlate must be a part: " .. instance:GetFullName())
		return nil
	end
	local self = setmetatable({
		instance = instance,
		scope = Signals.scopeFor(instance),
		output = attribute(instance, "Output", ""),
		required = attribute(instance, "RequiredMass", 20),
		height = attribute(instance, "SensorHeight", Config.Weight.SensorHeight),
		active = false,
		mass = 0,
		gauge = nil,
		connection = nil,
	}, PressurePlate)

	if attribute(instance, "ShowGauge", true) then
		self.gauge = Gauge.new(instance, attribute(instance, "Label", "LOAD"), Vector3.new(0, 4, 0))
	end
	self:render()

	local elapsed = 0
	self.connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= SENSOR_INTERVAL then
			elapsed = 0
			self:update()
		end
	end)
	return self
end

function PressurePlate.update(self: PressurePlate)
	local cframe, size = MassSensor.columnAbove(self.instance, self.height)
	local reading = MassSensor.measure(cframe, size, { self.instance })
	local active = reading.total >= self.required
	local changed = reading.total ~= self.mass or active ~= self.active
	self.mass = reading.total
	if active ~= self.active then
		self.active = active
		Signals.set(self.scope, self.output, self, active)
	end
	if changed then
		self.instance:SetAttribute("CurrentMass", reading.total)
		self:render()
	end
end

function PressurePlate.render(self: PressurePlate)
	self.instance.Color = if self.active then Config.Colors.On else Config.Colors.Off
	if self.gauge then
		self.gauge:set(self.mass, self.required, self.active)
	end
end

function PressurePlate.destroy(self: PressurePlate)
	if self.connection then
		self.connection:Disconnect()
	end
	Signals.set(self.scope, self.output, self, false)
	if self.gauge then
		self.gauge:destroy()
	end
end

return PressurePlate
