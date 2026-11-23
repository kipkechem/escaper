--!strict
-- Builds the tower: each level that has a builder, at its place in the tower, and the
-- connectors between them. To add a level, write its builder in Rooms/ and register it in
-- `Tower.Builders` under its level id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerMap = require(ReplicatedStorage.Shared.TowerMap)
local Connectors = require(script.Parent.Connectors)
local Placement = require(script.Parent.Placement)

export type Context = Placement.Context

type Builder = {
	build: (parent: Instance, context: Context) -> Model,
}

local Tower = {}

Tower.Builders = {
	["1"] = require(script.Parent.Parent.Rooms.LoadingDock),
	["2"] = require(script.Parent.Parent.Rooms.Switchboard),
} :: { [string]: Builder }

function Tower.isBuilt(id: string): boolean
	return Tower.Builders[id] ~= nil
end

function Tower.instanceName(id: string): string
	return "Level" .. id
end

function Tower.context(id: string): Context
	local level = TowerMap.levels[id]
	assert(level, "unknown level " .. id)
	return {
		id = id,
		level = level,
		label = TowerMap.label(id),
		frame = Placement.levelFrame(id),
		exits = Placement.exits(id),
	}
end

function Tower.buildLevel(parent: Instance, id: string): Model
	local builder = Tower.Builders[id]
	assert(builder, "level " .. id .. " has no builder")
	local context = Tower.context(id)
	local room = builder.build(parent, context)
	room.Name = Tower.instanceName(id)
	room:SetAttribute("LevelId", id)
	room:SetAttribute("RoomName", context.label)
	return room
end

-- Builds whatever is missing: rooms into `rooms`, connectors into `container`.Connectors.
-- A room or connector set that already exists (baked into the place, or edited in Studio)
-- is left as it is.
function Tower.build(rooms: Instance, container: Instance)
	for _, level in TowerMap.ordered do
		if Tower.isBuilt(level.id) and not rooms:FindFirstChild(Tower.instanceName(level.id)) then
			Tower.buildLevel(rooms, level.id)
		end
	end
	if not container:FindFirstChild("Connectors") then
		Connectors.build(container, Tower.isBuilt)
	end
end

return Tower
