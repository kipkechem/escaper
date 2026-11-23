--!nonstrict
-- Checks every built level must pass: it fits its footprint, loose objects start clear of
-- walls, lifts are clear along their travel, exits and entrance are open, every input is
-- wired to something, and checkpoints are numbered uniquely.

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local Geometry = require("./geometry")
local Loader = require("./loader")

local Expression = Loader.require("src/shared/Expression.luau")
local TowerMap = Loader.require("src/shared/TowerMap.luau")
local Placement = Loader.require("src/server/Tower/Placement.luau")

local RoomChecks = {}

local function collect(room: any): ({ [string]: { any } }, { any })
	local tagged: { [string]: { any } } = {}
	local solids = {}
	for _, instance in room:GetDescendants() do
		for _, tagName in instance:GetTags() do
			tagged[tagName] = tagged[tagName] or {}
			table.insert(tagged[tagName], instance)
		end
		if instance:IsA("BasePart") and instance.Anchored and instance.CanCollide then
			table.insert(solids, instance)
		end
	end
	return tagged, solids
end

local function isInside(instance: any, ancestor: any): boolean
	local current = instance
	while current do
		if current == ancestor then
			return true
		end
		current = current.Parent
	end
	return false
end

-- `t` is the harness; `expectedTags` maps tag names to how many the room should have.
function RoomChecks.run(t: any, room: any, levelId: string, expectedTags: { [string]: number })
	local tagged, solids = collect(room)
	local frame = Placement.levelFrame(levelId)
	local level = TowerMap.levels[levelId]

	t.it("tags the room and every puzzle part", function()
		t.expectEqual(room:HasTag("Room"), true, "Room tag")
		for tagName, count in expectedTags do
			t.expectEqual(#(tagged[tagName] or {}), count, tagName)
		end
	end)

	t.it("keeps everything inside the level's footprint", function()
		local envelope = Placement.envelope(levelId)
		for _, part in room:GetDescendants() do
			if part:IsA("BasePart") then
				local low, high = Geometry.partBox(part)
				assert(
					Geometry.inside(low, high, envelope.min, envelope.max, 0.01),
					string.format(
						"%s %s is outside %s",
						part:GetFullName(),
						Geometry.describe(low, high),
						envelope.name
					)
				)
			end
		end
	end)

	t.it("places every loose object clear of walls and floors", function()
		for _, object in tagged.Grabbable or {} do
			local minA, maxA = Geometry.partBox(object)
			for _, solid in solids do
				local depth = Geometry.overlap(minA, maxA, Geometry.partBox(solid))
				assert(
					depth <= 0.05,
					string.format("%s is inside %s by %.2f studs", object.Name, solid:GetFullName(), depth)
				)
			end
		end
	end)

	t.it("keeps lift platforms clear of the building along their whole travel", function()
		for _, lift in tagged.CounterweightLift or {} do
			local travel = lift:GetAttribute("Travel")
			local moves = {}
			for _, name in { "PlatformA", "PlatformB" } do
				local platform = lift:FindFirstChild(name)
				-- A sinks, B rises.
				local shift = if name == "PlatformA" then -travel else travel
				moves[platform] = shift
				for _, weld in lift:GetDescendants() do
					if weld:IsA("WeldConstraint") and weld.Part0 == platform then
						moves[weld.Part1] = shift
					end
				end
			end
			for part, shift in moves do
				local low, high = Geometry.partBox(part)
				local offset = Vector3.new(0, shift, 0)
				local sweptMin, sweptMax = low:Min(low + offset), high:Max(high + offset)
				for _, solid in solids do
					if isInside(solid, lift) then
						continue
					end
					local depth = Geometry.overlap(sweptMin, sweptMax, Geometry.partBox(solid))
					assert(
						depth <= 0,
						string.format("%s hits %s (%.2f studs)", part.Name, solid:GetFullName(), depth)
					)
				end
			end
		end
	end)

	t.it("leaves every exit and the entrance open (doors aside)", function()
		local openings = {}
		for _, exit in Placement.exits(levelId) do
			table.insert(openings, { name = "exit to " .. exit.target, box = Placement.exitOpening(exit) })
		end
		if #level.incoming > 0 then
			table.insert(openings, { name = "entrance", box = Placement.entranceOpening() })
		end
		for _, opening in openings do
			local low, high = Geometry.transformBox(frame, opening.box.min, opening.box.max)
			for _, solid in solids do
				if solid:HasTag("Door") then
					continue
				end
				local depth = Geometry.overlap(low, high, Geometry.partBox(solid))
				assert(depth <= 0.05, string.format("%s blocks the %s", solid:GetFullName(), opening.name))
			end
		end
	end)

	t.it("wires every input to a signal something in the room produces", function()
		local outputs = {}
		for _, list in tagged do
			for _, instance in list do
				local output = instance:GetAttribute("Output")
				if type(output) == "string" then
					outputs[output] = true
				end
			end
		end
		for _, tagName in { "Door", "Indicator" } do
			for _, instance in tagged[tagName] or {} do
				local compiled, err = Expression.compile(instance:GetAttribute("Input"))
				assert(compiled, instance.Name .. ": " .. tostring(err))
				for _, name in compiled.names do
					assert(
						outputs[name],
						string.format("%s listens for %q, which nothing outputs", instance.Name, name)
					)
				end
			end
		end
	end)

	t.it("numbers checkpoints uniquely, by floor", function()
		local seen = {}
		for _, checkpoint in tagged.Checkpoint or {} do
			local order = checkpoint:GetAttribute("Order")
			assert(type(order) == "number", checkpoint.Name .. " has no Order")
			assert(
				order // 10 == level.floor,
				string.format("%s: order %d is not on floor %d", checkpoint.Name, order, level.floor)
			)
			assert(not seen[order], "duplicate checkpoint " .. order)
			seen[order] = true
		end
	end)

	return tagged, solids
end

return RoomChecks
