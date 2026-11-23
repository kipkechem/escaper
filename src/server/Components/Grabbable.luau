--!strict
-- Tag: Grabbable (a part, or a model of welded parts)
-- Attributes:
--   Mass (number, optional)   sets the object's weight; its parts' densities are scaled to match
--   DisplayName (string)      shown when a player aims at it, e.g. "Crate"
-- Grabbables remember where they started. A room reset, or falling out of the world,
-- puts them back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grabbables = require(ReplicatedStorage.Shared.Grabbables)
local GrabService = require(script.Parent.Parent.Services.GrabService)
local Signals = require(script.Parent.Parent.Services.Signals)

local Grabbable = {}
Grabbable.__index = Grabbable

export type Grabbable = typeof(setmetatable(
	{} :: {
		instance: Instance,
		scope: Instance,
		home: CFrame,
	},
	Grabbable
))

local live: { [Grabbable]: boolean } = {}

local function applyMass(root: Instance, target: number)
	local parts = Grabbables.parts(root)
	local current = 0
	for _, part in parts do
		if not part.Massless then
			current += part:GetMass()
		end
	end
	if current <= 0 or target <= 0 then
		return
	end
	local scale = target / current
	for _, part in parts do
		local properties = part.CurrentPhysicalProperties
		part.CustomPhysicalProperties = PhysicalProperties.new(
			math.clamp(properties.Density * scale, 0.01, 100),
			properties.Friction,
			properties.Elasticity,
			properties.FrictionWeight,
			properties.ElasticityWeight
		)
	end
end

local function serverOwn(root: Instance)
	local rootPart = Grabbables.rootPart(root)
	if rootPart and not rootPart.Anchored and rootPart:CanSetNetworkOwnership() then
		rootPart:SetNetworkOwner(nil)
	end
end

function Grabbable.new(instance: Instance): Grabbable
	local self = setmetatable({
		instance = instance,
		scope = Signals.scopeFor(instance),
		home = (instance :: PVInstance):GetPivot(),
	}, Grabbable)

	for _, part in Grabbables.parts(instance) do
		part.Anchored = false
	end
	local mass = instance:GetAttribute("Mass")
	if type(mass) == "number" then
		applyMass(instance, mass)
	end
	serverOwn(instance)

	live[self] = true
	return self
end

function Grabbable.reset(self: Grabbable)
	local instance = self.instance
	GrabService.forceRelease(instance)
	for _, part in Grabbables.parts(instance) do
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end
	(instance :: PVInstance):PivotTo(self.home)
	serverOwn(instance)
end

function Grabbable.destroy(self: Grabbable)
	live[self] = nil
end

-- Return objects that fell out of the world.
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 then
		return
	end
	elapsed = 0
	for object in live do
		local pivot = (object.instance :: PVInstance):GetPivot()
		if pivot.Position.Y < Config.Reset.VoidHeight then
			object:reset()
		end
	end
end)

return Grabbable
