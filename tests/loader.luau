--!nonstrict
-- Loads the game's ModuleScripts under Lune, outside Roblox.
-- Modules require each other with `script.Parent.Name`, so each one gets a fake
-- `script` whose Parent is a table mirroring the folder it lives in.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Loader = {}

local cache: { [string]: any } = {}
local folders: { [string]: any } = {}

local robloxGlobals = {
	Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	BrickColor = roblox.BrickColor,
	Enum = roblox.Enum,
	Instance = roblox.Instance,
	PhysicalProperties = roblox.PhysicalProperties,
	Font = roblox.Font,
}

-- Builds a table for `directory`: each `Name.luau` file or `Name/` folder is a field.
-- Done eagerly because Lune's file functions cannot run inside metamethods.
local function buildFolder(directory: string, parent: any?): any
	local folder = { Parent = parent, Name = string.match(directory, "[^/]+$") }
	folders[directory] = folder
	for _, entry in fs.readDir(directory) do
		local path = directory .. "/" .. entry
		if fs.isDir(path) then
			local child = buildFolder(path, folder)
			local init = path .. "/init.luau"
			if fs.isFile(init) then
				child.__modulePath = init
			end
			folder[entry] = child
		else
			local name = string.match(entry, "^(.-)%.luau$")
			if name and not string.match(name, "%.") then
				folder[name] = { __modulePath = path, Parent = folder, Name = name }
			end
		end
	end
	return folder
end

local function folderFor(directory: string): any
	if not folders[directory] then
		local parentDirectory = string.match(directory, "^(.*)/[^/]+$")
		local parent = if parentDirectory then folderFor(parentDirectory) else nil
		if not folders[directory] then
			buildFolder(directory, parent)
		end
	end
	return folders[directory]
end

function Loader.require(path: string): any
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = fs.readFile(path)
	local directory = string.match(path, "^(.*)/[^/]+$") or "."
	-- Lune copies the environment's own fields, so globals go in as plain fields.
	local environment: { [string]: any } = {
		script = { Parent = folderFor(directory), Name = "script" },
		require = function(target: any)
			if type(target) == "table" and target.__modulePath then
				return Loader.require(target.__modulePath)
			end
			return require(target)
		end,
	}
	for key, value in robloxGlobals do
		environment[key] = value
	end
	local chunk = luau.load(source, { debugName = path, environment = environment })
	local result = chunk()
	cache[path] = result
	return result
end

return Loader
