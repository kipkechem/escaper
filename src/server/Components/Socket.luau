--!strict
-- Tag: Socket (a non-colliding part marking the space above a tray or cradle)
-- Attributes:
--   Key (string)      the socket accepts grabbables whose Key attribute matches, e.g. "Fuse"
--   Output (string)   signal that is on while a matching object rests in the socket
-- Build the socket as a tray with lips that the object can rest in, and put the tagged
-- part just above it with CanCollide and CanQuery off (so players can still aim at, and
-- take back, what is in it). Nothing snaps: the object just has to be put down there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grabbables = require(ReplicatedStorage.Shared.Grabbables)
local Signals = require(script.Parent.Parent.Services.Signals)

local SENSE_INTERVAL = 0.2
-- An object still moving faster than this has not settled in the socket.
local SETTLED_SPEED = 3

local Socket = {}
Socket.__index = Socket

export type Socket = typeof(setmetatable(
	{} :: {
		instance: BasePart,
		scope: Instance,
		key: string,
		output: string,
		filled: boolean,
		connection: RBXScriptConnection?,
	},
	Socket
))

function Socket.new(instance: Instance): Socket?
	if not instance:IsA("BasePart") then
		warn("[Escaper] Socket must be a part: " .. instance:GetFullName())
		return nil
	end
	local key = instance:GetAttribute("Key")
	local output = instance:GetAttribute("Output")
	instance.CanCollide = false
	instance.CanTouch = false
	instance.CanQuery = false

	local self = setmetatable({
		instance = instance,
		scope = Signals.scopeFor(instance),
		key = if type(key) == "string" then key else "",
		output = if type(output) == "string" then output else "",
		filled = false,
		connection = nil,
	}, Socket)
	self:render()

	local elapsed = 0
	self.connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= SENSE_INTERVAL then
			elapsed = 0
			self:update()
		end
	end)
	return self
end

function Socket.update(self: Socket)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.instance }
	local filled = false
	for _, part in workspace:GetPartBoundsInBox(self.instance.CFrame, self.instance.Size, params) do
		local root = Grabbables.findRoot(part)
		if
			root
			and root:GetAttribute("Key") == self.key
			and not Grabbables.heldBy(root)
			and part.AssemblyLinearVelocity.Magnitude < SETTLED_SPEED
		then
			filled = true
			break
		end
	end
	if filled ~= self.filled then
		self.filled = filled
		Signals.set(self.scope, self.output, self, filled)
		self.instance:SetAttribute("Filled", filled)
		self:render()
	end
end

function Socket.render(self: Socket)
	self.instance.Color = if self.filled then Config.Colors.On else Config.Colors.Off
end

function Socket.destroy(self: Socket)
	if self.connection then
		self.connection:Disconnect()
	end
	Signals.set(self.scope, self.output, self, false)
end

return Socket
