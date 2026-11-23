--!strict
-- Remembers the furthest checkpoint each player has reached, and where to respawn them.
-- Checkpoints are numbered by their "Order" attribute; higher means further on.

local Checkpoints = {}

type Entry = { cframe: CFrame, roomName: string }

local entries: { [number]: Entry } = {}

function Checkpoints.register(order: number, cframe: CFrame, roomName: string)
	entries[order] = { cframe = cframe, roomName = roomName }
end

function Checkpoints.unregister(order: number)
	entries[order] = nil
end

-- Records the checkpoint if it is further than the player's current one. Returns true if so.
function Checkpoints.reach(player: Player, order: number): boolean
	local current = player:GetAttribute("Checkpoint")
	if type(current) == "number" and current >= order then
		return false
	end
	player:SetAttribute("Checkpoint", order)
	return true
end

function Checkpoints.spawnCFrame(player: Player): CFrame?
	local order = player:GetAttribute("Checkpoint")
	if type(order) ~= "number" then
		return nil
	end
	local entry = entries[order]
	return if entry then entry.cframe else nil
end

return Checkpoints
