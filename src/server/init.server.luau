--!strict
-- Server entry point.
-- 1. Collision groups and player setup.
-- 2. Build any room that is not already in the Workspace (so a room baked into the place,
--    or edited by hand in Studio, is used as it is).
-- 3. Start grabbing, then give behaviour to every tagged part.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Binder = require(script.Services.Binder)
local GrabService = require(script.Services.GrabService)
local PlayerService = require(script.Services.PlayerService)

PlayerService.start()

local rooms = workspace:FindFirstChild("Rooms")
if not rooms then
	local folder = Instance.new("Folder")
	folder.Name = "Rooms"
	folder.Parent = workspace
	rooms = folder
end

local roomBuilders = {
	require(script.Rooms.LoadingDock),
}
for _, builder in roomBuilders do
	if not (rooms :: Instance):FindFirstChild(builder.InstanceName) then
		builder.build(rooms :: Instance)
	end
end

GrabService.start()

local components = script.Components
Binder.bind(Tags.Grabbable, require(components.Grabbable) :: any)
Binder.bind(Tags.PressurePlate, require(components.PressurePlate) :: any)
Binder.bind(Tags.Lever, require(components.Lever) :: any)
Binder.bind(Tags.CounterweightLift, require(components.CounterweightLift) :: any)
Binder.bind(Tags.Door, require(components.Door) :: any)
Binder.bind(Tags.Indicator, require(components.Indicator) :: any)
Binder.bind(Tags.Checkpoint, require(components.Checkpoint) :: any)
Binder.bind(Tags.RoomReset, require(components.RoomReset) :: any)
Binder.bind(Tags.RoomGoal, require(components.RoomGoal) :: any)

print("[Escaper] Server ready")
