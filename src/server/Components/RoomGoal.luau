--!strict
-- Tag: RoomGoal (a trigger part at a room's exit)
-- When a player touches it they are told they escaped, with their time since joining,
-- and everyone else hears about it.

local Players = game:GetService("Players")

local Notify = require(script.Parent.Parent.Services.Notify)
local Signals = require(script.Parent.Parent.Services.Signals)

local RoomGoal = {}
RoomGoal.__index = RoomGoal

export type RoomGoal = typeof(setmetatable(
	{} :: {
		instance: BasePart,
		scope: Instance,
		connection: RBXScriptConnection,
	},
	RoomGoal
))

local function formatTime(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function RoomGoal.new(instance: Instance): RoomGoal?
	if not instance:IsA("BasePart") then
		return nil
	end
	local scope = Signals.scopeFor(instance)
	local roomName = scope:GetAttribute("RoomName")
	local name = if type(roomName) == "string" then roomName else "the room"
	local key = "Escaped_" .. string.gsub(scope.Name, "[^%w_]", "_")

	instance.CanTouch = true
	local connection = instance.Touched:Connect(function(hit)
		local player = hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player:GetAttribute(key) then
			return
		end
		player:SetAttribute(key, true)
		local joinedAt = player:GetAttribute("JoinedAt")
		local elapsed = if type(joinedAt) == "number" then workspace:GetServerTimeNow() - joinedAt else 0
		Notify.player(player, string.format("You escaped %s in %s!", name, formatTime(elapsed)), "success")
		Notify.others(player, string.format("%s escaped %s", player.DisplayName, name), "info")
	end)

	return setmetatable({ instance = instance, scope = scope, connection = connection }, RoomGoal)
end

function RoomGoal.destroy(self: RoomGoal)
	self.connection:Disconnect()
end

return RoomGoal
