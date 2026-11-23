--!strict
-- Weighs everything resting in a box: loose objects by their physics mass, players by
-- Config.Weight.Player plus whatever they are carrying. Used by plates and lifts.
--
-- Not counted: anchored parts, objects being carried (their weight goes through the
-- carrier instead), and objects moving fast (thrown, falling). A player counts while
-- standing, and for a moment after leaving the ground, so a jump does not flicker a plate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Grabbables = require(ReplicatedStorage.Shared.Grabbables)
local GrabService = require(script.Parent.GrabService)

local MassSensor = {}

local lastGrounded: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function isGrounded(character: Model, now: number): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		lastGrounded[character] = now
		return true
	end
	local last = lastGrounded[character]
	return last ~= nil and now - last <= Config.Weight.GroundedGrace
end

local function insideBox(cframe: CFrame, size: Vector3, point: Vector3): boolean
	local localPoint = cframe:PointToObjectSpace(point)
	local half = size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

export type Reading = {
	total: number,
	players: number,
	objects: number,
	-- Characters whose root is in the box (standing or not).
	characters: { Model },
}

-- `ignore` is a list of instances (and their descendants) to leave out, e.g. the plate.
function MassSensor.measure(cframe: CFrame, size: Vector3, ignore: { Instance }): Reading
	local now = os.clock()
	local reading: Reading = { total = 0, players = 0, objects = 0, characters = {} }

	local characters: { [Model]: boolean } = {}
	local exclude = table.clone(ignore)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			characters[character] = true
			table.insert(exclude, character)
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart and insideBox(cframe, size, rootPart.Position) then
				table.insert(reading.characters, character)
				if isGrounded(character, now) then
					reading.players += 1
					reading.total += Config.Weight.Player + GrabService.carriedWeight(player)
				end
			end
		end
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	local seen: { [BasePart]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(cframe, size, params) do
		if part.Anchored then
			continue
		end
		local assembly = part.AssemblyRootPart
		if not assembly or seen[assembly] or assembly.Anchored then
			continue
		end
		seen[assembly] = true
		local root = Grabbables.findRoot(part)
		if root and Grabbables.heldBy(root) then
			continue
		end
		if assembly.AssemblyLinearVelocity.Magnitude > Config.Weight.RestingSpeed then
			continue
		end
		reading.objects += 1
		reading.total += assembly.AssemblyMass
	end

	reading.total = math.floor(reading.total + 0.5)
	return reading
end

-- The box above the top face of `part`, `height` studs tall, inset slightly from the edges.
function MassSensor.columnAbove(part: BasePart, height: number): (CFrame, Vector3)
	local size = Vector3.new(math.max(part.Size.X - 0.2, 0.2), height, math.max(part.Size.Z - 0.2, 0.2))
	local cframe = part.CFrame * CFrame.new(0, part.Size.Y / 2 + height / 2, 0)
	return cframe, size
end

-- True if any loose object or character overlaps the box (used so lifts and doors
-- do not crush things).
function MassSensor.anythingIn(cframe: CFrame, size: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	for _, part in workspace:GetPartBoundsInBox(cframe, size, params) do
		if not part.Anchored or (part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")) then
			return true
		end
	end
	return false
end

return MassSensor
