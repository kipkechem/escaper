--!nonstrict
-- Puts the rooms into a built place file, so they appear in Studio's edit mode and can be
-- edited by hand. Run from the repository root after `rojo build`:
--
--   rojo build -o build/escaper.rbxl
--   lune run tools/bake.luau build/escaper.rbxl
--
-- The server skips building any room that already exists in Workspace.Rooms.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Loader = require("../tests/loader")

local input = process.args[1] or "build/escaper.rbxl"
local output = process.args[2] or input

local game = roblox.deserializePlace(fs.readFile(input))
local workspace = game:GetService("Workspace")

local rooms = workspace:FindFirstChild("Rooms")
if not rooms then
	rooms = roblox.Instance.new("Folder")
	rooms.Name = "Rooms"
	rooms.Parent = workspace
end

local builders = {
	Loader.require("src/server/Rooms/LoadingDock.luau"),
}

for _, builder in builders do
	local existing = rooms:FindFirstChild(builder.InstanceName)
	if existing then
		existing:Destroy()
	end
	local room = builder.build(rooms)
	local parts = 0
	for _, descendant in room:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end
	print(string.format("Baked %s: %d parts", room.Name, parts))
end

fs.writeFile(output, roblox.serializePlace(game))
print("Wrote " .. output)
