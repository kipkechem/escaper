--!strict
-- Server entry point.
-- 1. Collision groups and player setup.
-- 2. Build the tower: any level that is not already in Workspace.Rooms, and the connectors
--    between levels (Workspace.Tower.Connectors) if they are missing. A level baked into the
--    place, or edited by hand in Studio, is used as it is.
-- 3. Start grabbing, then give behaviour to every tagged part.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Binder = require(script.Services.Binder)
local GrabService = require(script.Services.GrabService)
local PlayerService = require(script.Services.PlayerService)
local Tower = require(script.Tower.Tower)

PlayerService.start()

local function folder(name: string): Instance
	local existing = workspace:FindFirstChild(name)
	if existing then
		return existing
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = name
	newFolder.Parent = workspace
	return newFolder
end

Tower.build(folder("Rooms"), folder("Tower"))

GrabService.start()

local components = script.Components
Binder.bind(Tags.Grabbable, require(components.Grabbable) :: any)
Binder.bind(Tags.PressurePlate, require(components.PressurePlate) :: any)
Binder.bind(Tags.Socket, require(components.Socket) :: any)
Binder.bind(Tags.Lever, require(components.Lever) :: any)
Binder.bind(Tags.CounterweightLift, require(components.CounterweightLift) :: any)
Binder.bind(Tags.Door, require(components.Door) :: any)
Binder.bind(Tags.Indicator, require(components.Indicator) :: any)
Binder.bind(Tags.Checkpoint, require(components.Checkpoint) :: any)
Binder.bind(Tags.RoomReset, require(components.RoomReset) :: any)
Binder.bind(Tags.RoomGoal, require(components.RoomGoal) :: any)

print("[Escaper] Server ready")
