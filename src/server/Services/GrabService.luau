--!strict
-- Server side of grabbing. The client asks to grab; the server checks the request, hands
-- physics ownership of the object to that player (so carrying feels instant), and marks
-- it with the "HeldBy" attribute. The client then moves the object itself.
--
-- While held, an object is in the "Held" collision group, which does not collide with
-- characters: you cannot stand on what you are carrying, and it cannot shove you around.
-- After release the group is restored once the object is clear of every character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GrabMath = require(ReplicatedStorage.Shared.GrabMath)
local Grabbables = require(ReplicatedStorage.Shared.Grabbables)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestGrab = remotes:WaitForChild("RequestGrab") :: RemoteFunction
local releaseGrab = remotes:WaitForChild("ReleaseGrab") :: RemoteEvent

local HELD_GROUP = "Held"

type Hold = {
	root: Instance,
	rootPart: BasePart,
}

type PendingRestore = {
	root: Instance,
	deadline: number,
}

local GrabService = {}

local holds: { [Player]: Hold } = {}
local originalGroups: { [BasePart]: string } = {}
local pendingRestores: { [Instance]: PendingRestore } = {}
local releaseCount: { [Instance]: number } = {}

local function characterParts(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function setHeldGroup(root: Instance)
	for _, part in Grabbables.parts(root) do
		if originalGroups[part] == nil then
			originalGroups[part] = part.CollisionGroup
		end
		part.CollisionGroup = HELD_GROUP
	end
end

local function restoreGroup(root: Instance)
	for _, part in Grabbables.parts(root) do
		part.CollisionGroup = originalGroups[part] or "Default"
		originalGroups[part] = nil
	end
end

local function overlapsAnyCharacter(root: Instance): boolean
	local characters = characterParts()
	if #characters == 0 then
		return false
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = characters
	local cframe, size = Grabbables.bounds(root)
	return #workspace:GetPartBoundsInBox(cframe, size + Vector3.new(0.5, 0.5, 0.5), params) > 0
end

local function release(player: Player)
	local hold = holds[player]
	if not hold then
		return
	end
	holds[player] = nil

	local root = hold.root
	local rootPart = hold.rootPart
	if root:GetAttribute("HeldBy") == player.UserId then
		root:SetAttribute("HeldBy", nil)
	end

	pendingRestores[root] = { root = root, deadline = os.clock() + 3 }

	-- Let the thrower keep simulating the throw for a moment, then the server takes the
	-- object back, so objects at rest on lifts and plates are simulated by the server.
	local count = (releaseCount[root] or 0) + 1
	releaseCount[root] = count
	task.delay(Config.Grab.OwnershipHandBackDelay, function()
		if releaseCount[root] ~= count or Grabbables.heldBy(root) then
			return
		end
		if rootPart:IsDescendantOf(workspace) and not rootPart.Anchored then
			local ok = rootPart:CanSetNetworkOwnership()
			if ok then
				rootPart:SetNetworkOwner(nil)
			end
		end
	end)
end

local function onRequestGrab(player: Player, part: unknown): (boolean, string?)
	if typeof(part) ~= "Instance" or not (part :: Instance):IsA("BasePart") then
		return false, nil
	end
	local target = part :: BasePart
	if not target:IsDescendantOf(workspace) then
		return false, nil
	end
	local root = Grabbables.findRoot(target)
	if not root then
		return false, nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local characterRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not characterRoot then
		return false, nil
	end

	local holder = Grabbables.heldBy(root)
	if holder and holder ~= player.UserId then
		return false, "Someone else is holding that"
	end

	local rootPart = Grabbables.rootPart(root)
	if not rootPart or rootPart.Anchored then
		return false, "That is fixed in place"
	end

	if
		Grabbables.distanceTo(root, characterRoot.Position)
		> Config.Grab.Reach + Config.Grab.ServerReachSlack
	then
		return false, "Too far away"
	end

	local canOwn = rootPart:CanSetNetworkOwnership()
	if not canOwn then
		return false, "That cannot be moved right now"
	end

	if holds[player] then
		release(player)
	end

	rootPart:SetNetworkOwner(player)
	pendingRestores[root] = nil
	setHeldGroup(root)
	root:SetAttribute("HeldBy", player.UserId)
	holds[player] = { root = root, rootPart = rootPart }
	return true, nil
end

local function watchdog()
	for player, hold in holds do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local characterRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local root = hold.root
		local broken = not humanoid
			or humanoid.Health <= 0
			or not characterRoot
			or not root:IsDescendantOf(workspace)
			or hold.rootPart.Anchored
			or root:GetAttribute("HeldBy") ~= player.UserId
		if not broken and characterRoot then
			broken = Grabbables.distanceTo(root, characterRoot.Position) > Config.Grab.BreakDistance
		end
		if broken then
			release(player)
		end
	end

	local now = os.clock()
	for root, pending in pendingRestores do
		if Grabbables.heldBy(root) then
			pendingRestores[root] = nil
		elseif
			not root:IsDescendantOf(workspace)
			or now > pending.deadline
			or not overlapsAnyCharacter(root)
		then
			pendingRestores[root] = nil
			restoreGroup(root)
		end
	end
end

function GrabService.start()
	requestGrab.OnServerInvoke = onRequestGrab
	releaseGrab.OnServerEvent:Connect(function(player)
		release(player)
	end)
	Players.PlayerRemoving:Connect(release)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			watchdog()
		end
	end)
end

-- Drops whatever is holding `root` (used by room resets).
function GrabService.forceRelease(root: Instance)
	for player, hold in holds do
		if hold.root == root then
			release(player)
		end
	end
	if root:GetAttribute("HeldBy") ~= nil then
		root:SetAttribute("HeldBy", nil)
	end
end

-- Weight a player adds to a plate or lift through what they are carrying.
function GrabService.carriedWeight(player: Player): number
	local hold = holds[player]
	if not hold then
		return 0
	end
	return GrabMath.carriedWeight(hold.rootPart.AssemblyMass)
end

GrabService.HELD_GROUP = HELD_GROUP

return GrabService
