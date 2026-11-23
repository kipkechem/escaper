--!nonstrict
-- Level 1, the Loading Dock: its puzzle sums, and its built geometry.

local roblox = require("@lune/roblox")

local t = require("../harness")
local Loader = require("../loader")
local RoomChecks = require("../room_checks")

local describe, it, expectEqual = t.describe, t.it, t.expectEqual

local Config = Loader.require("src/shared/Config.luau")
local GrabMath = Loader.require("src/shared/GrabMath.luau")
local LiftMath = Loader.require("src/shared/LiftMath.luau")
local Layout = Loader.require("src/server/Rooms/LoadingDockLayout.luau")
local Tower = Loader.require("src/server/Tower/Tower.luau")

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

describe("Loading Dock geometry and wiring", function()
	local container = roblox.Instance.new("Folder")
	local room = Tower.buildLevel(container, "1")
	RoomChecks.run(t, room, "1", {
		Grabbable = #Layout.Crates,
		PressurePlate = 2,
		CounterweightLift = 1,
		Lever = 1,
		Door = 3,
		Checkpoint = 3,
		RoomReset = 2,
		RoomGoal = 0,
	})

	it("fills each door opening exactly when closed", function()
		local shutter = room:FindFirstChild("Shutter", true)
		local exitDoor = room:FindFirstChild("ExitDoor", true)
		expectEqual(shutter.Size, roblox.Vector3.new(10, 10, 2))
		expectEqual(exitDoor.Size, roblox.Vector3.new(6, 8, 2))
	end)
end)
