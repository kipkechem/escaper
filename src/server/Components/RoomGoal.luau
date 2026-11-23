--!strict
-- Tag: RoomGoal (a trigger part where a level is finished, e.g. the start of an exit tube)
-- Attributes:
--   Message (string)   what the player is told, e.g. "Level 1 complete! On to Level 2 ..."
--   Id (string)        a player hears each Id only once
-- Everyone else hears that the player got through.

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
	local message = instance:GetAttribute("Message")
	local id = instance:GetAttribute("Id")
	local text = if type(message) == "string" then message else "Level complete!"
	local key = "Goal_"
		.. string.gsub(if type(id) == "string" then id else instance:GetFullName(), "[^%w_]", "_")

	instance.CanTouch = true
	local connection = instance.Touched:Connect(function(hit)
		local player = hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player:GetAttribute(key) then
			return
		end
		player:SetAttribute(key, true)
		local joinedAt = player:GetAttribute("JoinedAt")
		local elapsed = if type(joinedAt) == "number" then workspace:GetServerTimeNow() - joinedAt else 0
		Notify.player(player, string.format("%s  (%s)", text, formatTime(elapsed)), "success")
		Notify.others(player, string.format("%s: %s", player.DisplayName, text), "info")
	end)

	return setmetatable(
		{ instance = instance, scope = Signals.scopeFor(instance), connection = connection },
		RoomGoal
	)
end

function RoomGoal.destroy(self: RoomGoal)
	self.connection:Disconnect()
end

return RoomGoal
