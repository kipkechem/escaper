--!nonstrict
-- Unit tests for the pure game logic. Run from the repository root with:
--   lune run tests/run.luau

local process = require("@lune/process")

local Loader = require("./loader")

local passed = 0
local failed = 0
local currentSuite = ""

local function describe(name: string, body: () -> ())
	currentSuite = name
	body()
end

local function it(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		print(string.format("FAIL  %s: %s\n      %s", currentSuite, name, tostring(err)))
	end
end

local function expectEqual(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(
			string.format(
				"%sexpected %s, got %s",
				if label then label .. ": " else "",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end

local function expectNear(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(
			string.format("%sexpected %.3f, got %.3f", if label then label .. ": " else "", expected, actual),
			2
		)
	end
end

local shared = "src/shared"
local Expression = Loader.require(shared .. "/Expression.luau")
local LiftMath = Loader.require(shared .. "/LiftMath.luau")
local GrabMath = Loader.require(shared .. "/GrabMath.luau")
local Config = Loader.require(shared .. "/Config.luau")
local Layout = Loader.require("src/server/Rooms/LoadingDockLayout.luau")

local function lookupFrom(values: { [string]: boolean })
	return function(name: string): boolean
		return values[name] == true
	end
end

describe("Expression", function()
	local function eval(source: string, values: { [string]: boolean }): boolean
		local compiled, err = Expression.compile(source)
		assert(compiled, err)
		return compiled.evaluate(lookupFrom(values))
	end

	it("reads a single name", function()
		expectEqual(eval("Plate", { Plate = true }), true)
		expectEqual(eval("Plate", {}), false)
	end)

	it("supports and / or / not with symbols and words", function()
		expectEqual(eval("A & B", { A = true, B = true }), true)
		expectEqual(eval("A & B", { A = true }), false)
		expectEqual(eval("A | B", { B = true }), true)
		expectEqual(eval("!A", {}), true)
		expectEqual(eval("A and not B", { A = true }), true)
		expectEqual(eval("A && B || C", { C = true }), true)
	end)

	it("gives and higher precedence than or", function()
		expectEqual(eval("A | B & C", { A = true }), true)
		expectEqual(eval("A | B & C", { B = true }), false)
		expectEqual(eval("(A | B) & C", { A = true }), false)
		expectEqual(eval("(A | B) & C", { A = true, C = true }), true)
	end)

	it("handles double negation and constants", function()
		expectEqual(eval("!!A", { A = true }), true)
		expectEqual(eval("true", {}), true)
		expectEqual(eval("false | A", { A = true }), true)
	end)

	it("lists each referenced name once", function()
		local compiled = Expression.compile("(A & B) | !A | Room.C")
		assert(compiled, "did not compile")
		expectEqual(#compiled.names, 3)
		expectEqual(compiled.names[1], "A")
		expectEqual(compiled.names[2], "B")
		expectEqual(compiled.names[3], "Room.C")
	end)

	it("rejects broken expressions with a message", function()
		for _, source in { "", "A &", "(A", "A B", "A $ B", ")" } do
			local compiled, err = Expression.compile(source)
			expectEqual(compiled, nil, source)
			assert(type(err) == "string" and #err > 0, "missing message for " .. source)
		end
	end)
end)

describe("LiftMath", function()
	it("holds still inside the deadband", function()
		expectEqual(LiftMath.direction(37, 35, 2), 0)
		expectEqual(LiftMath.direction(33, 35, 2), 0)
	end)

	it("moves towards the heavier side", function()
		expectEqual(LiftMath.direction(40, 35, 2), 1)
		expectEqual(LiftMath.direction(0, 10, 2), -1)
	end)

	it("speeds up with imbalance, within limits", function()
		local base = 5
		expectNear(LiftMath.speed(21, 20, base), base * 0.5, 1e-6, "small imbalance")
		expectNear(LiftMath.speed(40, 20, base), base, 1e-6, "imbalance of 20")
		expectNear(LiftMath.speed(200, 0, base), base * 1.5, 1e-6, "huge imbalance")
	end)

	it("clamps travel to the ends", function()
		expectEqual(LiftMath.step(15.9, 1, 5, 1, 16), 16)
		expectEqual(LiftMath.step(0.1, -1, 5, 1, 16), 0)
		expectNear(LiftMath.step(4, 1, 5, 0.1, 16), 4.5, 1e-6)
	end)
end)

describe("GrabMath", function()
	local capacity = Config.Grab.LiftCapacity

	it("lets players lift crates but only drag the pallet", function()
		expectEqual(GrabMath.canLift(10), true)
		expectEqual(GrabMath.canLift(20), true)
		expectEqual(GrabMath.canLift(capacity), true)
		expectEqual(GrabMath.canLift(60), false)
	end)

	it("throws light things fast and heavy things slowly", function()
		expectEqual(GrabMath.throwSpeed(10), Config.Grab.ThrowMaxSpeed)
		expectNear(GrabMath.throwSpeed(20), 45, 1e-6)
		expectEqual(GrabMath.throwSpeed(60), 0)
	end)

	it("slows walking more for heavier loads", function()
		assert(GrabMath.walkFactor(10) > GrabMath.walkFactor(20), "10 KG should be easier than 20 KG")
		assert(GrabMath.walkFactor(20) > GrabMath.walkFactor(60), "20 KG should be easier than 60 KG")
		expectEqual(GrabMath.walkFactor(1000), Config.Grab.MinWalkFactor)
	end)

	it("lifts liftable masses against the game's gravity", function()
		local gravity = 196.2
		local horizontal, vertical = GrabMath.holdForces(gravity)
		assert(vertical > capacity * gravity, "cannot lift the capacity mass")
		assert(vertical < 60 * gravity, "would lift the 60 KG pallet")
		assert(horizontal > vertical, "drag should be stronger than lift")
	end)
end)

-- The Loading Dock's numbers, checked against the same rules the game uses.
describe("Loading Dock puzzle numbers", function()
	local player = Config.Weight.Player
	local deadband = Config.Lift.Deadband
	local lift = Layout.Lift

	local function liftRises(cargo: number, rider: number): boolean
		return LiftMath.direction(cargo + lift.TareA, rider + lift.TareB, deadband) == 1
	end

	local function sum(masses: { number }): number
		local total = 0
		for _, mass in masses do
			total += mass
		end
		return total
	end

	local function cratesIn(zone: string): { number }
		local masses = {}
		for _, crate in Layout.Crates do
			if crate.zone == zone and GrabMath.canLift(crate.mass) then
				table.insert(masses, crate.mass)
			end
		end
		return masses
	end

	it("cannot climb out of the truck bay without a crate", function()
		local jump = 7.2
		assert(Layout.BayDepth > jump, "bay is shallow enough to jump out of")
		assert(Layout.BayDepth - Layout.CrateSize < jump - 1, "a crate is not enough of a step")
		expectEqual(#cratesIn("bay") >= 1, true)
	end)

	it("cannot open the shutter by standing on its plate alone", function()
		assert(player < Layout.ShutterPlateMass, "one player opens the shutter alone")
	end)

	it("can open the shutter with the dock crates", function()
		assert(sum(cratesIn("dock")) >= Layout.ShutterPlateMass, "not enough dock crates")
	end)

	it("lets the empty rider platform rest at the bottom", function()
		expectEqual(LiftMath.direction(lift.TareA, lift.TareB, deadband), -1)
	end)

	it("lifts a lone rider using only the lift-hall crates", function()
		expectEqual(liftRises(sum(cratesIn("hall")), player), true)
	end)

	it("does not lift a rider carrying a crate on lift-hall crates alone", function()
		local carried = 10
		local hall = sum(cratesIn("hall"))
		expectEqual(liftRises(hall, player + carried), false)
	end)

	it("lifts a rider carrying a crate once dock crates are brought through", function()
		local carried = 10
		local available = sum(cratesIn("hall")) + sum(cratesIn("dock")) + sum(cratesIn("bay")) - carried
		expectEqual(liftRises(available, player + carried), true)
	end)

	it("needs a carried crate (or a friend) on the exit plate", function()
		assert(player < Layout.ExitPlateMass, "one player alone opens the exit")
		assert(player + 10 >= Layout.ExitPlateMass, "a player with a small crate cannot open the exit")
		assert(player * 2 >= Layout.ExitPlateMass, "two players cannot open the exit")
	end)

	it("lets two players ride with one player plus a crate as cargo", function()
		expectEqual(liftRises(player + 20, player), true)
	end)

	it("raises the rider platform to the mezzanine", function()
		expectEqual(lift.Travel, Layout.MezzanineHeight)
	end)
end)

-- Build the room headlessly and check its geometry and wiring.
describe("Loading Dock geometry and wiring", function()
	local roblox = require("@lune/roblox")
	local Vector3 = roblox.Vector3
	local LoadingDock = Loader.require("src/server/Rooms/LoadingDock.luau")

	local container = roblox.Instance.new("Folder")
	local room = LoadingDock.build(container)

	local function aabb(cframe: CFrame, size: Vector3): (Vector3, Vector3)
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cframe:GetComponents()
		local half = size / 2
		local extent = Vector3.new(
			math.abs(r00) * half.X + math.abs(r01) * half.Y + math.abs(r02) * half.Z,
			math.abs(r10) * half.X + math.abs(r11) * half.Y + math.abs(r12) * half.Z,
			math.abs(r20) * half.X + math.abs(r21) * half.Y + math.abs(r22) * half.Z
		)
		return cframe.Position - extent, cframe.Position + extent
	end

	-- How deeply two boxes overlap (the smallest axis overlap; <= 0 means apart).
	local function overlap(minA: Vector3, maxA: Vector3, minB: Vector3, maxB: Vector3): number
		local x = math.min(maxA.X, maxB.X) - math.max(minA.X, minB.X)
		local y = math.min(maxA.Y, maxB.Y) - math.max(minA.Y, minB.Y)
		local z = math.min(maxA.Z, maxB.Z) - math.max(minA.Z, minB.Z)
		return math.min(x, y, z)
	end

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

	local function isInside(instance: any, ancestorName: string): boolean
		local current = instance
		while current do
			if current.Name == ancestorName then
				return true
			end
			current = current.Parent
		end
		return false
	end

	it("tags the room and every puzzle part", function()
		expectEqual(room:HasTag("Room"), true)
		expectEqual(#(tagged.Grabbable or {}), #Layout.Crates)
		expectEqual(#(tagged.PressurePlate or {}), 2)
		expectEqual(#(tagged.CounterweightLift or {}), 1)
		expectEqual(#(tagged.Lever or {}), 1)
		expectEqual(#(tagged.Door or {}), 3)
		expectEqual(#(tagged.Checkpoint or {}), 3)
		expectEqual(#(tagged.RoomReset or {}), 2)
		expectEqual(#(tagged.RoomGoal or {}), 1)
	end)

	it("places every crate clear of walls and floors", function()
		for _, crate in tagged.Grabbable do
			local minA, maxA = aabb(crate.CFrame, crate.Size)
			for _, solid in solids do
				local minB, maxB = aabb(solid.CFrame, solid.Size)
				local depth = overlap(minA, maxA, minB, maxB)
				assert(
					depth <= 0.05,
					string.format("%s is inside %s by %.2f studs", crate.Name, solid:GetFullName(), depth)
				)
			end
		end
	end)

	it("keeps both lift platforms clear of the building along their whole travel", function()
		local lift = tagged.CounterweightLift[1]
		local travel = lift:GetAttribute("Travel")
		for _, part in lift:GetDescendants() do
			if not part:IsA("BasePart") or part.Anchored and not string.find(part.Name, "Platform") then
				continue
			end
			if part.Name == "Girder" or string.find(part.Name, "Wheel") then
				continue
			end
			-- Railings follow their platform; work out which one from the position.
			local onB = part.CFrame.Position.X < 3.5
			local direction = if onB then 1 else -1
			local minA, maxA = aabb(part.CFrame, part.Size)
			local sweptMin = minA:Min(minA + Vector3.new(0, direction * travel, 0))
			local sweptMax = maxA:Max(maxA + Vector3.new(0, direction * travel, 0))
			for _, solid in solids do
				if isInside(solid, "FreightLift") then
					continue
				end
				local minB, maxB = aabb(solid.CFrame, solid.Size)
				local depth = overlap(sweptMin, sweptMax, minB, maxB)
				assert(
					depth <= 0,
					string.format("%s hits %s (%.2f studs)", part.Name, solid:GetFullName(), depth)
				)
			end
		end
	end)

	it("fills each door opening exactly when closed", function()
		local shutter = room:FindFirstChild("Shutter", true)
		local exitDoor = room:FindFirstChild("ExitDoor", true)
		expectEqual(shutter.Size, Vector3.new(10, 10, 2))
		expectEqual(exitDoor.Size, Vector3.new(6, 8, 2))
	end)

	it("wires every input to a signal something in the room produces", function()
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

	it("numbers checkpoints uniquely", function()
		local seen = {}
		for _, checkpoint in tagged.Checkpoint do
			local order = checkpoint:GetAttribute("Order")
			assert(type(order) == "number", checkpoint.Name .. " has no Order")
			assert(not seen[order], "duplicate checkpoint " .. order)
			seen[order] = true
		end
	end)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
