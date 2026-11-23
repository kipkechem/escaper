--!nonstrict
-- Puts the tower (every built level and the connectors between them) into a built place
-- file, so it appears in Studio's edit mode and can be edited by hand. Run from the
-- repository root after `rojo build`:
--
--   rojo build -o build/escaper.rbxl
--   lune run tools/bake.luau build/escaper.rbxl
--
-- Baking replaces whatever was baked before. The server only builds what is missing.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Loader = require("../tests/loader")

local input = process.args[1] or "build/escaper.rbxl"
local output = process.args[2] or input

local game = roblox.deserializePlace(fs.readFile(input))
local workspace = game:GetService("Workspace")

local function freshFolder(name: string)
	local existing = workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local folder = roblox.Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

local Tower = Loader.require("src/server/Tower/Tower.luau")
local rooms = freshFolder("Rooms")
local container = freshFolder("Tower")
Tower.build(rooms, container)

for _, room in rooms:GetChildren() do
	local parts = 0
	for _, descendant in room:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end
	print(string.format("Baked %s (%s): %d parts", room.Name, room:GetAttribute("RoomName"), parts))
end
local connectors = container:FindFirstChild("Connectors")
print(string.format("Baked %d connectors and pads", #connectors:GetChildren()))

fs.writeFile(output, roblox.serializePlace(game))
print("Wrote " .. output)
