--!strict
-- Tag: RoomReset (a part; gets a hold-to-use prompt)
-- Puts every Grabbable in the same room back where it started and switches its levers off.
-- Latched doors stay open, so progress is kept. Shared cooldown per room.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Binder = require(script.Parent.Parent.Services.Binder)
local Notify = require(script.Parent.Parent.Services.Notify)
local Signals = require(script.Parent.Parent.Services.Signals)

local RoomReset = {}
RoomReset.__index = RoomReset

export type RoomReset = typeof(setmetatable(
	{} :: {
		instance: Instance,
		scope: Instance,
		prompt: ProximityPrompt,
	},
	RoomReset
))

local lastReset: { [Instance]: number } = {}

local function resetRoom(scope: Instance)
	for _, object in Binder.objects(Tags.Grabbable, scope) do
		object:reset()
	end
	for _, object in Binder.objects(Tags.Lever, scope) do
		object:reset()
	end
end

function RoomReset.new(instance: Instance): RoomReset
	local scope = Signals.scopeFor(instance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ResetPrompt"
	prompt.ActionText = "Reset room"
	prompt.ObjectText = "Crates back to start"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance

	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		local last = lastReset[scope]
		if last and now - last < Config.Reset.Cooldown then
			Notify.player(
				player,
				string.format("Reset is cooling down (%ds)", math.ceil(Config.Reset.Cooldown - (now - last))),
				"warning"
			)
			return
		end
		lastReset[scope] = now
		resetRoom(scope)
		local roomName = scope:GetAttribute("RoomName")
		local where = if type(roomName) == "string" then roomName else "the room"
		Notify.all(string.format("%s reset %s", player.DisplayName, where), "warning")
	end)

	return setmetatable({ instance = instance, scope = scope, prompt = prompt }, RoomReset)
end

function RoomReset.destroy(self: RoomReset)
	self.prompt:Destroy()
end

return RoomReset
