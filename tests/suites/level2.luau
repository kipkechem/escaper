--!nonstrict
-- Level 2, the Switchboard: its puzzle sums, and its built geometry.

local roblox = require("@lune/roblox")

local t = require("../harness")
local Loader = require("../loader")
local RoomChecks = require("../room_checks")

local describe, it, expectEqual = t.describe, t.it, t.expectEqual

local Config = Loader.require("src/shared/Config.luau")
local GrabMath = Loader.require("src/shared/GrabMath.luau")
local LiftMath = Loader.require("src/shared/LiftMath.luau")
local Layout = Loader.require("src/server/Rooms/SwitchboardLayout.luau")
local Tower = Loader.require("src/server/Tower/Tower.luau")

describe("Switchboard puzzle numbers", function()
	local player = Config.Weight.Player
	local jump = 7.2
	-- A standing player's HumanoidRootPart is about 3 studs above their feet.
	local rootHeight = 3
	local reach = Config.Grab.Reach

	local crates, steel, fuses = {}, nil, {}
	for _, object in Layout.Objects do
		if object.kind == "crate" then
			table.insert(crates, object.mass)
		elseif object.kind == "steel" then
			steel = object
		else
			table.insert(fuses, object)
		end
	end
	table.sort(crates, function(a, b)
		return a > b
	end)
	local function sum(list: { number }, count: number?): number
		local total = 0
		for index, mass in list do
			if count and index > count then
				break
			end
			total += mass
		end
		return total
	end
	local allCrates = sum(crates)

	it("has three fuses, and enough sockets for the main exit to need all of them", function()
		expectEqual(#fuses, 3)
		expectEqual(#Layout.Sockets, 4) -- SocketM and three main sockets (socket H is on the rack)
	end)

	it("opens the fuse cage with crates but not with a player alone", function()
		assert(player < Layout.CagePlateMass, "a player alone opens the cage")
		assert(allCrates >= Layout.CagePlateMass, "not enough crates for the cage")
	end)

	it("needs you standing on the stack to load plate H", function()
		local twoBig = sum(crates, 2)
		assert(twoBig < Layout.PlateHMass, "two crates alone already load plate H")
		assert(twoBig + player >= Layout.PlateHMass, "two crates and a player do not load plate H")
	end)

	it("puts fuse 2 out of jumping reach but within reach from a two-crate stack", function()
		local plateTop = Layout.MezzanineHeight + 0.5
		local fuseBottom = Layout.ShelfHeight
		local jumping = plateTop + rootHeight + jump
		assert(fuseBottom - jumping > reach, "fuse 2 can be grabbed with a jump from the plate")
		local onStack = plateTop + 2 * Layout.CrateSize + rootHeight
		assert(fuseBottom - onStack <= reach, "fuse 2 is out of reach from two crates")
	end)

	it("makes 120 KG impossible alone without the steel crate", function()
		local everythingLiftable = allCrates + player + sum({ Layout.FuseMass })
		assert(
			everythingLiftable < Layout.PlateMainMass,
			"the main plate can be loaded without the steel crate"
		)
	end)

	it("can load the main plate with the steel crate, two 20s and you", function()
		assert(
			steel.mass + sum(crates, 2) + player >= Layout.PlateMainMass,
			"steel + 40 + player is not enough"
		)
	end)

	it("cannot lift the steel crate, or get it up the ramp", function()
		expectEqual(GrabMath.canLift(steel.mass), false)
		assert(
			steel.size.X > Layout.RampWidth and steel.size.Z > Layout.RampWidth,
			"the steel crate fits the ramp"
		)
		assert(Layout.CrateSize < Layout.RampWidth, "crates do not fit up the ramp")
	end)

	it("raises the steel crate on the lift with the cargo available", function()
		local lift = Layout.Lift
		local rider = steel.mass + lift.TareB
		local function rises(cargo: number): boolean
			return LiftMath.direction(cargo + lift.TareA, rider, Config.Lift.Deadband) == 1
		end
		assert(rises(allCrates), "all the crates do not lift the steel crate")
		assert(rises(player + 50), "you and 50 KG of crates do not lift the steel crate")
		assert(not rises(player + 40), "you and 40 KG already lift the steel crate (too easy)")
	end)

	it("lets one player ride the cargo side down into the pit", function()
		local lift = Layout.Lift
		expectEqual(LiftMath.direction(player + lift.TareA, lift.TareB, Config.Lift.Deadband), 1)
	end)

	it("lets two players skip the steel crate", function()
		assert(allCrates + 2 * player >= Layout.PlateMainMass, "two players and every crate fall short")
	end)
end)

describe("Switchboard geometry and wiring", function()
	local container = roblox.Instance.new("Folder")
	local room = Tower.buildLevel(container, "2")
	local tagged = RoomChecks.run(t, room, "2", {
		Grabbable = #Layout.Objects,
		PressurePlate = 3,
		Socket = 5,
		CounterweightLift = 1,
		Lever = 1,
		-- Cage door, pit hatch, three exits.
		Door = 5,
		Indicator = 3,
		Checkpoint = 1,
		RoomReset = 2,
	})

	it("sits on floor 2, turned round over Level 1's exit end", function()
		local floor = room:FindFirstChild("Floor", true)
		assert(floor, "no floor")
		local base = (2 - 1) * Config.Tower.FloorHeight
		local plate = room:FindFirstChild("PlateMain", true)
		assert(
			math.abs(plate.CFrame.Position.Y - (base + Layout.MezzanineHeight)) < 1e-3,
			"main plate height"
		)
	end)

	it("puts each exit's door in its opening, wired to its rule", function()
		for target, rule in Layout.ExitRules do
			local door = room:FindFirstChild("Exit" .. target, true)
			assert(door, "no door for " .. target)
			expectEqual(door:GetAttribute("Input"), rule.input, target)
			expectEqual(door:GetAttribute("Latch"), true, target)
		end
	end)

	it("gives every fuse the socket key", function()
		local count = 0
		for _, object in tagged.Grabbable do
			if object:GetAttribute("Key") == "Fuse" then
				count += 1
			end
		end
		expectEqual(count, 3)
		for _, socket in tagged.Socket do
			expectEqual(socket:GetAttribute("Key"), "Fuse")
			expectEqual(socket.CanQuery, false, socket.Name .. " must not block aiming")
		end
	end)
end)
