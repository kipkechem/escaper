--!strict
-- Tag: Checkpoint (a part; usually an invisible trigger box with CanCollide off)
-- Attributes:
--   Order (number)      floor x 10 + n. Players respawn at the highest they have touched.
--   Announce (string)   optional message shown on first touch, e.g. "Level 2 · The Switchboard"
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
	local announce = instance:GetAttribute("Announce")
	-- Respawn standing on the bottom of the checkpoint box, facing the way it faces.
	local floor = instance.CFrame * CFrame.new(0, -instance.Size.Y / 2, 0)
	Checkpoints.register(instance, floor + Vector3.new(0, 3.5, 0))

	instance.CanTouch = true
	local connection = instance.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local humanoid = (character :: Instance):FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or not Checkpoints.reach(player, instance, order) then
			return
		end
		if type(announce) == "string" then
			Notify.player(player, announce, "info")
		elseif order % 10 ~= 1 then
			Notify.player(player, "Checkpoint reached", "success")
		end
	end)

	return setmetatable({
		instance = instance,
		scope = Signals.scopeFor(instance),
		order = order,
		connection = connection,
	}, Checkpoint)
end

function Checkpoint.destroy(self: Checkpoint)
	self.connection:Disconnect()
	Checkpoints.unregister(self.instance)
end

return Checkpoint
