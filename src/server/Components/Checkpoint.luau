--!strict
-- Tag: Checkpoint (a part; usually an invisible trigger box with CanCollide off)
-- Attributes:
--   Order (number)   higher numbers are further on; players respawn at the highest they touched
-- A SpawnLocation can carry this tag too, as the first checkpoint.

local Players = game:GetService("Players")

local Checkpoints = require(script.Parent.Parent.Services.Checkpoints)
local Notify = require(script.Parent.Parent.Services.Notify)
local Signals = require(script.Parent.Parent.Services.Signals)

local Checkpoint = {}
Checkpoint.__index = Checkpoint

export type Checkpoint = typeof(setmetatable(
	{} :: {
		instance: BasePart,
		scope: Instance,
		order: number,
		connection: RBXScriptConnection,
	},
	Checkpoint
))

function Checkpoint.new(instance: Instance): Checkpoint?
	if not instance:IsA("BasePart") then
		return nil
	end
	local order = instance:GetAttribute("Order")
	if type(order) ~= "number" then
		warn("[Escaper] Checkpoint needs a number Order attribute: " .. instance:GetFullName())
		return nil
	end
	local scope = Signals.scopeFor(instance)
	local roomName = scope:GetAttribute("RoomName")
	-- Respawn standing on the bottom of the checkpoint box, facing the way it faces.
	local floor = instance.CFrame * CFrame.new(0, -instance.Size.Y / 2, 0)
	Checkpoints.register(
		order,
		floor + Vector3.new(0, 3.5, 0),
		if type(roomName) == "string" then roomName else ""
	)

	instance.CanTouch = true
	local connection = instance.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local humanoid = (character :: Instance):FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and Checkpoints.reach(player, order) and order > 1 then
			Notify.player(player, "Checkpoint reached", "success")
		end
	end)

	return setmetatable({
		instance = instance,
		scope = scope,
		order = order,
		connection = connection,
	}, Checkpoint)
end

function Checkpoint.destroy(self: Checkpoint)
	self.connection:Disconnect()
	Checkpoints.unregister(self.order)
end

return Checkpoint
