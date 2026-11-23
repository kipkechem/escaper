--!strict
-- Sets up characters: collision group, jump height, and respawning at the last checkpoint.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local Checkpoints = require(script.Parent.Checkpoints)
local GrabService = require(script.Parent.GrabService)

local CHARACTER_GROUP = "Characters"

local PlayerService = {}

local function setupCollisionGroups()
	for _, group in { CHARACTER_GROUP, GrabService.HELD_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(GrabService.HELD_GROUP, CHARACTER_GROUP, false)
end

local function onCharacterAdded(player: Player, character: Model)
	local function assign(instance: Instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = CHARACTER_GROUP
		end
	end
	for _, descendant in character:GetDescendants() do
		assign(descendant)
	end
	character.DescendantAdded:Connect(assign)

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
	end

	local spawnCFrame = Checkpoints.spawnCFrame(player)
	if spawnCFrame then
		local rootPart = character:WaitForChild("HumanoidRootPart", 10)
		if rootPart then
			task.defer(function()
				if character.Parent then
					character:PivotTo(spawnCFrame)
				end
			end)
		end
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("JoinedAt", workspace:GetServerTimeNow())
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function PlayerService.start()
	setupCollisionGroups()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

PlayerService.CHARACTER_GROUP = CHARACTER_GROUP

return PlayerService
