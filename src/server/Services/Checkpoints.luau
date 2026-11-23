--!strict
-- Remembers each player's checkpoint and where to respawn them. Checkpoints are compared
-- by their "Order" attribute, floor x 10 + n, so higher in the tower wins. Two staircases
-- can share a floor, so the latest one touched wins a tie.

local Checkpoints = {}

local spawnPoints: { [BasePart]: CFrame } = {}
local current: { [Player]: BasePart } = setmetatable({}, { __mode = "k" }) :: any

function Checkpoints.register(part: BasePart, cframe: CFrame)
	spawnPoints[part] = cframe
end

function Checkpoints.unregister(part: BasePart)
	spawnPoints[part] = nil
end

-- Moves the player's checkpoint to `part` unless they already have a higher one.
-- Returns true if it changed.
function Checkpoints.reach(player: Player, part: BasePart, order: number): boolean
	if current[player] == part then
		return false
	end
	local currentOrder = player:GetAttribute("Checkpoint")
	if type(currentOrder) == "number" and currentOrder > order then
		return false
	end
	current[player] = part
	player:SetAttribute("Checkpoint", order)
	return true
end

function Checkpoints.spawnCFrame(player: Player): CFrame?
	local part = current[player]
	return if part then spawnPoints[part] else nil
end

return Checkpoints
